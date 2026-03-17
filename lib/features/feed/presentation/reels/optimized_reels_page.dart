import 'dart:async';

import 'package:blips_mobile/core/config/memory_config.dart';
import 'package:blips_mobile/core/error/error.dart';
import 'package:blips_mobile/features/feed/data/feed_repository.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:blips_mobile/features/feed/presentation/widgets/widgets.dart';
import 'package:blips_mobile/features/feed/presentation/reels/reel_item.dart';
import 'package:blips_mobile/features/feed/providers/feed_providers.dart';
import 'package:blips_mobile/features/feed/providers/video/youtube_player_manager.dart';
import 'package:blips_mobile/features/feed/providers/video/youtube_player_manager_base.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

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
    final reelsFeed = ref.watch(reelsFeedProvider);
    final fallbackController = usePageController();
    final effectiveController = controller ?? fallbackController;
    final videoManager = ref.watch(youtubePlayerManagerProvider);
    final currentIndex = useState(0);
    final lastCaughtUpEntryId = useRef<int?>(null);
    final reelsNotifier = ref.read(reelsFeedProvider.notifier);

    _useInitialPreload(reelsFeed, videoManager, isVisible);
    _useVisibilityHandler(reelsFeed, videoManager, isVisible, currentIndex);
    _useLifecycleObserver(reelsFeed, videoManager, isVisible, currentIndex);
    _useCaughtUpTracking(
      ref: ref,
      reelsFeed: reelsFeed,
      currentIndex: currentIndex,
      isCaughtUp: reelsNotifier.isCaughtUp,
      lastCaughtUpEntryId: lastCaughtUpEntryId,
    );

    final isMounted = useIsMounted();

    return Scaffold(
      backgroundColor: Colors.black,
      body: reelsFeed.when(
        data: (entries) => _buildContent(
          entries: entries,
          controller: effectiveController,
          videoManager: videoManager,
          currentIndex: currentIndex,
          isMounted: isMounted,
          isCaughtUp: reelsNotifier.isCaughtUp,
          ref: ref,
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Theme(
          data: ThemeData.dark(),
          child: ErrorView(
            error: error,
            onRetry: onManualRefresh ?? () => ref.invalidate(reelsFeedProvider),
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
    useEffect(
      () {
        if (kDebugMode) {
          debugPrint(
            'ReelsPage: _useInitialPreload effect — hasValue=${reelsFeed.hasValue}, isVisible=$isVisible',
          );
        }
        if (reelsFeed.hasValue && reelsFeed.value!.isNotEmpty) {
          final entries = reelsFeed.value!;

          // Keep warm preloads aligned with pool capacity to avoid churn.
          final warmTarget =
              MemoryConfig.reelPreloadCount + 1; // current + ahead
          final cappedWarmTarget = warmTarget > MemoryConfig.playerPoolSize
              ? MemoryConfig.playerPoolSize
              : warmTarget;
          final preloadCount = entries.length.clamp(0, cappedWarmTarget);

          var cancelled = false;
          Future.microtask(() async {
            for (var i = 0; i < preloadCount; i++) {
              if (cancelled) return;
              await videoManager.initController(entries[i].link);
            }
          });
          return () => cancelled = true;
        }
        return null;
      },
      [reelsFeed.valueOrNull],
    ); // isVisible intentionally excluded — see above
  }

  /// Handle visibility changes.
  void _useVisibilityHandler(
    AsyncValue<List<ReelFeedEntry>> reelsFeed,
    YoutubePlayerManagerBase videoManager,
    bool isVisible,
    ValueNotifier<int> currentIndex,
  ) {
    useEffect(
      () {
        final entries = reelsFeed.valueOrNull;
        if (entries == null || entries.isEmpty) return null;

        if (isVisible) {
          // Route through onPageChanged so visible-entry playback uses the
          // same proven path as manual swipes (pause others + preload next).
          final index = currentIndex.value.clamp(0, entries.length - 1);
          final urls = entries.map((e) => e.link).toList(growable: false);
          if (kDebugMode) {
            debugPrint(
                'ReelsPage: Visibility ON — playing video at index $index');
          }
          videoManager.onPageChanged(
            currentIndex: index,
            videoUrls: urls,
            preloadAhead: MemoryConfig.reelPreloadCount,
          );
        } else {
          // Pause all when leaving (keep cached for faster resume)
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
  ///
  /// iOS (and Android) can suspend or kill the WKWebView process while the
  /// app is in the background.  When the user returns — whether from a
  /// home-screen visit, a notification check, or tapping “Open” to watch
  /// a reel in the browser — the cached controller may have a stale iframe.
  /// Calling [retryVideo] disposes the old controller and initialises a fresh
  /// one so playback resumes reliably instead of silently hanging.
  ///
  /// We register the observer once and use a [useRef] to hold a
  /// fresh closure on every rebuild, avoiding any stale-capture issues.
  void _useLifecycleObserver(
    AsyncValue<List<ReelFeedEntry>> reelsFeed,
    YoutubePlayerManagerBase videoManager,
    bool isVisible,
    ValueNotifier<int> currentIndex,
  ) {
    // Callback ref keeps the closure fresh without removing/re-adding the
    // WidgetsBindingObserver on every rebuild.
    final callbackRef = useRef<VoidCallback>(() {});
    callbackRef.value = () {
      if (!isVisible) return;
      if (!reelsFeed.hasValue || reelsFeed.value!.isEmpty) return;
      final entries = reelsFeed.value!;
      final index = currentIndex.value.clamp(0, entries.length - 1);
      final link = entries[index].link;
      debugPrint(
        'ReelsPage: App resumed — retrying video at index $index to clear stale iframe',
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
    ); // register once for the lifetime of the page
  }

  void _useCaughtUpTracking({
    required WidgetRef ref,
    required AsyncValue<List<ReelFeedEntry>> reelsFeed,
    required ValueNotifier<int> currentIndex,
    required bool isCaughtUp,
    required ObjectRef<int?> lastCaughtUpEntryId,
  }) {
    useEffect(() {
      final entries = reelsFeed.valueOrNull;
      if (entries == null || entries.isEmpty || !isCaughtUp) {
        return null;
      }

      final index = currentIndex.value.clamp(0, entries.length - 1);
      if (index < entries.length - 1) {
        return null;
      }

      final entry = entries[index];
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

  Widget _buildContent({
    required List<ReelFeedEntry> entries,
    required PageController controller,
    required YoutubePlayerManagerBase videoManager,
    required ValueNotifier<int> currentIndex,
    required bool Function() isMounted,
    required bool isCaughtUp,
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

    final urls = entries.map((e) => e.link).toList();
    final indexByEntryId = <int, int>{
      for (var i = 0; i < entries.length; i++) entries[i].id: i,
    };

    final showCaughtUpBanner =
        isCaughtUp && currentIndex.value >= entries.length - 1;

    return Stack(
      children: [
        PageView.builder(
          controller: controller,
          scrollDirection: Axis.vertical,
          findChildIndexCallback: (key) {
            if (key is ValueKey<int>) {
              return indexByEntryId[key.value];
            }
            return null;
          },
          onPageChanged: (index) {
            currentIndex.value = index;

            videoManager.onPageChanged(
              currentIndex: index,
              videoUrls: urls,
              preloadAhead: MemoryConfig.reelPreloadCount,
            );

            // Pagination: Load more when close to end
            if (index >= entries.length - 3) {
              Future.microtask(() {
                if (isMounted())
                  ref.read(reelsFeedProvider.notifier).loadMore();
              });
            }
          },
          itemCount: entries.length,
          itemBuilder: (context, index) => ReelItem(
            key: ValueKey(entries[index].id),
            entry: entries[index],
            isActive: index == currentIndex.value,
            isVisible: isVisible,
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

/// [WidgetsBindingObserver] that fires a callback when the app returns to the
/// foreground.  Kept as a private top-level class so it can be instantiated
/// inside a flutter_hooks [useEffect] without capturing stale closures.
class _ReelLifecycleObserver extends WidgetsBindingObserver {
  _ReelLifecycleObserver({required this.onResumed});

  final VoidCallback onResumed;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onResumed();
  }
}
