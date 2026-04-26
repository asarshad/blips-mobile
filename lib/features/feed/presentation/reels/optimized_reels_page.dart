import 'dart:async';

import 'package:blips_mobile/core/config/memory_config.dart';
import 'package:blips_mobile/core/error/error.dart';
import 'package:blips_mobile/features/ads/domain/feed_page_item.dart';
import 'package:blips_mobile/features/ads/presentation/ad_card.dart';
import 'package:blips_mobile/features/ads/presentation/native_ad_card.dart';
import 'package:blips_mobile/features/feed/data/feed_repository.dart';
import 'package:blips_mobile/features/feed/data/feed_session_store.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:blips_mobile/features/feed/presentation/reels/reel_item.dart';
import 'package:blips_mobile/features/feed/presentation/widgets/widgets.dart';
import 'package:blips_mobile/features/feed/providers/feed_providers.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

const _loadMoreOrganicRemainingThreshold = 10;

/// Shared player flags for every pre-warmed controller in the pool.
///
/// Mirrors the flags used inside [ReelItem] so there is no visible difference
/// when a pooled controller is adopted by the widget.
const _kReelPlayerFlags = YoutubePlayerFlags(
  hideControls: true,
  autoPlay: false,
  loop: false,
  disableDragSeek: true,
  enableCaption: false,
);

/// Reels page — vertical PageView of [ReelItem] widgets.
///
/// Each [ReelItem] owns its own [YoutubePlayerController]; this page only
/// tracks pagination, analytics, and caught-up state. No video pool needed.
class OptimizedReelsPage extends HookConsumerWidget {
  const OptimizedReelsPage({
    super.key,
    this.isVisible = true,
    this.controller,
    this.onManualRefresh,
  });

  /// Whether this page is currently visible to the user.
  final bool isVisible;

  /// External page controller owned by the shell.
  final PageController? controller;

  /// Called when the user taps a visible refresh/retry button.
  final VoidCallback? onManualRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reelsFeed = ref.watch(reelsFeedWithAdsProvider);
    final fallbackController = usePageController();
    final effectiveController = controller ?? fallbackController;
    final currentIndex = useState(0);
    final lastCaughtUpEntryId = useRef<int?>(null);
    final reelsNotifier = ref.read(reelsFeedProvider.notifier);
    final uiState = ref.watch(feedSurfaceUiStateProvider(FeedSurface.reels));
    final isMounted = useIsMounted();
    final autoRetryInProgress = useState(false);
    final autoRetryAttempts = useRef(0);

    // ── Controller pool ───────────────────────────────────────────────────────
    // Keyed by ReelFeedEntry.id so controllers survive feed refreshes that
    // insert / reorder entries without changing content ids.
    final pool = useRef<Map<int, YoutubePlayerController>>({});

    // Incrementing this triggers a widget rebuild so itemBuilder picks up
    // controllers that were just added to the pool.
    final poolVersion = useState(0);

    // Close every pooled controller when this widget is disposed.
    useEffect(() {
      return () {
        for (final c in pool.value.values) {
          c.dispose();
        }
        pool.value.clear();
      };
    }, const []);

    // Maintain the pool window as the user scrolls.
    useEffect(() {
      final pageItems = reelsFeed.valueOrNull;
      if (pageItems == null || pageItems.isEmpty) return null;

      // Build an ordered list of (pageIndex, entry) pairs for all organic reels.
      final organicReels = <(int, ReelFeedEntry)>[];
      for (var i = 0; i < pageItems.length; i++) {
        final organic = pageItems[i].organicEntry;
        if (organic is ReelFeedEntry) organicReels.add((i, organic));
      }
      if (organicReels.isEmpty) return null;

      // Find which organic position corresponds to the current page index.
      // Walk forward: the last organic entry whose page index ≤ currentIndex.
      var currentOrganicPos = 0;
      for (var i = 0; i < organicReels.length; i++) {
        if (organicReels[i].$1 <= currentIndex.value) {
          currentOrganicPos = i;
        } else {
          break;
        }
      }

      // Compute the desired window around the current organic position.
      final windowStart = (currentOrganicPos - MemoryConfig.reelPreloadBehind)
          .clamp(0, organicReels.length - 1);
      final windowEnd = (currentOrganicPos + MemoryConfig.reelPreloadAhead)
          .clamp(0, organicReels.length - 1);

      // Collect the entry ids that should be in the pool.
      final desiredIds = <int>{
        for (var i = windowStart; i <= windowEnd; i++) organicReels[i].$2.id,
      };

      var changed = false;

      // Create controllers for entries entering the window.
      for (var i = windowStart; i <= windowEnd; i++) {
        final entry = organicReels[i].$2;
        if (pool.value.containsKey(entry.id)) continue;

        final videoId = YoutubePlayer.convertUrlToId(entry.link);
        if (videoId == null) continue;

        pool.value[entry.id] = YoutubePlayerController(
          initialVideoId: videoId,
          flags: _kReelPlayerFlags,
        );
        changed = true;
      }

      // Evict and close controllers for entries leaving the window.
      final staleIds =
          pool.value.keys.where((id) => !desiredIds.contains(id)).toList();
      for (final id in staleIds) {
        pool.value.remove(id)?.dispose();
        changed = true;
      }

      // Trigger a rebuild so itemBuilder sees the updated pool.
      if (changed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (isMounted()) poolVersion.value++;
        });
      }

