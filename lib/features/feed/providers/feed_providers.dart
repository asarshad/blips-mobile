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
import 'package:blips_mobile/features/feed/data/feed_session_store.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:blips_mobile/features/feed/domain/feed_freshness.dart';
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

/// Provides persisted continuity/session state helpers for feed surfaces.
final feedSessionStoreProvider = Provider<FeedSessionStore>((ref) {
  return FeedSessionStore(ref.watch(feedCacheProvider));
});

class FeedSurfaceUiState {
  const FeedSurfaceUiState({
    this.pendingNewCount = 0,
    this.restoreItemId,
    this.restoreApproximateIndex,
  });

  final int pendingNewCount;
  final int? restoreItemId;
  final int? restoreApproximateIndex;

  bool get hasPendingNewItems => pendingNewCount > 0;

  FeedSurfaceUiState copyWith({
    int? pendingNewCount,
    int? restoreItemId,
    bool clearRestoreItemId = false,
    int? restoreApproximateIndex,
    bool clearRestoreApproximateIndex = false,
  }) {
    return FeedSurfaceUiState(
      pendingNewCount: pendingNewCount ?? this.pendingNewCount,
      restoreItemId:
          clearRestoreItemId ? null : (restoreItemId ?? this.restoreItemId),
      restoreApproximateIndex: clearRestoreApproximateIndex
          ? null
          : (restoreApproximateIndex ?? this.restoreApproximateIndex),
    );
  }
}

final feedSurfaceUiStateProvider =
    StateProvider.family<FeedSurfaceUiState, FeedSurface>(
  (ref, _) => const FeedSurfaceUiState(),
);

// ---------------------------------------------------------------------------
// Shared feed-seen state
// ---------------------------------------------------------------------------

/// Shared "last seen" cutoff across articles and videos.
final _feedLastSeenAtProvider = StateProvider<DateTime?>((ref) => null);

List<int> _headBaselineIds<T extends FeedEntry>(List<T> entries, int limit) {
  return entries.take(limit).map((entry) => entry.id).toList(growable: false);
}

