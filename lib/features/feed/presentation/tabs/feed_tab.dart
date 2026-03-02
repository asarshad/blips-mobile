import 'package:blips_mobile/core/error/error.dart';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = usePageController();
    final currentPage = useState(0);
    final videoManager = ref.watch(youtubePlayerManagerProvider);

    // Preload first videos when data loads
    final hasVideos = containsVideos || T == VideoFeedEntry;
    useEffect(() {
      if (feed.hasValue && feed.value!.isNotEmpty && hasVideos) {
        _preloadInitialVideos(feed.value!, videoManager);
      }
      return null;
    }, [feed.hasValue]);

    return SafeArea(
      bottom: false,
      child: feed.when(
        data: (entries) =>
            _buildFeedContent(entries, controller, videoManager, hasVideos, currentPage),
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

    videoManager.initController(videos.first.link);
    if (videos.length > 1) {
      videoManager.initController(videos[1].link);
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

    return PageView.builder(
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
    // Collect video URLs, skipping non-video entries (e.g. ads)
    final videoEntries = <int, String>{};
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      if (e is VideoFeedEntry) {
        videoEntries[i] = e.link;
      }
    }

    if (videoEntries.isEmpty) return;

    // Use the centralized page change handler with the video-only URLs
    videoManager.onPageChanged(
      currentIndex: index,
      videoUrls: entries
          .map((e) => e is VideoFeedEntry ? e.link : '')
          .where((url) => url.isNotEmpty)
          .toList(),
    );
  }
}
