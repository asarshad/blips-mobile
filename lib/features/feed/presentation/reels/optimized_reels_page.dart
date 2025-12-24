import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:blips_mobile/features/feed/providers/feed_providers.dart';
import 'package:blips_mobile/features/feed/providers/optimized_video_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'reel_item.dart';
import 'video_performance_overlay.dart';

/// Optimized Reels page with video player pooling and preloading.
/// 
/// Achieves near-instant playback (target: <200ms time-to-first-frame)
/// through intelligent preloading and player pooling.
class OptimizedReelsPage extends HookConsumerWidget {
  /// Creates an optimized reels page.
  const OptimizedReelsPage({
    super.key,
    this.isVisible = true,
  });

  /// Whether this page is currently visible.
  final bool isVisible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reelsFeed = ref.watch(reelsFeedProvider);
    final controller = usePageController();
    final videoManager = ref.watch(optimizedVideoManagerProvider);
    final currentIndex = useState(0);

    _useInitialPreload(reelsFeed, videoManager, isVisible);
    _useVisibilityHandler(reelsFeed, videoManager, isVisible, currentIndex);

    return Scaffold(
      backgroundColor: Colors.black,
      body: reelsFeed.when(
        data: (entries) => _buildContent(
          entries: entries,
          controller: controller,
          videoManager: videoManager,
          currentIndex: currentIndex,
          ref: ref,
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _ErrorView(
          onRetry: () => ref.invalidate(reelsFeedProvider),
        ),
      ),
    );
  }

  /// Preload initial videos when data loads.
  void _useInitialPreload(
    AsyncValue<List<ReelFeedEntry>> reelsFeed,
    OptimizedVideoPlayerManager videoManager,
    bool isVisible,
  ) {
    useEffect(() {
      if (reelsFeed.hasValue && reelsFeed.value!.isNotEmpty) {
        final entries = reelsFeed.value!;

        // Preload first few videos
        for (var i = 0; i < 3 && i < entries.length; i++) {
          final link = entries[i].link;
          if (i == 0) {
            if (isVisible) {
              videoManager.playVideo(link);
            } else {
              videoManager.preload(link);
            }
          } else {
            videoManager.preload(link);
          }
        }
      }
      return null;
    }, [reelsFeed.hasValue]);
  }

  /// Handle visibility changes.
  void _useVisibilityHandler(
    AsyncValue<List<ReelFeedEntry>> reelsFeed,
    OptimizedVideoPlayerManager videoManager,
    bool isVisible,
    ValueNotifier<int> currentIndex,
  ) {
    useEffect(() {
      if (reelsFeed.hasValue && reelsFeed.value!.isNotEmpty) {
        final entries = reelsFeed.value!;
        if (isVisible) {
          final link = entries[currentIndex.value].link;
          videoManager.playVideo(link);
        } else {
          videoManager.pauseAll();
        }
      }
      return null;
    }, [isVisible]);
  }

  Widget _buildContent({
    required List<ReelFeedEntry> entries,
    required PageController controller,
    required OptimizedVideoPlayerManager videoManager,
    required ValueNotifier<int> currentIndex,
    required WidgetRef ref,
  }) {
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

            videoManager.onPageChanged(
              currentIndex: index,
              videoUrls: urls,
            );

            // Pagination: Load more when close to end
            if (index >= entries.length - 3) {
              Future.microtask(
                () => ref.read(reelsFeedProvider.notifier).loadMore(),
              );
            }
          },
          itemCount: entries.length,
          itemBuilder: (context, index) => ReelItem(
            entry: entries[index],
            isActive: index == currentIndex.value,
            isVisible: isVisible,
          ),
        ),

        // Performance overlay (debug mode only)
        if (const bool.fromEnvironment('dart.vm.product') == false)
          VideoPerformanceOverlay(videoManager: videoManager),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
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
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
