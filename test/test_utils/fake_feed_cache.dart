import 'package:blips_mobile/features/feed/data/feed_cache_interface.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';

/// In-memory fake cache for tests.
final class FakeFeedCache implements FeedCacheInterface {
  List<FeedEntry> _feed = const [];
  List<ReelFeedEntry> _reels = const [];
  DateTime? _feedLastSeenAt;

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
  Future<void> cacheReels(List<ReelFeedEntry> reels) async {
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
}
