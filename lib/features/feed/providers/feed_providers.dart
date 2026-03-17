import 'dart:async';

import 'package:blips_mobile/core/error/error.dart';
import 'package:blips_mobile/core/network/backend_api_client.dart';
import 'package:blips_mobile/core/network/dio_provider.dart';
import 'package:blips_mobile/features/ads/domain/ads_config.dart';
import 'package:blips_mobile/features/ads/domain/feed_page_item.dart';
import 'package:blips_mobile/features/ads/providers/ads_providers.dart';
import 'package:blips_mobile/features/feed/data/feed_cache.dart';
import 'package:blips_mobile/features/feed/data/feed_cache_interface.dart';
import 'package:blips_mobile/features/feed/data/feed_repository.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:blips_mobile/features/feed/domain/feed_freshness.dart';
import 'package:blips_mobile/features/feed/domain/feed_ordering.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Provides a singleton [FeedRepository].
final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return FeedRepository(DioBackendApiClient(dio));
});

/// Provides access to the feed cache singleton.
final feedCacheProvider = Provider<FeedCacheInterface>((ref) {
  return FeedCache.instance;
});

// ---------------------------------------------------------------------------
// Shared feed-seen state
// ---------------------------------------------------------------------------

/// Shared "last seen" cutoff across articles and videos.
final _feedLastSeenAtProvider = StateProvider<DateTime?>((ref) => null);

// ---------------------------------------------------------------------------
// ArticlesNotifier
// ---------------------------------------------------------------------------

