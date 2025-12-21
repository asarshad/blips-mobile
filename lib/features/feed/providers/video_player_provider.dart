import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

final videoPlayerManagerProvider = ChangeNotifierProvider((ref) => VideoPlayerManager());

class VideoPlayerManager extends ChangeNotifier {
  final Map<String, YoutubePlayerController> _controllers = {};
  final Map<String, bool> _isInitialized = {};
  final Set<String> _autoPlayUrls = {};
  final Set<String> _pendingUrls = {};

  bool isInitialized(String url) => _isInitialized[url] ?? false;
  bool shouldPlay(String url) => _autoPlayUrls.contains(url);

  YoutubePlayerController? getController(String url) => _controllers[url];

  Future<YoutubePlayerController?> initController(String url) async {
    if (_controllers.containsKey(url)) {
      return _controllers[url];
    }
    if (_pendingUrls.contains(url)) {
      return null; // Already initializing
    }

    _pendingUrls.add(url);

    try {
      final videoId = YoutubePlayer.convertUrlToId(url);
      if (videoId == null) throw Exception('Invalid YouTube URL');

      final controller = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: false,
          mute: false,
          hideControls: true,
          hideThumbnail: true,
          disableDragSeek: true,
          loop: true,
          forceHD: true,
        ),
      );

      _controllers[url] = controller;
      _isInitialized[url] = true;
      
      if (_autoPlayUrls.contains(url)) {
        controller.play();
      } else {
        // Preload/Cue the video
        // Note: The player might not actually load until attached to a widget
        // But we prepare the controller.
      }

      // Schedule notification to avoid build-phase updates
      Future.microtask(() => notifyListeners());
      return controller;
    } catch (e) {
      debugPrint('Error initializing video $url: $e');
      _controllers.remove(url);
      _autoPlayUrls.remove(url);
      return null;
    } finally {
      _pendingUrls.remove(url);
    }
  }

  void play(String url) {
    final controller = _controllers[url];
    if (controller != null) {
      controller.play();
    } else {
      _autoPlayUrls.add(url);
    }
  }

  void pause(String url) {
    _autoPlayUrls.remove(url);
    final controller = _controllers[url];
    if (controller != null) {
      controller.pause();
    }
  }

  void disposeController(String url) {
    _autoPlayUrls.remove(url);
    final controller = _controllers[url];
    if (controller != null) {
      controller.dispose();
      _controllers.remove(url);
      _isInitialized.remove(url);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    _isInitialized.clear();
    _autoPlayUrls.clear();
    _pendingUrls.clear();
    super.dispose();
  }
}
