import 'package:blips_mobile/core/error/error.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:blips_mobile/features/feed/providers/feed_providers.dart';
import 'package:blips_mobile/features/feed/providers/video/youtube_player_manager.dart';
import 'package:blips_mobile/features/feed/providers/video/youtube_player_manager_base.dart';
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
  ///
  /// Only initialises controllers — does NOT call playVideo.
  /// Playback is started exclusively by `_useVisibilityHandler` so there is a
  /// single, authoritative place that decides what should be playing.  Having
  /// `isVisible` in this effect's deps caused it to re-run on every tab switch
  /// and call playVideo(entries[0]) instead of entries[currentIndex], fighting
  /// with [_useVisibilityHandler].
  void _useInitialPreload(
    AsyncValue<List<ReelFeedEntry>> reelsFeed,
    YoutubePlayerManagerBase videoManager,
    bool isVisible,
  ) {
    useEffect(() {
      debugPrint(
          'ReelsPage: _useInitialPreload effect - hasValue=${reelsFeed.hasValue}, isVisible=$isVisible');
      if (reelsFeed.hasValue && reelsFeed.value!.isNotEmpty) {
        final entries = reelsFeed.value!;

        // Initialise first 5 controllers so they are warm when the user starts
        // swiping.  Playback is triggered by _useVisibilityHandler.
        final preloadCount = entries.length.clamp(0, 5);
        for (var i = 0; i < preloadCount; i++) {
          videoManager.initController(entries[i].link);
        }
      }
      return null;
    }, [reelsFeed.hasValue]); // isVisible intentionally excluded — see above
  }

  /// Handle visibility changes.
  void _useVisibilityHandler(
    AsyncValue<List<ReelFeedEntry>> reelsFeed,
    YoutubePlayerManagerBase videoManager,
    bool isVisible,
    ValueNotifier<int> currentIndex,
  ) {
    useEffect(() {
      if (!reelsFeed.hasValue || reelsFeed.value!.isEmpty) return null;

      final entries = reelsFeed.value!;
      if (isVisible) {
        // Play current video when becoming visible
        final index = currentIndex.value.clamp(0, entries.length - 1);
        final link = entries[index].link;
        debugPrint('ReelsPage: Visibility ON - playing video at index $index');
        videoManager.playVideo(link);
      } else {
        // Pause all when leaving (keep cached for faster resume)
        debugPrint('ReelsPage: Visibility OFF - pausing all');
        videoManager.pauseAll();
      }
      return null;
    }, [isVisible, reelsFeed.hasValue]);
  }

  Widget _buildContent({
    required List<ReelFeedEntry> entries,
    required PageController controller,
    required YoutubePlayerManagerBase videoManager,
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

        // Track current view index for seamless cache updates
        ref.read(reelsFeedProvider.notifier).setCurrentViewIndex(index);

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
