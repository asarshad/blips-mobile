import 'package:blips_mobile/core/network/dio_provider.dart';
import 'package:blips_mobile/features/feed/data/feed_repository.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Provides a singleton [FeedRepository].
final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return FeedRepository(dio);
});

/// Loads the merged article/video feed for the home experience.
final feedItemsProvider = FutureProvider.autoDispose<List<FeedEntry>>((ref) {
  final repository = ref.watch(feedRepositoryProvider);
  return repository.fetchFeed();
});

/// Filters only article entries from the merged feed.
final articleFeedProvider =
    FutureProvider.autoDispose<List<ArticleFeedEntry>>((ref) async {
  final mergedFeed = await ref.watch(feedItemsProvider.future);
  return mergedFeed.whereType<ArticleFeedEntry>().toList(growable: false);
});

/// Filters only video entries from the merged feed.
final videoFeedProvider =
    FutureProvider.autoDispose<List<VideoFeedEntry>>((ref) async {
  final mergedFeed = await ref.watch(feedItemsProvider.future);
  return mergedFeed.whereType<VideoFeedEntry>().toList(growable: false);
});
