import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Provider for the optimized video player manager
final optimizedVideoManagerProvider =
    ChangeNotifierProvider((ref) => OptimizedVideoPlayerManager());

/// Performance metrics for video playback
class VideoPerformanceMetrics {
  VideoPerformanceMetrics({
    required this.videoUrl,
    required this.startTime,
  });

  final String videoUrl;
  final DateTime startTime;
  DateTime? urlResolutionTime;
  DateTime? controllerCreatedTime;
  DateTime? initializedTime;
  DateTime? firstFrameTime;
  DateTime? playingTime;

  Duration? get urlResolutionDuration =>
      urlResolutionTime?.difference(startTime);

  Duration? get controllerCreationDuration =>
      controllerCreatedTime != null && urlResolutionTime != null
          ? controllerCreatedTime!.difference(urlResolutionTime!)
          : null;

  Duration? get initializationDuration =>
      initializedTime != null && controllerCreatedTime != null
          ? initializedTime!.difference(controllerCreatedTime!)
          : null;

  Duration? get timeToFirstFrame =>
      firstFrameTime != null ? firstFrameTime!.difference(startTime) : null;

  Duration? get timeToPlaying =>
      playingTime != null ? playingTime!.difference(startTime) : null;

  Map<String, dynamic> toJson() => {
        'videoUrl': videoUrl,
        'urlResolutionMs': urlResolutionDuration?.inMilliseconds,
        'controllerCreationMs': controllerCreationDuration?.inMilliseconds,
        'initializationMs': initializationDuration?.inMilliseconds,
        'timeToFirstFrameMs': timeToFirstFrame?.inMilliseconds,
        'timeToPlayingMs': timeToPlaying?.inMilliseconds,
      };

  @override
  String toString() => 'VideoPerformanceMetrics(${toJson()})';
}

/// State of a pooled video player
enum PlayerState {
  idle, // Available for reuse
  loading, // URL being resolved or controller initializing
  ready, // Initialized and ready to play
  playing, // Currently playing
  paused, // Paused but ready
  error, // Error occurred
}

/// A pooled video player that can be reused
class PooledVideoPlayer {
  PooledVideoPlayer({required this.id});

  final int id;
  String? assignedUrl;
  String? resolvedStreamUrl;
  VideoPlayerController? controller;
  PlayerState state = PlayerState.idle;
  VideoPerformanceMetrics? metrics;
  DateTime? lastUsedTime;
  bool isVisible = false;

  bool get isAvailable => state == PlayerState.idle && assignedUrl == null;
  bool get isReady => state == PlayerState.ready || state == PlayerState.paused;
  bool get isPlaying => state == PlayerState.playing;

  Future<void> reset() async {
    try {
      await controller?.pause();
      await controller?.seekTo(Duration.zero);
    } catch (e) {
      debugPrint('Error resetting player $id: $e');
    }
    assignedUrl = null;
    resolvedStreamUrl = null;
    state = PlayerState.idle;
    metrics = null;
    isVisible = false;
  }

  Future<void> dispose() async {
    try {
      await controller?.dispose();
    } catch (e) {
      debugPrint('Error disposing player $id: $e');
    }
    controller = null;
    assignedUrl = null;
    resolvedStreamUrl = null;
    state = PlayerState.idle;
    metrics = null;
  }
}

/// Manages a pool of video players for optimal performance
class OptimizedVideoPlayerManager extends ChangeNotifier {
  OptimizedVideoPlayerManager() {
    _initializePool();
  }

  /// Pool configuration
  static const int poolSize = 5; // Number of players to maintain
  static const int preloadCount = 2; // How many videos ahead to preload
  static const int disposeThreshold = 2; // How many videos behind to keep

  final List<PooledVideoPlayer> _pool = [];
  final Map<String, PooledVideoPlayer> _urlToPlayer = {};
  final Map<String, String> _resolvedUrls = {}; // Cache resolved stream URLs
  final List<VideoPerformanceMetrics> _performanceHistory = [];

  YoutubeExplode? _youtubeExplode;
  String? _currentActiveUrl;
  bool _isDisposed = false;

  /// Get all performance metrics
  List<VideoPerformanceMetrics> get performanceHistory =>
      List.unmodifiable(_performanceHistory);

  /// Get average time to first frame (last 10 videos)
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

  /// Initialize the player pool
  void _initializePool() {
    _youtubeExplode = YoutubeExplode();
    for (var i = 0; i < poolSize; i++) {
      _pool.add(PooledVideoPlayer(id: i));
    }
    debugPrint('Initialized video player pool with $poolSize players');
  }

  /// Get the controller for a video URL
  VideoPlayerController? getController(String url) {
    return _urlToPlayer[url]?.controller;
  }

  /// Check if video is ready to play
  bool isReady(String url) {
    final player = _urlToPlayer[url];
    return player != null && player.isReady;
  }

  /// Check if video is currently playing
  bool isPlaying(String url) {
    final player = _urlToPlayer[url];
    return player != null && player.isPlaying;
  }

  /// Get player state for a URL
  PlayerState? getPlayerState(String url) {
    return _urlToPlayer[url]?.state;
  }

  /// Preload a video for future playback
  Future<void> preload(String url) async {
    if (_isDisposed) return;
    if (_urlToPlayer.containsKey(url)) return; // Already loaded

    await _assignAndPreparePlayer(url, autoPlay: false);
  }

