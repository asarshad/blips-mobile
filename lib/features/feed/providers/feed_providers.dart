import 'package:blips_mobile/core/error/error.dart';
import 'package:blips_mobile/core/network/dio_provider.dart';
import 'package:blips_mobile/features/feed/data/feed_cache.dart';
import 'package:blips_mobile/features/feed/data/feed_repository.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Provides a singleton [FeedRepository].
final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return FeedRepository(dio);
});

/// Provides access to the feed cache singleton.
final feedCacheProvider = Provider<FeedCache>((ref) {
  return FeedCache.instance;
});

/// Manages the paginated state of the main feed (articles + videos).
///
/// Implements stale-while-revalidate:
/// 1. Show cached data immediately if available
/// 2. Fetch fresh data in background
/// 3. Seamlessly merge new data, preserving user's current position
class FeedNotifier extends StateNotifier<AsyncValue<List<FeedEntry>>> {
  FeedNotifier(this._repository, this._cache) : super(const AsyncValue.loading()) {
    loadInitial();
  }

  final FeedRepository _repository;
  final FeedCache _cache;
  int _page = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  bool _isRefreshing = false;
  static const int _articleLimit = 15;
  static const int _videoLimit = 10;

  /// Index of the item currently being viewed by the user.
  /// Used to preserve position during seamless updates.
  int _currentViewIndex = 0;

  /// Updates the current view index when user swipes.
  void setCurrentViewIndex(int index) {
    _currentViewIndex = index;
  }

  Future<void> loadInitial() async {
    if (!mounted) return;

    // Try to show cached data first (stale-while-revalidate)
    try {
      final cached = await _cache.getCachedFeed(
        articleLimit: _articleLimit,
        videoLimit: _videoLimit,
      );

      if (cached.isNotEmpty && mounted) {
        // Show cached data immediately
        state = AsyncValue.data(cached);
        _page = 1;
        _hasMore = true;

        // Then fetch fresh data in background
        _refreshInBackground();
        return;
      }
    } catch (e) {
      // Cache read failed, continue to network fetch
      logger.warning(
        'Failed to read feed cache',
        category: LogCategory.app,
        error: e,
      );
    }

    // No cache, fetch from network
    await _fetchFromNetwork();
  }

