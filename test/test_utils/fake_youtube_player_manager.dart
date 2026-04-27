import 'package:blips_mobile/features/feed/providers/video/youtube_player_manager_base.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

/// Fake YouTube manager that never creates WebViews/controllers.
///
/// Use this in widget/golden tests to avoid platform video dependencies.
final class FakeYoutubePlayerManager extends YoutubePlayerManagerBase {
  final Map<String, YTPlayerState> _states = {};
  final Map<String, YTPlayerError?> _errors = {};
  final Map<String, YTPlaybackOverlayState> _overlayStates = {};
  bool _isDisposed = false;

  void _notifySafe() {
    Future.microtask(() {
      if (_isDisposed) return;
      notifyListeners();
    });
  }

  void setState(String url, YTPlayerState state) {
    _states[url] = state;
    _notifySafe();
  }

  void setError(String url, YTPlayerError? error) {
    _errors[url] = error;
    _notifySafe();
  }

  void setPlaybackOverlayState(String url, YTPlaybackOverlayState state) {
    _overlayStates[url] = state;
    _notifySafe();
  }

  @override
  YoutubePlayerController? getController(String url) => null;

  @override
  YTPlayerError? getError(String url) => _errors[url];

  @override
  YTPlayerState getState(String url) => _states[url] ?? YTPlayerState.idle;

  @override
  YTPlaybackOverlayState getPlaybackOverlayState(String url) {
    final state = getState(url);
    if (state == YTPlayerState.error) {
      return YTPlaybackOverlayState.error;
    }
    if (state == YTPlayerState.playing) {
      return YTPlaybackOverlayState.none;
    }
    final override = _overlayStates[url];
    if (override != null) {
      return override;
    }
    return switch (state) {
      YTPlayerState.paused => YTPlaybackOverlayState.manualPause,
      YTPlayerState.ready ||
      YTPlayerState.loading ||
      YTPlayerState.idle =>
        YTPlaybackOverlayState.autoplayPending,
      YTPlayerState.error ||
      YTPlayerState.playing =>
        YTPlaybackOverlayState.none,
    };
  }

  @override
  bool isPlaying(String url) => getState(url) == YTPlayerState.playing;

  @override
  bool isReady(String url) {
    final state = getState(url);
    return state == YTPlayerState.ready ||
        state == YTPlayerState.playing ||
        state == YTPlayerState.paused;
  }

  @override
  String? extractVideoId(String url) => YoutubePlayer.convertUrlToId(url);

  @override
  Future<YoutubePlayerController?> initController(String url) async {
    // No-op: do not create controllers in tests.
    final existing = _states[url];
    _states[url] = switch (existing) {
      YTPlayerState.playing => YTPlayerState.playing,
      YTPlayerState.paused => YTPlayerState.paused,
      YTPlayerState.ready => YTPlayerState.ready,
      _ => YTPlayerState.ready,
    };
    _notifySafe();
    return null;
  }

  @override
  Future<void> playVideo(String url) async {
    _states[url] = YTPlayerState.playing;
    _overlayStates[url] = YTPlaybackOverlayState.none;
    _notifySafe();
  }

  @override
  Future<void> retryVideo(String url) async {
    // No-op retry: just set to playing again.
    await playVideo(url);
  }

  @override
  void pauseAll() {
    for (final entry in _states.entries.toList()) {
      if (entry.value == YTPlayerState.playing) {
        _states[entry.key] = YTPlayerState.paused;
      }
    }
    _notifySafe();
  }

  @override
  void pauseVideo(String url) {
    _states[url] = YTPlayerState.paused;
    _overlayStates[url] = YTPlaybackOverlayState.manualPause;
    _notifySafe();
  }

  @override
  void onPageChanged({
    required int currentIndex,
    required List<String> videoUrls,
    int? preloadAhead,
  }) {
    if (currentIndex < 0 || currentIndex >= videoUrls.length) return;
    final currentUrl = videoUrls[currentIndex];
    for (final entry in _states.entries.toList()) {
      if (entry.key != currentUrl && entry.value == YTPlayerState.playing) {
        _states[entry.key] = YTPlayerState.paused;
        _overlayStates[entry.key] = YTPlaybackOverlayState.manualPause;
      }
    }
    for (final url in videoUrls) {
      _states[url] =
          url == currentUrl ? YTPlayerState.playing : YTPlayerState.paused;
      _overlayStates[url] = url == currentUrl
          ? YTPlaybackOverlayState.none
          : YTPlaybackOverlayState.manualPause;
    }
    _notifySafe();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
