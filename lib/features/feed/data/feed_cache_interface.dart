import 'package:blips_mobile/features/feed/domain/feed_entry.dart';

/// Cache abstraction so unit/widget tests can run without SQLite.
abstract interface class FeedCacheInterface {
  Future<List<FeedEntry>> getCachedFeed({
    int articleLimit = 15,
    int videoLimit = 10,
  });

  Future<void> cacheFeed(List<FeedEntry> entries);

  Future<List<ReelFeedEntry>> getCachedReels({int limit = 50});

  Future<void> cacheReels(List<ReelFeedEntry> reels);
}
