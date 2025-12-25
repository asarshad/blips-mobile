import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:blips_mobile/features/feed/providers/optimized_video_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import 'reel_action_button.dart';

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
    final videoManager = ref.watch(optimizedVideoManagerProvider);
    final controller = videoManager.getController(entry.link);
    final playerState = videoManager.getPlayerState(entry.link);
    final showThumbnail = useState(true);
    final isMounted = useIsMounted();

    // Track when video is actually playing to hide thumbnail
    _useThumbnailVisibility(
      controller: controller,
      isActive: isActive,
      showThumbnail: showThumbnail,
      isMounted: isMounted,
    );

    final isLoading =
        playerState == PlayerState.loading || playerState == null;
    final isError = playerState == PlayerState.error;

    return GestureDetector(
      onTap: () => _handleTap(controller, videoManager, playerState),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video Layer
          if (controller != null && controller.value.isInitialized)
            _VideoLayer(controller: controller),

          // Thumbnail Layer
          _ThumbnailLayer(
            thumbnailUrl: entry.thumbnailUrl,
            isVisible: showThumbnail.value,
          ),

          // Gradient Overlay
          const _GradientOverlay(),

          // Play indicator - show when paused OR when there's an error (tap to retry)
          if (isActive && (controller == null || !controller.value.isPlaying))
            const _PlayIndicator(),

          // Action Buttons
          _ActionButtons(entry: entry),

          // Info Layer
          _InfoLayer(entry: entry),

          // Loading Indicator
          if (isActive && isLoading)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),

          // Error indicator
          if (isError) const _ErrorIndicator(),
        ],
      ),
    );
  }

  void _useThumbnailVisibility({
    required VideoPlayerController? controller,
    required bool isActive,
    required ValueNotifier<bool> showThumbnail,
    required bool Function() isMounted,
  }) {
    useEffect(() {
      if (controller != null) {
        void listener() {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!isMounted()) return;

            final isPlaying = controller.value.isPlaying;
            final hasPosition = controller.value.position > Duration.zero;

            if (isPlaying && hasPosition && showThumbnail.value) {
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
    VideoPlayerController? controller,
    OptimizedVideoPlayerManager videoManager,
    PlayerState? playerState,
  ) {
    // If error state, retry loading
    if (playerState == PlayerState.error) {
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
    if (controller.value.isPlaying) {
      videoManager.pauseVideo(entry.link);
    } else {
      videoManager.playVideo(entry.link);
    }
  }
}

class _VideoLayer extends StatelessWidget {
  const _VideoLayer({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: VideoPlayer(controller),
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
}

class _InfoLayer extends StatefulWidget {
  const _InfoLayer({required this.entry});

  final ReelFeedEntry entry;

  @override
  State<_InfoLayer> createState() => _InfoLayerState();
}

class _InfoLayerState extends State<_InfoLayer> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 32,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _SourceBadge(source: widget.entry.source),
          const SizedBox(height: 12),
          Text(
            widget.entry.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (widget.entry.summary.isNotEmpty) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: AnimatedCrossFade(
                firstChild: Text(
                  widget.entry.summary,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                secondChild: Text(
                  widget.entry.summary,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.3,
                  ),
                ),
                crossFadeState: _isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
            ),
            if (widget.entry.summary.length > 80) ...[
              const SizedBox(height: 4),
              Text(
                _isExpanded ? 'tap to collapse' : 'tap to expand...',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
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
  const _ErrorIndicator();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 8),
          Text(
            'Failed to load video',
            style: TextStyle(color: Colors.grey[400]),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap to retry',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
        ],
      ),
    );
  }
}
