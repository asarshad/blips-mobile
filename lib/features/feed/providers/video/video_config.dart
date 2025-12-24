/// Configuration constants for the video player pool.
/// 
/// These values control memory usage and preloading behavior.
class VideoPoolConfig {
  const VideoPoolConfig._();

  /// Number of video players to maintain in the pool.
  /// Higher values use more memory but enable faster switching.
  static const int poolSize = 5;

  /// Number of videos ahead to preload when scrolling.
  /// Preloaded videos have their URLs resolved and controllers ready.
  static const int preloadCount = 2;

  /// Number of videos behind to keep in memory before releasing.
  /// Videos beyond this threshold are disposed to free memory.
  static const int disposeThreshold = 2;

  /// Maximum number of performance metrics to keep in history.
  static const int metricsHistorySize = 50;

  /// Preferred video height for quality selection (pixels).
  static const int preferredMaxHeight = 720;

  /// Minimum video height for quality selection (pixels).
  static const int preferredMinHeight = 360;
}
