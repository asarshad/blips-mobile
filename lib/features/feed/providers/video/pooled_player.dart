import 'package:blips_mobile/features/feed/providers/video/video_metrics.dart';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

/// Lifecycle state of a pooled video player.
enum PlayerState {
  /// Available for reuse, no video assigned.
  idle,

  /// URL being resolved or controller initializing.
  loading,

  /// Initialized and ready to play.
  ready,

  /// Currently playing video.
  playing,

  /// Paused but ready to resume.
  paused,

  /// Error occurred during loading or playback.
  error,
}

/// A reusable video player from the pool.
///
/// Wraps a [VideoPlayerController] with state tracking and lifecycle
/// management to enable efficient recycling of players.
class PooledVideoPlayer {
  /// Creates a pooled player with the given pool index.
  PooledVideoPlayer({required this.id});

  /// Unique identifier within the pool.
  final int id;

  /// The YouTube URL currently assigned to this player.
  String? assignedUrl;

  /// The resolved direct stream URL.
  String? resolvedStreamUrl;

  /// The underlying video player controller.
  VideoPlayerController? controller;

  /// Current lifecycle state.
  PlayerState state = PlayerState.idle;

  /// Performance metrics for current video.
  VideoPerformanceMetrics? metrics;

  /// When this player was last used (for LRU recycling).
  DateTime? lastUsedTime;

  /// Whether this player's video is currently visible on screen.
  bool isVisible = false;

  /// Whether this player can be assigned a new video.
  bool get isAvailable => state == PlayerState.idle && assignedUrl == null;

  /// Whether this player is initialized and ready to play.
  bool get isReady => state == PlayerState.ready || state == PlayerState.paused;

  /// Whether this player is actively playing.
  bool get isPlaying => state == PlayerState.playing;

  /// Resets player state for reuse with a new video.
  ///
  /// Disposes the current controller to ensure no stale frames are shown.
  Future<void> reset() async {
    try {
      await controller?.dispose();
    } catch (e) {
      debugPrint('Error disposing player $id during reset: $e');
    }
    controller = null;
    assignedUrl = null;
    resolvedStreamUrl = null;
    state = PlayerState.idle;
    metrics = null;
    isVisible = false;
  }

  /// Fully disposes this player and releases all resources.
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
