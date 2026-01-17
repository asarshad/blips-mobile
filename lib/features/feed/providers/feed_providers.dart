import 'package:blips_mobile/core/error/error.dart';
import 'package:blips_mobile/core/network/dio_provider.dart';
import 'package:blips_mobile/features/feed/data/feed_repository.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Provides a singleton [FeedRepository].
final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return FeedRepository(dio);
});

/// Manages the paginated state of the main feed (articles + videos).
class FeedNotifier extends StateNotifier<AsyncValue<List<FeedEntry>>> {
  FeedNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadInitial();
  }

  final FeedRepository _repository;
  int _page = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  static const int _articleLimit = 15;
  static const int _videoLimit = 10;

  Future<void> loadInitial() async {
    try {
      if (!mounted) return;
      state = const AsyncValue.loading();
      final items = await _repository.fetchFeed(
        page: 1,
        articleLimit: _articleLimit,
        videoLimit: _videoLimit,
      );
      if (!mounted) return;
      _page = 1;
      _hasMore = items.isNotEmpty;
      state = AsyncValue.data(items);
    } catch (e, st) {
      if (!mounted) return;
      logger.warning(
        'Failed to load feed',
        category: LogCategory.network,
        error: e,
        stackTrace: st,
      );
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    final currentList = state.valueOrNull;
    if (currentList == null) return;

    _isLoadingMore = true;
    try {
      final nextItems = await _repository.fetchFeed(
        page: _page + 1,
        articleLimit: _articleLimit,
        videoLimit: _videoLimit,
      );

      if (mounted) {
        _page++;
        _hasMore = nextItems.isNotEmpty;
        state = AsyncValue.data([...currentList, ...nextItems]);
      }
    } catch (e, st) {
      logger.warning(
        'Failed to load more feed items',
        category: LogCategory.network,
        error: e,
        stackTrace: st,
      );
      // Don't update state on loadMore failure - keep existing data
    } finally {
      _isLoadingMore = false;
    }
  }
}

/// Loads the merged article/video feed for the home experience.
final paginatedFeedProvider = StateNotifierProvider.autoDispose<FeedNotifier,
    AsyncValue<List<FeedEntry>>>(
  (ref) => FeedNotifier(ref.watch(feedRepositoryProvider)),
);

/// Filters only article entries from the merged feed.
final filteredArticleFeedProvider =
    Provider.autoDispose<AsyncValue<List<ArticleFeedEntry>>>((ref) {
  final feedState = ref.watch(paginatedFeedProvider);

  return feedState.when(
    data: (items) => AsyncValue.data(
      items.whereType<ArticleFeedEntry>().toList(growable: false),
    ),
    error: (err, stack) => AsyncValue.error(err, stack),
    loading: () => const AsyncValue.loading(),
  );
});

/// Filters only video entries from the merged feed.
final filteredVideoFeedProvider =
    Provider.autoDispose<AsyncValue<List<VideoFeedEntry>>>((ref) {
  final feedState = ref.watch(paginatedFeedProvider);

  return feedState.when(
    data: (items) => AsyncValue.data(
      items.whereType<VideoFeedEntry>().toList(growable: false),
    ),
    error: (err, stack) => AsyncValue.error(err, stack),
    loading: () => const AsyncValue.loading(),
  );
});

/// Manages the paginated state of the reels feed.
class ReelsNotifier extends StateNotifier<AsyncValue<List<ReelFeedEntry>>> {
  ReelsNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadInitial();
  }

  final FeedRepository _repository;
  int _page = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  static const int _limit = 20;

  Future<void> loadInitial() async {
    try {
      if (!mounted) return;
      state = const AsyncValue.loading();
      final reels = await _repository.fetchReels(page: 1, limit: _limit);
      if (!mounted) return;
      _page = 1;
      _hasMore = reels.length >= _limit;
      state = AsyncValue.data(reels);
    } catch (e, st) {
      if (!mounted) return;
      logger.warning(
        'Failed to load reels',
        category: LogCategory.network,
        error: e,
        stackTrace: st,
      );
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    // Don't reload if we are in error or loading state initially
    final currentList = state.valueOrNull;
    if (currentList == null) return;

    _isLoadingMore = true;
    try {
      final nextReels = await _repository.fetchReels(
        page: _page + 1,
        limit: _limit,
      );

      if (mounted) {
        _page++;
        _hasMore = nextReels.length >= _limit;
        state = AsyncValue.data([...currentList, ...nextReels]);
      }
    } catch (e, st) {
      logger.warning(
        'Failed to load more reels',
        category: LogCategory.network,
        error: e,
        stackTrace: st,
      );
      // Don't update state on loadMore failure - keep existing data
    } finally {
      _isLoadingMore = false;
    }
  }
}

/// Loads the reels feed with pagination support.
final reelsFeedProvider = StateNotifierProvider.autoDispose<ReelsNotifier,
    AsyncValue<List<ReelFeedEntry>>>(
  (ref) => ReelsNotifier(ref.watch(feedRepositoryProvider)),
);
