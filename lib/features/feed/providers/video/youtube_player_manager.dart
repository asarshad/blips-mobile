import 'dart:async';

import 'package:blips_mobile/core/config/memory_config.dart';
import 'package:blips_mobile/features/feed/providers/video/youtube_player_manager_base.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

/// Provider for the YouTube player manager that uses iframe-based playback.
/// This approach is more reliable than stream URL extraction which can break
/// when YouTube changes their backend.
final youtubePlayerManagerProvider =
    ChangeNotifierProvider<YoutubePlayerManagerBase>(
  (ref) => YoutubePlayerManager(),
);

/// Manages YouTube video players using iframe-based playback.
///
/// This uses the official YouTube IFrame Player API which is more reliable
/// than extracting stream URLs. The trade-off is slightly higher latency
/// but guaranteed compatibility.
///
/// Implements [WidgetsBindingObserver] to pause all videos when the app
/// is backgrounded, preserving [_currentActiveUrl] so [OptimizedReelsPage]
/// can resume the correct video on foreground.
class YoutubePlayerManager extends YoutubePlayerManagerBase
    with WidgetsBindingObserver {
  YoutubePlayerManager() {
    WidgetsBinding.instance.addObserver(this);
  }

  /// Maximum number of controllers to keep in memory.
  /// Configured via MemoryConfig.playerPoolSize.
  /// Lower values save memory. Higher values improve scroll smoothness.
  static int get maxControllers => MemoryConfig.playerPoolSize;

  final Map<String, YoutubePlayerController> _controllers = {};
  final Map<String, YTPlayerState> _states = {};
  final Map<String, YTPlayerError?> _errors = {};
  final Set<String> _pendingInit = {};

  /// The single URL that is currently intended to be playing.
  ///
  /// Set synchronously by [playVideo] and [onPageChanged] so that
  /// [_handleControllerUpdate] always knows which video should auto-play
  /// when its iframe fires the first `unStarted`/`cued` event — eliminating
  /// the race that existed when a `Set<String> _autoPlayUrls` was cleared by
  /// a concurrent `onPageChanged` microtask before the ready event fired.
  ///
  /// Intentionally *not* cleared by [_pauseAllForBackground] so that the
  /// correct video can be resumed when the app returns to the foreground.
  String? _currentActiveUrl;
  bool _isDisposed = false;

  /// Gets the controller for a URL if available.
  @override
  YoutubePlayerController? getController(String url) => _controllers[url];

  /// Gets the player state for a URL.
  @override
  YTPlayerState getState(String url) => _states[url] ?? YTPlayerState.idle;

  /// Gets any error that occurred for a URL.
  @override
  YTPlayerError? getError(String url) => _errors[url];

  /// Checks if a video is ready to play.
  @override
  bool isReady(String url) {
    final state = _states[url];
    return state == YTPlayerState.ready ||
        state == YTPlayerState.playing ||
        state == YTPlayerState.paused;
  }

  /// Checks if a video is currently playing.
  @override
  bool isPlaying(String url) => _states[url] == YTPlayerState.playing;

  /// Extracts YouTube video ID from various URL formats.
  @override
  String? extractVideoId(String url) {
    return YoutubePlayer.convertUrlToId(url);
  }

  /// Initializes a controller for the given URL without playing.
  @override
  Future<YoutubePlayerController?> initController(String url) async {
    if (_isDisposed) return null;

    // Already have a controller
    if (_controllers.containsKey(url)) {
      return _controllers[url];
    }

    // Already initializing
    if (_pendingInit.contains(url)) {
      return null;
    }

    final videoId = extractVideoId(url);
    if (videoId == null) {
      debugPrint('YoutubePlayerManager: Invalid YouTube URL: $url');
      _states[url] = YTPlayerState.error;
      _errors[url] = const YTPlayerError(
        code: -1,
        message: 'Invalid YouTube URL',
      );
      _notifySafe();
      return null;
    }

    _pendingInit.add(url);
    _states[url] = YTPlayerState.loading;
    _notifySafe();

    try {
      final controller = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: false,
          hideControls: true,
          hideThumbnail: true,
          showLiveFullscreenButton: false,
          disableDragSeek: true,
          loop: true,
          enableCaption: false,
          // Origin is automatically set by the package to match the app's scheme
        ),
      );

      if (_isDisposed) {
        controller.dispose();
        return null;
      }

      // Manage pool size
      await _managePoolSize(url);

      _controllers[url] = controller;
      _states[url] = YTPlayerState.ready;
      _errors[url] = null;

      // Set up error listener
      controller.addListener(() {
        if (_isDisposed) return;
        _handleControllerUpdate(url, controller);
      });

      if (kDebugMode) {
        debugPrint('YoutubePlayerManager: initController complete for $videoId'
            ' — state=${_states[url]}, pendingPlay=${_currentActiveUrl == url}');
      }
      // Note: Don't call play() here — iframe isn't mounted yet.
      // If this URL is _currentActiveUrl, _handleControllerUpdate will
      // auto-play once the `unStarted` event fires from the iframe.

      _notifySafe();
      return controller;
    } catch (e) {
      debugPrint('YoutubePlayerManager: Error initializing $url: $e');
      _states[url] = YTPlayerState.error;
      _errors[url] = YTPlayerError(code: -1, message: e.toString());
      _notifySafe();
      return null;
    } finally {
      _pendingInit.remove(url);
    }
  }

  void _handleControllerUpdate(String url, YoutubePlayerController controller) {
    final playerState = controller.value.playerState;
    final error = controller.value.errorCode;

    // Handle errors
    if (error != 0) {
      _states[url] = YTPlayerState.error;
      _errors[url] = YTPlayerError(
        code: error,
        message: _getErrorMessage(error),
      );
      debugPrint(
        'YoutubePlayerManager: Error $error for $url: ${_errors[url]?.message}',
      );
      _notifySafe();
      return;
    }

    // Auto-play when the iframe first becomes ready AND this is the intended
    // active video.  We only trigger on unStarted/cued — the very first states
    // after the WebView loads — so buffering events during normal playback
    // never re-trigger play().
    if (controller.value.isReady &&
        url == _currentActiveUrl &&
        (playerState == PlayerState.unStarted ||
            playerState == PlayerState.cued)) {
      if (kDebugMode) {
        debugPrint('YoutubePlayerManager: [auto-play] iframe ready → $url');
      }
      controller.play();
      // State will be updated by the subsequent playing/buffering events.
      return;
    }

    // Map iframe states to our state enum.
    final newState = switch (playerState) {
      PlayerState.playing => YTPlayerState.playing,
      PlayerState.paused => YTPlayerState.paused,
      PlayerState.ended => YTPlayerState.paused,
      PlayerState.buffering => _states[url] ?? YTPlayerState.loading,
      PlayerState.unStarted => YTPlayerState.ready,
      PlayerState.cued => YTPlayerState.ready,
      _ => _states[url] ?? YTPlayerState.loading,
    };

    if (_states[url] != newState) {
      _states[url] = newState;
      _notifySafe();
    }
  }

  String _getErrorMessage(int errorCode) {
    return switch (errorCode) {
      2 => 'Invalid video ID parameter',
      5 => 'HTML5 player error',
      100 => 'Video not found or has been removed',
      101 || 150 => 'Playback disabled by video owner',
      152 => 'Playback restricted (geographic or other)',
      153 => 'Video player configuration error',
      _ => 'Unknown error ($errorCode)',
    };
  }

  /// Plays a video. Initializes the controller if needed.
  ///
  /// Sets [_currentActiveUrl] so that when the iframe fires its first
  /// `unStarted` event (i.e. the WebView has finished loading), auto-play
  /// is triggered inside [_handleControllerUpdate].  If the controller is
  /// already fully loaded (`isReady == true`), `play()` is called immediately.
  @override
  Future<void> playVideo(String url) async {
    if (_isDisposed) return;

    if (kDebugMode) {
      debugPrint('YoutubePlayerManager: playVideo($url)'
          ' — ready=${_controllers[url]?.value.isReady}');
    }
    _currentActiveUrl = url;

    var controller = _controllers[url];

    // Start initialization if needed.
    if (controller == null && !_pendingInit.contains(url)) {
      controller = await initController(url);
    }

    // Guard against stale play requests: the user may have swiped to another
    // video while initController was awaiting, or the manager may have been
    // disposed. Either way, playing the old URL would cause ghost audio.
    if (_isDisposed || _currentActiveUrl != url) return;

    // If ready, play immediately.  The actual playing/buffering events from the
    // iframe will update _states[url] — we never set it optimistically here,
    // which prevents the UI from showing a frozen "playing" state.
    if (controller != null && controller.value.isReady) {
      if (kDebugMode) {
        debugPrint('YoutubePlayerManager: [play] controller ready → $url');
      }
      controller.play();
    } else {
      if (kDebugMode) {
        debugPrint(
            'YoutubePlayerManager: [play] controller not ready → armed for $url');
      }
    }
  }

  /// Pauses a video.
  @override
  void pauseVideo(String url) {
    if (kDebugMode) debugPrint('YoutubePlayerManager: pauseVideo($url)');
    // Clear active intent only for the specific video being paused so that
    // other videos (e.g. in the pool) do not accidentally inherit it.
    if (_currentActiveUrl == url) _currentActiveUrl = null;
    final controller = _controllers[url];
    if (controller != null) {
      controller.pause();
      _states[url] = YTPlayerState.paused;
      _notifySafe();
    }
  }

  /// Pauses all videos and clears the active-play intent.
  ///
  /// Use for tab-navigation pauses.  For app-background pauses use
  /// [_pauseAllForBackground] which preserves [_currentActiveUrl] so the
  /// correct video can be resumed when the app returns to foreground.
  @override
  void pauseAll() {
    if (kDebugMode) debugPrint('YoutubePlayerManager: pauseAll()');
    _currentActiveUrl = null;
    for (final entry in _controllers.entries) {
      entry.value.pause();
      _states[entry.key] = YTPlayerState.paused;
    }
    _notifySafe();
  }

  /// Pauses all videos WITHOUT clearing [_currentActiveUrl].
  ///
  /// Called when the app is backgrounded so the correct video can be
  /// resumed when the app returns to the foreground (handled by
  /// [OptimizedReelsPage] via its lifecycle observer).
  void _pauseAllForBackground() {
    if (kDebugMode)
      debugPrint('YoutubePlayerManager: _pauseAllForBackground()');
    for (final entry in _controllers.entries) {
      entry.value.pause();
      _states[entry.key] = YTPlayerState.paused;
    }
    _notifySafe();
  }

  // ── App Lifecycle ─────────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (kDebugMode) {
      debugPrint('YoutubePlayerManager: AppLifecycleState → $state');
    }
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        // Pause all but preserve _currentActiveUrl so the page-level
        // lifecycle observer can resume the correct video on foreground.
        _pauseAllForBackground();
      default:
        // 'resumed' is intentionally handled by OptimizedReelsPage's
        // lifecycle hook which has visibility awareness and knows whether
        // the Reels tab is currently on screen.
        break;
    }
  }

  @override
  void onPageChanged({
    required int currentIndex,
    required List<String> videoUrls,
  }) {
    if (_isDisposed) return;
    if (currentIndex < 0 || currentIndex >= videoUrls.length) return;

    final currentUrl = videoUrls[currentIndex];

    if (kDebugMode) {
      debugPrint(
          'YoutubePlayerManager: onPageChanged(index=$currentIndex, url=$currentUrl)');
    }

    // ── SYNCHRONOUS SECTION ─────────────────────────────────────────────────
    // Setting _currentActiveUrl synchronously is critical: if a preloaded
    // controller fires its `unStarted` event *before* the microtask below
    // runs, _handleControllerUpdate needs to see the correct target URL or
    // the video will be silently skipped.
    _currentActiveUrl = currentUrl;

    // Pause all other controllers synchronously to prevent audio bleed.
    for (final entry in _controllers.entries) {
      if (entry.key != currentUrl) {
        entry.value.pause();
        _states[entry.key] = YTPlayerState.paused;
      }
    }

    // Play current if the controller is already ready; otherwise
    // _handleControllerUpdate will auto-play when the iframe fires unStarted.
    final controller = _controllers[currentUrl];
    if (controller != null && controller.value.isReady) {
      if (kDebugMode) {
        debugPrint(
            'YoutubePlayerManager: [onPageChanged] playing ready controller → $currentUrl');
      }
      controller.play();
    }
    _notifySafe();
    // ── END SYNCHRONOUS SECTION ─────────────────────────────────────────────

    // Async: initialise current if missing, preload next, release old.
    Future.microtask(() async {
      if (_isDisposed || _currentActiveUrl != currentUrl) return; // stale swipe

      if (controller == null && !_pendingInit.contains(currentUrl)) {
        // Controller doesn't exist yet. initController sets _currentActiveUrl
        // isn't needed here since we already set it above; _handleControllerUpdate
        // will auto-play when the iframe fires its first event.
        await initController(currentUrl);
      }

      if (_isDisposed || _currentActiveUrl != currentUrl) return;

      // Preload next 3 videos in background.
      for (var i = 1; i <= 3; i++) {
        final nextIndex = currentIndex + i;
        if (nextIndex < videoUrls.length) {
          unawaited(initController(videoUrls[nextIndex]));
        }
      }

      // Keep 2 videos behind for back-swipe, release older ones.
      for (var i = 0; i < currentIndex - 2; i++) {
        if (i >= 0 && i < videoUrls.length) {
          releaseVideo(videoUrls[i]);
        }
      }
    });
  }

  /// Releases a specific video controller.
  void releaseVideo(String url) {
    if (kDebugMode) {
      debugPrint('YoutubePlayerManager: releaseVideo($url)');
    }
    // Clear pending init so retryVideo doesn't leave an orphaned listener.
    _pendingInit.remove(url);
    if (_currentActiveUrl == url) _currentActiveUrl = null;
    final controller = _controllers.remove(url);
    if (controller != null) {
      try {
        controller.dispose();
      } catch (e) {
        // Controller may already be disposed or in invalid state
        debugPrint(
          'YoutubePlayerManager: Error disposing controller for $url: $e',
        );
      }
    }
    _states.remove(url);
    _errors.remove(url);
    _notifySafe();
  }

  /// Releases all controllers.
  void releaseAll() {
    _currentActiveUrl = null;
    for (final entry in _controllers.entries) {
      try {
        entry.value.dispose();
      } catch (e) {
        // Controller may already be disposed or in invalid state
        debugPrint(
          'YoutubePlayerManager: Error disposing controller for ${entry.key}: $e',
        );
      }
    }
    _controllers.clear();
    _states.clear();
    _errors.clear();
    _notifySafe();
  }

  /// Retries a failed video.
  @override
  Future<void> retryVideo(String url) async {
    releaseVideo(url);
    await playVideo(url);
  }

  /// Manages pool size by disposing least recently used controllers.
  Future<void> _managePoolSize(String currentUrl) async {
    // Count pending inits to prevent bypassing the pool limit via concurrent calls.
    if (_controllers.length + _pendingInit.length <= maxControllers) return;

    // Find controllers to dispose (not current, not pending)
    final urlsToDispose = _controllers.keys
        .where((url) => url != currentUrl && url != _currentActiveUrl)
        .take(_controllers.length - maxControllers + 1)
        .toList();

    for (final url in urlsToDispose) {
      releaseVideo(url);
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
    for (final entry in _controllers.entries) {
      try {
        entry.value.dispose();
      } catch (e) {
        debugPrint(
          'YoutubePlayerManager: Error disposing controller on manager dispose: $e',
        );
      }
    }
    _controllers.clear();
    _states.clear();
    _errors.clear();
    _pendingInit.clear();
    _currentActiveUrl = null;
    super.dispose();
  }
}
