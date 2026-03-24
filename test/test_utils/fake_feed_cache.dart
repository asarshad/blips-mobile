import 'package:blips_mobile/features/feed/data/feed_cache_interface.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:blips_mobile/features/feed/domain/saved_item.dart';

/// In-memory fake cache for tests.
final class FakeFeedCache implements FeedCacheInterface {
  List<FeedEntry> _feed = const [];
  List<ReelFeedEntry> _reels = const [];
  List<SavedArticleItem> _savedArticles = const [];
  List<SavedVideoItem> _savedVideos = const [];
  DateTime? _feedLastSeenAt;
  final Map<String, String> _meta = <String, String>{};

  @override
  Future<void> cacheFeed(List<FeedEntry> entries) async {
    _feed = List<FeedEntry>.from(entries);
  }

  @override
  Future<DateTime?> getFeedLastSeenAt() async => _feedLastSeenAt;

  @override
  Future<List<FeedEntry>> getCachedFeed({
    int articleLimit = 15,
    int videoLimit = 10,
  }) async {
    return List<FeedEntry>.from(_feed);
  }

  @override
  Future<List<ArticleFeedEntry>> getCachedArticles({int limit = 50}) async {
    return _feed.whereType<ArticleFeedEntry>().take(limit).toList();
  }

  @override
  Future<void> cacheArticles(List<ArticleFeedEntry> articles) async {
    _feed = [
      ...articles,
      ..._feed.whereType<VideoFeedEntry>(),
    ];
  }

  @override
  Future<List<VideoFeedEntry>> getCachedVideos({int limit = 30}) async {
    return _feed.whereType<VideoFeedEntry>().take(limit).toList();
  }

  @override
  Future<void> cacheVideos(List<VideoFeedEntry> videos) async {
    _feed = [
      ..._feed.whereType<ArticleFeedEntry>(),
      ...videos,
    ];
  }

  @override
  Future<void> replaceVideosSnapshot(List<VideoFeedEntry> videos) async {
    _feed = [
      ..._feed.whereType<ArticleFeedEntry>(),
      ...videos,
    ];
  }

  @override
  Future<void> cacheReels(List<ReelFeedEntry> reels) async {
    _reels = List<ReelFeedEntry>.from(reels);
  }

  @override
  Future<void> replaceReelsSnapshot(List<ReelFeedEntry> reels) async {
    _reels = List<ReelFeedEntry>.from(reels);
  }

  @override
  Future<void> setFeedLastSeenAt(DateTime lastSeenAt) async {
    _feedLastSeenAt = lastSeenAt;
  }

  @override
  Future<List<ReelFeedEntry>> getCachedReels({int limit = 50}) async {
    return List<ReelFeedEntry>.from(_reels);
  }

  @override
  Future<String?> getMeta(String key) async => _meta[key];

  @override
  Future<void> setMeta(String key, String value) async {
    _meta[key] = value;
  }

  @override
  Future<void> deleteMeta(String key) async {
    _meta.remove(key);
  }

  @override
  Future<List<SavedArticleItem>> getSavedArticles() async {
    return List<SavedArticleItem>.from(_savedArticles);
  }

  @override
  Future<void> saveArticleBookmark(SavedArticleItem article) async {
    _savedArticles = [
      article,
      ..._savedArticles.where((item) => item.contentId != article.contentId),
    ]..sort((a, b) => b.savedAt.compareTo(a.savedAt));
  }

  @override
  Future<void> removeSavedArticleBookmark(int contentId) async {
    _savedArticles =
        _savedArticles.where((item) => item.contentId != contentId).toList();
  }

  @override
  Future<List<SavedVideoItem>> getSavedVideos() async {
    return List<SavedVideoItem>.from(_savedVideos);
  }

  @override
  Future<void> saveVideoBookmark(SavedVideoItem video) async {
    _savedVideos = [
      video,
      ..._savedVideos.where((item) => item.contentId != video.contentId),
    ]..sort((a, b) => b.savedAt.compareTo(a.savedAt));
  }

  @override
  Future<void> removeSavedVideoBookmark(int contentId) async {
    _savedVideos =
        _savedVideos.where((item) => item.contentId != contentId).toList();
  }
}
