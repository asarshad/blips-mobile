import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:blips_mobile/features/feed/presentation/reels/reel_action_button.dart';
import 'package:blips_mobile/features/feed/presentation/widgets/widgets.dart';
import 'package:blips_mobile/features/feed/providers/video/youtube_player_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

/// Individual reel item with video playback.
///
/// Shows thumbnail while loading, then transitions to video.
/// Tap to play/pause.
class ReelItem extends HookConsumerWidget {
  /// Creates a reel item.
  const ReelItem({
    required this.entry,
    required this.isActive,
    required this.isVisible,
    super.key,
  });

  /// The reel entry data.
  final ReelFeedEntry entry;

  /// Whether this reel is the currently active one in the PageView.
  final bool isActive;

  /// Whether the reels page is currently visible.
  final bool isVisible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videoManager = ref.watch(youtubePlayerManagerProvider);
    final controller = videoManager.getController(entry.link);
    final playerState = videoManager.getState(entry.link);
    final playerError = videoManager.getError(entry.link);
    final showThumbnail = useState(true);
    final isMounted = useIsMounted();
    final isTextExpanded = useState(false);

    // Track when video is actually playing to hide thumbnail
    _useThumbnailVisibility(
      controller: controller,
      isActive: isActive,
      showThumbnail: showThumbnail,
      isMounted: isMounted,
    );

    final isLoading = playerState == YTPlayerState.loading || playerState == YTPlayerState.idle;
    final isError = playerState == YTPlayerState.error;

    // Show video when controller exists and ready
    final showVideo = controller != null && 
        (playerState == YTPlayerState.ready || 
         playerState == YTPlayerState.playing || 
         playerState == YTPlayerState.paused);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Video Layer (tappable for play/pause)
        GestureDetector(
          onTap: () => _handleTap(controller, videoManager, playerState),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Video Layer - only show when ready
              if (showVideo && controller != null) 
                _YoutubeVideoLayer(controller: controller),

              // Thumbnail Layer
              _ThumbnailLayer(
                thumbnailUrl: entry.thumbnailUrl,
                isVisible: showThumbnail.value,
              ),

              // Gradient Overlay
              const _GradientOverlay(),

              // Play indicator - show when paused OR when there's an error (tap to retry)
              if (isActive && playerState != YTPlayerState.playing)
                const _PlayIndicator(),

              // Loading Indicator
              if (isActive && isLoading)
                const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),

              // Error indicator
              if (isError) _ErrorIndicator(error: playerError),
            ],
          ),
        ),

        // Action Buttons
        _ActionButtons(entry: entry),

        // Info Layer (not tappable for play/pause, but text is tappable for expand/collapse)
        _InfoLayer(
          entry: entry,
          isTextExpanded: isTextExpanded,
        ),
      ],
    );
  }

  void _useThumbnailVisibility({
    required YoutubePlayerController? controller,
    required bool isActive,
    required ValueNotifier<bool> showThumbnail,
    required bool Function() isMounted,
  }) {
    useEffect(() {
      if (controller != null) {
        void listener() {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!isMounted()) return;

            final isPlaying = controller.value.playerState == PlayerState.playing;

            // Hide thumbnail as soon as video starts playing
            if (isPlaying && showThumbnail.value) {
              showThumbnail.value = false;
            } else if (!isActive && !showThumbnail.value) {
              showThumbnail.value = true;
            }
          });
        }

        controller.addListener(listener);
        return () => controller.removeListener(listener);
      }
      return null;
    }, [controller, isActive]);
  }

  void _handleTap(
    YoutubePlayerController? controller,
    YoutubePlayerManager videoManager,
    YTPlayerState playerState,
  ) {
    // If error state, retry loading
    if (playerState == YTPlayerState.error) {
      debugPrint('Retrying failed video: ${entry.link}');
      videoManager.retryVideo(entry.link);
      return;
    }

    // If no controller yet, try to play (will trigger load)
    if (controller == null) {
      videoManager.playVideo(entry.link);
      return;
    }

    // Toggle play/pause
    if (controller.value.playerState == PlayerState.playing) {
      videoManager.pauseVideo(entry.link);
    } else {
      videoManager.playVideo(entry.link);
    }
  }
}

class _YoutubeVideoLayer extends StatelessWidget {
  const _YoutubeVideoLayer({required this.controller});

  final YoutubePlayerController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.width * 16 / 9,
          child: YoutubePlayer(
            controller: controller,
            showVideoProgressIndicator: false,
            progressColors: const ProgressBarColors(
              playedColor: Colors.white,
              handleColor: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _ThumbnailLayer extends StatelessWidget {
  const _ThumbnailLayer({
    required this.thumbnailUrl,
    required this.isVisible,
  });

  final String? thumbnailUrl;
  final bool isVisible;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      child: IgnorePointer(
        child: Image.network(
          thumbnailUrl ?? '',
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => Container(color: Colors.black),
        ),
      ),
    );
  }
}

class _GradientOverlay extends StatelessWidget {
  const _GradientOverlay();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.transparent, Colors.black87],
          begin: Alignment.center,
          end: Alignment.bottomCenter,
          stops: [0.6, 1.0],
        ),
      ),
    );
  }
}

class _PlayIndicator extends StatelessWidget {
  const _PlayIndicator();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.black38,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.play_arrow,
          color: Colors.white70,
          size: 48,
        ),
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({required this.entry});

  final ReelFeedEntry entry;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 4,
      bottom: 120,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ReelActionButton(
            icon: Icons.share,
            label: 'Share',
            onTap: () => _shareReel(),
          ),
          const SizedBox(height: 12),
          ReelActionButton(
            icon: Icons.open_in_new,
            label: 'Open',
            onTap: () async {
              final uri = Uri.parse(entry.link);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _shareReel() async {
    await ShareService.instance.shareReel(
      title: entry.title,
      videoUrl: entry.link,
    );
  }
}

class _InfoLayer extends HookWidget {
  const _InfoLayer({
    required this.entry,
    required this.isTextExpanded,
  });

  final ReelFeedEntry entry;
  final ValueNotifier<bool> isTextExpanded;

  @override
  Widget build(BuildContext context) {
    // Watch the value notifier
    final expanded = useValueListenable(isTextExpanded);

    return Positioned(
      left: 16,
      right: 16,
      bottom: 32,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          IgnorePointer(
            child: _SourceBadge(source: entry.source),
          ),
          const SizedBox(height: 12),
          IgnorePointer(
            child: Text(
              entry.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (entry.summary.isNotEmpty) ...[
            const SizedBox(height: 8),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                isTextExpanded.value = !isTextExpanded.value;
              },
              child: Text(
                entry.summary,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.3,
                ),
                maxLines: expanded ? null : 2,
                overflow: expanded ? null : TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.source});

  final String source;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        source,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _ErrorIndicator extends StatelessWidget {
  const _ErrorIndicator({this.error});
  
  final YTPlayerError? error;

  @override
  Widget build(BuildContext context) {
    String message = 'Failed to load video';
    String hint = 'Tap to retry';
    
    if (error != null) {
      if (error!.isPlaybackDisabled) {
        message = 'Playback disabled';
        hint = 'Video owner disabled playback';
      } else if (error!.isVideoUnavailable) {
        message = 'Video unavailable';
        hint = 'Video may be private or removed';
      } else if (error!.isConfigError) {
        message = 'Configuration error';
        hint = 'Tap to retry';
      }
    }
    
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(color: Colors.grey[400]),
          ),
          const SizedBox(height: 4),
          Text(
            hint,
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
        ],
      ),
    );
  }
}