      return null;
    }, [reelsFeed.valueOrNull, currentIndex.value]);

    // Clear auto-retry counter when data arrives.
    useEffect(() {
      if (reelsFeed.hasValue) {
        autoRetryAttempts.value = 0;
        autoRetryInProgress.value = false;
      }
      return null;
    }, [reelsFeed.valueOrNull]);

    // Single automatic retry on error.
    useEffect(() {
      if (!reelsFeed.hasError || !isVisible) {
        autoRetryInProgress.value = false;
        return null;
      }
      if (autoRetryInProgress.value || autoRetryAttempts.value >= 1) {
        return null;
      }

      autoRetryInProgress.value = true;
      final timer = Timer(const Duration(milliseconds: 900), () async {
        if (!isMounted()) return;
        autoRetryAttempts.value += 1;
        final ok = await reelsNotifier.manualRefresh();
        if (!isMounted()) return;
        autoRetryInProgress.value = false;
        if (ok) autoRetryAttempts.value = 0;
      });
      return timer.cancel;
    }, [reelsFeed.hasError, isVisible, autoRetryInProgress.value]);

    _useCaughtUpTracking(
      ref: ref,
      reelsFeed: reelsFeed,
      currentIndex: currentIndex,
      isCaughtUp: reelsNotifier.isCaughtUp,
      lastCaughtUpEntryId: lastCaughtUpEntryId,
    );
    _useRestorePosition(
      reelsFeed: reelsFeed,
      controller: effectiveController,
      currentIndex: currentIndex,
      restoreEntryId: uiState.restoreItemId,
      restoreApproximateIndex: uiState.restoreApproximateIndex,
      onRestoreApplied: reelsNotifier.consumeRestoreTarget,
    );
    _useLoadMoreNearEnd(
      reelsFeed: reelsFeed,
      currentIndex: currentIndex,
      isMounted: isMounted,
      onLoadMore: () => ref.read(reelsFeedProvider.notifier).loadMore(),
    );
    _useExposureTracking(
      reelsFeed: reelsFeed,
      currentIndex: currentIndex,
      isVisible: isVisible,
      onExposed: reelsNotifier.markExposed,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: reelsFeed.when(
        data: (entries) => _buildContent(
          context: context,
          entries: entries,
          controller: effectiveController,
          currentIndex: currentIndex,
          isMounted: isMounted,
          hasMore: reelsNotifier.hasMore,
          isCaughtUp: reelsNotifier.isCaughtUp,
          uiState: uiState,
          ref: ref,
          pool: pool,
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => autoRetryInProgress.value
            ? const Center(child: CircularProgressIndicator())
            : Theme(
                data: ThemeData.dark(),
                child: ErrorView(
                  error: error,
                  onRetry: onManualRefresh ??
                      () => ref.invalidate(reelsFeedProvider),
                ),
              ),
      ),
    );
  }

  void _useCaughtUpTracking({
    required WidgetRef ref,
    required AsyncValue<List<FeedPageItem>> reelsFeed,
    required ValueNotifier<int> currentIndex,
    required bool isCaughtUp,
    required ObjectRef<int?> lastCaughtUpEntryId,
  }) {
    useEffect(() {
      final pageItems = reelsFeed.valueOrNull;
      if (pageItems == null || pageItems.isEmpty || !isCaughtUp) return null;

      final entries = _organicEntries(pageItems);
      if (entries.isEmpty) return null;

      final pageIndex = currentIndex.value.clamp(0, pageItems.length - 1);
      final organicIndex = _organicIndexForPageIndex(pageItems, pageIndex);
      if (organicIndex == null || organicIndex < entries.length - 1) {
        return null;
      }

      final entry = entries[organicIndex];
      if (lastCaughtUpEntryId.value == entry.id) return null;

      lastCaughtUpEntryId.value = entry.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(
          ref.read(feedRepositoryProvider).recordInteraction(
            contentItemId: entry.id,
            eventType: FeedInteractionEvent.caughtUp,
            extraData: const {'surface': 'reels'},
          ),
        );
      });
      return null;
    }, [reelsFeed.valueOrNull, currentIndex.value, isCaughtUp]);
  }

  void _useRestorePosition({
    required AsyncValue<List<FeedPageItem>> reelsFeed,
    required PageController controller,
    required ValueNotifier<int> currentIndex,
    required int? restoreEntryId,
    required int? restoreApproximateIndex,
    required VoidCallback onRestoreApplied,
  }) {
    useEffect(() {
      final pageItems = reelsFeed.valueOrNull;
      if (pageItems == null || pageItems.isEmpty) return null;
      if (restoreEntryId == null && restoreApproximateIndex == null) {
        return null;
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!controller.hasClients) return;

        final exactIndex = restoreEntryId == null
            ? -1
            : pageItems.indexWhere(
                (e) => e.organicEntry?.id == restoreEntryId,
              );
        final targetIndex = exactIndex >= 0
            ? exactIndex
            : (restoreApproximateIndex == null
                ? 0
                : (_pageIndexForOrganicIndex(
                        pageItems, restoreApproximateIndex) ??
                    0));
        controller.jumpToPage(targetIndex);
        currentIndex.value = targetIndex;
        onRestoreApplied();
      });
      return null;
    }, [reelsFeed.valueOrNull, restoreEntryId, restoreApproximateIndex]);
  }

  void _useExposureTracking({
    required AsyncValue<List<FeedPageItem>> reelsFeed,
    required ValueNotifier<int> currentIndex,
    required bool isVisible,
    required Future<void> Function(int contentId) onExposed,
  }) {
    useEffect(() {
      final pageItems = reelsFeed.valueOrNull;
      if (!isVisible || pageItems == null || pageItems.isEmpty) return null;

      final index = currentIndex.value.clamp(0, pageItems.length - 1);
      final entry = pageItems[index].organicEntry;
      if (entry == null) return null;

      final timer = Timer(const Duration(seconds: 1), () {
        unawaited(onExposed(entry.id));
      });
      return timer.cancel;
    }, [reelsFeed.valueOrNull, currentIndex.value, isVisible]);
  }

  void _useLoadMoreNearEnd({
    required AsyncValue<List<FeedPageItem>> reelsFeed,
    required ValueNotifier<int> currentIndex,
    required bool Function() isMounted,
    required Future<void> Function() onLoadMore,
  }) {
    useEffect(() {
      final pageItems = reelsFeed.valueOrNull;
      if (pageItems == null || pageItems.isEmpty) return null;
      if (!_shouldLoadMore(pageItems, currentIndex.value)) return null;

      Future.microtask(() {
        if (isMounted()) unawaited(onLoadMore());
      });
      return null;
    }, [reelsFeed.valueOrNull, currentIndex.value]);
  }

  Widget _buildContent({
    required BuildContext context,
    required List<FeedPageItem> entries,
    required PageController controller,
    required ValueNotifier<int> currentIndex,
    required bool Function() isMounted,
    required bool hasMore,
    required bool isCaughtUp,
    required FeedSurfaceUiState uiState,
    required WidgetRef ref,
    required ObjectRef<Map<int, YoutubePlayerController>> pool,
  }) {
    if (entries.isEmpty) {
      return Theme(
        data: ThemeData.dark(),
        child: FeedMessageState(
          message: 'No reels available right now.',
          actionLabel: 'Refresh',
          onAction: onManualRefresh ?? () => ref.invalidate(reelsFeedProvider),
        ),
      );
    }

    final organicEntries = _organicEntries(entries);
    if (organicEntries.isEmpty) {
      return Theme(
        data: ThemeData.dark(),
        child: FeedMessageState(
          message: 'No reels available right now.',
          actionLabel: 'Refresh',
          onAction: onManualRefresh ?? () => ref.invalidate(reelsFeedProvider),
        ),
      );
    }

    final indexByStableId = <int, int>{
      for (var i = 0; i < entries.length; i++) entries[i].stableId: i,
    };

    final boundedIndex = currentIndex.value.clamp(0, entries.length - 1);
    final currentOrganicIndex =
        _organicIndexForPageIndex(entries, boundedIndex);
    final showCaughtUpBanner = isCaughtUp &&
        currentOrganicIndex != null &&
        currentOrganicIndex >= organicEntries.length - 1;
    final topActionLabel = uiState.pendingActionLabel;

    return Stack(
      children: [
        PageView.builder(
          controller: controller,
          scrollDirection: Axis.vertical,
          dragStartBehavior: DragStartBehavior.down,
          pageSnapping: true,
          physics: buildFeedPagePhysics(context),
          findChildIndexCallback: (key) {
            if (key is ValueKey<int>) return indexByStableId[key.value];
            return null;
          },
          onPageChanged: (index) {
            currentIndex.value = index;
            final organicEntry = entries[index].organicEntry;
            final organicIndex = _organicIndexForPageIndex(entries, index);

            if (organicEntry is ReelFeedEntry && organicIndex != null) {
              ref
                  .read(reelsFeedProvider.notifier)
                  .setCurrentViewPosition(organicIndex, organicEntry);
            }

            if (_shouldLoadMore(entries, index)) {
              Future.microtask(() {
                if (isMounted()) {
                  unawaited(ref.read(reelsFeedProvider.notifier).loadMore());
                }
              });
            }
          },
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final pageItem = entries[index];
            if (pageItem is NativeAdSlotFeedPageItem) {
              return NativeAdCard(slot: pageItem);
            }
            if (pageItem is SponsorCardFeedPageItem) {
              return AdCard(entry: pageItem.entry);
            }
            final organicEntry = pageItem.organicEntry;
            if (organicEntry is! ReelFeedEntry) {
              return const SizedBox.shrink();
            }
            return ReelItem(
              key: ValueKey(pageItem.stableId),
              entry: organicEntry,
              isActive: index == currentIndex.value,
              isVisible: isVisible,
              // Provide the pre-warmed controller if the pool has one ready.
              // When null, ReelItem falls back to creating its own controller.
              externalController: pool.value[organicEntry.id],
            );
          },
        ),
        if (topActionLabel != null)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: FeedActionPill(
              label: topActionLabel,
              onTap: () => onManualRefresh?.call(),
              dark: true,
              placement: FeedActionPillPlacement.bottom,
            ),
          ),
        if (showCaughtUpBanner)
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: FeedStateBanner(
              message: 'Caught up on reels for now.',
              dark: true,
            ),
          ),
      ],
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

