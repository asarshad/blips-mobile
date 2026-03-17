import 'package:blips_mobile/features/feed/domain/feed_entry.dart';

/// Cache abstraction so unit/widget tests can run without SQLite.
abstract interface class FeedCacheInterface {
  Future<List<FeedEntry>> getCachedFeed({
    int articleLimit = 15,
    int videoLimit = 10,
  });

  Future<void> cacheFeed(List<FeedEntry> entries);

  Future<List<ArticleFeedEntry>> getCachedArticles({int limit = 50});

  Future<void> cacheArticles(List<ArticleFeedEntry> articles);

  Future<List<VideoFeedEntry>> getCachedVideos({int limit = 30});

  Future<void> cacheVideos(List<VideoFeedEntry> videos);

  /// Replaces the persisted page-1 videos snapshot.
  Future<void> replaceVideosSnapshot(List<VideoFeedEntry> videos);

  /// Last timestamp when the user viewed the main feed.
  Future<DateTime?> getFeedLastSeenAt();

  /// Persist the timestamp for "new since last seen" UX.
  Future<void> setFeedLastSeenAt(DateTime lastSeenAt);

  Future<List<ReelFeedEntry>> getCachedReels({int limit = 50});

  Future<void> cacheReels(List<ReelFeedEntry> reels);

  /// Replaces the persisted page-1 reels snapshot.
  Future<void> replaceReelsSnapshot(List<ReelFeedEntry> reels);
}
