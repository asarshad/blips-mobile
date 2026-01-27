import 'package:blips_mobile/core/error/error.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:blips_mobile/features/feed/providers/feed_providers.dart';
import 'package:blips_mobile/features/feed/providers/video/youtube_player_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'reel_item.dart';

/// Optimized Reels page with video player pooling and preloading.
///
/// Uses YouTube IFrame API for reliable playback without stream URL extraction.
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
    final videoManager = ref.watch(youtubePlayerManagerProvider);
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

  /// Preload initial videos when data loads.
  void _useInitialPreload(
    AsyncValue<List<ReelFeedEntry>> reelsFeed,
    YoutubePlayerManager videoManager,
    bool isVisible,
  ) {
    useEffect(() {
      if (reelsFeed.hasValue && reelsFeed.value!.isNotEmpty) {
        final entries = reelsFeed.value!;

        // Preload first 5 videos for smoother swiping
        final preloadCount = entries.length.clamp(0, 5);
        for (var i = 0; i < preloadCount; i++) {
          final link = entries[i].link;
          if (i == 0) {
            if (isVisible) {
              videoManager.playVideo(link);
            } else {
              videoManager.initController(link);
            }
          } else {
            videoManager.initController(link);
          }
        }
      }
      return null;
    }, [reelsFeed.hasValue]);
  }

  /// Handle visibility changes.
  void _useVisibilityHandler(
    AsyncValue<List<ReelFeedEntry>> reelsFeed,
    YoutubePlayerManager videoManager,
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
          // Release all resources when leaving reels tab
          videoManager.releaseAll();
          logger.debug(
            'Reels tab hidden: released all video resources',
            category: LogCategory.video,
          );
        }
      }
      return null;
    }, [isVisible]);
  }

  Widget _buildContent({
    required List<ReelFeedEntry> entries,
    required PageController controller,
    required YoutubePlayerManager videoManager,
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

    return PageView.builder(
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
        key: ValueKey(entries[index].link),
        entry: entries[index],
        isActive: index == currentIndex.value,
        isVisible: isVisible,
      ),
    );
  }
}