  /// Fetches fresh data from network and updates state.
  Future<void> _fetchFromNetwork() async {
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

      // Cache the fresh data
      _cacheInBackground(items);
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

  /// Refreshes data in background without disrupting current view.
  Future<void> _refreshInBackground() async {
    if (_isRefreshing) return;
    _isRefreshing = true;

    try {
      final freshItems = await _repository.fetchFeed(
        page: 1,
        articleLimit: _articleLimit,
        videoLimit: _videoLimit,
      );

      if (!mounted || freshItems.isEmpty) return;

      // Cache the fresh data
      _cacheInBackground(freshItems);

      // Seamlessly merge: keep current item stable, update the rest
      final currentList = state.valueOrNull;
      if (currentList == null || currentList.isEmpty) {
        // No existing data, just replace
        state = AsyncValue.data(freshItems);
        return;
      }

      // Find the ID of the currently viewed item
      final currentItem = _currentViewIndex < currentList.length
          ? currentList[_currentViewIndex]
          : null;

      if (currentItem == null) {
        // No current item, just replace
        state = AsyncValue.data(freshItems);
        return;
      }

      // Check if current item exists in fresh data
      final freshIndex = freshItems.indexWhere((item) => item.id == currentItem.id);

      if (freshIndex >= 0) {
        // Current item exists in fresh data - use fresh list
        // The UI should maintain scroll position based on index
        _page = 1;
        _hasMore = true;
        state = AsyncValue.data(freshItems);
      } else {
        // Current item not in fresh data - merge lists
        // Keep items from current position onwards, prepend new items
        final itemsBeforeCurrent = freshItems;
        final itemsFromCurrent = currentList.sublist(_currentViewIndex);

        // Deduplicate: remove from fresh any items that exist in itemsFromCurrent
        final currentIds = itemsFromCurrent.map((e) => e.id).toSet();
        final uniqueFresh = itemsBeforeCurrent
            .where((item) => !currentIds.contains(item.id))
            .toList();

        final merged = [...uniqueFresh, ...itemsFromCurrent];
        _page = 1;
        _hasMore = true;
        state = AsyncValue.data(merged);
      }
    } catch (e, st) {
      // Background refresh failed - keep showing cached data
      logger.warning(
        'Background feed refresh failed',
        category: LogCategory.network,
        error: e,
        stackTrace: st,
      );
    } finally {
      _isRefreshing = false;
    }
  }

  /// Caches items in background without blocking.
  void _cacheInBackground(List<FeedEntry> items) {
    Future.microtask(() async {
      try {
        await _cache.cacheFeed(items);
      } catch (e) {
        logger.warning(
          'Failed to cache feed',
          category: LogCategory.app,
          error: e,
        );
      }
    });
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
        final merged = [...currentList, ...nextItems];
        state = AsyncValue.data(merged);

        // Cache the additional items
        _cacheInBackground(nextItems);
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

  /// Force refresh from network, showing loading state.
  Future<void> forceRefresh() async {
    _currentViewIndex = 0;
    await _fetchFromNetwork();
  }
}

/// Loads the merged article/video feed for the home experience.
final paginatedFeedProvider = StateNotifierProvider.autoDispose<FeedNotifier,
    AsyncValue<List<FeedEntry>>>(
  (ref) => FeedNotifier(
    ref.watch(feedRepositoryProvider),
    ref.watch(feedCacheProvider),
  ),
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
///
/// Implements stale-while-revalidate similar to FeedNotifier.
class ReelsNotifier extends StateNotifier<AsyncValue<List<ReelFeedEntry>>> {
  ReelsNotifier(this._repository, this._cache) : super(const AsyncValue.loading()) {
    loadInitial();
  }

  final FeedRepository _repository;
  final FeedCache _cache;
  int _page = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  bool _isRefreshing = false;
  static const int _limit = 20;

  /// Index of the item currently being viewed by the user.
  int _currentViewIndex = 0;

  /// Updates the current view index when user swipes.
  void setCurrentViewIndex(int index) {
    _currentViewIndex = index;
  }

  Future<void> loadInitial() async {
    if (!mounted) return;

    // Try to show cached data first
    try {
      final cached = await _cache.getCachedReels(limit: _limit);

      if (cached.isNotEmpty && mounted) {
        state = AsyncValue.data(cached);
        _page = 1;
        _hasMore = true;
        _refreshInBackground();
        return;
      }
    } catch (e) {
      logger.warning(
        'Failed to read reels cache',
        category: LogCategory.app,
        error: e,
      );
    }

    await _fetchFromNetwork();
  }

  Future<void> _fetchFromNetwork() async {
    try {
      if (!mounted) return;
      state = const AsyncValue.loading();
      final reels = await _repository.fetchReels(page: 1, limit: _limit);
      if (!mounted) return;
      _page = 1;
      _hasMore = reels.length >= _limit;
      state = AsyncValue.data(reels);

      _cacheInBackground(reels);
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

  Future<void> _refreshInBackground() async {
    if (_isRefreshing) return;
    _isRefreshing = true;

    try {
      final freshReels = await _repository.fetchReels(page: 1, limit: _limit);

      if (!mounted || freshReels.isEmpty) return;

      _cacheInBackground(freshReels);

      final currentList = state.valueOrNull;
      if (currentList == null || currentList.isEmpty) {
        state = AsyncValue.data(freshReels);
        return;
      }

      final currentItem = _currentViewIndex < currentList.length
          ? currentList[_currentViewIndex]
          : null;

      if (currentItem == null) {
        state = AsyncValue.data(freshReels);
        return;
      }

      final freshIndex = freshReels.indexWhere((r) => r.id == currentItem.id);

      if (freshIndex >= 0) {
        _page = 1;
        _hasMore = true;
        state = AsyncValue.data(freshReels);
      } else {
        final itemsFromCurrent = currentList.sublist(_currentViewIndex);
        final currentIds = itemsFromCurrent.map((e) => e.id).toSet();
        final uniqueFresh = freshReels
            .where((item) => !currentIds.contains(item.id))
            .toList();

        final merged = [...uniqueFresh, ...itemsFromCurrent];
        _page = 1;
        _hasMore = true;
        state = AsyncValue.data(merged);
      }
    } catch (e, st) {
      logger.warning(
        'Background reels refresh failed',
        category: LogCategory.network,
        error: e,
        stackTrace: st,
      );
    } finally {
      _isRefreshing = false;
    }
  }

  void _cacheInBackground(List<ReelFeedEntry> reels) {
    Future.microtask(() async {
      try {
        await _cache.cacheReels(reels);
      } catch (e) {
        logger.warning(
          'Failed to cache reels',
          category: LogCategory.app,
          error: e,
        );
      }
    });
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

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

        _cacheInBackground(nextReels);
      }
    } catch (e, st) {
      logger.warning(
        'Failed to load more reels',
        category: LogCategory.network,
        error: e,
        stackTrace: st,
      );
    } finally {
      _isLoadingMore = false;
    }
  }

  Future<void> forceRefresh() async {
    _currentViewIndex = 0;
    await _fetchFromNetwork();
  }
}

/// Loads the reels feed with pagination support.
final reelsFeedProvider = StateNotifierProvider.autoDispose<ReelsNotifier,
    AsyncValue<List<ReelFeedEntry>>>(
  (ref) => ReelsNotifier(
    ref.watch(feedRepositoryProvider),
    ref.watch(feedCacheProvider),
  ),
);
