import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

final videoPlayerManagerProvider = ChangeNotifierProvider((ref) => VideoPlayerManager());

class VideoPlayerManager extends ChangeNotifier {
  final Map<String, YoutubePlayerController> _controllers = {};
  final Map<String, bool> _isInitialized = {};
  final Set<String> _autoPlayUrls = {};
  final Set<String> _pendingUrls = {};
  final Set<String> _markedForDisposal = {};

  bool isInitialized(String url) => _isInitialized[url] ?? false;
  bool shouldPlay(String url) => _autoPlayUrls.contains(url);

  YoutubePlayerController? getController(String url) => _controllers[url];

  Future<YoutubePlayerController?> initController(String url) async {
    // If we are requesting it, unmark from disposal
    _markedForDisposal.remove(url);

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

      // Check if it was marked for disposal while we were creating it
      if (_markedForDisposal.contains(url)) {
        controller.dispose();
        return null;
      }

      _controllers[url] = controller;
      _isInitialized[url] = true;
      
      if (_autoPlayUrls.contains(url)) {
        controller.play();
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
    _autoPlayUrls.add(url);
    final controller = _controllers[url];
    if (controller != null) {
      controller.play();
    }
    Future.microtask(() => notifyListeners());
  }

  void pause(String url) {
    _autoPlayUrls.remove(url);
    final controller = _controllers[url];
    if (controller != null) {
      controller.pause();
    }
    Future.microtask(() => notifyListeners());
  }

  void disposeController(String url) {
    _markedForDisposal.add(url);
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
