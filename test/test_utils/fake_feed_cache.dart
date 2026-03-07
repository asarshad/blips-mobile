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
    // Keep semantics simple for tests: return what we have.
    return List<FeedEntry>.from(_feed);
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
