import 'dart:async';

import 'package:blips_mobile/core/error/error.dart';
import 'package:blips_mobile/core/config/memory_config.dart';
import 'package:blips_mobile/features/ads/domain/feed_page_item.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:blips_mobile/features/feed/presentation/widgets/widgets.dart';
import 'package:blips_mobile/features/feed/providers/video/playback_rearm.dart';
import 'package:blips_mobile/features/feed/providers/video/youtube_player_manager.dart';
import 'package:blips_mobile/features/feed/providers/video/youtube_player_manager_base.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

const _loadMoreOrganicRemainingThreshold = 5;

/// Generic vertical-scrolling feed tab with pagination support.
///
/// Handles:
/// - Empty states with refresh action
/// - Error states with retry action
/// - Loading states
/// - Video preloading for organic [VideoFeedEntry] pages
/// - Infinite scroll pagination
/// - Current view index tracking for seamless cache updates
class FeedTab<T extends FeedPageItem> extends HookConsumerWidget {
  const FeedTab({
    super.key,
    required this.feed,
    required this.builder,
    required this.emptyLabel,
    required this.onRefresh,
    required this.overlayLabel,
    this.controller,
    this.onLoadMore,
    this.onPageChanged,
    this.onPrimaryVisibleEntrySettled,
    this.containsVideos = false,
    this.isCaughtUp = false,
    this.caughtUpLabel = 'You are caught up.',
    this.onCaughtUp,
    this.restoreEntryId,
    this.restoreApproximateIndex,
    this.onRestoreApplied,
    this.topActionLabel,
    this.onTopAction,
    this.isActive = true,
    this.topActionDark = false,
    this.overlayDark = false,
    this.overlayHasMore = false,
  });

  final AsyncValue<List<T>> feed;
  final Widget Function(T entry, bool isCurrentPage) builder;
  final String emptyLabel;
  final VoidCallback onRefresh;
  final String overlayLabel;

  /// External page controller owned by the shell. Falls back to an internal
  /// controller when not provided.
  final PageController? controller;

  final VoidCallback? onLoadMore;

  /// Called when user swipes to a new page, for tracking current view index.
  final void Function(int index, FeedEntry? visibleEntry)? onPageChanged;

  /// Called when an organic page remains primary and visible for ~1 second.
  final ValueChanged<FeedEntry>? onPrimaryVisibleEntrySettled;

  /// When true, enables video preloading for organic video pages in the list.
  final bool containsVideos;

  /// Whether the backend has confirmed there is no more content for this tab.
  final bool isCaughtUp;

  /// Label shown when the user reaches the end of the available feed.
  final String caughtUpLabel;

  /// Called once per terminal entry when the user reaches a caught-up state.
  final void Function(FeedEntry entry)? onCaughtUp;

  /// Organic entry id to restore to once entries load.
  final int? restoreEntryId;

  /// Fallback organic index when the stored item id is missing.
  final int? restoreApproximateIndex;

  /// Called after an attempted restore jump so the caller can clear state.
  final VoidCallback? onRestoreApplied;

  /// Optional top pill label for continuity/freshness actions.
  final String? topActionLabel;

  /// Callback for the top pill tap.
  final VoidCallback? onTopAction;

  /// Whether this surface is currently visible to the user.
  final bool isActive;

  /// Whether the top pill should use the dark visual style.
  final bool topActionDark;

  /// Whether the diagnostics overlay should use the dark visual style.
  final bool overlayDark;

  /// Whether the current loaded feed is still expandable.
  final bool overlayHasMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fallbackController = usePageController();
    final effectiveController = controller ?? fallbackController;
    final currentPage = useState(0);
    final lastCaughtUpEntryId = useRef<int?>(null);
    final videoManager = ref.watch(youtubePlayerManagerProvider);

    useEffect(() {
      void syncCurrentPage() {
        final nextIndex = (() {
          if (!effectiveController.hasClients) {
            return effectiveController.initialPage;
          }
          final page = effectiveController.page;
          if (page == null) {
            return effectiveController.initialPage;
          }
          return page.round();
        })();
        if (nextIndex != currentPage.value) {
          currentPage.value = nextIndex;
        }
      }

      effectiveController.addListener(syncCurrentPage);
      WidgetsBinding.instance.addPostFrameCallback((_) => syncCurrentPage());
      return () => effectiveController.removeListener(syncCurrentPage);
    }, [effectiveController]);

