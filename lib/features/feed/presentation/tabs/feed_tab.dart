import 'package:blips_mobile/core/error/error.dart';
import 'package:blips_mobile/core/config/memory_config.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:blips_mobile/features/feed/presentation/widgets/widgets.dart';
import 'package:blips_mobile/features/feed/providers/video/youtube_player_manager.dart';
import 'package:blips_mobile/features/feed/providers/video/youtube_player_manager_base.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Generic vertical-scrolling feed tab with pagination support.
///
/// Handles:
/// - Empty states with refresh action
/// - Error states with retry action
/// - Loading states
/// - Video preloading for VideoFeedEntry types
/// - Infinite scroll pagination
/// - Current view index tracking for seamless cache updates
class FeedTab<T extends FeedEntry> extends HookConsumerWidget {
  const FeedTab({
    super.key,
    required this.feed,
    required this.builder,
    required this.emptyLabel,
    required this.onRefresh,
    this.onLoadMore,
    this.onPageChanged,
    this.containsVideos = false,
    this.isCaughtUp = false,
    this.caughtUpLabel = 'You are caught up.',
    this.onCaughtUp,
  });

  final AsyncValue<List<T>> feed;
  final Widget Function(T entry, bool isCurrentPage) builder;
  final String emptyLabel;
  final VoidCallback onRefresh;
  final VoidCallback? onLoadMore;

  /// Called when user swipes to a new page, for tracking current view index.
  final void Function(int index)? onPageChanged;

  /// When true, enables video preloading for [VideoFeedEntry] items
  /// in the list (even when [T] is a broader type like [FeedEntry]).
  final bool containsVideos;

  /// Whether the backend has confirmed there is no more content for this tab.
  final bool isCaughtUp;

  /// Label shown when the user reaches the end of the available feed.
  final String caughtUpLabel;

  /// Called once per terminal entry when the user reaches a caught-up state.
  final void Function(T entry)? onCaughtUp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = usePageController();
    final currentPage = useState(0);
    final lastCaughtUpEntryId = useRef<int?>(null);
    final videoManager = ref.watch(youtubePlayerManagerProvider);

    // Preload first videos when data loads
    final hasVideos = containsVideos || T == VideoFeedEntry;
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

      final entry = entries[index];
      if (lastCaughtUpEntryId.value == entry.id) {
        return null;
      }

      lastCaughtUpEntryId.value = entry.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onCaughtUp?.call(entry);
      });
      return null;
    }, [feed.valueOrNull, currentPage.value, isCaughtUp]);

    return SafeArea(
      bottom: false,
      child: feed.when(
        data: (entries) => _buildFeedContent(
            entries, controller, videoManager, hasVideos, currentPage),
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
    final videos = entries.whereType<VideoFeedEntry>().toList();
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

    return Stack(
      children: [
        PageView.builder(
          controller: controller,
          scrollDirection: Axis.vertical,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          onPageChanged: (index) {
            currentPage.value = index;
            _handlePageChange(index, entries, videoManager, hasVideos);
          },
          itemCount: entries.length,
          itemBuilder: (context, index) => SizedBox.expand(
            child: builder(entries[index], index == currentPage.value),
          ),
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

  void _handlePageChange(
    int index,
    List<T> entries,
    YoutubePlayerManagerBase videoManager,
    bool hasVideos,
  ) {
    // Notify parent of page change for cache position tracking
    onPageChanged?.call(index);

    // Video preloading logic
    if (hasVideos) {
      _handleVideoPreloading(index, entries, videoManager);
    }

    // Pagination
    if (onLoadMore != null && index >= entries.length - 3) {
      Future.microtask(() => onLoadMore!());
    }
  }

  void _handleVideoPreloading(
    int index,
    List<T> entries,
    YoutubePlayerManagerBase videoManager,
  ) {
    // Only process if the current entry is actually a video.
    final currentEntry = entries[index];
    if (currentEntry is! VideoFeedEntry) return;

    // Build video-only URL list (skip ad entries) while preserving the exact
    // current entry position in that filtered list.
    final videoEntries = entries.whereType<VideoFeedEntry>().toList();
    final videoUrls = <String>[];
    var videoIndex = -1;
    for (final videoEntry in videoEntries) {
      final playbackUrl = _resolvePlaybackUrl(videoEntry, videoManager);
      if (playbackUrl.isEmpty) continue;
      if (videoEntry.id == currentEntry.id) {
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
