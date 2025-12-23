import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:blips_mobile/features/feed/providers/feed_providers.dart';
import 'package:blips_mobile/features/feed/providers/optimized_video_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

/// Optimized Reels page with video player pooling and preloading
/// for near-instant playback (target: <200ms time-to-first-frame)
class OptimizedReelsPage extends HookConsumerWidget {
  const OptimizedReelsPage({
    super.key,
    this.isVisible = true,
  });

  final bool isVisible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reelsFeed = ref.watch(reelsFeedProvider);
    final controller = usePageController();
    final videoManager = ref.watch(optimizedVideoManagerProvider);
    final currentIndex = useState(0);

    // Preload initial videos when data loads
    useEffect(() {
      if (reelsFeed.hasValue && reelsFeed.value!.isNotEmpty) {
        final entries = reelsFeed.value!;
        final urls = entries.map((e) => e.link).toList();

        // Preload first few videos
        for (var i = 0; i < 3 && i < urls.length; i++) {
          if (i == 0) {
            // Play first video immediately if visible
            if (isVisible) {
              videoManager.playVideo(urls[i]);
            } else {
              videoManager.preload(urls[i]);
            }
          } else {
            videoManager.preload(urls[i]);
          }
        }
      }
      return null;
    }, [reelsFeed.hasValue]);

    // Handle visibility changes
    useEffect(() {
      if (reelsFeed.hasValue && reelsFeed.value!.isNotEmpty) {
        final entries = reelsFeed.value!;
        if (isVisible) {
          videoManager.playVideo(entries[currentIndex.value].link);
        } else {
          videoManager.pauseAll();
        }
      }
      return null;
    }, [isVisible]);

    return Scaffold(
      backgroundColor: Colors.black,
      body: reelsFeed.when(
        data: (entries) {
          if (entries.isEmpty) {
            return const Center(
              child: Text(
                'No reels available right now.',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          final urls = entries.map((e) => e.link).toList();

          return Stack(
            children: [
              PageView.builder(
                controller: controller,
                scrollDirection: Axis.vertical,
                allowImplicitScrolling: true,
                onPageChanged: (index) {
                  currentIndex.value = index;

                  // Use the feed manager extension for optimal preloading
                  videoManager.onPageChanged(
                    currentIndex: index,
                    videoUrls: urls,
                  );

                  // Pagination: Load more when we get close to the end
                  if (index >= entries.length - 3) {
                    Future.microtask(
                      () => ref.read(reelsFeedProvider.notifier).loadMore(),
                    );
                  }
                },
                itemCount: entries.length,
                itemBuilder: (context, index) => _OptimizedReelItem(
                  entry: entries[index],
                  isActive: index == currentIndex.value,
                  isVisible: isVisible,
                ),
              ),

              // Performance overlay (debug mode only)
              if (const bool.fromEnvironment('dart.vm.product') == false)
                _PerformanceOverlay(videoManager: videoManager),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                'Error loading reels',
                style: TextStyle(color: Colors.grey[400]),
              ),
              TextButton(
                onPressed: () => ref.invalidate(reelsFeedProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptimizedReelItem extends HookConsumerWidget {
  const _OptimizedReelItem({
    required this.entry,
    required this.isActive,
    required this.isVisible,
  });

  final ReelFeedEntry entry;
  final bool isActive;
  final bool isVisible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videoManager = ref.watch(optimizedVideoManagerProvider);
    final controller = videoManager.getController(entry.link);
    final playerState = videoManager.getPlayerState(entry.link);
    final showThumbnail = useState(true);
    final isMounted = useIsMounted();

    // Track when video is actually playing to hide thumbnail
    // Use post-frame callback to avoid setState during build
    useEffect(() {
      if (controller != null) {
        void listener() {
          // Schedule state update after current frame
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

    // Don't manage play/pause here - let the parent page handle it via onPageChanged
    // This prevents race conditions and multiple videos playing

    final isLoading =
        playerState == PlayerState.loading || playerState == null;
    final isError = playerState == PlayerState.error;

    return GestureDetector(
      onTap: () {
        if (controller != null) {
          if (controller.value.isPlaying) {
            videoManager.pauseVideo(entry.link);
          } else {
            videoManager.playVideo(entry.link);
          }
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video Layer
          if (controller != null && controller.value.isInitialized)
            Center(
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: VideoPlayer(controller),
              ),
            ),

          // Thumbnail Layer - Fades out when video starts playing
          AnimatedOpacity(
            opacity: showThumbnail.value ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            child: IgnorePointer(
              child: Image.network(
                entry.thumbnailUrl ?? '',
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (_, __, ___) => Container(color: Colors.black),
              ),
            ),
          ),

          // Gradient Overlay
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, Colors.black87],
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                stops: [0.6, 1.0],
              ),
            ),
          ),

          // Play/Pause indicator (shown briefly on tap)
          if (controller != null && !controller.value.isPlaying && isActive)
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white70,
                  size: 48,
                ),
              ),
            ),

          // Action Buttons
          Positioned(
            right: 4,
            bottom: 120,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ReelActionButton(
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
          ),

          // Info Layer
          Positioned(
            left: 16,
            right: 16,
            bottom: 32,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        entry.source,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
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
                if (entry.summary.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    entry.summary,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.3,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          // Loading Indicator
          if (isActive && isLoading)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),

          // Error indicator
          if (isError)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 8),
                  Text(
                    'Failed to load video',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ReelActionButton extends StatelessWidget {
  const _ReelActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black45,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              shadows: [
                Shadow(
                  color: Colors.black,
                  offset: Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Performance overlay for debugging (only shown in debug mode)
class _PerformanceOverlay extends StatelessWidget {
  const _PerformanceOverlay({required this.videoManager});

  final OptimizedVideoPlayerManager videoManager;

  @override
  Widget build(BuildContext context) {
    final avgTime = videoManager.averageTimeToFirstFrame;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 8,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Video Performance',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Avg TTFF: ${avgTime?.inMilliseconds ?? '-'}ms',
              style: TextStyle(
                color: avgTime != null && avgTime.inMilliseconds < 200
                    ? Colors.greenAccent
                    : Colors.orangeAccent,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