/// Manages the paginated state of the articles feed.
///
/// Implements stale-while-revalidate:
/// 1. Show cached data immediately if available
/// 2. Fetch fresh data in background
/// 3. Seamlessly merge new data, preserving user's current position
class ArticlesNotifier
    extends StateNotifier<AsyncValue<List<ArticleFeedEntry>>> {
  ArticlesNotifier(this._repository, this._cache, this._ref)
      : super(const AsyncValue.loading()) {
    _loadInitial();
    _startPolling();
  }

  final FeedRepository _repository;
  final FeedCacheInterface _cache;
  final Ref _ref;
  int _page = 1;
  bool _hasMore = true;
  FeedInventoryState _inventoryState = FeedInventoryState.warmingUp;
  bool _isLoadingMore = false;
  bool _isRefreshing = false;
  Timer? _pollTimer;
  static const int _limit = 15;
  static const Duration _pollInterval = Duration(seconds: 90);
  Set<int> _newSinceLastSeenIds = <int>{};

  int _currentViewIndex = 0;

  void setCurrentViewIndex(int index) {
    _currentViewIndex = index;
  }

  bool isEntryNewSinceLastSeen(int entryId) {
    return _newSinceLastSeenIds.contains(entryId);
  }

  bool get hasMore => _hasMore;
  FeedInventoryState get inventoryState => _inventoryState;
  bool get isCaughtUp => _inventoryState == FeedInventoryState.caughtUp;

  // -- lifecycle -----------------------------------------------------------

  Future<void> _loadInitial() async {
    if (!mounted) return;
    await _loadLastSeenCutoff();

    try {
      final cached = await _cache.getCachedArticles(limit: _limit);
      if (cached.isNotEmpty && mounted) {
        state = AsyncValue.data(cached);
        _updateNewSinceLastSeen(cached);
        _page = 1;
        _hasMore = true;
        _inventoryState = FeedInventoryState.healthy;

        logger.info(
          'Articles cache HIT: ${cached.length} items',
          category: LogCategory.app,
        );

        _markFeedSeenNowInBackground();
        _refreshInBackground();
        return;
      }
    } catch (e) {
      logger.warning('Failed to read articles cache',
          category: LogCategory.app, error: e);
    }

    logger.info('Articles cache MISS: fetching from network',
        category: LogCategory.app);
    await _fetchFromNetwork();
    _markFeedSeenNowInBackground();
  }

  Future<void> _fetchFromNetwork() async {
    try {
      if (!mounted) return;
      state = const AsyncValue.loading();

      final page = await _repository.fetchArticlesPage(page: 1, size: _limit);
      if (!mounted) return;
      _page = 1;
      _hasMore = page.hasMore;
      _inventoryState = page.inventoryState;
      final articles =
          page.items.whereType<ArticleFeedEntry>().toList(growable: false);
      state = AsyncValue.data(articles);
      _updateNewSinceLastSeen(articles);
      _cacheInBackground(articles);
    } catch (e, st) {
      if (!mounted) return;
      logger.warning('Failed to load articles',
          category: LogCategory.network, error: e, stackTrace: st);
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> _refreshInBackground() async {
    if (_isRefreshing) return;
    _isRefreshing = true;

    try {
      final freshPage =
          await _repository.fetchArticlesPage(page: 1, size: _limit);
      final freshItems =
          freshPage.items.whereType<ArticleFeedEntry>().toList(growable: false);
      _hasMore = freshPage.hasMore;
      _inventoryState = freshPage.inventoryState;
      if (!mounted || freshItems.isEmpty) return;

      _cacheInBackground(freshItems);

      final currentList = state.valueOrNull;
      if (currentList == null || currentList.isEmpty) {
        _page = 1;
        state = AsyncValue.data(freshItems);
        _updateNewSinceLastSeen(freshItems);
        return;
      }

      final merged = mergeFeedWithStableOrdering(
        currentItems: currentList,
        freshItems: freshItems,
        prependNewItems: _currentViewIndex <= 1,
      ).whereType<ArticleFeedEntry>().toList(growable: false);

      state = AsyncValue.data(merged);
      _updateNewSinceLastSeen(merged);
    } catch (e, st) {
      logger.warning('Background articles refresh failed',
          category: LogCategory.network, error: e, stackTrace: st);
    } finally {
      _isRefreshing = false;
    }
  }

  // -- public API ----------------------------------------------------------

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    final currentList = state.valueOrNull;
    if (currentList == null) return;

    _isLoadingMore = true;
    try {
      final nextPage =
          await _repository.fetchArticlesPage(page: _page + 1, size: _limit);
      final nextItems =
          nextPage.items.whereType<ArticleFeedEntry>().toList(growable: false);

      if (mounted) {
        _page++;
        _hasMore = nextPage.hasMore;
        _inventoryState = nextPage.inventoryState;
        final latestList = state.valueOrNull ?? currentList;
        final seenIds = latestList.map((e) => e.id).toSet();
        final unique = nextItems.where((e) => !seenIds.contains(e.id)).toList();
        final merged = [...latestList, ...unique];
        state = AsyncValue.data(merged);
        _updateNewSinceLastSeen(merged);
        _cacheInBackground(nextItems);
      }
    } catch (e, st) {
      logger.warning('Failed to load more articles',
          category: LogCategory.network, error: e, stackTrace: st);
    } finally {
      _isLoadingMore = false;
    }
  }

  /// Manual refresh: keeps current content visible, replaces on success,
  /// returns false on failure or timeout (no state mutation).
  Future<bool> manualRefresh() async {
    try {
      final page = await _repository.fetchArticlesPage(
        page: 1,
        size: _limit,
        requestMode: RequestMode.manualRefresh,
      );

      if (!mounted) return false;
      final articles =
          page.items.whereType<ArticleFeedEntry>().toList(growable: false);
      _page = 1;
      _hasMore = page.hasMore;
      _inventoryState = page.inventoryState;
      _currentViewIndex = 0;
      state = AsyncValue.data(articles);
      _updateNewSinceLastSeen(articles);
      _cacheInBackground(articles);
      return true;
    } catch (e, st) {
      logger.warning('Manual articles refresh failed',
          category: LogCategory.network, error: e, stackTrace: st);
      return false;
    }
  }

  /// Background refresh without spinners or index reset.
  Future<void> refreshSilently() async {
    await _refreshInBackground();
  }

  // -- polling -------------------------------------------------------------

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      if (!mounted) return;
      _refreshInBackground();
    });
  }

  // -- helpers -------------------------------------------------------------

  void _cacheInBackground(List<ArticleFeedEntry> items) {
    Future.microtask(() async {
      try {
        await _cache.cacheArticles(items);
      } catch (e) {
        logger.warning('Failed to cache articles',
            category: LogCategory.app, error: e);
      }
    });
  }

  Future<void> _loadLastSeenCutoff() async {
    final existing = _ref.read(_feedLastSeenAtProvider);
    if (existing != null) return;
    try {
      final stored = await _cache.getFeedLastSeenAt();
      if (stored != null) {
        _ref.read(_feedLastSeenAtProvider.notifier).state = stored;
      }
    } catch (_) {}
  }

  void _updateNewSinceLastSeen(List<ArticleFeedEntry> entries) {
    _newSinceLastSeenIds = computeNewSinceLastSeenIds(
      entries: entries,
      lastSeenAt: _ref.read(_feedLastSeenAtProvider),
    );
  }

  void _markFeedSeenNowInBackground() {
    final now = DateTime.now().toUtc();
    _ref.read(_feedLastSeenAtProvider.notifier).state = now;
    Future.microtask(() async {
      try {
        await _cache.setFeedLastSeenAt(now);
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// VideosNotifier
// ---------------------------------------------------------------------------

/// Manages the paginated state of the videos feed.
class VideosNotifier extends StateNotifier<AsyncValue<List<VideoFeedEntry>>> {
  VideosNotifier(this._repository, this._cache, this._ref)
      : super(const AsyncValue.loading()) {
    _loadInitial();
    // Stagger: videos start polling after a 45-second initial delay.
    _startPollingWithDelay(const Duration(seconds: 45));
  }

  final FeedRepository _repository;
  final FeedCacheInterface _cache;
  final Ref _ref;
  int _page = 1;
  bool _hasMore = true;
  FeedInventoryState _inventoryState = FeedInventoryState.warmingUp;
  bool _isLoadingMore = false;
  bool _isRefreshing = false;
  Timer? _pollTimer;
  Timer? _initialDelayTimer;
  static const int _limit = 10;
  static const Duration _pollInterval = Duration(seconds: 90);
  Set<int> _newSinceLastSeenIds = <int>{};

  int _currentViewIndex = 0;

  void setCurrentViewIndex(int index) {
    _currentViewIndex = index;
  }

  bool isEntryNewSinceLastSeen(int entryId) {
    return _newSinceLastSeenIds.contains(entryId);
  }

  bool get hasMore => _hasMore;
  FeedInventoryState get inventoryState => _inventoryState;
  bool get isCaughtUp => _inventoryState == FeedInventoryState.caughtUp;

  // -- lifecycle -----------------------------------------------------------

  Future<void> _loadInitial() async {
    if (!mounted) return;
    await _loadLastSeenCutoff();

    try {
      final cached = await _cache.getCachedVideos(limit: _limit);
      if (cached.isNotEmpty && mounted) {
        state = AsyncValue.data(cached);
        _updateNewSinceLastSeen(cached);
        _page = 1;
        _hasMore = true;
        _inventoryState = FeedInventoryState.healthy;

        logger.info(
          'Videos cache HIT: ${cached.length} items',
          category: LogCategory.app,
        );

        _refreshInBackground();
        return;
      }
    } catch (e) {
      logger.warning('Failed to read videos cache',
          category: LogCategory.app, error: e);
    }

    logger.info('Videos cache MISS: fetching from network',
        category: LogCategory.app);
    await _fetchFromNetwork();
  }

  Future<void> _fetchFromNetwork() async {
    try {
      if (!mounted) return;
      state = const AsyncValue.loading();

      final page = await _repository.fetchVideosPage(page: 1, size: _limit);
      if (!mounted) return;
      _page = 1;
      _hasMore = page.hasMore;
      _inventoryState = page.inventoryState;
      final videos =
          page.items.whereType<VideoFeedEntry>().toList(growable: false);
      state = AsyncValue.data(videos);
      _updateNewSinceLastSeen(videos);
      _replaceCacheSnapshotInBackground(videos);
    } catch (e, st) {
      if (!mounted) return;
      logger.warning('Failed to load videos',
          category: LogCategory.network, error: e, stackTrace: st);
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> _refreshInBackground() async {
    if (_isRefreshing) return;
    _isRefreshing = true;

    try {
      final freshPage =
          await _repository.fetchVideosPage(page: 1, size: _limit);
      final freshItems =
          freshPage.items.whereType<VideoFeedEntry>().toList(growable: false);
      _hasMore = freshPage.hasMore;
      _inventoryState = freshPage.inventoryState;
      if (!mounted) return;

      _replaceCacheSnapshotInBackground(freshItems);

      final currentList = state.valueOrNull;
      final hasOnlyPageOne =
          currentList == null || currentList.length <= _limit;
      if (freshItems.isEmpty) {
        if (hasOnlyPageOne) {
          _page = 1;
          state = const AsyncValue.data(<VideoFeedEntry>[]);
          _updateNewSinceLastSeen(const <VideoFeedEntry>[]);
        }
        return;
      }
      if (currentList == null || currentList.isEmpty) {
        _page = 1;
        state = AsyncValue.data(freshItems);
        _updateNewSinceLastSeen(freshItems);
        return;
      }
      if (hasOnlyPageOne) {
        _page = 1;
        state = AsyncValue.data(freshItems);
        _updateNewSinceLastSeen(freshItems);
        return;
      }

      final merged = mergeFeedWithStableOrdering(
        currentItems: currentList,
        freshItems: freshItems,
        prependNewItems: _currentViewIndex <= 1,
      ).whereType<VideoFeedEntry>().toList(growable: false);

      state = AsyncValue.data(merged);
      _updateNewSinceLastSeen(merged);
    } catch (e, st) {
      logger.warning('Background videos refresh failed',
          category: LogCategory.network, error: e, stackTrace: st);
    } finally {
      _isRefreshing = false;
    }
  }

  // -- public API ----------------------------------------------------------

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    final currentList = state.valueOrNull;
    if (currentList == null) return;

    _isLoadingMore = true;
    try {
      final nextPage =
          await _repository.fetchVideosPage(page: _page + 1, size: _limit);
      final nextItems =
          nextPage.items.whereType<VideoFeedEntry>().toList(growable: false);

      if (mounted) {
        _page++;
        _hasMore = nextPage.hasMore;
        _inventoryState = nextPage.inventoryState;
        final latestList = state.valueOrNull ?? currentList;
        final seenIds = latestList.map((e) => e.id).toSet();
        final unique = nextItems.where((e) => !seenIds.contains(e.id)).toList();
        final merged = [...latestList, ...unique];
        state = AsyncValue.data(merged);
        _updateNewSinceLastSeen(merged);
        _cacheInBackground(nextItems);
      }
    } catch (e, st) {
      logger.warning('Failed to load more videos',
          category: LogCategory.network, error: e, stackTrace: st);
    } finally {
      _isLoadingMore = false;
    }
  }

  /// Manual refresh: keeps current content visible, replaces on success,
  /// returns false on failure or timeout (no state mutation).
  Future<bool> manualRefresh() async {
    try {
      final page = await _repository.fetchVideosPage(
        page: 1,
        size: _limit,
        requestMode: RequestMode.manualRefresh,
      );

      if (!mounted) return false;
      final videos =
          page.items.whereType<VideoFeedEntry>().toList(growable: false);
      _page = 1;
      _hasMore = page.hasMore;
      _inventoryState = page.inventoryState;
      _currentViewIndex = 0;
      state = AsyncValue.data(videos);
      _updateNewSinceLastSeen(videos);
      _replaceCacheSnapshotInBackground(videos);
      return true;
    } catch (e, st) {
      logger.warning('Manual videos refresh failed',
          category: LogCategory.network, error: e, stackTrace: st);
      return false;
    }
  }

  /// Background refresh without spinners or index reset.
  Future<void> refreshSilently() async {
    await _refreshInBackground();
  }

  // -- polling -------------------------------------------------------------

  void _startPollingWithDelay(Duration initialDelay) {
    _initialDelayTimer?.cancel();
    _initialDelayTimer = Timer(initialDelay, () {
      if (!mounted) return;
      _refreshInBackground();
      _pollTimer?.cancel();
      _pollTimer = Timer.periodic(_pollInterval, (_) {
        if (!mounted) return;
        _refreshInBackground();
      });
    });
  }

  // -- helpers -------------------------------------------------------------

  void _cacheInBackground(List<VideoFeedEntry> items) {
    Future.microtask(() async {
      try {
        await _cache.cacheVideos(items);
      } catch (e) {
        logger.warning('Failed to cache videos',
            category: LogCategory.app, error: e);
      }
    });
  }

  void _replaceCacheSnapshotInBackground(List<VideoFeedEntry> items) {
    Future.microtask(() async {
      try {
        await _cache.replaceVideosSnapshot(items);
      } catch (e) {
        logger.warning('Failed to replace videos cache snapshot',
            category: LogCategory.app, error: e);
      }
    });
  }

  Future<void> _loadLastSeenCutoff() async {
    final existing = _ref.read(_feedLastSeenAtProvider);
    if (existing != null) return;
    try {
      final stored = await _cache.getFeedLastSeenAt();
      if (stored != null) {
        _ref.read(_feedLastSeenAtProvider.notifier).state = stored;
      }
    } catch (_) {}
  }

  void _updateNewSinceLastSeen(List<VideoFeedEntry> entries) {
    _newSinceLastSeenIds = computeNewSinceLastSeenIds(
      entries: entries,
      lastSeenAt: _ref.read(_feedLastSeenAtProvider),
    );
  }

  @override
  void dispose() {
    _initialDelayTimer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Provider definitions (articles + videos)
// ---------------------------------------------------------------------------

/// Loads the articles feed.
final articlesFeedProvider = StateNotifierProvider.autoDispose<ArticlesNotifier,
    AsyncValue<List<ArticleFeedEntry>>>(
  (ref) => ArticlesNotifier(
    ref.watch(feedRepositoryProvider),
    ref.watch(feedCacheProvider),
    ref,
  ),
);

/// Loads the videos feed.
final videosFeedProvider = StateNotifierProvider.autoDispose<VideosNotifier,
    AsyncValue<List<VideoFeedEntry>>>(
  (ref) => VideosNotifier(
    ref.watch(feedRepositoryProvider),
    ref.watch(feedCacheProvider),
    ref,
  ),
);

/// Articles feed with device-local native ad slots.
final articleFeedWithAdsProvider =
    Provider.autoDispose<AsyncValue<List<FeedPageItem>>>((ref) {
  final feedState = ref.watch(articlesFeedProvider);
  final adsConfig =
      ref.watch(adsConfigProvider).valueOrNull ?? const AdsConfig();
  final repository = ref.watch(feedRepositoryProvider);

  return feedState.when(
    data: (items) => AsyncValue.data(
      buildFeedPageItems(
        entries: items,
        adsConfig: adsConfig,
        surface: AdSurface.articles,
        sessionId: repository.articleSessionId,
      ),
    ),
    error: (err, stack) => AsyncValue.error(err, stack),
    loading: () => const AsyncValue.loading(),
  );
});

/// Videos feed with device-local native ad slots.
final videoFeedWithAdsProvider =
    Provider.autoDispose<AsyncValue<List<FeedPageItem>>>((ref) {
  final feedState = ref.watch(videosFeedProvider);
  final adsConfig =
      ref.watch(adsConfigProvider).valueOrNull ?? const AdsConfig();
  final repository = ref.watch(feedRepositoryProvider);

  return feedState.when(
    data: (items) => AsyncValue.data(
      buildFeedPageItems(
        entries: items,
        adsConfig: adsConfig,
        surface: AdSurface.videos,
        sessionId: repository.videoSessionId,
      ),
    ),
    error: (err, stack) => AsyncValue.error(err, stack),
    loading: () => const AsyncValue.loading(),
  );
});

// ---------------------------------------------------------------------------
// ReelsNotifier (kept, manualRefresh added)
// ---------------------------------------------------------------------------

/// Manages the paginated state of the reels feed.
///
/// Implements stale-while-revalidate similar to FeedNotifier.
class ReelsNotifier extends StateNotifier<AsyncValue<List<ReelFeedEntry>>> {
  ReelsNotifier(this._repository, this._cache)
      : super(const AsyncValue.loading()) {
    loadInitial();
    _startPolling();
  }

  final FeedRepository _repository;
  final FeedCacheInterface _cache;
  bool _hasMore = true;
  String? _nextCursor;
  FeedInventoryState _inventoryState = FeedInventoryState.warmingUp;
  bool _isLoadingMore = false;
  bool _isRefreshing = false;
  Timer? _pollTimer;
  static const int _limit = 20;
  static const Duration _pollInterval = Duration(seconds: 60);

  bool get hasMore => _hasMore;

  FeedInventoryState get inventoryState => _inventoryState;

  bool get isCaughtUp => _inventoryState == FeedInventoryState.caughtUp;

  Future<void> loadInitial() async {
    if (!mounted) return;

    // Try to show cached data first
    try {
      final cached = await _cache.getCachedReels(limit: _limit);

      if (cached.isNotEmpty && mounted) {
        state = AsyncValue.data(cached);
        _hasMore = true;
        _nextCursor = null;
        _inventoryState = FeedInventoryState.healthy;

        logger.info(
          'Reels cache HIT: ${cached.length} items served from cache',
          category: LogCategory.app,
        );

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

    logger.info(
      'Reels cache MISS: fetching from network',
      category: LogCategory.app,
    );

    await _fetchFromNetwork();
  }

  Future<void> _fetchFromNetwork() async {
    try {
      if (!mounted) return;
      state = const AsyncValue.loading();
      final page = await _repository.fetchReelsPage(limit: _limit);
      if (!mounted) return;
      _hasMore = page.hasMore;
      _nextCursor = page.nextCursor;
      _inventoryState = page.inventoryState;
      state = AsyncValue.data(page.items);

      _replaceCacheSnapshotInBackground(page.items);
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
      final freshPage = await _repository.fetchReelsPage(limit: _limit);
      final freshReels = freshPage.items;
      _inventoryState = freshPage.inventoryState;
      if (!mounted) return;
      _replaceCacheSnapshotInBackground(freshReels);
      if (freshReels.isEmpty) {
        return;
      }

      final currentList = state.valueOrNull;
      final preservePagination =
          currentList != null && currentList.length > _limit;
      if (!preservePagination) {
        _hasMore = freshPage.hasMore;
        _nextCursor = freshPage.nextCursor;
      }
      if (currentList == null || currentList.isEmpty) {
        state = AsyncValue.data(freshReels);
        return;
      }

      final merged = mergeFeedWithStableOrdering(
        currentItems: currentList,
        freshItems: freshReels,
        // Reels is a full-screen, position-sensitive surface.
        // Silent refresh must never prepend page-1 newcomers into a live
        // session because that can shift the visible reel away from the
        // numeric page index the player manager is using.
        prependNewItems: false,
      ).whereType<ReelFeedEntry>().toList(growable: false);

      state = AsyncValue.data(merged);
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

  void _replaceCacheSnapshotInBackground(List<ReelFeedEntry> reels) {
    Future.microtask(() async {
      try {
        await _cache.replaceReelsSnapshot(reels);
      } catch (e) {
        logger.warning(
          'Failed to replace reels cache snapshot',
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
      final nextPage = await _repository.fetchReelsPage(
        cursor: _nextCursor,
        limit: _limit,
      );
      final nextReels = nextPage.items;

      if (mounted) {
        _hasMore = nextPage.hasMore;
        _nextCursor = nextPage.nextCursor;
        _inventoryState = nextPage.inventoryState;
        final latestList = state.valueOrNull ?? currentList;
        final seenIds = latestList.map((entry) => entry.id).toSet();
        final uniqueNextReels = nextReels
            .where((entry) => !seenIds.contains(entry.id))
            .toList(growable: false);
        state = AsyncValue.data([...latestList, ...uniqueNextReels]);

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

  /// Manual refresh: keeps current content visible, replaces on success,
  /// returns false on failure or timeout.
  Future<bool> manualRefresh() async {
    try {
      final page = await _repository.fetchReelsPage(
        limit: _limit,
        requestMode: RequestMode.manualRefresh,
      );

      if (!mounted) return false;
      _hasMore = page.hasMore;
      _nextCursor = page.nextCursor;
      _inventoryState = page.inventoryState;
      state = AsyncValue.data(page.items);
      _replaceCacheSnapshotInBackground(page.items);
      return true;
    } catch (e, st) {
      logger.warning('Manual reels refresh failed',
          category: LogCategory.network, error: e, stackTrace: st);
      return false;
    }
  }

  /// Background refresh without disrupting current playback.
  Future<void> refreshSilently() async {
    await _refreshInBackground();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      if (!mounted) return;
      _refreshInBackground();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
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
