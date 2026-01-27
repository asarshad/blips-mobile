import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

/// Provider for the YouTube player manager that uses iframe-based playback.
/// This approach is more reliable than stream URL extraction which can break
/// when YouTube changes their backend.
final youtubePlayerManagerProvider =
    ChangeNotifierProvider((ref) => YoutubePlayerManager());

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
  
  /// Error 100: Video not found or private.
  bool get isVideoUnavailable => code == 100 || code == 101;
}

/// Manages YouTube video players using iframe-based playback.
/// 
/// This uses the official YouTube IFrame Player API which is more reliable
/// than extracting stream URLs. The trade-off is slightly higher latency
/// but guaranteed compatibility.
class YoutubePlayerManager extends ChangeNotifier {
  /// Maximum number of controllers to keep in memory.
  static const int maxControllers = 8;
  
  final Map<String, YoutubePlayerController> _controllers = {};
  final Map<String, YTPlayerState> _states = {};
  final Map<String, YTPlayerError?> _errors = {};
  final Set<String> _pendingInit = {};
  final Set<String> _autoPlayUrls = {};
  
  String? _currentActiveUrl;
  bool _isDisposed = false;
  
  /// Gets the controller for a URL if available.
  YoutubePlayerController? getController(String url) => _controllers[url];
  
  /// Gets the player state for a URL.
  YTPlayerState getState(String url) => _states[url] ?? YTPlayerState.idle;
  
  /// Gets any error that occurred for a URL.
  YTPlayerError? getError(String url) => _errors[url];
  
  /// Checks if a video is ready to play.
  bool isReady(String url) {
    final state = _states[url];
    return state == YTPlayerState.ready || 
           state == YTPlayerState.playing || 
           state == YTPlayerState.paused;
  }
  
  /// Checks if a video is currently playing.
  bool isPlaying(String url) => _states[url] == YTPlayerState.playing;
  
  /// Extracts YouTube video ID from various URL formats.
  String? extractVideoId(String url) {
    return YoutubePlayer.convertUrlToId(url);
  }
  
  /// Initializes a controller for the given URL without playing.
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
          mute: false,
          hideControls: true,
          hideThumbnail: true,
          showLiveFullscreenButton: false,
          disableDragSeek: true,
          loop: true,
          forceHD: false,
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
      
      debugPrint('YoutubePlayerManager: Initialized controller for $videoId');
      
      // Auto-play if requested
      if (_autoPlayUrls.contains(url)) {
        controller.play();
        _states[url] = YTPlayerState.playing;
      }
      
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
      debugPrint('YoutubePlayerManager: Error $error for $url: ${_errors[url]?.message}');
      _notifySafe();
      return;
    }
    
    // Update state based on player state
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
  Future<void> playVideo(String url) async {
    if (_isDisposed) return;
    
    _currentActiveUrl = url;
    _autoPlayUrls.add(url);
    
    var controller = _controllers[url];
    if (controller == null) {
      controller = await initController(url);
    }
    
    if (controller != null) {
      controller.play();
      _states[url] = YTPlayerState.playing;
      _notifySafe();
    }
  }
  
  /// Pauses a video.
  void pauseVideo(String url) {
    _autoPlayUrls.remove(url);
    final controller = _controllers[url];
    if (controller != null) {
      controller.pause();
      _states[url] = YTPlayerState.paused;
      _notifySafe();
    }
  }
  
  /// Pauses all videos.
  void pauseAll() {
    _autoPlayUrls.clear();
    for (final entry in _controllers.entries) {
      entry.value.pause();
      _states[entry.key] = YTPlayerState.paused;
    }
    _notifySafe();
  }
  
  /// Releases a specific video controller.
  void releaseVideo(String url) {
    final controller = _controllers.remove(url);
    if (controller != null) {
      controller.dispose();
    }
    _states.remove(url);
    _errors.remove(url);
    _autoPlayUrls.remove(url);
    _notifySafe();
  }
  
  /// Releases all controllers.
  void releaseAll() {
    _currentActiveUrl = null;
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    _states.clear();
    _errors.clear();
    _autoPlayUrls.clear();
    _notifySafe();
  }
  
  /// Retries a failed video.
  Future<void> retryVideo(String url) async {
    releaseVideo(url);
    await playVideo(url);
  }
  
  /// Manages pool size by disposing least recently used controllers.
  Future<void> _managePoolSize(String currentUrl) async {
    if (_controllers.length < maxControllers) return;
    
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
      Future.microtask(notifyListeners);
    }
  }
  
  @override
  void dispose() {
    _isDisposed = true;
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    _states.clear();
    _errors.clear();
    _autoPlayUrls.clear();
    _pendingInit.clear();
    super.dispose();
  }
}

/// Extension for handling page changes in video feeds.
extension YoutubePlayerFeedManager on YoutubePlayerManager {
  /// Handles feed page changes with preloading and cleanup.
  Future<void> onPageChanged({
    required int currentIndex,
    required List<String> videoUrls,
  }) async {
    if (currentIndex < 0 || currentIndex >= videoUrls.length) return;
    
    final currentUrl = videoUrls[currentIndex];
    
    // Pause all videos except current
    for (final entry in _controllers.entries) {
      if (entry.key != currentUrl) {
        entry.value.pause();
        _states[entry.key] = YTPlayerState.paused;
      }
    }
    _autoPlayUrls.clear();
    
    // Play current video immediately
    _currentActiveUrl = currentUrl;
    _autoPlayUrls.add(currentUrl);
    
    final controller = _controllers[currentUrl];
    if (controller != null) {
      // Controller exists - play immediately
      controller.play();
      _states[currentUrl] = YTPlayerState.playing;
      _notifySafe();
    } else {
      // Need to init first - playVideo will handle it
      await playVideo(currentUrl);
    }
    
    // Preload next 2 videos in background (don't await)
    for (var i = 1; i <= 2; i++) {
      final nextIndex = currentIndex + i;
      if (nextIndex < videoUrls.length) {
        initController(videoUrls[nextIndex]);
      }
    }
    
    // Release old videos
    for (var i = 0; i < currentIndex - 2; i++) {
      if (i >= 0 && i < videoUrls.length) {
        releaseVideo(videoUrls[i]);
      }
    }
  }
}