List<ReelFeedEntry> _organicEntries(List<FeedPageItem> pageItems) {
  return pageItems
      .map((item) => item.organicEntry)
      .whereType<ReelFeedEntry>()
      .toList(growable: false);
}

int? _organicIndexForPageIndex(List<FeedPageItem> pageItems, int pageIndex) {
  if (pageIndex < 0 || pageIndex >= pageItems.length) return null;
  if (pageItems[pageIndex].organicEntry is! ReelFeedEntry) return null;

  var organicIndex = -1;
  for (var i = 0; i <= pageIndex; i++) {
    if (pageItems[i].organicEntry is ReelFeedEntry) organicIndex += 1;
  }
  return organicIndex >= 0 ? organicIndex : null;
}

int _organicCountThroughPageIndex(List<FeedPageItem> pageItems, int pageIndex) {
  final clamped = pageIndex.clamp(0, pageItems.length - 1);
  var count = 0;
  for (var i = 0; i <= clamped; i++) {
    if (pageItems[i].organicEntry is ReelFeedEntry) count += 1;
  }
  return count;
}

bool _shouldLoadMore(List<FeedPageItem> pageItems, int pageIndex) {
  if (pageItems.isEmpty) return false;
  final totalOrganic = _organicEntries(pageItems).length;
  if (totalOrganic == 0) return false;
  final boundedPage = pageIndex.clamp(0, pageItems.length - 1);
  final organicPosition = _organicCountThroughPageIndex(pageItems, boundedPage);
  return totalOrganic - organicPosition <= _loadMoreOrganicRemainingThreshold;
}

int? _pageIndexForOrganicIndex(
  List<FeedPageItem> pageItems,
  int organicIndex,
) {
  if (organicIndex < 0) return null;
  var seenOrganic = 0;
  for (var i = 0; i < pageItems.length; i++) {
    if (pageItems[i].organicEntry is ReelFeedEntry) {
      if (seenOrganic == organicIndex) return i;
      seenOrganic += 1;
    }
  }
  return null;
}
