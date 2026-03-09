import 'package:blips_mobile/features/feed/providers/video/youtube_player_manager_base.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

/// Fake YouTube manager that never creates WebViews/controllers.
///
/// Use this in widget/golden tests to avoid platform video dependencies.
final class FakeYoutubePlayerManager extends YoutubePlayerManagerBase {
  final Map<String, YTPlayerState> _states = {};
  final Map<String, YTPlayerError?> _errors = {};
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

  @override
  YoutubePlayerController? getController(String url) => null;

  @override
  YTPlayerError? getError(String url) => _errors[url];

  @override
  YTPlayerState getState(String url) => _states[url] ?? YTPlayerState.idle;

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
  String? extractVideoId(String url) => null;

  @override
  Future<YoutubePlayerController?> initController(String url) async {
    // No-op: do not create controllers in tests.
    _states[url] = YTPlayerState.ready;
    _notifySafe();
    return null;
  }

  @override
  Future<void> playVideo(String url) async {
    _states[url] = YTPlayerState.playing;
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
    for (final url in videoUrls) {
      _states[url] =
          url == currentUrl ? YTPlayerState.playing : YTPlayerState.paused;
    }
    _notifySafe();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
