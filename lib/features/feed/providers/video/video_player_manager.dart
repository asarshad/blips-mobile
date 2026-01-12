import 'package:blips_mobile/features/feed/providers/video/pooled_player.dart';
import 'package:blips_mobile/features/feed/providers/video/video_config.dart';
import 'package:blips_mobile/features/feed/providers/video/video_metrics.dart';
import 'package:blips_mobile/features/feed/providers/video/youtube_resolver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

export 'package:blips_mobile/features/feed/providers/video/pooled_player.dart'
    show PlayerState;
export 'package:blips_mobile/features/feed/providers/video/video_config.dart';
export 'package:blips_mobile/features/feed/providers/video/video_metrics.dart';

/// Provider for the optimized video player manager.
final optimizedVideoManagerProvider =
    ChangeNotifierProvider((ref) => OptimizedVideoPlayerManager());

/// Manages a pool of video players for optimal performance.
///
/// Uses player pooling to minimize initialization overhead when
/// scrolling through video feeds. Players are recycled using LRU
/// (least recently used) strategy.
class OptimizedVideoPlayerManager extends ChangeNotifier {
  /// Creates and initializes the player pool.
  OptimizedVideoPlayerManager() {
    _initializePool();
  }

  final List<PooledVideoPlayer> _pool = [];
  final Map<String, PooledVideoPlayer> _urlToPlayer = {};
  final List<VideoPerformanceMetrics> _performanceHistory = [];

  late final YoutubeUrlResolver _urlResolver;
  String? _currentActiveUrl;
  bool _isDisposed = false;

  /// All recorded performance metrics (most recent first).
  List<VideoPerformanceMetrics> get performanceHistory =>
      List.unmodifiable(_performanceHistory);

  /// Average time to first frame for recent videos.
  Duration? get averageTimeToFirstFrame {
    final recent = _performanceHistory
        .where((m) => m.timeToFirstFrame != null)
        .take(10)
        .toList();
    if (recent.isEmpty) return null;
    final totalMs = recent.fold<int>(
      0,
      (sum, m) => sum + m.timeToFirstFrame!.inMilliseconds,
    );
    return Duration(milliseconds: totalMs ~/ recent.length);
  }

  void _initializePool() {
    _urlResolver = YoutubeUrlResolver();
    for (var i = 0; i < VideoPoolConfig.poolSize; i++) {
      _pool.add(PooledVideoPlayer(id: i));
    }
    debugPrint(
      'Initialized video player pool with ${VideoPoolConfig.poolSize} players',
    );
  }

  /// Gets the controller for a video URL if available.
  ///
  /// Returns null if no player is assigned to this URL, or if the
  /// player's assigned URL doesn't match (safety check).
  VideoPlayerController? getController(String url) {
    final player = _urlToPlayer[url];
    if (player == null) return null;

    // Safety check: ensure player is actually assigned to this URL
    if (player.assignedUrl != url) {
      debugPrint(
          'WARNING: Player URL mismatch! Map key: $url, assigned: ${player.assignedUrl}');
      return null;
    }

    return player.controller;
  }

  /// Checks if video is ready to play.
  bool isReady(String url) {
    final player = _urlToPlayer[url];
    return player != null && player.isReady;
  }

  /// Checks if video is currently playing.
  bool isPlaying(String url) {
    final player = _urlToPlayer[url];
    return player != null && player.isPlaying;
  }

  /// Gets player state for a URL.
  PlayerState? getPlayerState(String url) {
    return _urlToPlayer[url]?.state;
  }

  /// Preloads a video for future playback without starting it.
  Future<void> preload(String url) async {
    if (_isDisposed) return;
    if (_urlToPlayer.containsKey(url)) return;

    await _assignAndPreparePlayer(url, autoPlay: false);
  }

