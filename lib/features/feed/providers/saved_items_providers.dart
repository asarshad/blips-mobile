import 'dart:async';

import 'package:blips_mobile/core/error/error.dart';
import 'package:blips_mobile/features/feed/data/feed_cache_interface.dart';
import 'package:blips_mobile/features/feed/data/feed_repository.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:blips_mobile/features/feed/domain/saved_item.dart';
import 'package:blips_mobile/features/feed/providers/feed_providers.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

enum SavedItemsSegment {
  articles,
  videos;
}

class SavedArticlesNotifier
    extends StateNotifier<AsyncValue<List<SavedArticleItem>>> {
  SavedArticlesNotifier(this._cache, this._repository)
      : super(const AsyncValue.loading()) {
    _load();
  }

  final FeedCacheInterface _cache;
  final FeedRepository _repository;

  Future<void> _load() async {
    try {
      final items = await _cache.getSavedArticles();
      if (!mounted) return;
      state = AsyncValue.data(items);
    } catch (error, stackTrace) {
      logger.warning(
        'Failed to load saved articles',
        category: LogCategory.app,
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> toggle(ArticleFeedEntry entry) async {
    final saved = _isSaved(entry.id);
    if (saved) {
      await remove(entry.id);
      return;
    }
    await save(entry);
  }

  Future<void> save(ArticleFeedEntry entry) async {
    final item = SavedArticleItem.fromFeedEntry(entry);
    final previous = state.valueOrNull ?? const <SavedArticleItem>[];
    final next = [
      item,
      ...previous.where((saved) => saved.contentId != entry.id),
    ]..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    state = AsyncValue.data(next);
    try {
      await _cache.saveArticleBookmark(item);
    } catch (error, stackTrace) {
      logger.warning(
        'Failed to persist saved article',
        category: LogCategory.app,
        error: error,
        stackTrace: stackTrace,
      );
      state = AsyncValue.data(previous);
      return;
    }
    unawaited(_recordSaveSignal(entry.id));
  }

  Future<void> remove(int contentId) async {
    final previous = state.valueOrNull ?? const <SavedArticleItem>[];
    final next = previous.where((item) => item.contentId != contentId).toList();
    state = AsyncValue.data(next);
    try {
      await _cache.removeSavedArticleBookmark(contentId);
    } catch (error, stackTrace) {
      logger.warning(
        'Failed to remove saved article',
        category: LogCategory.app,
        error: error,
        stackTrace: stackTrace,
      );
      state = AsyncValue.data(previous);
    }
  }

  bool _isSaved(int contentId) {
    return (state.valueOrNull ?? const <SavedArticleItem>[])
        .any((item) => item.contentId == contentId);
  }

  Future<void> _recordSaveSignal(int contentId) async {
    try {
      await _repository.recordInteraction(
        contentItemId: contentId,
        eventType: FeedInteractionEvent.save,
        extraData: const {'surface': 'articles'},
      );
    } catch (error, stackTrace) {
      logger.warning(
        'Failed to record article save signal',
        category: LogCategory.network,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}

class SavedVideosNotifier
    extends StateNotifier<AsyncValue<List<SavedVideoItem>>> {
  SavedVideosNotifier(this._cache, this._repository)
      : super(const AsyncValue.loading()) {
    _load();
  }

  final FeedCacheInterface _cache;
  final FeedRepository _repository;

  Future<void> _load() async {
    try {
      final items = await _cache.getSavedVideos();
      if (!mounted) return;
      state = AsyncValue.data(items);
    } catch (error, stackTrace) {
      logger.warning(
        'Failed to load saved videos',
        category: LogCategory.app,
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> toggle(VideoFeedEntry entry) async {
    final saved = _isSaved(entry.id);
    if (saved) {
      await remove(entry.id);
      return;
    }
    await save(entry);
  }

  Future<void> save(VideoFeedEntry entry) async {
    await _saveItem(
      SavedVideoItem.fromFeedEntry(entry),
      source: entry.source,
      surface: 'videos',
    );
  }

  Future<void> toggleReel(ReelFeedEntry entry) async {
    final saved = _isSaved(entry.id);
    if (saved) {
      await remove(entry.id);
      return;
    }
    await saveReel(entry);
  }

  Future<void> saveReel(ReelFeedEntry entry) async {
    await _saveItem(
      SavedVideoItem.fromReelEntry(entry),
      source: entry.source,
      surface: 'reels',
    );
  }

  Future<void> remove(int contentId) async {
    final previous = state.valueOrNull ?? const <SavedVideoItem>[];
    final next = previous.where((item) => item.contentId != contentId).toList();
    state = AsyncValue.data(next);
    try {
      await _cache.removeSavedVideoBookmark(contentId);
    } catch (error, stackTrace) {
      logger.warning(
        'Failed to remove saved video',
        category: LogCategory.app,
        error: error,
        stackTrace: stackTrace,
      );
      state = AsyncValue.data(previous);
    }
  }

  bool _isSaved(int contentId) {
    return (state.valueOrNull ?? const <SavedVideoItem>[])
        .any((item) => item.contentId == contentId);
  }

  Future<void> _saveItem(
    SavedVideoItem item, {
    required String source,
    required String surface,
  }) async {
    final previous = state.valueOrNull ?? const <SavedVideoItem>[];
    final next = [
      item,
      ...previous.where((saved) => saved.contentId != item.contentId),
    ]..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    state = AsyncValue.data(next);
    try {
      await _cache.saveVideoBookmark(item);
    } catch (error, stackTrace) {
      logger.warning(
        'Failed to persist saved video',
        category: LogCategory.app,
        error: error,
        stackTrace: stackTrace,
      );
      state = AsyncValue.data(previous);
      return;
    }
    unawaited(
      _recordSaveSignal(
        item.contentId,
        source: source,
        surface: surface,
      ),
    );
  }

  Future<void> _recordSaveSignal(
    int contentId, {
    required String source,
    required String surface,
  }) async {
    try {
      await _repository.recordInteraction(
        contentItemId: contentId,
        eventType: FeedInteractionEvent.videoSave,
        extraData: {
          'surface': surface,
          'source': source,
        },
      );
    } catch (error, stackTrace) {
      logger.warning(
        'Failed to record video save signal',
        category: LogCategory.network,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}

final savedArticlesProvider = StateNotifierProvider<SavedArticlesNotifier,
    AsyncValue<List<SavedArticleItem>>>((ref) {
  return SavedArticlesNotifier(
    ref.watch(feedCacheProvider),
    ref.watch(feedRepositoryProvider),
  );
});

final savedVideosProvider = StateNotifierProvider<SavedVideosNotifier,
    AsyncValue<List<SavedVideoItem>>>((ref) {
  return SavedVideosNotifier(
    ref.watch(feedCacheProvider),
    ref.watch(feedRepositoryProvider),
  );
});

final savedArticleIdsProvider = Provider<Set<int>>((ref) {
  final items = ref.watch(savedArticlesProvider).valueOrNull ??
      const <SavedArticleItem>[];
  return items.map((item) => item.contentId).toSet();
});

final savedVideoIdsProvider = Provider<Set<int>>((ref) {
  final items =
      ref.watch(savedVideosProvider).valueOrNull ?? const <SavedVideoItem>[];
  return items.map((item) => item.contentId).toSet();
});

final savedItemsSegmentProvider =
    StateProvider<SavedItemsSegment>((ref) => SavedItemsSegment.articles);