int _countHeadNewItems(List<int> baselineIds, List<int> freshHeadIds) {
  if (baselineIds.isEmpty) return 0;
  final baseline = baselineIds.toSet();
  return freshHeadIds.where((id) => !baseline.contains(id)).length;
}

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
  ArticlesNotifier(
    this._repository,
    this._cache,
    this._sessionStore,
    this._ref,
  ) : super(const AsyncValue.loading()) {
    _loadInitial();
    _startPolling();
  }

  final FeedRepository _repository;
  final FeedCacheInterface _cache;
  final FeedSessionStore _sessionStore;
  final Ref _ref;
  final FeedSurface _surface = FeedSurface.articles;
  int _page = 1;
  bool _hasMore = true;
  FeedInventoryState _inventoryState = FeedInventoryState.warmingUp;
  bool _isLoadingMore = false;
  bool _isRefreshing = false;
  Future<bool>? _manualRefreshFuture;
  Timer? _pollTimer;
  static const int _limit = 15;
  static const Duration _pollInterval = Duration(seconds: 90);
  Set<int> _newSinceLastSeenIds = <int>{};
  List<int> _currentHeadBaselineIds = const <int>[];

  int? _currentItemId;
  bool _canContinueRemotely = true;

  FeedSurfaceUiState get _uiState =>
      _ref.read(feedSurfaceUiStateProvider(_surface));

  void _setUiState(FeedSurfaceUiState value) {
    _ref.read(feedSurfaceUiStateProvider(_surface).notifier).state = value;
  }

  void setCurrentViewPosition(int index, ArticleFeedEntry? entry) {
    _currentItemId = entry?.id;
    unawaited(_persistActiveSession());
  }

  Future<void> markExposed(int contentId) async {
    await _sessionStore.markExposed(_surface, contentId);
  }

  Future<void> markConsumed(int contentId) async {
    await _sessionStore.markConsumed(_surface, contentId);
  }

  void consumeRestoreTarget() {
    _setUiState(
      _uiState.copyWith(
        clearRestoreItemId: true,
        clearRestoreApproximateIndex: true,
      ),
    );
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

    final restore = await _sessionStore.prepareRestore(_surface);
    if (restore.resumeSnapshot != null) {
      _applyResumedSnapshot(restore.resumeSnapshot!);
      _markFeedSeenNowInBackground();
      unawaited(_refreshInBackground());
      return;
    }

    try {
      final cached = await _cache.getCachedArticles(limit: _limit);
      if (cached.isNotEmpty && mounted) {
        state = AsyncValue.data(cached);
        _updateNewSinceLastSeen(cached);
        _currentItemId = cached.firstOrNull?.id;
        _currentHeadBaselineIds = _headBaselineIds(cached, _limit);
        _page = 1;
        _hasMore = true;
        _inventoryState = FeedInventoryState.healthy;

        logger.info(
          'Articles cache HIT: ${cached.length} items',
          category: LogCategory.app,
        );

        _markFeedSeenNowInBackground();
        unawaited(
          _fetchFreshSessionFromNetwork(
            preserveVisibleState: true,
          ),
        );
        return;
      }
    } catch (e) {
      logger.warning('Failed to read articles cache',
          category: LogCategory.app, error: e);
    }

    logger.info('Articles cache MISS: fetching from network',
        category: LogCategory.app);
    await _fetchFreshSessionFromNetwork();
    _markFeedSeenNowInBackground();
  }

  Future<bool> _fetchFreshSessionFromNetwork({
    RequestMode requestMode = RequestMode.normal,
    bool preserveVisibleState = false,
  }) async {
    final previousState = state;
    try {
      if (!mounted) return false;
      if (!(preserveVisibleState && previousState.hasValue)) {
        state = const AsyncValue.loading();
      }

      final page = await _repository.fetchArticlesPage(
        page: 1,
        size: _limit,
        requestMode: requestMode,
      );
      if (!mounted) return false;
      final articles =
          page.items.whereType<ArticleFeedEntry>().toList(growable: false);
      _applyFreshArticles(
        articles,
        hasMore: page.hasMore,
        inventoryState: page.inventoryState,
      );
      _cacheInBackground(articles);
      await _persistActiveSession(
        pendingNewCount: 0,
      );
      return true;
    } catch (e, st) {
      if (!mounted) return false;
      if (preserveVisibleState && previousState.hasValue) {
        state = previousState;
      } else {
        state = AsyncValue.error(e, st);
      }
      logger.warning('Failed to load articles',
          category: LogCategory.network, error: e, stackTrace: st);
      return false;
    }
  }

  Future<void> _refreshInBackground() async {
    if (_isRefreshing || _manualRefreshFuture != null) return;
    _isRefreshing = true;

    try {
      final freshPage = await _repository.previewArticlesHead(size: _limit);
      final freshItems =
          freshPage.items.whereType<ArticleFeedEntry>().toList(growable: false);
      if (!mounted) return;
      if (freshItems.isNotEmpty) {
        _cacheInBackground(freshItems);
      }

      final freshHeadIds = _headBaselineIds(freshItems, _limit);
      final baseline = _currentHeadBaselineIds;
      final pendingNewCount =
          freshHeadIds.isEmpty ? 0 : _countHeadNewItems(baseline, freshHeadIds);
      _setUiState(
        _uiState.copyWith(
          pendingNewCount: pendingNewCount,
        ),
      );
      await _persistActiveSession(
        pendingNewCount: pendingNewCount,
      );
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
      final nextPage = _canContinueRemotely
          ? await _repository.fetchArticlesPage(page: _page + 1, size: _limit)
          : await _startFreshContinuationAfterExpiry(currentList);
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
        await _persistActiveSession();
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
  Future<bool> manualRefresh() {
    final inFlight = _manualRefreshFuture;
    if (inFlight != null) return inFlight;

    final future = _runManualRefresh();
    _manualRefreshFuture = future;
    future.whenComplete(() {
      if (identical(_manualRefreshFuture, future)) {
        _manualRefreshFuture = null;
      }
    });
    return future;
  }

  Future<bool> _runManualRefresh() async {
    try {
      _currentItemId = null;
      _setUiState(
        _uiState.copyWith(
          pendingNewCount: 0,
          clearRestoreItemId: true,
          clearRestoreApproximateIndex: true,
        ),
      );
      return await _fetchFreshSessionFromNetwork(
        requestMode: RequestMode.manualRefresh,
        preserveVisibleState: true,
      );
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

  void _applyResumedSnapshot(FeedSessionSnapshot snapshot) {
    final articles =
        snapshot.items.whereType<ArticleFeedEntry>().toList(growable: false);
    _page = ((articles.length - 1) ~/ _limit) + 1;
    _hasMore = snapshot.hasMore;
    _inventoryState = snapshot.inventoryState;
    _currentHeadBaselineIds = snapshot.headBaselineIds.isNotEmpty
        ? snapshot.headBaselineIds
        : _headBaselineIds(articles, _limit);
    _currentItemId = snapshot.currentItemId ?? articles.firstOrNull?.id;
    _canContinueRemotely =
        _sessionStore.isRemoteContinuationFresh(_surface, snapshot);
    if (_canContinueRemotely) {
      _repository.restoreArticleSession(
        sessionId: snapshot.sessionId,
        cursor: int.tryParse(snapshot.continuationCursor ?? ''),
      );
    } else {
      _repository.restoreArticleSession(sessionId: null, cursor: null);
    }
    state = AsyncValue.data(articles);
    _updateNewSinceLastSeen(articles);
    _setUiState(
      _uiState.copyWith(
        pendingNewCount: snapshot.pendingNewCount,
        restoreItemId: snapshot.currentItemId,
        restoreApproximateIndex:
            _restoreApproximateIndex(snapshot.currentItemId, articles),
      ),
    );
  }

  void _applyFreshArticles(
    List<ArticleFeedEntry> articles, {
    required bool hasMore,
    required FeedInventoryState inventoryState,
  }) {
    _page = 1;
    _hasMore = hasMore;
    _inventoryState = inventoryState;
    _currentItemId = articles.firstOrNull?.id;
    _currentHeadBaselineIds = _headBaselineIds(articles, _limit);
    _canContinueRemotely = true;
    state = AsyncValue.data(articles);
    _updateNewSinceLastSeen(articles);
    _setUiState(
      _uiState.copyWith(
        pendingNewCount: 0,
      ),
    );
  }

  int _restoreApproximateIndex(
    int? itemId,
    List<ArticleFeedEntry> entries,
  ) {
    if (entries.isEmpty) return 0;
    if (itemId == null) return 0;
    final index = entries.indexWhere((entry) => entry.id == itemId);
    return index < 0 ? 0 : index;
  }

  Future<FeedPageResult<FeedEntry>> _startFreshContinuationAfterExpiry(
    List<ArticleFeedEntry> currentList,
  ) async {
    final existingIds = currentList.map((entry) => entry.id).toSet();
    var result = await _repository.fetchArticlesPage(page: 1, size: _limit);
    var collected = result.items.whereType<ArticleFeedEntry>().where((entry) {
      return !existingIds.contains(entry.id);
    }).toList(growable: true);

    var pageCount = 1;
    while (collected.isEmpty && result.hasMore && pageCount < 3) {
      pageCount += 1;
      result =
          await _repository.fetchArticlesPage(page: pageCount, size: _limit);
      collected.addAll(
        result.items
            .whereType<ArticleFeedEntry>()
            .where((entry) => !existingIds.contains(entry.id)),
      );
    }

    _canContinueRemotely = true;
    _page = pageCount;
    return FeedPageResult<FeedEntry>(
      items: collected,
      hasMore: result.hasMore,
      inventoryState: result.inventoryState,
      sessionId: result.sessionId,
    );
  }

  Future<void> _persistActiveSession({int? pendingNewCount}) async {
    final items = state.valueOrNull;
    if (items == null || items.isEmpty) return;
    final currentItemId = _currentItemId ?? items.first.id;
    final baseline = _currentHeadBaselineIds.isNotEmpty
        ? _currentHeadBaselineIds
        : _headBaselineIds(items, _limit);
    _currentHeadBaselineIds = baseline;
    await _sessionStore.saveActiveSession(
      FeedSessionSnapshot(
        surface: _surface,
        items: items,
        currentItemId: currentItemId,
        lastActiveAt: DateTime.now().toUtc(),
        headBaselineIds: baseline,
        sessionId: _canContinueRemotely ? _repository.articleSessionId : null,
        continuationCursor:
            _canContinueRemotely ? _repository.articleCursor?.toString() : null,
        hasMore: _hasMore,
        inventoryState: _inventoryState,
        pendingNewCount: pendingNewCount ?? _uiState.pendingNewCount,
      ),
    );
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
  VideosNotifier(
    this._repository,
    this._cache,
    this._sessionStore,
    this._ref,
  ) : super(const AsyncValue.loading()) {
    _loadInitial();
    // Stagger: videos start polling after a 45-second initial delay.
    _startPollingWithDelay(const Duration(seconds: 45));
  }

  final FeedRepository _repository;
  final FeedCacheInterface _cache;
  final FeedSessionStore _sessionStore;
  final Ref _ref;
  final FeedSurface _surface = FeedSurface.videos;
  int _page = 1;
  bool _hasMore = true;
  FeedInventoryState _inventoryState = FeedInventoryState.warmingUp;
  bool _isLoadingMore = false;
  bool _isRefreshing = false;
  Future<bool>? _manualRefreshFuture;
  Timer? _pollTimer;
  Timer? _initialDelayTimer;
  static const int _limit = 10;
  static const Duration _pollInterval = Duration(seconds: 90);
  Set<int> _newSinceLastSeenIds = <int>{};
  List<int> _currentHeadBaselineIds = const <int>[];

  int? _currentItemId;
  bool _canContinueRemotely = true;

  FeedSurfaceUiState get _uiState =>
      _ref.read(feedSurfaceUiStateProvider(_surface));

  void _setUiState(FeedSurfaceUiState value) {
    _ref.read(feedSurfaceUiStateProvider(_surface).notifier).state = value;
  }

  void setCurrentViewPosition(int index, VideoFeedEntry? entry) {
    _currentItemId = entry?.id;
    unawaited(_persistActiveSession());
  }

  Future<void> markExposed(int contentId) async {
    await _sessionStore.markExposed(_surface, contentId);
  }

  Future<void> markConsumed(int contentId) async {
    await _sessionStore.markConsumed(_surface, contentId);
  }

  void consumeRestoreTarget() {
    _setUiState(
      _uiState.copyWith(
        clearRestoreItemId: true,
        clearRestoreApproximateIndex: true,
      ),
    );
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

    final restore = await _sessionStore.prepareRestore(_surface);
    if (restore.resumeSnapshot != null) {
      _applyResumedSnapshot(restore.resumeSnapshot!);
      unawaited(_refreshInBackground());
      return;
    }

    try {
      final cached = await _cache.getCachedVideos(limit: _limit);
      if (cached.isNotEmpty && mounted) {
        state = AsyncValue.data(cached);
        _updateNewSinceLastSeen(cached);
        _currentItemId = cached.isEmpty ? null : cached.first.id;
        _currentHeadBaselineIds = _headBaselineIds(cached, _limit);
        _page = 1;
        _hasMore = true;
        _inventoryState = FeedInventoryState.healthy;

        logger.info(
          'Videos cache HIT: ${cached.length} items',
          category: LogCategory.app,
        );

        unawaited(
          _fetchFreshSessionFromNetwork(
            preserveVisibleState: true,
          ),
        );
        return;
      }
    } catch (e) {
      logger.warning('Failed to read videos cache',
          category: LogCategory.app, error: e);
    }

    logger.info('Videos cache MISS: fetching from network',
        category: LogCategory.app);
    await _fetchFreshSessionFromNetwork();
  }

  Future<bool> _fetchFreshSessionFromNetwork({
    RequestMode requestMode = RequestMode.normal,
    bool preserveVisibleState = false,
  }) async {
    final previousState = state;
    try {
      if (!mounted) return false;
      if (!(preserveVisibleState && previousState.hasValue)) {
        state = const AsyncValue.loading();
      }

      final page = await _repository.fetchVideosPage(
        page: 1,
        size: _limit,
        requestMode: requestMode,
      );
      if (!mounted) return false;
      final videos =
          page.items.whereType<VideoFeedEntry>().toList(growable: false);
      _applyFreshVideos(
        videos,
        hasMore: page.hasMore,
        inventoryState: page.inventoryState,
      );
      _replaceCacheSnapshotInBackground(videos);
      await _persistActiveSession(
        pendingNewCount: 0,
      );
      return true;
    } catch (e, st) {
      if (!mounted) return false;
      if (preserveVisibleState && previousState.hasValue) {
        state = previousState;
      } else {
        state = AsyncValue.error(e, st);
      }
      logger.warning('Failed to load videos',
          category: LogCategory.network, error: e, stackTrace: st);
      return false;
    }
  }

  Future<void> _refreshInBackground() async {
    if (_isRefreshing || _manualRefreshFuture != null) return;
    _isRefreshing = true;

    try {
      final freshPage = await _repository.previewVideosHead(size: _limit);
      final freshItems =
          freshPage.items.whereType<VideoFeedEntry>().toList(growable: false);
      if (!mounted) return;

      if (freshItems.isNotEmpty) {
        _replaceCacheSnapshotInBackground(freshItems);
      }

      final freshHeadIds = _headBaselineIds(freshItems, _limit);
      final pendingNewCount = freshHeadIds.isEmpty
          ? 0
          : _countHeadNewItems(_currentHeadBaselineIds, freshHeadIds);
      _setUiState(
        _uiState.copyWith(
          pendingNewCount: pendingNewCount,
        ),
      );
      await _persistActiveSession(
        pendingNewCount: pendingNewCount,
      );
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
      final nextPage = _canContinueRemotely
          ? await _repository.fetchVideosPage(page: _page + 1, size: _limit)
          : await _startFreshContinuationAfterExpiry(currentList);
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
        await _persistActiveSession();
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
  Future<bool> manualRefresh() {
    final inFlight = _manualRefreshFuture;
    if (inFlight != null) return inFlight;

    final future = _runManualRefresh();
    _manualRefreshFuture = future;
    future.whenComplete(() {
      if (identical(_manualRefreshFuture, future)) {
        _manualRefreshFuture = null;
      }
    });
    return future;
  }

  Future<bool> _runManualRefresh() async {
    try {
      _currentItemId = null;
      _setUiState(
        _uiState.copyWith(
          pendingNewCount: 0,
          clearRestoreItemId: true,
          clearRestoreApproximateIndex: true,
        ),
      );
      return await _fetchFreshSessionFromNetwork(
        requestMode: RequestMode.manualRefresh,
        preserveVisibleState: true,
      );
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

  void _applyResumedSnapshot(FeedSessionSnapshot snapshot) {
    final videos =
        snapshot.items.whereType<VideoFeedEntry>().toList(growable: false);
    _page = ((videos.length - 1) ~/ _limit) + 1;
    _hasMore = snapshot.hasMore;
    _inventoryState = snapshot.inventoryState;
    _currentHeadBaselineIds = snapshot.headBaselineIds.isNotEmpty
        ? snapshot.headBaselineIds
        : _headBaselineIds(videos, _limit);
    _currentItemId =
        snapshot.currentItemId ?? (videos.isEmpty ? null : videos.first.id);
    _canContinueRemotely =
        _sessionStore.isRemoteContinuationFresh(_surface, snapshot);
    if (_canContinueRemotely) {
      _repository.restoreVideoSession(
        sessionId: snapshot.sessionId,
        cursor: int.tryParse(snapshot.continuationCursor ?? ''),
      );
    } else {
      _repository.restoreVideoSession(sessionId: null, cursor: null);
    }
    state = AsyncValue.data(videos);
    _updateNewSinceLastSeen(videos);
    _setUiState(
      _uiState.copyWith(
        pendingNewCount: snapshot.pendingNewCount,
        restoreItemId: snapshot.currentItemId,
        restoreApproximateIndex:
            _restoreApproximateIndex(snapshot.currentItemId, videos),
      ),
    );
  }

  void _applyFreshVideos(
    List<VideoFeedEntry> videos, {
    required bool hasMore,
    required FeedInventoryState inventoryState,
  }) {
    _page = 1;
    _hasMore = hasMore;
    _inventoryState = inventoryState;
    _currentItemId = videos.isEmpty ? null : videos.first.id;
    _currentHeadBaselineIds = _headBaselineIds(videos, _limit);
    _canContinueRemotely = true;
    state = AsyncValue.data(videos);
    _updateNewSinceLastSeen(videos);
    _setUiState(
      _uiState.copyWith(
        pendingNewCount: 0,
      ),
    );
  }

  int _restoreApproximateIndex(
    int? itemId,
    List<VideoFeedEntry> entries,
  ) {
    if (entries.isEmpty) return 0;
    if (itemId == null) return 0;
    final index = entries.indexWhere((entry) => entry.id == itemId);
    return index < 0 ? 0 : index;
  }

  Future<FeedPageResult<FeedEntry>> _startFreshContinuationAfterExpiry(
    List<VideoFeedEntry> currentList,
  ) async {
    final existingIds = currentList.map((entry) => entry.id).toSet();
    var result = await _repository.fetchVideosPage(page: 1, size: _limit);
    var collected = result.items.whereType<VideoFeedEntry>().where((entry) {
      return !existingIds.contains(entry.id);
    }).toList(growable: true);

    var pageCount = 1;
    while (collected.isEmpty && result.hasMore && pageCount < 3) {
      pageCount += 1;
      result = await _repository.fetchVideosPage(page: pageCount, size: _limit);
      collected.addAll(
        result.items
            .whereType<VideoFeedEntry>()
            .where((entry) => !existingIds.contains(entry.id)),
      );
    }

    _canContinueRemotely = true;
    _page = pageCount;
    return FeedPageResult<FeedEntry>(
      items: collected,
      hasMore: result.hasMore,
      inventoryState: result.inventoryState,
      sessionId: result.sessionId,
    );
  }

  Future<void> _persistActiveSession({int? pendingNewCount}) async {
    final items = state.valueOrNull;
    if (items == null || items.isEmpty) return;
    final currentItemId = _currentItemId ?? items.first.id;
    final baseline = _currentHeadBaselineIds.isNotEmpty
        ? _currentHeadBaselineIds
        : _headBaselineIds(items, _limit);
    _currentHeadBaselineIds = baseline;
    await _sessionStore.saveActiveSession(
      FeedSessionSnapshot(
        surface: _surface,
        items: items,
        currentItemId: currentItemId,
        lastActiveAt: DateTime.now().toUtc(),
        headBaselineIds: baseline,
        sessionId: _canContinueRemotely ? _repository.videoSessionId : null,
        continuationCursor:
            _canContinueRemotely ? _repository.videoCursor?.toString() : null,
        hasMore: _hasMore,
        inventoryState: _inventoryState,
        pendingNewCount: pendingNewCount ?? _uiState.pendingNewCount,
      ),
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
    ref.watch(feedSessionStoreProvider),
    ref,
  ),
);

/// Loads the videos feed.
final videosFeedProvider = StateNotifierProvider.autoDispose<VideosNotifier,
    AsyncValue<List<VideoFeedEntry>>>(
  (ref) => VideosNotifier(
    ref.watch(feedRepositoryProvider),
    ref.watch(feedCacheProvider),
    ref.watch(feedSessionStoreProvider),
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
  ReelsNotifier(
    this._repository,
    this._cache,
    this._sessionStore,
    this._ref,
  ) : super(const AsyncValue.loading()) {
    loadInitial();
    _startPolling();
  }

  final FeedRepository _repository;
  final FeedCacheInterface _cache;
  final FeedSessionStore _sessionStore;
  final Ref _ref;
  final FeedSurface _surface = FeedSurface.reels;
  bool _hasMore = true;
  String? _nextCursor;
  FeedInventoryState _inventoryState = FeedInventoryState.warmingUp;
  bool _isLoadingMore = false;
  bool _isRefreshing = false;
  Future<bool>? _manualRefreshFuture;
  Timer? _pollTimer;
  static const int _limit = 20;
  static const Duration _pollInterval = Duration(seconds: 60);
  List<int> _currentHeadBaselineIds = const <int>[];
  int? _currentItemId;

  FeedSurfaceUiState get _uiState =>
      _ref.read(feedSurfaceUiStateProvider(_surface));

  void _setUiState(FeedSurfaceUiState value) {
    _ref.read(feedSurfaceUiStateProvider(_surface).notifier).state = value;
  }

  void setCurrentViewPosition(int index, ReelFeedEntry? entry) {
    _currentItemId = entry?.id;
    unawaited(_persistActiveSession());
  }

  Future<void> markExposed(int contentId) async {
    await _sessionStore.markExposed(_surface, contentId);
  }

  Future<void> markConsumed(int contentId) async {
    await _sessionStore.markConsumed(_surface, contentId);
  }

  void consumeRestoreTarget() {
    _setUiState(
      _uiState.copyWith(
        clearRestoreItemId: true,
        clearRestoreApproximateIndex: true,
      ),
    );
  }

  bool get hasMore => _hasMore;

  FeedInventoryState get inventoryState => _inventoryState;

  bool get isCaughtUp => _inventoryState == FeedInventoryState.caughtUp;

  Future<void> loadInitial() async {
    if (!mounted) return;

    final restore = await _sessionStore.prepareRestore(_surface);
    if (restore.resumeSnapshot != null) {
      _applyResumedSnapshot(restore.resumeSnapshot!);
      unawaited(_refreshInBackground());
      return;
    }

    // Try to show cached data first
    try {
      final cached = await _cache.getCachedReels(limit: _limit);

      if (cached.isNotEmpty && mounted) {
        state = AsyncValue.data(cached);
        _hasMore = true;
        _nextCursor = null;
        _inventoryState = FeedInventoryState.healthy;
        _currentItemId = cached.isEmpty ? null : cached.first.id;
        _currentHeadBaselineIds = _headBaselineIds(cached, _limit);

        logger.info(
          'Reels cache HIT: ${cached.length} items served from cache',
          category: LogCategory.app,
        );

        unawaited(
          _fetchFreshSessionFromNetwork(
            preserveVisibleState: true,
          ),
        );
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

    await _fetchFreshSessionFromNetwork();
  }

  Future<bool> _fetchFreshSessionFromNetwork({
    RequestMode requestMode = RequestMode.normal,
    bool preserveVisibleState = false,
  }) async {
    final previousState = state;
    try {
      if (!mounted) return false;
      if (!(preserveVisibleState && previousState.hasValue)) {
        state = const AsyncValue.loading();
      }
      final page = await _repository.fetchReelsPage(
        limit: _limit,
        requestMode: requestMode,
      );
      if (!mounted) return false;
      _applyFreshReels(
        page.items,
        hasMore: page.hasMore,
        nextCursor: page.nextCursor,
        inventoryState: page.inventoryState,
      );
      _replaceCacheSnapshotInBackground(page.items);
      await _persistActiveSession(
        pendingNewCount: 0,
      );
      return true;
    } catch (e, st) {
      if (!mounted) return false;
      if (preserveVisibleState && previousState.hasValue) {
        state = previousState;
      } else {
        state = AsyncValue.error(e, st);
      }
      logger.warning(
        'Failed to load reels',
        category: LogCategory.network,
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  Future<void> _refreshInBackground() async {
    if (_isRefreshing || _manualRefreshFuture != null) return;
    _isRefreshing = true;

    try {
      final freshPage = await _repository.previewReelsHead(limit: _limit);
      final freshReels = freshPage.items;
      if (!mounted) return;
      if (freshReels.isNotEmpty) {
        _replaceCacheSnapshotInBackground(freshReels);
      }
      final freshHeadIds = _headBaselineIds(freshReels, _limit);
      final pendingNewCount = freshHeadIds.isEmpty
          ? 0
          : _countHeadNewItems(_currentHeadBaselineIds, freshHeadIds);
      _setUiState(
        _uiState.copyWith(
          pendingNewCount: pendingNewCount,
        ),
      );
      await _persistActiveSession(
        pendingNewCount: pendingNewCount,
      );
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
        await _persistActiveSession();
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
  Future<bool> manualRefresh() {
    final inFlight = _manualRefreshFuture;
    if (inFlight != null) return inFlight;

    final future = _runManualRefresh();
    _manualRefreshFuture = future;
    future.whenComplete(() {
      if (identical(_manualRefreshFuture, future)) {
        _manualRefreshFuture = null;
      }
    });
    return future;
  }

  Future<bool> _runManualRefresh() async {
    try {
      _currentItemId = null;
      _setUiState(
        _uiState.copyWith(
          pendingNewCount: 0,
          clearRestoreItemId: true,
          clearRestoreApproximateIndex: true,
        ),
      );
      return await _fetchFreshSessionFromNetwork(
        requestMode: RequestMode.manualRefresh,
        preserveVisibleState: true,
      );
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

  void _applyResumedSnapshot(FeedSessionSnapshot snapshot) {
    final reels =
        snapshot.items.whereType<ReelFeedEntry>().toList(growable: false);
    _hasMore = snapshot.hasMore;
    _nextCursor = snapshot.continuationCursor;
    _inventoryState = snapshot.inventoryState;
    _currentHeadBaselineIds = snapshot.headBaselineIds.isNotEmpty
        ? snapshot.headBaselineIds
        : _headBaselineIds(reels, _limit);
    _currentItemId =
        snapshot.currentItemId ?? (reels.isEmpty ? null : reels.first.id);
    _repository.restoreReelsCursor(snapshot.continuationCursor);
    state = AsyncValue.data(reels);
    _setUiState(
      _uiState.copyWith(
        pendingNewCount: snapshot.pendingNewCount,
        restoreItemId: snapshot.currentItemId,
        restoreApproximateIndex:
            _restoreApproximateIndex(snapshot.currentItemId, reels),
      ),
    );
  }

  void _applyFreshReels(
    List<ReelFeedEntry> reels, {
    required bool hasMore,
    required String? nextCursor,
    required FeedInventoryState inventoryState,
  }) {
    _hasMore = hasMore;
    _nextCursor = nextCursor;
    _inventoryState = inventoryState;
    _currentItemId = reels.isEmpty ? null : reels.first.id;
    _currentHeadBaselineIds = _headBaselineIds(reels, _limit);
    state = AsyncValue.data(reels);
    _setUiState(
      _uiState.copyWith(
        pendingNewCount: 0,
      ),
    );
  }

  int _restoreApproximateIndex(
    int? itemId,
    List<ReelFeedEntry> entries,
  ) {
    if (entries.isEmpty) return 0;
    if (itemId == null) return 0;
    final index = entries.indexWhere((entry) => entry.id == itemId);
    return index < 0 ? 0 : index;
  }

  Future<void> _persistActiveSession({int? pendingNewCount}) async {
    final items = state.valueOrNull;
    if (items == null || items.isEmpty) return;
    final currentItemId = _currentItemId ?? items.first.id;
    final baseline = _currentHeadBaselineIds.isNotEmpty
        ? _currentHeadBaselineIds
        : _headBaselineIds(items, _limit);
    _currentHeadBaselineIds = baseline;
    await _sessionStore.saveActiveSession(
      FeedSessionSnapshot(
        surface: _surface,
        items: items,
        currentItemId: currentItemId,
        lastActiveAt: DateTime.now().toUtc(),
        headBaselineIds: baseline,
        continuationCursor: _nextCursor,
        hasMore: _hasMore,
        inventoryState: _inventoryState,
        pendingNewCount: pendingNewCount ?? _uiState.pendingNewCount,
      ),
    );
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
    ref.watch(feedSessionStoreProvider),
    ref,
  ),
);
