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
  });

  final AsyncValue<List<T>> feed;
  final Widget Function(T entry) builder;
  final String emptyLabel;
  final VoidCallback onRefresh;
  final VoidCallback? onLoadMore;

  /// Called when user swipes to a new page, for tracking current view index.
  final void Function(int index)? onPageChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = usePageController();
    final videoManager = ref.watch(youtubePlayerManagerProvider);

    // Preload first videos when data loads
    useEffect(() {
      if (feed.hasValue && feed.value!.isNotEmpty && T == VideoFeedEntry) {
        _preloadInitialVideos(feed.value!, videoManager);
      }
      return null;
    }, [feed.hasValue]);

    return SafeArea(
      bottom: false,
      child: feed.when(
        data: (entries) => _buildFeedContent(entries, controller, videoManager),
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
    final firstEntry = entries[0] as VideoFeedEntry;
    videoManager.initController(firstEntry.link);

    if (entries.length > 1) {
      final secondEntry = entries[1] as VideoFeedEntry;
      videoManager.initController(secondEntry.link);
    }
  }

  Widget _buildFeedContent(
    List<T> entries,
    PageController controller,
    YoutubePlayerManagerBase videoManager,
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
      onPageChanged: (index) => _handlePageChange(index, entries, videoManager),
      itemCount: entries.length,
      itemBuilder: (context, index) => SizedBox.expand(
        child: builder(entries[index]),
      ),
    );
  }

  void _handlePageChange(
    int index,
    List<T> entries,
    YoutubePlayerManagerBase videoManager,
  ) {
    // Notify parent of page change for cache position tracking
    onPageChanged?.call(index);

    // Video preloading logic
    if (T == VideoFeedEntry) {
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
    // Collect video URLs for the manager
    final urls = entries.map((e) => (e as VideoFeedEntry).link).toList();

    // Use the centralized page change handler
    videoManager.onPageChanged(
      currentIndex: index,
      videoUrls: urls,
    );
  }
}
