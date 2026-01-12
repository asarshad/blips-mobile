import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:blips_mobile/features/feed/presentation/widgets/widgets.dart';
import 'package:blips_mobile/features/feed/providers/optimized_video_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

/// Fallback image when video thumbnail is unavailable.
const _videoFallbackImage =
    'https://images.unsplash.com/photo-1504384308090-c894fdcc538d?w=800';

/// Card widget for displaying video feed entries.
/// Includes inline video playback with thumbnail fallback.
class VideoCard extends HookConsumerWidget {
  const VideoCard({
    super.key,
    required this.entry,
    this.isVisible = true,
  });

  final VideoFeedEntry entry;
  final bool isVisible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showBubbles = useState(false);
    final preview = entry.thumbnailUrl ?? _videoFallbackImage;
    final dateLabel =
        DateFormat('MMM d, yyyy').format(entry.publishedAt.toLocal());

    final videoManager = ref.watch(optimizedVideoManagerProvider);
    final controller = videoManager.getController(entry.link);
    final playerState = videoManager.getPlayerState(entry.link);

    // Listen to controller changes to update UI
    final dummyListenable = useMemoized(ChangeNotifier.new);
    useListenable(controller ?? dummyListenable);

    final isPlayerReady = playerState == PlayerState.ready ||
        playerState == PlayerState.playing ||
        playerState == PlayerState.paused;
    final isLoading = playerState == PlayerState.loading || playerState == null;

    // Handle visibility changes
    useEffect(() {
      if (!isVisible) {
        videoManager.pauseVideo(entry.link);
      }
      return null;
    }, [isVisible]);

    // Cleanup: release video resources when this card is disposed
    useEffect(() {
      return () {
        debugPrint('VideoCard disposed for ${entry.link}, releasing resources');
        videoManager.releaseVideo(entry.link);
      };
    }, [entry.link]);

    return Stack(
      children: [
        FeedCardFrame(
          media: _VideoMedia(
            thumbnailUrl: preview,
            controller: controller,
            isPlayerReady: isPlayerReady,
            isLoading: isLoading,
          ),
          category: entry.category,
          title: entry.title,
          summary: entry.summary,
          source: entry.source,
          date: dateLabel,
          readTime: '${entry.readTime} min watch',
          onTap: () => _handleTap(
            showBubbles: showBubbles,
            controller: controller,
            videoManager: videoManager,
          ),
          onOpenLink: () => _openInBrowser(entry.link),
          onChat: () => showBubbles.value = !showBubbles.value,
          onShare: () => _shareVideo(entry),
        ),
        if (showBubbles.value)
          Positioned(
            bottom: 70,
            right: 20,
            left: 40,
            child: FloatingChatBubbles(
              entry: entry,
              onClose: () => showBubbles.value = false,
            ),
          ),
      ],
    );
  }

  Future<void> _handleTap({
    required ValueNotifier<bool> showBubbles,
    required VideoPlayerController? controller,
    required OptimizedVideoPlayerManager videoManager,
  }) async {
    if (showBubbles.value) {
      showBubbles.value = false;
      return;
    }

    if (controller != null && controller.value.isInitialized) {
      if (controller.value.isPlaying) {
        videoManager.pauseVideo(entry.link);
      } else {
        videoManager.playVideo(entry.link);
      }
    } else {
      // No controller yet, start loading and playing
      await videoManager.playVideo(entry.link);
    }
  }

  Future<void> _openInBrowser(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _shareVideo(VideoFeedEntry entry) {
    Share.share(
      'Check out this video: ${entry.link}\n\nShared via Blips',
      subject: entry.title,
    );
  }
}

class _VideoMedia extends StatelessWidget {
  const _VideoMedia({
    required this.thumbnailUrl,
    required this.controller,
    required this.isPlayerReady,
    required this.isLoading,
  });

  final String thumbnailUrl;
  final VideoPlayerController? controller;
  final bool isPlayerReady;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      clipBehavior: Clip.hardEdge,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Thumbnail background
          Positioned.fill(
            child: Image.network(
              thumbnailUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.grey.shade900,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.broken_image_outlined,
                  size: 32,
                  color: Colors.white54,
                ),
              ),
            ),
          ),

          // Video player when ready
          if (controller != null && controller!.value.isInitialized)
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: controller!.value.size.width,
                  height: controller!.value.size.height,
                  child: VideoPlayer(controller!),
                ),
              ),
            ),

          // Gradient overlay
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black54],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // Play button overlay - show when no controller or not playing, but not when loading
          if ((controller == null && !isLoading) || 
              (controller != null && !controller!.value.isPlaying && !isLoading))
            _PlayButton(),

          // Loading indicator - show when loading (with or without controller)
          if (isLoading)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
        ],
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 2,
          ),
        ),
        child: const Icon(
          Icons.play_arrow_rounded,
          size: 72,
          color: Colors.white,
        ),
      ),
    );
  }
}
