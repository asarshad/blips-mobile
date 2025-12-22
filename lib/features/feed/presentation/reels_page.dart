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
    
    // Listen to controller changes to update UI (play/pause icon)
    if (controller != null) {
      useListenable(controller);
    }

    final isPlayerReady = useState(false);

    // Sync play state
    useEffect(() {
      if (controller != null && isPlayerReady.value) {
        if (isActive && isVisible) {
          controller.play();
        } else {
          controller.pause();
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
            )
          else
            Image.network(
              entry.thumbnailUrl ?? '',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: Colors.black),
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
          if (!isPlayerReady.value)
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
