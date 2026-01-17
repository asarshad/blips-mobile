import 'package:blips_mobile/core/error/error.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:blips_mobile/features/feed/providers/feed_providers.dart';
import 'package:blips_mobile/features/feed/providers/video_player_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class ReelsPage extends HookConsumerWidget {
  const ReelsPage({
    super.key,
    this.isVisible = true,
  });

  final bool isVisible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reelsFeed = ref.watch(reelsFeedProvider);
    final controller = usePageController();
    final videoManager = ref.watch(videoPlayerManagerProvider);
    final currentIndex = useState(0);

    // Preload initial items
    useEffect(() {
      if (reelsFeed.hasValue && reelsFeed.value!.isNotEmpty) {
        final entries = reelsFeed.value!;
        // Init first item
        videoManager.initController(entries[0].link);
        // Preload second
        if (entries.length > 1) {
          videoManager.initController(entries[1].link);
        }
      }
      return null;
    }, [reelsFeed.hasValue]);

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

          return PageView.builder(
            controller: controller,
            scrollDirection: Axis.vertical,
            allowImplicitScrolling: true,
            onPageChanged: (index) {
              currentIndex.value = index;

              // 1. Ensure current is initialized
              videoManager.initController(entries[index].link);

              // 2. Preload next 2
              if (index + 1 < entries.length) {
                videoManager.initController(entries[index + 1].link);
              }
              if (index + 2 < entries.length) {
                videoManager.initController(entries[index + 2].link);
              }

              // 3. Dispose old
              if (index > 1) {
                videoManager.disposeController(entries[index - 2].link);
              }

              // 4. Pagination: Load more when we get close to the end
              if (index >= entries.length - 3) {
                Future.microtask(
                  () => ref.read(reelsFeedProvider.notifier).loadMore(),
                );
              }
            },
            itemCount: entries.length,
            itemBuilder: (context, index) => _ReelItem(
              entry: entries[index],
              isActive: index == currentIndex.value,
              isVisible: isVisible,
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Theme(
          data: ThemeData.dark(),
          child: ErrorView(
            error: error,
            onRetry: () => ref.invalidate(reelsFeedProvider),
          ),
        ),
      ),
    );
  }
}

class _ReelItem extends HookConsumerWidget {
  const _ReelItem({
    required this.entry,
    required this.isActive,
    required this.isVisible,
  });

  final ReelFeedEntry entry;
  final bool isActive;
  final bool isVisible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videoManager = ref.watch(videoPlayerManagerProvider);
    final controller = videoManager.getController(entry.link);
    final isPlayerReady = useState(false);
    final isVideoPlaying = useState(false);

    // Listen to controller changes to update UI (play/pause icon)
    // We use a dummy listenable when controller is null to maintain hook consistency
    final dummyListenable = useMemoized(() => ChangeNotifier());
    useListenable(controller ?? dummyListenable);

    // Track when video is actually playing (not just ready)
    useEffect(() {
      if (controller != null) {
        void listener() {
          final playing = controller.value.isPlaying;
          if (playing && !isVideoPlaying.value) {
            // Small delay to ensure video frame is visible before hiding thumbnail
            Future.delayed(const Duration(milliseconds: 200), () {
              if (controller.value.isPlaying) {
                isVideoPlaying.value = true;
              }
            });
          } else if (!playing && !isActive) {
            // Reset when paused and not active (swiped away)
            isVideoPlaying.value = false;
          }
        }

        controller.addListener(listener);
        return () => controller.removeListener(listener);
      }
      return null;
    }, [controller, isActive]);

    // Sync play state
    useEffect(() {
      if (controller != null && isPlayerReady.value) {
        if (isActive && isVisible) {
          controller.play();
        } else {
          controller.pause();
          // Reset playing state when not active
          if (!isActive) {
            isVideoPlaying.value = false;
          }
        }
      }
      return null;
    }, [isActive, isVisible, isPlayerReady.value, controller]);

    return GestureDetector(
      onTap: () {
        if (controller != null) {
          if (controller.value.isPlaying) {
            controller.pause();
          } else {
            controller.play();
          }
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video Layer
          if (controller != null)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: 1080, // Aspect ratio 9:16
                height: 1920,
                child: YoutubePlayer(
                  controller: controller,
                  showVideoProgressIndicator: false,
                  onReady: () {
                    isPlayerReady.value = true;
                    if (isActive && isVisible) {
                      controller.play();
                    }
                  },
                ),
              ),
            ),

          // Thumbnail Layer - Fades out only when video is actually playing
          IgnorePointer(
            ignoring: true,
            child: AnimatedOpacity(
              opacity: isVideoPlaying.value ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
              child: Image.network(
                entry.thumbnailUrl ?? '',
                fit: BoxFit.cover,
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
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
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
                          horizontal: 8, vertical: 4),
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

          // Loading Indicator - only show when active and not yet playing
          if (isActive && !isVideoPlaying.value)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
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
