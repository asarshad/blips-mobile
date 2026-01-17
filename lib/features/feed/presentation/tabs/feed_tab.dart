import 'package:blips_mobile/core/error/error.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:blips_mobile/features/feed/presentation/widgets/widgets.dart';
import 'package:blips_mobile/features/feed/providers/optimized_video_provider.dart';
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
class FeedTab<T extends FeedEntry> extends HookConsumerWidget {
  const FeedTab({
    super.key,
    required this.feed,
    required this.builder,
    required this.emptyLabel,
    required this.onRefresh,
    this.onLoadMore,
  });

  final AsyncValue<List<T>> feed;
  final Widget Function(T entry) builder;
  final String emptyLabel;
  final VoidCallback onRefresh;
  final VoidCallback? onLoadMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = usePageController();
    final videoManager = ref.watch(optimizedVideoManagerProvider);

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
    OptimizedVideoPlayerManager videoManager,
  ) {
    final firstEntry = entries[0] as VideoFeedEntry;
    videoManager.preload(firstEntry.link);

    if (entries.length > 1) {
      final secondEntry = entries[1] as VideoFeedEntry;
      videoManager.preload(secondEntry.link);
    }
  }

  Widget _buildFeedContent(
    List<T> entries,
    PageController controller,
    OptimizedVideoPlayerManager videoManager,
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
    OptimizedVideoPlayerManager videoManager,
  ) {
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
    OptimizedVideoPlayerManager videoManager,
  ) {
    // Preload current
    final currentEntry = entries[index] as VideoFeedEntry;
    videoManager.preload(currentEntry.link);

    // Pause previous
    if (index > 0) {
      final prevEntry = entries[index - 1] as VideoFeedEntry;
      videoManager.pauseVideo(prevEntry.link);
    }

    // Pause next (if scrolling back)
    if (index < entries.length - 1) {
      final nextEntry = entries[index + 1] as VideoFeedEntry;
      videoManager.pauseVideo(nextEntry.link);
    }

    // Preload next 2
    if (index + 1 < entries.length) {
      final nextEntry = entries[index + 1] as VideoFeedEntry;
      videoManager.preload(nextEntry.link);
    }
    if (index + 2 < entries.length) {
      final nextNextEntry = entries[index + 2] as VideoFeedEntry;
      videoManager.preload(nextNextEntry.link);
    }

    // Release old videos (keep 1 behind for smooth back swipe)
    if (index > 1) {
      final oldEntry = entries[index - 2] as VideoFeedEntry;
      videoManager.releaseVideo(oldEntry.link);
    }
  }
}