  /// Prepares and starts playing a video.
  Future<void> playVideo(String url) async {
    if (_isDisposed) return;

    debugPrint('playVideo called for: $url');
    _currentActiveUrl = url;

    final existingPlayer = _urlToPlayer[url];
    if (existingPlayer != null) {
      // Verify the player is actually assigned to this URL
      if (existingPlayer.assignedUrl != url) {
        debugPrint(
            'ERROR: existingPlayer URL mismatch! Expected: $url, got: ${existingPlayer.assignedUrl}');
        _urlToPlayer.remove(url);
        await _assignAndPreparePlayer(url, autoPlay: true);
        return;
      }

      existingPlayer.isVisible = true;
      if (existingPlayer.isReady) {
        debugPrint('Playing existing ready player for: $url');
        await existingPlayer.controller?.play();
        existingPlayer.state = PlayerState.playing;
        existingPlayer.metrics?.playingTime = DateTime.now();
        _notifyListenersSafe();
      }
      // If not ready yet, isVisible=true ensures it will autoplay when ready
      return;
    }

    await _assignAndPreparePlayer(url, autoPlay: true);
  }

  /// Pauses a specific video.
  Future<void> pauseVideo(String url) async {
    final player = _urlToPlayer[url];
    if (player != null && player.controller != null) {
      await player.controller!.pause();
      player.state = PlayerState.paused;
      _notifyListenersSafe();
    }
  }

  /// Pauses all videos in the pool.
  Future<void> pauseAll() async {
    for (final player in _pool) {
      if (player.controller != null && player.isPlaying) {
        await player.controller!.pause();
        player.state = PlayerState.paused;
      }
    }
    _notifyListenersSafe();
  }

  /// Releases all video resources (for tab switches or screen disposal).
  Future<void> releaseAll() async {
    debugPrint('Releasing all video resources...');
    _currentActiveUrl = null;

    // Reset all players and clear mapping
    for (final player in _pool) {
      await player.reset();
    }
    _urlToPlayer.clear();

    _notifyListenersSafe();
    debugPrint('All video resources released');
  }

  /// Releases resources for a video that's no longer needed.
  Future<void> releaseVideo(String url) async {
    final player = _urlToPlayer[url];
    if (player != null) {
      await player.reset();
      _urlToPlayer.remove(url);
      _notifyListenersSafe();
    }
  }

  /// Retries loading a failed video.
  Future<void> retryVideo(String url) async {
    if (_isDisposed) return;

    // Clear the URL from cache so it gets re-resolved
    _urlResolver.clearUrlFromCache(url);

    // Release any existing player assignment
    await releaseVideo(url);

    // Try playing again
    await playVideo(url);
  }

  Future<void> _assignAndPreparePlayer(
    String url, {
    required bool autoPlay,
  }) async {
    if (_isDisposed) return;

    final metrics = VideoPerformanceMetrics(
      videoUrl: url,
      startTime: DateTime.now(),
    );

    // Find an available player or recycle the oldest one
    var player = _pool.firstWhere(
      (p) => p.isAvailable,
      orElse: () {
        // Find the player that was used longest ago and isn't current
        final candidates = _pool
            .where((p) => p.assignedUrl != _currentActiveUrl)
            .toList()
          ..sort((a, b) => (a.lastUsedTime ?? DateTime(2000))
              .compareTo(b.lastUsedTime ?? DateTime(2000)));
        return candidates.first;
      },
    );

    // If recycling, clean up old assignment
    if (player.assignedUrl != null) {
      // Remove ALL map entries that point to this player (handles race conditions)
      _urlToPlayer.removeWhere((key, value) => value == player);
      await player.reset();
    }

    player
      ..assignedUrl = url
      ..state = PlayerState.loading
      ..metrics = metrics
      ..lastUsedTime = DateTime.now()
      ..isVisible = autoPlay;

    _urlToPlayer[url] = player;
    _notifyListenersSafe();

    try {
      // Resolve YouTube URL to direct stream URL
      final streamUrl = await _urlResolver.resolve(url);
      if (_isDisposed || player.assignedUrl != url) return;

      metrics.urlResolutionTime = DateTime.now();
      player.resolvedStreamUrl = streamUrl;

      // Create video controller
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(streamUrl),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: false,
          allowBackgroundPlayback: false,
        ),
      );