  /// Prepare a video and start playing when ready
  Future<void> playVideo(String url) async {
    if (_isDisposed) return;

    _currentActiveUrl = url;

    final existingPlayer = _urlToPlayer[url];
    if (existingPlayer != null) {
      existingPlayer.isVisible = true;
      if (existingPlayer.isReady) {
        await existingPlayer.controller?.play();
        existingPlayer.state = PlayerState.playing;
        existingPlayer.metrics?.playingTime = DateTime.now();
        _notifyListenersSafe();
      }
      return;
    }

    await _assignAndPreparePlayer(url, autoPlay: true);
  }

  /// Pause a video
  Future<void> pauseVideo(String url) async {
    final player = _urlToPlayer[url];
    if (player != null && player.controller != null) {
      await player.controller!.pause();
      player.state = PlayerState.paused;
      _notifyListenersSafe();
    }
  }

  /// Pause all videos
  Future<void> pauseAll() async {
    for (final player in _pool) {
      if (player.controller != null && player.isPlaying) {
        await player.controller!.pause();
        player.state = PlayerState.paused;
      }
    }
    _notifyListenersSafe();
  }

  /// Release resources for a video that's no longer needed
  Future<void> releaseVideo(String url) async {
    final player = _urlToPlayer[url];
    if (player != null) {
      await player.reset();
      _urlToPlayer.remove(url);
      _notifyListenersSafe();
    }
  }

  /// Find or create a player for the URL
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
        // Find the player that was used longest ago and isn't the current video
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
      _urlToPlayer.remove(player.assignedUrl);
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
      final streamUrl = await _resolveYoutubeUrl(url);
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
      void onFirstFrame() {
        if (metrics.firstFrameTime == null) {
          metrics.firstFrameTime = DateTime.now();
          _performanceHistory.insert(0, metrics);
          if (_performanceHistory.length > 50) {
            _performanceHistory.removeLast();
          }
          debugPrint(
            'Video ready: ${metrics.timeToFirstFrame?.inMilliseconds}ms to first frame',
          );
        }
      }

      controller.addListener(() {
        if (controller.value.isInitialized &&
            controller.value.position > Duration.zero) {
          onFirstFrame();
        }
      });

      _notifyListenersSafe();

      // Auto-play if this is the active video
      if (autoPlay && url == _currentActiveUrl && player.isVisible) {
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

  /// Resolve YouTube URL to direct stream URL
  Future<String> _resolveYoutubeUrl(String url) async {
    // Check cache first
    if (_resolvedUrls.containsKey(url)) {
      return _resolvedUrls[url]!;
    }

    final videoId = _extractVideoId(url);
    if (videoId == null) {
      throw Exception('Invalid YouTube URL: $url');
    }

    try {
      final manifest =
          await _youtubeExplode!.videos.streamsClient.getManifest(videoId);

      // Prefer muxed streams for faster loading (video + audio combined)
      // Choose medium quality for balance of speed and quality
      final streams = manifest.muxed.toList()
        ..sort((a, b) => b.bitrate.compareTo(a.bitrate));

      // Find a good quality stream (720p or lower for fast loading)
      final stream = streams.firstWhere(
        (s) =>
            s.videoResolution.height <= 720 &&
            s.videoResolution.height >= 360,
        orElse: () => streams.first,
      );

      final streamUrl = stream.url.toString();
      _resolvedUrls[url] = streamUrl;
      return streamUrl;
    } catch (e) {
      debugPrint('Error resolving YouTube URL: $e');
      rethrow;
    }
  }

  /// Extract video ID from various YouTube URL formats
  String? _extractVideoId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    // youtube.com/shorts/VIDEO_ID (check this BEFORE regular youtube.com)
    if (uri.host.contains('youtube.com') && uri.pathSegments.contains('shorts')) {
      final shortsIndex = uri.pathSegments.indexOf('shorts');
      if (uri.pathSegments.length > shortsIndex + 1) {
        return uri.pathSegments[shortsIndex + 1];
      }
    }

    // youtube.com/watch?v=VIDEO_ID
    if (uri.host.contains('youtube.com')) {
      final videoId = uri.queryParameters['v'];
      if (videoId != null && videoId.isNotEmpty) {
        return videoId;
      }
    }

    // youtu.be/VIDEO_ID
    if (uri.host.contains('youtu.be')) {
      final segments = uri.pathSegments;
      if (segments.isNotEmpty) {
        return segments.first;
      }
    }

    return null;
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
    _resolvedUrls.clear();
    _youtubeExplode?.close();
    _youtubeExplode = null;
    super.dispose();
  }
}

/// Extension to help with feed management
extension VideoFeedManager on OptimizedVideoPlayerManager {
  /// Called when the feed page changes
  /// Handles preloading next videos and releasing old ones
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
    for (var i = 1; i <= OptimizedVideoPlayerManager.preloadCount; i++) {
      final nextIndex = currentIndex + i;
      if (nextIndex < videoUrls.length) {
        await preload(videoUrls[nextIndex]);
      }
    }

    // Release old videos
    for (var i = 0; i < currentIndex - OptimizedVideoPlayerManager.disposeThreshold; i++) {
      if (i >= 0 && i < videoUrls.length) {
        await releaseVideo(videoUrls[i]);
      }
    }
  }
}
