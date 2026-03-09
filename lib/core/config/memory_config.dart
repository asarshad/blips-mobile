/// Memory management configuration.
///
/// These settings control resource usage to balance performance with memory.
/// Adjust based on device capabilities and user feedback.
class MemoryConfig {
  MemoryConfig._();

  /// Maximum number of video player instances in the pool.
  ///
  /// Lower values save memory but may cause buffering when scrolling fast.
  /// Recommended: 3 for most devices, 2 for low-memory devices.
  static const int playerPoolSize = 3;

  /// Maximum number of images to keep in memory cache.
  static const int imageCacheMaxImages = 100;

  /// Maximum bytes for the image memory cache.
  ///
  /// 50MB is a good balance for most devices.
  static const int imageCacheMaxBytes = 50 * 1024 * 1024; // 50MB

  /// Number of reels to preload ahead and behind current position.
  ///
  /// Higher values provide smoother scrolling but use more memory.
  static const int reelPreloadCount = 1;

  /// Number of long-form videos to preload ahead of current position.
  ///
  /// Videos generally tolerate a slightly larger ahead window than reels.
  static const int videoPreloadCount = 2;

  /// Number of articles to preload ahead when scrolling.
  static const int articlePreloadCount = 3;

  /// Whether to log memory usage periodically (debug only).
  static const bool enableMemoryLogging = false;

  /// Interval between memory logs in seconds (if enabled).
  static const int memoryLogIntervalSeconds = 30;

  /// Maximum memory usage warning threshold (MB).
  ///
  /// If current memory exceeds this, trigger cleanup.
  static const int memoryWarningThresholdMB = 250;

  /// Maximum memory usage critical threshold (MB).
  ///
  /// If current memory exceeds this, aggressive cleanup + warn user.
  static const int memoryCriticalThresholdMB = 350;
}
