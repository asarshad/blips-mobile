import 'dart:async';

import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:blips_mobile/features/feed/presentation/widgets/widgets.dart';
import 'package:blips_mobile/features/feed/providers/video/youtube_player_manager.dart';
import 'package:blips_mobile/features/feed/providers/video/youtube_player_manager_base.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

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
    this.isNewSinceLastSeen = false,
  });

  final VideoFeedEntry entry;
  final bool isVisible;
  final bool isNewSinceLastSeen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showBubbles = useState(false);
    final preview = entry.thumbnailUrl ?? _videoFallbackImage;

    final videoManager = ref.watch(youtubePlayerManagerProvider);
    final playbackUrl = _resolvePlaybackUrl(videoManager);
    final controller = videoManager.getController(playbackUrl);
    final playerState = videoManager.getState(playbackUrl);
    final playerError = videoManager.getError(playbackUrl);

    final isLoading = playerState == YTPlayerState.loading ||
        playerState == YTPlayerState.idle;
    final isError = playerState == YTPlayerState.error;

    // Resume video when app returns to foreground (Videos tab lifecycle fix).
    // The manager's WidgetsBindingObserver handles pause-on-background but
    // resume must be triggered per-card since only this widget knows whether
    // it is the currently visible page.
    useEffect(() {
      if (!isVisible) return null;
      final listener = AppLifecycleListener(
        onResume: () => unawaited(videoManager.playVideo(playbackUrl)),
      );
      return listener.dispose;
    }, [isVisible, playbackUrl]);

    // Handle visibility changes
    useEffect(() {
      if (!isVisible) {
        videoManager.pauseVideo(playbackUrl);
        showBubbles.value = false;
      } else {
        // Auto-play when this card becomes the visible current page.
        // isVisible is true only when the Videos tab is active AND this
        // card is the current page in the FeedTab PageView.
        unawaited(videoManager.playVideo(playbackUrl));
      }
      return null;
    }, [isVisible, playbackUrl]);

    // Note: Don't release video resources on dispose - let the pool manager handle cleanup.
    // Releasing here causes "IOSInAppWebViewController used after disposed" errors
    // because the YoutubePlayer widget's WebView may still be unmounting.

    return Stack(
      children: [
        FeedCardFrame(
          // 16:9 ensures YoutubePlayer fills the media section exactly —
          // no black bars when the inline player is active.
          mediaAspectRatio: 16 / 9,
          media: _VideoMedia(
            thumbnailUrl: preview,
            controller: controller,
            isLoading: isLoading,
            isError: isError,
            playerError: playerError,
          ),
          category: entry.category,
          title: entry.title,
          summary: entry.summary,
          source: entry.source,
          freshnessInfo: FreshnessInfo(
            publishedAt: entry.publishedAt,
            addedAt: entry.addedAt,
            tier: entry.freshnessTier,
            isNewSinceLastSeen: isNewSinceLastSeen,
          ),
          readTime: '${entry.readTime} min watch',
          onTap: () => _handleTap(
            showBubbles: showBubbles,
            controller: controller,
            videoManager: videoManager,
            playbackUrl: playbackUrl,
            playerState: playerState,
          ),
          onOpenLink: () => _openInBrowser(entry.link),
          onChat: () => showBubbles.value = !showBubbles.value,
          onShare: () => _shareVideo(context),
        ),
        if (showBubbles.value)
          Positioned(
            bottom: 60,
            right: 16,
            left: 16,
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
    required YoutubePlayerController? controller,
    required YoutubePlayerManagerBase videoManager,
    required String playbackUrl,
    required YTPlayerState playerState,
  }) async {
    if (showBubbles.value) {
      showBubbles.value = false;
      return;
    }

    if (playerState == YTPlayerState.error) {
      await videoManager.retryVideo(playbackUrl);
      return;
    }

    if (controller != null) {
      if (controller.value.playerState == PlayerState.playing) {
        videoManager.pauseVideo(playbackUrl);
      } else {
        videoManager.playVideo(playbackUrl);
      }
    } else {
      // No controller yet, start loading and playing
      await videoManager.playVideo(playbackUrl);
    }
  }

  String _resolvePlaybackUrl(YoutubePlayerManagerBase videoManager) {
    final preferred = entry.videoUrl.trim();
    if (preferred.isNotEmpty &&
        videoManager.extractVideoId(preferred) != null) {
      return preferred;
    }
    return entry.link.trim();
  }

  Future<void> _openInBrowser(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _shareVideo(BuildContext context) async {
    final dateLabel = DateFormat(
      'MMM d, yyyy',
    ).format(entry.publishedAt.toLocal());
    final preview = entry.thumbnailUrl ?? _videoFallbackImage;

    await ShareService.instance.shareVideo(
      context: context,
      title: entry.title,
      summary: entry.summary,
      channelName: entry.source,
      category: entry.category,
      date: dateLabel,
      duration: '${entry.readTime} min watch',
      thumbnailUrl: preview,
      videoUrl: entry.link,
    );
  }
}

class _VideoMedia extends StatelessWidget {
  const _VideoMedia({
    required this.thumbnailUrl,
    required this.controller,
    required this.isLoading,
    required this.isError,
    required this.playerError,
  });

  final String thumbnailUrl;
  final YoutubePlayerController? controller;
  final bool isLoading;
  final bool isError;
  final YTPlayerError? playerError;

  /// Checks if controller exists and can render the underlying WebView.
  bool get _isControllerValid {
    return controller != null;
  }

  /// Determines if play button should be shown.
  bool _shouldShowPlayButton(bool showPlayer) {
    if (!showPlayer) return true;
    return controller?.value.playerState != PlayerState.playing;
  }

  @override
  Widget build(BuildContext context) {
    final showPlayer = _isControllerValid;

    return ClipRect(
      clipBehavior: Clip.hardEdge,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Thumbnail background
          Positioned.fill(
            child: thumbnailUrl.trim().isEmpty
                ? Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.blueGrey.shade800,
                          Colors.blueGrey.shade900,
                        ],
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.videocam_outlined,
                      size: 36,
                      color: Colors.white30,
                    ),
                  )
                : Image.network(
                    thumbnailUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.blueGrey.shade800,
                            Colors.blueGrey.shade900,
                          ],
                        ),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.videocam_outlined,
                        size: 36,
                        color: Colors.white30,
                      ),
                    ),
                  ),
          ),

          // Video player when ready and controller is valid
          if (showPlayer)
            Positioned.fill(
              child: YoutubePlayer(
                controller: controller!,
                showVideoProgressIndicator: false,
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

          if (isError) _VideoErrorOverlay(error: playerError),

          // Play button overlay - show when no valid player or not playing, but not when loading
          if (!isLoading && !isError && _shouldShowPlayButton(showPlayer))
            _PlayButton(),

          // Loading indicator - show when loading (with or without controller)
          if (isLoading)
            const Center(child: CircularProgressIndicator(color: Colors.white)),
        ],
      ),
    );
  }
}

class _VideoErrorOverlay extends StatelessWidget {
  const _VideoErrorOverlay({required this.error});

  final YTPlayerError? error;

  @override
  Widget build(BuildContext context) {
    var title = 'Playback failed';
    var hint = 'Tap to retry';

    if (error != null) {
      if (error!.isPlaybackDisabled) {
        title = 'Playback disabled';
        hint = 'Video owner disabled embedding';
      } else if (error!.isVideoUnavailable) {
        title = 'Video unavailable';
        hint = 'Video may be private or removed';
      }
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 28),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              hint,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