    // Preload first videos when data loads
    final hasVideos = containsVideos;
    useEffect(() {
      if (feed.hasValue && feed.value!.isNotEmpty && hasVideos) {
        _preloadInitialVideos(feed.value!, videoManager);
      }
      return null;
    }, [feed.hasValue]);

    useEffect(() {
      final entries = feed.valueOrNull;
      if (entries == null ||
          entries.isEmpty ||
          !isCaughtUp ||
          onCaughtUp == null) {
        return null;
      }

      final index = currentPage.value.clamp(0, entries.length - 1);
      if (index < entries.length - 1) {
        return null;
      }

      final entry = entries[index].organicEntry;
      if (entry == null || lastCaughtUpEntryId.value == entry.id) {
        return null;
      }

      lastCaughtUpEntryId.value = entry.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onCaughtUp?.call(entry);
      });
      return null;
    }, [feed.valueOrNull, currentPage.value, isCaughtUp]);

    useEffect(() {
      final entries = feed.valueOrNull;
      final targetEntryId = restoreEntryId;
      final fallbackOrganicIndex = restoreApproximateIndex;
      if (entries == null || entries.isEmpty) {
        return null;
      }
      if (targetEntryId == null && fallbackOrganicIndex == null) {
        return null;
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!effectiveController.hasClients) return;
        final targetIndex = _resolveRestorePageIndex(
          entries,
          targetEntryId: targetEntryId,
          fallbackOrganicIndex: fallbackOrganicIndex,
        );
        if (targetIndex != null) {
          effectiveController.jumpToPage(targetIndex);
          currentPage.value = targetIndex;
        }
        onRestoreApplied?.call();
      });
      return null;
    }, [feed.valueOrNull, restoreEntryId, restoreApproximateIndex]);

    useEffect(() {
      final entries = feed.valueOrNull;
      if (!isActive ||
          entries == null ||
          entries.isEmpty ||
          onPrimaryVisibleEntrySettled == null) {
        return null;
      }

      final index = currentPage.value.clamp(0, entries.length - 1);
      final organicEntry = entries[index].organicEntry;
      if (organicEntry == null) {
        return null;
      }

      final timer = Timer(const Duration(seconds: 1), () {
        onPrimaryVisibleEntrySettled?.call(organicEntry);
      });
      return timer.cancel;
    }, [feed.valueOrNull, currentPage.value, isActive]);

    useEffect(() {
      final entries = feed.valueOrNull;
      if (!isActive || !hasVideos || entries == null || entries.isEmpty) {
        return null;
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final activeIndex = (() {
          if (effectiveController.hasClients) {
            final page = effectiveController.page;
            if (page != null) {
              return page.round().clamp(0, entries.length - 1);
            }
            return effectiveController.initialPage.clamp(0, entries.length - 1);
          }
          return currentPage.value.clamp(0, entries.length - 1);
        })();
        _handleVideoPreloading(
          activeIndex,
          entries,
          videoManager,
        );
        final activeVideoEntry = entries[activeIndex].videoEntry;
        if (activeVideoEntry != null) {
          final activeUrl =
              _resolvePlaybackUrl(activeVideoEntry, videoManager).trim();
          if (activeUrl.isNotEmpty) {
            unawaited(nudgePrimaryPlayback(videoManager, activeUrl));
          }
        }
      });
      return null;
    }, [isActive, hasVideos, feed.valueOrNull, currentPage.value]);

    useEffect(() {
      final entries = feed.valueOrNull;
      if (entries == null || entries.isEmpty || onLoadMore == null) {
        return null;
      }
      if (!_shouldLoadMore(entries, currentPage.value)) {
        return null;
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        onLoadMore?.call();
      });
      return null;
    }, [feed.valueOrNull, currentPage.value]);

    return SafeArea(
      bottom: false,
      child: feed.when(
        data: (entries) => _buildFeedContent(
          context,
          entries,
          effectiveController,
          videoManager,
          hasVideos,
          currentPage,
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => ErrorView(
          error: error,
          onRetry: onRefresh,
        ),
      ),
    );
  }

  void _preloadInitialVideos(
    List<T> entries,
    YoutubePlayerManagerBase videoManager,
  ) {
    final videos = entries
        .map((entry) => entry.videoEntry)
        .whereType<VideoFeedEntry>()
        .toList(growable: false);
    if (videos.isEmpty) return;

    final preloadUrls = videos
        .map((entry) => _resolvePlaybackUrl(entry, videoManager))
        .where((url) => url.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (preloadUrls.isEmpty) return;

    videoManager.initController(preloadUrls.first);
    if (preloadUrls.length > 1) {
      videoManager.initController(preloadUrls[1]);
    }
  }

  Widget _buildFeedContent(
    BuildContext context,
    List<T> entries,
    PageController controller,
    YoutubePlayerManagerBase videoManager,
    bool hasVideos,
    ValueNotifier<int> currentPage,
  ) {
    if (entries.isEmpty) {
      return FeedMessageState(
        message: emptyLabel,
        actionLabel: 'Refresh',
        onAction: onRefresh,
      );
    }

    final showCaughtUpBanner =
        isCaughtUp && currentPage.value >= entries.length - 1;
    final showTopAction = topActionLabel != null && onTopAction != null;
    final overlayData = _buildOverlayData(entries, currentPage.value);

    return Stack(
      children: [
        PageView.builder(
          controller: controller,
          scrollDirection: Axis.vertical,
          dragStartBehavior: DragStartBehavior.down,
          pageSnapping: true,
          physics: buildFeedPagePhysics(context),
          onPageChanged: (index) {
            currentPage.value = index;
            _handlePageChange(index, entries, videoManager, hasVideos);
          },
          itemCount: entries.length,
          itemBuilder: (context, index) => SizedBox.expand(
            key: ValueKey(entries[index].stableId),
            child: builder(entries[index], index == currentPage.value),
          ),
        ),
        if (showTopAction)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: FeedActionPill(
              label: topActionLabel!,
              onTap: onTopAction!,
              dark: topActionDark,
              placement: FeedActionPillPlacement.bottom,
            ),
          ),
        FeedStatusOverlay(
          title:
              '$overlayLabel ${overlayData.position}/${overlayData.total}${overlayHasMore ? '+' : ''}',
          subtitle: overlayData.subtitle,
          dark: overlayDark,
        ),
        if (showCaughtUpBanner)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: FeedStateBanner(message: caughtUpLabel),
          ),
      ],
    );
  }

  _FeedOverlayData _buildOverlayData(List<T> entries, int currentPage) {
    final organicEntries = entries
        .where((entry) => entry.organicEntry != null)
        .toList(growable: false);
    final total = organicEntries.length;
    if (total == 0) {
      return const _FeedOverlayData(
        position: 0,
        total: 0,
        subtitle: 'no content',
      );
    }

    final boundedPage = currentPage.clamp(0, entries.length - 1);
    final currentOrganic = entries[boundedPage].organicEntry;
    var organicPosition = _organicCountThroughPageIndex(entries, boundedPage);

    if (organicPosition <= 0) {
      organicPosition = 1;
    }

    if (currentOrganic == null) {
      return _FeedOverlayData(
        position: organicPosition.clamp(1, total),
        total: total,
        subtitle: 'ad slot',
      );
    }

    return _FeedOverlayData(
      position: organicPosition.clamp(1, total),
      total: total,
      subtitle: '#${currentOrganic.id} · ${overlayHasMore ? 'more' : 'end'}',
    );
  }

  void _handlePageChange(
    int index,
    List<T> entries,
    YoutubePlayerManagerBase videoManager,
    bool hasVideos,
  ) {
    // Notify parent of page change for cache position tracking
    onPageChanged?.call(index, entries[index].organicEntry);

    // Video preloading logic
    if (hasVideos) {
      _handleVideoPreloading(index, entries, videoManager);
      final activeVideoEntry = entries[index].videoEntry;
      if (activeVideoEntry != null) {
        final activeUrl = _resolvePlaybackUrl(activeVideoEntry, videoManager);
        if (activeUrl.isNotEmpty) {
          unawaited(nudgePrimaryPlayback(videoManager, activeUrl));
        }
      }
    }

    // Pagination
    if (onLoadMore != null && _shouldLoadMore(entries, index)) {
      Future.microtask(() => onLoadMore!());
    }
  }

  bool _shouldLoadMore(List<T> entries, int pageIndex) {
    final totalOrganic =
        entries.where((entry) => entry.organicEntry != null).length;
    if (totalOrganic == 0) return false;
    final boundedPage = pageIndex.clamp(0, entries.length - 1);
    final organicPosition = _organicCountThroughPageIndex(entries, boundedPage);
    final remainingAfterCurrent = totalOrganic - organicPosition;
    return remainingAfterCurrent <= _loadMoreOrganicRemainingThreshold;
  }

  int? _resolveRestorePageIndex(
    List<T> entries, {
    required int? targetEntryId,
    required int? fallbackOrganicIndex,
  }) {
    if (entries.isEmpty) return null;

    if (targetEntryId != null) {
      for (var pageIndex = 0; pageIndex < entries.length; pageIndex += 1) {
        if (entries[pageIndex].organicEntry?.id == targetEntryId) {
          return pageIndex;
        }
      }
    }

    if (fallbackOrganicIndex == null) {
      return null;
    }

    var seenOrganic = 0;
    for (var pageIndex = 0; pageIndex < entries.length; pageIndex += 1) {
      if (entries[pageIndex].organicEntry == null) {
        continue;
      }
      if (seenOrganic >= fallbackOrganicIndex) {
        return pageIndex;
      }
      seenOrganic += 1;
    }

    for (var pageIndex = entries.length - 1; pageIndex >= 0; pageIndex -= 1) {
      if (entries[pageIndex].organicEntry != null) {
        return pageIndex;
      }
    }
    return 0;
  }

  int _organicCountThroughPageIndex(List<T> entries, int pageIndex) {
    var count = 0;
    for (var i = 0; i <= pageIndex; i += 1) {
      if (entries[i].organicEntry != null) {
        count += 1;
      }
    }
    return count;
  }

  void _handleVideoPreloading(
    int index,
    List<T> entries,
    YoutubePlayerManagerBase videoManager,
  ) {
    // Only process if the current entry is actually a video.
    final currentEntry = entries[index];
    final currentVideoEntry = currentEntry.videoEntry;
    if (currentVideoEntry == null) return;

    // Build video-only URL list (skip ad entries) while preserving the exact
    // current entry position in that filtered list.
    final videoEntries = entries
        .map((entry) => entry.videoEntry)
        .whereType<VideoFeedEntry>()
        .toList(growable: false);
    final videoUrls = <String>[];
    var videoIndex = -1;
    for (final videoEntry in videoEntries) {
      final playbackUrl = _resolvePlaybackUrl(videoEntry, videoManager);
      if (playbackUrl.isEmpty) continue;
      if (videoEntry.id == currentVideoEntry.id) {
        videoIndex = videoUrls.length;
      }
      videoUrls.add(playbackUrl);
    }
    if (videoUrls.isEmpty || videoIndex == -1) return;

    videoManager.onPageChanged(
      currentIndex: videoIndex,
      videoUrls: videoUrls,
      preloadAhead: MemoryConfig.videoPreloadCount,
    );
  }

  String _resolvePlaybackUrl(
    VideoFeedEntry entry,
    YoutubePlayerManagerBase videoManager,
  ) {
    final preferred = entry.videoUrl.trim();
    if (preferred.isNotEmpty &&
        videoManager.extractVideoId(preferred) != null) {
      return preferred;
    }
    return entry.link.trim();
  }
}

class _FeedOverlayData {
  const _FeedOverlayData({
    required this.position,
    required this.total,
    required this.subtitle,
  });

  final int position;
  final int total;
  final String subtitle;
}
