import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:blips_mobile/features/feed/providers/feed_providers.dart';
import 'package:blips_mobile/features/feed/providers/video_player_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class ReelsPage extends HookConsumerWidget {
  const ReelsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reelsFeed = ref.watch(reelsFeedProvider);
    final controller = usePageController();
    final videoManager = ref.watch(videoPlayerManagerProvider);

    useEffect(() {
      if (reelsFeed.hasValue && reelsFeed.value!.isNotEmpty) {
        final entries = reelsFeed.value!;
        // Play first
        videoManager.play(entries[0].link);
        
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
              // 1. Play current
              final currentEntry = entries[index];
              videoManager.play(currentEntry.link);

              // 2. Pause previous
              if (index > 0) {
                final prevEntry = entries[index - 1];
                videoManager.pause(prevEntry.link);
              }
              if (index < entries.length - 1) {
                final nextEntry = entries[index + 1];
                videoManager.pause(nextEntry.link);
              }

              // 3. Preload next 2
              if (index + 1 < entries.length) {
                videoManager.initController(entries[index + 1].link);
              }
              if (index + 2 < entries.length) {
                videoManager.initController(entries[index + 2].link);
              }

              // 4. Dispose old
              if (index > 1) {
                videoManager.disposeController(entries[index - 2].link);
              }
            },
            itemCount: entries.length,
            itemBuilder: (context, index) => _ReelItem(entry: entries[index]),
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
  const _ReelItem({required this.entry});

  final ReelFeedEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videoManager = ref.watch(videoPlayerManagerProvider);
    final controller = videoManager.getController(entry.link);
    final isPlayerReady = useState(false);

    // Trigger init if not ready
    useEffect(() {
      if (controller == null) {
        videoManager.initController(entry.link);
      }
      return null;
    }, [entry.link]);

    // Sync play state
    useEffect(() {
      if (controller != null && isPlayerReady.value) {
        if (videoManager.shouldPlay(entry.link)) {
          controller.play();
        } else {
          controller.pause();
        }
      }
      return null;
    }, [videoManager.shouldPlay(entry.link), isPlayerReady.value, controller]);

    return Stack(
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
                  if (videoManager.shouldPlay(entry.link)) {
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
          ),
        ),

        // Loading Indicator
        if (!isPlayerReady.value)
          const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
      ],
    );
  }
}