      if (_isDisposed || player.assignedUrl != url) {
        await controller.dispose();
        return;
      }

      player.controller = controller;
      metrics.controllerCreatedTime = DateTime.now();

      // Initialize controller
      await controller.initialize();
      if (_isDisposed || player.assignedUrl != url) {
        await controller.dispose();
        return;
      }

      metrics.initializedTime = DateTime.now();
      player.state = PlayerState.ready;

      // Set up looping
      await controller.setLooping(true);

      // Listen for first frame
      _setupFirstFrameListener(controller, metrics);

      _notifyListenersSafe();

      // Auto-play if this video should be playing
      // Check both: explicit autoPlay request OR isVisible (set by playVideo while loading)
      final shouldAutoPlay =
          (autoPlay || player.isVisible) && url == _currentActiveUrl;
      if (shouldAutoPlay) {
        debugPrint(
            'Auto-playing video $url (autoPlay=$autoPlay, isVisible=${player.isVisible})');
        await controller.play();
        player.state = PlayerState.playing;
        metrics.playingTime = DateTime.now();
        _notifyListenersSafe();
      }
    } catch (e) {
      debugPrint('Error preparing video $url: $e');
      player.state = PlayerState.error;
      _notifyListenersSafe();
    }
  }

  void _setupFirstFrameListener(
    VideoPlayerController controller,
    VideoPerformanceMetrics metrics,
  ) {
    void onFirstFrame() {
      if (metrics.firstFrameTime == null) {
        metrics.firstFrameTime = DateTime.now();
        _performanceHistory.insert(0, metrics);
        if (_performanceHistory.length > VideoPoolConfig.metricsHistorySize) {
          _performanceHistory.removeLast();
        }
        debugPrint(
          'Video ready: ${metrics.timeToFirstFrame?.inMilliseconds}ms '
          'to first frame',
        );
      }
    }

    controller.addListener(() {
      if (controller.value.isInitialized &&
          controller.value.position > Duration.zero) {
        onFirstFrame();
      }
    });
  }

  void _notifyListenersSafe() {
    if (!_isDisposed) {
      Future.microtask(notifyListeners);
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    for (final player in _pool) {
      player.dispose();
    }
    _pool.clear();
    _urlToPlayer.clear();
    _urlResolver.dispose();
    super.dispose();
  }
}

/// Extension for feed navigation handling.
extension VideoFeedManager on OptimizedVideoPlayerManager {
  /// Handles feed page changes with preloading and cleanup.
  ///
  /// - Pauses all videos
  /// - Plays the current video
  /// - Preloads upcoming videos
  /// - Releases videos that are no longer needed
  Future<void> onPageChanged({
    required int currentIndex,
    required List<String> videoUrls,
  }) async {
    if (currentIndex < 0 || currentIndex >= videoUrls.length) return;

    final currentUrl = videoUrls[currentIndex];

    // FIRST: Pause ALL videos to stop multiple audio
    await pauseAll();

    // Play current video
    await playVideo(currentUrl);

    // Preload next videos (but don't play them)
    for (var i = 1; i <= VideoPoolConfig.preloadCount; i++) {
      final nextIndex = currentIndex + i;
      if (nextIndex < videoUrls.length) {
        await preload(videoUrls[nextIndex]);
      }
    }

    // Release old videos
    for (var i = 0; i < currentIndex - VideoPoolConfig.disposeThreshold; i++) {
      if (i >= 0 && i < videoUrls.length) {
        await releaseVideo(videoUrls[i]);
      }
    }
  }
}
