import 'dart:async';

import 'package:blips_mobile/core/config/memory_config.dart';
import 'package:blips_mobile/core/diagnostics/app_diagnostics.dart';
import 'package:blips_mobile/features/feed/providers/video/youtube_player_manager_base.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

// ── Controller factory (injectable for tests) ─────────────────────────────

typedef ControllerFactory = YoutubePlayerController Function(String videoId);

YoutubePlayerController _defaultFactory(String videoId) {
  return YoutubePlayerController(
    initialVideoId: videoId,
    flags: const YoutubePlayerFlags(
      autoPlay: true,
      mute: true,
      hideControls: true,
      hideThumbnail: true,
      showLiveFullscreenButton: false,
      disableDragSeek: true,
      loop: true,
      enableCaption: false,
    ),
  );
}

// ── Slot ──────────────────────────────────────────────────────────────────

class _Slot {
  _Slot({required this.controller, required this.url});
  final YoutubePlayerController controller;
  final String url;
  DateTime lastTouched = DateTime.now();
  VoidCallback? listener;
  // True while we muted for autoplay; cleared once playing so we can unmute.
  bool mutedForAutoplay = false;
}

// ── Provider ──────────────────────────────────────────────────────────────

final youtubePlayerManagerProvider =
    ChangeNotifierProvider<YoutubePlayerManagerBase>(
  (ref) => YoutubePlayerManager(
    diagnostics: ref.watch(appDiagnosticsProvider),
  ),
);

// ── Manager ───────────────────────────────────────────────────────────────

