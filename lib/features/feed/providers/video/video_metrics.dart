/// Performance metrics tracking for video playback.
/// 
/// Captures timing data for debugging and optimization.
class VideoPerformanceMetrics {
  /// Creates a new metrics instance when video loading begins.
  VideoPerformanceMetrics({
    required this.videoUrl,
    required this.startTime,
  });

  /// The original video URL being measured.
  final String videoUrl;
  
  /// When the load process started.
  final DateTime startTime;
  
  /// When URL resolution completed (YouTube URL → direct stream URL).
  DateTime? urlResolutionTime;
  
  /// When the VideoPlayerController was created.
  DateTime? controllerCreatedTime;
  
  /// When the controller finished initializing.
  DateTime? initializedTime;
  
  /// When the first video frame was decoded.
  DateTime? firstFrameTime;
  
  /// When playback actually started.
  DateTime? playingTime;

  /// Time taken to resolve the stream URL.
  Duration? get urlResolutionDuration =>
      urlResolutionTime?.difference(startTime);

  /// Time taken to create the controller after URL resolution.
  Duration? get controllerCreationDuration =>
      controllerCreatedTime != null && urlResolutionTime != null
          ? controllerCreatedTime!.difference(urlResolutionTime!)
          : null;

  /// Time taken to initialize the controller.
  Duration? get initializationDuration =>
      initializedTime != null && controllerCreatedTime != null
          ? initializedTime!.difference(controllerCreatedTime!)
          : null;

  /// Total time from start to first frame display.
  Duration? get timeToFirstFrame =>
      firstFrameTime != null ? firstFrameTime!.difference(startTime) : null;

  /// Total time from start to playback beginning.
  Duration? get timeToPlaying =>
      playingTime != null ? playingTime!.difference(startTime) : null;

  /// Serializes metrics to JSON for logging.
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
