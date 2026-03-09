import 'package:flutter/foundation.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

/// Player state for YouTube iframe players.
enum YTPlayerState {
  /// No player initialized yet.
  idle,

  /// Controller created, waiting for WebView to load.
  loading,

  /// Ready to play.
  ready,

  /// Currently playing.
  playing,

  /// Paused.
  paused,

  /// Error occurred (e.g., video unavailable, playback disabled).
  error,
}

/// Information about an error that occurred during playback.
class YTPlayerError {
  const YTPlayerError({required this.code, required this.message});

  final int code;
  final String message;

  /// Error 150/152: Playback disabled by video owner.
  bool get isPlaybackDisabled => code == 150 || code == 152;

  /// Error 153: Video player configuration error (usually origin mismatch).
  bool get isConfigError => code == 153;

  /// Error 100/101: Video not found or private.
  bool get isVideoUnavailable => code == 100 || code == 101;
}

/// Contract for YouTube playback management.
///
/// This exists so tests can provide a fake implementation that does not create
/// WebViews or require network/video playback.
abstract class YoutubePlayerManagerBase extends ChangeNotifier {
  YoutubePlayerController? getController(String url);

  YTPlayerState getState(String url);

  YTPlayerError? getError(String url);

  bool isReady(String url);

  bool isPlaying(String url);

  String? extractVideoId(String url);

  Future<YoutubePlayerController?> initController(String url);

  Future<void> playVideo(String url);

  Future<void> retryVideo(String url);

  void pauseVideo(String url);

  void pauseAll();

  void onPageChanged({
    required int currentIndex,
    required List<String> videoUrls,
    int? preloadAhead,
  });
}