/// Manages YouTube iframe players for both the Videos and Reels screens.
///
/// Keeps a fixed-size pool of [YoutubePlayerController]s (one WKWebView each)
/// so memory stays bounded regardless of feed length. When the pool is full,
/// the least-recently-used controller outside the keep-window is synchronously
/// disposed — disposal is the only reliable way to stop audio on iOS when
/// [controller.pause()] is silently ignored by WKWebView.
///
/// State is read directly from [YoutubePlayerController.value]; there are no
/// shadow maps to get out of sync. A single per-active-URL stall timer
/// transitions the overlay to [YTPlaybackOverlayState.autoplayStalled] if the
/// video has not started playing within [_stallDuration].
class YoutubePlayerManager extends YoutubePlayerManagerBase
    with WidgetsBindingObserver {
  YoutubePlayerManager({
    AppDiagnosticsController? diagnostics,
    ControllerFactory? controllerFactory,
  })  : _diagnostics = diagnostics,
        _controllerFactory = controllerFactory ?? _defaultFactory {
    WidgetsBinding.instance.addObserver(this);
  }

  static int get maxControllers => MemoryConfig.playerPoolSize;
  static const _stallDuration = Duration(seconds: 5);

  // ignore: unused_field — kept for future diagnostics wiring
  final AppDiagnosticsController? _diagnostics;
  final ControllerFactory _controllerFactory;

  final List<_Slot> _slots = [];
  final Map<String, _Slot> _slotByUrl = {};

  String? _currentActiveUrl;
  final Set<String> _userPausedUrls = {};
  final Set<String> _stalledUrls = {};

  Timer? _stallTimer;
  bool _isDisposed = false;

  // ── Pool management ───────────────────────────────────────────────────

  /// Returns the slot for [url], creating one if absent.
  /// Evicts the LRU non-active slot when the pool is full.
  _Slot? _ensureSlot(String url) {
    if (_isDisposed) return null;

    final existing = _slotByUrl[url];
    if (existing != null) {
      existing.lastTouched = DateTime.now();
      return existing;
    }

    final videoId = extractVideoId(url);
    if (videoId == null) {
      if (kDebugMode) debugPrint('YoutubePlayerManager: invalid URL $url');
      return null;
    }

    while (_slots.length >= maxControllers) {
      _evictLru();
    }

    final controller = _controllerFactory(videoId);
    final slot = _Slot(controller: controller, url: url);
    _slots.add(slot);
    _slotByUrl[url] = slot;

    void listener() {
      if (_isDisposed) return;
      if (_slotByUrl[url] != slot) return; // stale after release+recreate

      final playerState = controller.value.playerState;
      // isActuallyPlaying uses only the iframe playerState — not position —
      // so it is false when the video is paused at a non-zero position.
      // position.inMilliseconds > 250 stays true after a pause, so if we
      // used it here we would immediately re-clear the user-pause intent
      // that pauseVideo() just set, making the play button vanish on device.
      final isActuallyPlaying = playerState == PlayerState.playing;
      // For stall detection we still use the position heuristic: a video
      // whose position has advanced is not stalled, even if playerState lags.
      final isPlaying = isActuallyPlaying ||
          controller.value.position.inMilliseconds > 250;

      if (isPlaying) {
        _stalledUrls.remove(url);
      }

      if (isActuallyPlaying) {
        _userPausedUrls.remove(url);
        // Unmute now that playback has started — we muted to satisfy iOS's
        // requirement that the first programmatic play be muted.
        if (slot.mutedForAutoplay) {
          slot.mutedForAutoplay = false;
          try {
            controller.unMute();
          } catch (_) {}
        }
      }

      // Re-issue play() when the iframe becomes ready for the active URL.
      // playVideo() is called before the WebView finishes loading, so that
      // initial play() is silently dropped. The iframe fires unStarted/cued
      // once it's ready — that's when we re-issue the command.
      if (controller.value.isReady &&
          url == _currentActiveUrl &&
          !_userPausedUrls.contains(url) &&
          !isPlaying &&
          (playerState == PlayerState.unStarted ||
              playerState == PlayerState.cued)) {
        try {
          controller.play();
        } catch (_) {}
      }

      _notifySafe();
    }

    slot.listener = listener;
    controller.addListener(listener);

    if (kDebugMode) {
      debugPrint(
          'YoutubePlayerManager: created slot for $videoId (pool=${_slots.length})');
    }
    return slot;
  }

  /// Disposes and removes the slot for [url]. Safe to call when no slot exists.
  void _releaseSlot(String url) {
    final slot = _slotByUrl.remove(url);
    if (slot == null) return;
    _slots.remove(slot);
    _userPausedUrls.remove(url);
    _stalledUrls.remove(url);
    if (_currentActiveUrl == url) _currentActiveUrl = null;
    if (kDebugMode) {
      debugPrint(
          'YoutubePlayerManager: releasing $url (pool=${_slots.length})');
    }
    // Remove listener before disposal to prevent stale callbacks.
    if (slot.listener != null) {
      slot.controller.removeListener(slot.listener!);
      slot.listener = null;
    }
    try {
      slot.controller.dispose();
    } catch (e) {
      debugPrint('YoutubePlayerManager: dispose error for $url: $e');
    }
  }

  void _evictLru() {
    if (_slots.isEmpty) return;
    // Prefer evicting non-active slots; fall back to the oldest slot overall
    // when all slots are the active URL (e.g. maxControllers == 1).
    final nonActive =
        _slots.where((s) => s.url != _currentActiveUrl).toList();
    final candidate = nonActive.isNotEmpty
        ? nonActive.reduce(
            (a, b) => a.lastTouched.isBefore(b.lastTouched) ? a : b)
        : _slots.reduce(
            (a, b) => a.lastTouched.isBefore(b.lastTouched) ? a : b);
    if (kDebugMode) {
      debugPrint('YoutubePlayerManager: LRU evicting ${candidate.url}');
    }
    _releaseSlot(candidate.url);
  }

  // ── Stall detection ───────────────────────────────────────────────────

  void _armStallTimer(String url) {
    _stallTimer?.cancel();
    _stallTimer = Timer(_stallDuration, () {
      if (_isDisposed || _currentActiveUrl != url) return;
      final ctrl = _slotByUrl[url]?.controller;
      if (ctrl == null) return;
      final playing = ctrl.value.playerState == PlayerState.playing ||
          ctrl.value.position.inMilliseconds > 250;
      if (!playing && !_userPausedUrls.contains(url)) {
        if (kDebugMode) {
          debugPrint('YoutubePlayerManager: autoplay stalled for $url');
        }
        _stalledUrls.add(url);
        _notifySafe();
      }
    });
  }

  // ── Public accessors ──────────────────────────────────────────────────

  @override
  YoutubePlayerController? getController(String url) =>
      _slotByUrl[url]?.controller;

  @override
  String? extractVideoId(String url) => YoutubePlayer.convertUrlToId(url);

  @override
  YTPlayerState getState(String url) {
    final ctrl = _slotByUrl[url]?.controller;
    if (ctrl == null) return YTPlayerState.idle;
    if (ctrl.value.errorCode != 0) return YTPlayerState.error;
    if (_userPausedUrls.contains(url)) return YTPlayerState.paused;
    return switch (ctrl.value.playerState) {
      PlayerState.playing => YTPlayerState.playing,
      PlayerState.paused => YTPlayerState.paused,
      PlayerState.ended => YTPlayerState.paused,
      PlayerState.buffering => ctrl.value.isReady
          ? YTPlayerState.ready
          : YTPlayerState.loading,
      PlayerState.unStarted => YTPlayerState.ready,
      PlayerState.cued => YTPlayerState.ready,
      _ =>
        ctrl.value.isReady ? YTPlayerState.ready : YTPlayerState.loading,
    };
  }

  @override
  YTPlayerError? getError(String url) {
    final code = _slotByUrl[url]?.controller.value.errorCode ?? 0;
    if (code == 0) return null;
    return YTPlayerError(code: code, message: _errorMessage(code));
  }

  @override
  YTPlaybackOverlayState getPlaybackOverlayState(String url) {
    final ctrl = _slotByUrl[url]?.controller;

    if (ctrl == null) {
      return url == _currentActiveUrl
          ? YTPlaybackOverlayState.autoplayPending
          : YTPlaybackOverlayState.none;
    }

    if (ctrl.value.errorCode != 0) return YTPlaybackOverlayState.error;

    // Check user-paused BEFORE the position heuristic. Once a video has
    // played past 250 ms, position stays > 250 even while paused — if we
    // checked position first we would skip the manualPause branch and the
    // play button would never appear after a tap-to-pause on a real device.
    if (_userPausedUrls.contains(url)) {
      return YTPlaybackOverlayState.manualPause;
    }

    final playing = ctrl.value.playerState == PlayerState.playing ||
        ctrl.value.position.inMilliseconds > 250;
    if (playing) return YTPlaybackOverlayState.none;
    if (_stalledUrls.contains(url)) {
      return YTPlaybackOverlayState.autoplayStalled;
    }
    if (url == _currentActiveUrl) {
      return YTPlaybackOverlayState.autoplayPending;
    }
    return YTPlaybackOverlayState.none;
  }

  @override
  bool isReady(String url) {
    final s = getState(url);
    return s == YTPlayerState.ready ||
        s == YTPlayerState.playing ||
        s == YTPlayerState.paused;
  }

  @override
  bool isPlaying(String url) => getState(url) == YTPlayerState.playing;

  // ── Playback API ──────────────────────────────────────────────────────

  @override
  Future<YoutubePlayerController?> initController(String url) async {
    if (_isDisposed) return null;
    final slot = _ensureSlot(url);
    _notifySafe();
    return slot?.controller;
  }

  @override
  Future<void> playVideo(String url) async {
    if (_isDisposed) return;

    _currentActiveUrl = url;
    _userPausedUrls.remove(url);
    _stalledUrls.remove(url);
    _armStallTimer(url);

    final slot = _ensureSlot(url);
    if (_isDisposed || _currentActiveUrl != url) return;

    if (slot != null) {
      slot.mutedForAutoplay = true;
      try {
        slot.controller.play();
      } catch (e) {
        if (kDebugMode) debugPrint('YoutubePlayerManager: play() threw: $e');
      }
    }
    _notifySafe();
  }

  @override
  Future<void> ensurePlayback(String url) => playVideo(url);

  @override
  void pauseVideo(String url) {
    if (_currentActiveUrl == url) {
      _currentActiveUrl = null;
      _stallTimer?.cancel();
    }
    _userPausedUrls.add(url);
    _stalledUrls.remove(url);
    try {
      _slotByUrl[url]?.controller.pause();
    } catch (_) {}
    _notifySafe();
  }

  @override
  void pauseAll() {
    _stallTimer?.cancel();
    _currentActiveUrl = null;
    for (final slot in _slots) {
      try {
        slot.controller.pause();
      } catch (_) {}
    }
    _notifySafe();
  }

  void _pauseAllForBackground() {
    _stallTimer?.cancel();
    // Preserve _currentActiveUrl so the correct video resumes on foreground.
    for (final slot in _slots) {
      try {
        slot.controller.pause();
      } catch (_) {}
    }
    _notifySafe();
  }

  @override
  Future<void> retryVideo(String url) async {
    _releaseSlot(url);
    await playVideo(url);
  }

  void releaseVideo(String url) => _releaseSlot(url);

  @override
  void onPageChanged({
    required int currentIndex,
    required List<String> videoUrls,
    int? preloadAhead,
  }) {
    if (_isDisposed) return;
    if (currentIndex < 0 || currentIndex >= videoUrls.length) return;

    final currentUrl = videoUrls[currentIndex];

    // No-op when nothing has actually changed. The shell page watches this
    // manager (so any pause notify rebuilds it), which causes the Videos
    // FeedTab to recompute a new feed list and re-fire its preloading
    // useEffect. Without this guard, every tap-to-pause would trigger
    // onPageChanged → clear _userPausedUrls → playVideo → instant resume.
    if (_userPausedUrls.contains(currentUrl)) {
      return;
    }

    _currentActiveUrl = currentUrl;
    _stallTimer?.cancel();
    _stalledUrls.remove(currentUrl);
    _userPausedUrls.remove(currentUrl);

    // Compute keep-window.
    final ahead = (preloadAhead ?? MemoryConfig.reelPreloadCount)
        .clamp(0, maxControllers > 0 ? maxControllers - 1 : 0);
    final behind = (maxControllers - ahead - 1).clamp(0, maxControllers);

    final keepUrls = <String>{currentUrl};
    for (var i = 1; i <= ahead; i++) {
      final idx = currentIndex + i;
      if (idx < videoUrls.length) keepUrls.add(videoUrls[idx]);
    }
    for (var i = 1; i <= behind; i++) {
      final idx = currentIndex - i;
      if (idx >= 0) keepUrls.add(videoUrls[idx]);
    }

    // Synchronously release out-of-window controllers.
    // Dispose is the only reliable way to stop audio on iOS when pause is ignored.
    for (final url in _slotByUrl.keys.toList()) {
      if (!keepUrls.contains(url)) {
        _releaseSlot(url);
      } else if (url != currentUrl) {
        final s = _slotByUrl[url];
        if (s != null) {
          final ps = s.controller.value.playerState;
          // Only pause controllers that are actively playing/buffering.
          // Preloaded controllers in unStarted/cued state must stay there —
          // iOS blocks muted programmatic play from paused state when no
          // media session has ever been established.
          if (ps == PlayerState.playing || ps == PlayerState.buffering) {
            try {
              s.controller.pause();
            } catch (_) {}
          }
        }
      }
    }

    // playVideo arms the stall timer — don't arm it separately here.
    unawaited(playVideo(currentUrl));

    // Preload ahead in the background.
    Future.microtask(() {
      if (_isDisposed || _currentActiveUrl != currentUrl) return;
      for (var i = 1; i <= ahead; i++) {
        final idx = currentIndex + i;
        if (idx < videoUrls.length) _ensureSlot(videoUrls[idx]);
      }
    });
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        _pauseAllForBackground();
      default:
        break;
    }
  }

  void _notifySafe() {
    if (!_isDisposed) {
      Future.microtask(() {
        if (!_isDisposed) notifyListeners();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _isDisposed = true;
    _stallTimer?.cancel();
    for (final slot in _slots) {
      if (slot.listener != null) {
        slot.controller.removeListener(slot.listener!);
        slot.listener = null;
      }
      try {
        slot.controller.dispose();
      } catch (_) {}
    }
    _slots.clear();
    _slotByUrl.clear();
    super.dispose();
  }

  String _errorMessage(int code) => switch (code) {
        2 => 'Invalid video ID',
        5 => 'HTML5 player error',
        100 => 'Video not found or removed',
        101 || 150 => 'Playback disabled by owner',
        152 => 'Playback restricted',
        153 => 'Player configuration error',
        _ => 'Unknown error ($code)',
      };
}
