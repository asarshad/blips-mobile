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
import 'package:blips_mobile/features/feed/providers/video/youtube_player_manager.dart';
import 'package:blips_mobile/features/feed/providers/video/youtube_player_manager_base.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

const _loadMoreOrganicRemainingThreshold = 5;

/// Optimized Reels page with video player pooling and preloading.
///
/// Uses YouTube IFrame API for reliable playback without stream URL extraction.
class OptimizedReelsPage extends HookConsumerWidget {
  /// Creates an optimized reels page.
  const OptimizedReelsPage({
    super.key,
    this.isVisible = true,
    this.controller,
    this.onManualRefresh,
  });

  /// Whether this page is currently visible.
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
    final videoManager = ref.watch(youtubePlayerManagerProvider);
    final currentIndex = useState(0);
    final lastCaughtUpEntryId = useRef<int?>(null);
    final reelsNotifier = ref.read(reelsFeedProvider.notifier);
    final uiState = ref.watch(feedSurfaceUiStateProvider(FeedSurface.reels));
    final isMounted = useIsMounted();
    final autoRetryInProgress = useState(false);
    final autoRetryAttempts = useRef(0);

    useEffect(() {
      if (reelsFeed.hasValue) {
        autoRetryAttempts.value = 0;
        autoRetryInProgress.value = false;
      }
      return null;
    }, [reelsFeed.valueOrNull]);

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
        if (ok) {
          autoRetryAttempts.value = 0;
        }
      });
      return timer.cancel;
    }, [reelsFeed.hasError, isVisible, autoRetryInProgress.value]);

    _useInitialPreload(reelsFeed, videoManager, isVisible);
    _useViewportWarmup(
      reelsFeed: reelsFeed,
      controller: effectiveController,
      videoManager: videoManager,
      isVisible: isVisible,
    );
    _useVisibilityHandler(reelsFeed, videoManager, isVisible, currentIndex);
    _useLifecycleObserver(reelsFeed, videoManager, isVisible, currentIndex);
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
          videoManager: videoManager,
          currentIndex: currentIndex,
          isMounted: isMounted,
          hasMore: reelsNotifier.hasMore,
          isCaughtUp: reelsNotifier.isCaughtUp,
          uiState: uiState,
          ref: ref,
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

  /// Preload initial videos when data loads.
  ///
  /// Only initialises controllers — does NOT call playVideo.
  /// Playback is started exclusively by `_useVisibilityHandler` so there is a
  /// single, authoritative place that decides what should be playing.
  void _useInitialPreload(
    AsyncValue<List<FeedPageItem>> reelsFeed,
    YoutubePlayerManagerBase videoManager,
    bool isVisible,
  ) {
    useEffect(
      () {
        if (kDebugMode) {
          debugPrint(
            'ReelsPage: _useInitialPreload effect — hasValue=${reelsFeed.hasValue}, isVisible=$isVisible',
          );
        }
        if (reelsFeed.hasValue && reelsFeed.value!.isNotEmpty) {
          final entries = _organicEntries(reelsFeed.value!);
          if (entries.isEmpty) return null;

          final warmTarget = MemoryConfig.reelPreloadCount + 1;
          final cappedWarmTarget = warmTarget > MemoryConfig.playerPoolSize
              ? MemoryConfig.playerPoolSize
              : warmTarget;
          final preloadCount = entries.length.clamp(0, cappedWarmTarget);

          var cancelled = false;
          Future.microtask(() async {
            for (var i = 0; i < preloadCount; i++) {
              if (cancelled) return;
              unawaited(videoManager.initController(entries[i].link));
            }
          });
          return () => cancelled = true;
        }
        return null;
      },
      [reelsFeed.valueOrNull],
    );
  }

  void _useViewportWarmup({
    required AsyncValue<List<FeedPageItem>> reelsFeed,
    required PageController controller,
    required YoutubePlayerManagerBase videoManager,
    required bool isVisible,
  }) {
    useEffect(() {
      final pageItems = reelsFeed.valueOrNull;
      if (!isVisible || pageItems == null || pageItems.isEmpty) {
        return null;
      }

      void warmViewport() {
        if (!controller.hasClients) return;
        final page = controller.page ?? controller.initialPage.toDouble();
        final lower = page.floor().clamp(0, pageItems.length - 1);
        final upper = page.ceil().clamp(0, pageItems.length - 1);
        _warmPageIfOrganic(pageItems, lower, videoManager);
        _warmPageIfOrganic(pageItems, upper, videoManager);

        final rounded = page.round().clamp(0, pageItems.length - 1);
        final nextPage = _nextOrganicPageIndex(pageItems, rounded + 1);
        if (nextPage != null) {
          _warmPageIfOrganic(pageItems, nextPage, videoManager);
        }
      }

      controller.addListener(warmViewport);
      WidgetsBinding.instance.addPostFrameCallback((_) => warmViewport());
      return () => controller.removeListener(warmViewport);
    }, [reelsFeed.valueOrNull, controller, isVisible]);
  }

  /// Handle visibility changes.
  void _useVisibilityHandler(
    AsyncValue<List<FeedPageItem>> reelsFeed,
    YoutubePlayerManagerBase videoManager,
    bool isVisible,
    ValueNotifier<int> currentIndex,
  ) {
    useEffect(
      () {
        final pageItems = reelsFeed.valueOrNull;
        if (pageItems == null || pageItems.isEmpty) return null;

        final entries = _organicEntries(pageItems);
        if (entries.isEmpty) return null;

        if (isVisible) {
          final pageIndex = currentIndex.value.clamp(0, pageItems.length - 1);
          final organicIndex = _organicIndexForPageIndex(pageItems, pageIndex);
          if (organicIndex == null) {
            if (kDebugMode) {
              debugPrint('ReelsPage: Visibility ON — ad page active, pausing');
            }
            videoManager.pauseAll();
            return null;
          }

          final urls = entries.map((e) => e.link).toList(growable: false);
          if (kDebugMode) {
            debugPrint(
              'ReelsPage: Visibility ON — playing video at organic index $organicIndex',
            );
          }
          videoManager.onPageChanged(
            currentIndex: organicIndex,
            videoUrls: urls,
            preloadAhead: MemoryConfig.reelPreloadCount,
          );
        } else {
          if (kDebugMode) {
            debugPrint('ReelsPage: Visibility OFF — pausing all');
          }
          videoManager.pauseAll();
        }
        return null;
      },
      [
        isVisible,
        reelsFeed.valueOrNull,
      ],
    );
  }

  /// Re-start the current reel whenever the app returns to the foreground.
  void _useLifecycleObserver(
    AsyncValue<List<FeedPageItem>> reelsFeed,
    YoutubePlayerManagerBase videoManager,
    bool isVisible,
    ValueNotifier<int> currentIndex,
  ) {
    final callbackRef = useRef<VoidCallback>(() {});
    callbackRef.value = () {
      if (!isVisible) return;
      if (!reelsFeed.hasValue || reelsFeed.value!.isEmpty) return;
      final pageItems = reelsFeed.value!;
      final entries = _organicEntries(pageItems);
      if (entries.isEmpty) return;

      final pageIndex = currentIndex.value.clamp(0, pageItems.length - 1);
      final organicIndex = _organicIndexForPageIndex(pageItems, pageIndex);
      if (organicIndex == null) return;

      final link = entries[organicIndex].link;
      debugPrint(
        'ReelsPage: App resumed — retrying video at organic index $organicIndex to clear stale iframe',
      );
      videoManager.retryVideo(link);
    };

    useEffect(
      () {
        final observer = _ReelLifecycleObserver(
          onResumed: () => callbackRef.value(),
        );
        WidgetsBinding.instance.addObserver(observer);
        return () => WidgetsBinding.instance.removeObserver(observer);
      },
      const [],
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
      if (pageItems == null || pageItems.isEmpty || !isCaughtUp) {
        return null;
      }

      final entries = _organicEntries(pageItems);
      if (entries.isEmpty) return null;

      final pageIndex = currentIndex.value.clamp(0, pageItems.length - 1);
      final organicIndex = _organicIndexForPageIndex(pageItems, pageIndex);
      if (organicIndex == null || organicIndex < entries.length - 1) {
        return null;
      }

      final entry = entries[organicIndex];
      if (lastCaughtUpEntryId.value == entry.id) {
        return null;
      }

      lastCaughtUpEntryId.value = entry.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(
          ref.read(feedRepositoryProvider).recordInteraction(
            contentItemId: entry.id,
            eventType: FeedInteractionEvent.caughtUp,
            extraData: const {
              'surface': 'reels',
            },
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
                (entry) => entry.organicEntry?.id == restoreEntryId,
              );
        final targetIndex = exactIndex >= 0
            ? exactIndex
            : (restoreApproximateIndex == null
                ? 0
                : (_pageIndexForOrganicIndex(
                      pageItems,
                      restoreApproximateIndex,
                    ) ??
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
      if (!isVisible || pageItems == null || pageItems.isEmpty) {
        return null;
      }

      final index = currentIndex.value.clamp(0, pageItems.length - 1);
      final entry = pageItems[index].organicEntry;
      if (entry == null) {
        return null;
      }

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
        if (isMounted()) {
          unawaited(onLoadMore());
        }
      });
      return null;
    }, [reelsFeed.valueOrNull, currentIndex.value]);
  }

  Widget _buildContent({
    required BuildContext context,
    required List<FeedPageItem> entries,
    required PageController controller,
    required YoutubePlayerManagerBase videoManager,
    required ValueNotifier<int> currentIndex,
    required bool Function() isMounted,
    required bool hasMore,
    required bool isCaughtUp,
    required FeedSurfaceUiState uiState,
    required WidgetRef ref,
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

    final urls = organicEntries.map((e) => e.link).toList(growable: false);
    final indexByStableId = <int, int>{
      for (var i = 0; i < entries.length; i++) entries[i].stableId: i,
    };

    final boundedIndex = currentIndex.value.clamp(0, entries.length - 1);
    final currentPageItem = entries[boundedIndex];
    final currentOrganicIndex =
        _organicIndexForPageIndex(entries, boundedIndex);
    final currentOrganicPosition =
        _organicCountThroughPageIndex(entries, boundedIndex).clamp(
      1,
      organicEntries.length,
    );
    final currentEntry = currentOrganicIndex == null
        ? null
        : organicEntries[currentOrganicIndex];
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
            if (key is ValueKey<int>) {
              return indexByStableId[key.value];
            }
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
              videoManager.onPageChanged(
                currentIndex: organicIndex,
                videoUrls: urls,
                preloadAhead: MemoryConfig.reelPreloadCount,
              );
            } else {
              videoManager.pauseAll();
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
        FeedStatusOverlay(
          title:
              '${currentPageItem.organicEntry == null ? 'AD' : 'REEL'} $currentOrganicPosition/${organicEntries.length}${hasMore ? '+' : ''}',
          subtitle: currentPageItem is NativeAdSlotFeedPageItem
              ? 'slot ${currentPageItem.slotIndex + 1} · ${hasMore ? 'more' : 'end'}'
              : '#${currentEntry?.id ?? '-'} · ${hasMore ? 'more' : 'end'}',
          dark: true,
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

List<ReelFeedEntry> _organicEntries(List<FeedPageItem> pageItems) {
  return pageItems
      .map((item) => item.organicEntry)
      .whereType<ReelFeedEntry>()
      .toList(growable: false);
}

void _warmPageIfOrganic(
  List<FeedPageItem> pageItems,
  int pageIndex,
  YoutubePlayerManagerBase videoManager,
) {
  if (pageIndex < 0 || pageIndex >= pageItems.length) return;
  final entry = pageItems[pageIndex].organicEntry;
  if (entry is ReelFeedEntry) {
    unawaited(videoManager.initController(entry.link));
  }
}

int? _organicIndexForPageIndex(List<FeedPageItem> pageItems, int pageIndex) {
  if (pageIndex < 0 || pageIndex >= pageItems.length) return null;
  if (pageItems[pageIndex].organicEntry is! ReelFeedEntry) return null;

  var organicIndex = -1;
  for (var i = 0; i <= pageIndex; i++) {
    if (pageItems[i].organicEntry is ReelFeedEntry) {
      organicIndex += 1;
    }
  }
  return organicIndex >= 0 ? organicIndex : null;
}

int _organicCountThroughPageIndex(List<FeedPageItem> pageItems, int pageIndex) {
  final clamped = pageIndex.clamp(0, pageItems.length - 1);
  var count = 0;
  for (var i = 0; i <= clamped; i++) {
    if (pageItems[i].organicEntry is ReelFeedEntry) {
      count += 1;
    }
  }
  return count;
}

bool _shouldLoadMore(List<FeedPageItem> pageItems, int pageIndex) {
  if (pageItems.isEmpty) return false;
  final totalOrganic = _organicEntries(pageItems).length;
  if (totalOrganic == 0) return false;

  final boundedPage = pageIndex.clamp(0, pageItems.length - 1);
  final organicPosition = _organicCountThroughPageIndex(pageItems, boundedPage);
  final remainingAfterCurrent = totalOrganic - organicPosition;
  return remainingAfterCurrent <= _loadMoreOrganicRemainingThreshold;
}

int? _pageIndexForOrganicIndex(
  List<FeedPageItem> pageItems,
  int organicIndex,
) {
  if (organicIndex < 0) return null;
  var seenOrganic = 0;
  for (var i = 0; i < pageItems.length; i++) {
    if (pageItems[i].organicEntry is ReelFeedEntry) {
      if (seenOrganic == organicIndex) {
        return i;
      }
      seenOrganic += 1;
    }
  }
  return null;
}

int? _nextOrganicPageIndex(List<FeedPageItem> pageItems, int startIndex) {
  for (var i = startIndex; i < pageItems.length; i++) {
    if (pageItems[i].organicEntry is ReelFeedEntry) {
      return i;
    }
  }
  return null;
}

/// [WidgetsBindingObserver] that fires a callback when the app returns to the
/// foreground. Kept as a private top-level class so it can be instantiated
/// inside a flutter_hooks [useEffect] without capturing stale closures.
class _ReelLifecycleObserver extends WidgetsBindingObserver {
  _ReelLifecycleObserver({required this.onResumed});

  final VoidCallback onResumed;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onResumed();
  }
}
