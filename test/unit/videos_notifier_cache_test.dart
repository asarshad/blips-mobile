@Tags(['unit'])
library videos_notifier_cache_test;

import 'package:blips_mobile/features/feed/data/feed_repository.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:blips_mobile/features/feed/providers/feed_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../test_utils/fake_backend_api_client.dart';
import '../test_utils/fake_feed_cache.dart';

Map<String, dynamic> _videoJson(int id) {
  final day = ((id - 1) % 28) + 1;
  return {
    'id': id,
    'type': 'VIDEO',
    'title': 'Video $id',
    'video_url': 'https://youtube.com/watch?v=vid$id',
    'source_url': 'https://youtube.com/watch?v=vid$id',
    'summary': 'Summary $id',
    'source': 'YouTube',
    'image_url': 'https://img.youtube.com/vi/vid$id/0.jpg',
    'duration_seconds': 90,
    'created_at': '2026-03-${day.toString().padLeft(2, '0')}T00:00:00Z',
    'published_at': '2026-03-${day.toString().padLeft(2, '0')}T00:00:00Z',
  };
}

Map<String, dynamic> _videosResponse(List<int> ids) {
  return {
    'items': ids.map(_videoJson).toList(growable: false),
    'session_id': 'video-session',
    'cursor': ids.length,
    'has_more': true,
    'inventory_state': 'healthy',
  };
}

Future<void> _settle() async {
  for (var i = 0; i < 12; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

void main() {
  test(
    'VideosNotifier replaces stale cached page-1 items during silent refresh',
    () async {
      final cache = FakeFeedCache();
      await cache.replaceVideosSnapshot(
        [
          VideoFeedEntry(
            id: 17171,
            title: 'Why I intentionally misuse my fitness tracker',
            summary: 'Old cached row that moved to reels.',
            videoUrl: 'https://www.youtube.com/shorts/VvGaDPViMKY',
            link: 'https://www.youtube.com/shorts/VvGaDPViMKY',
            source: 'The Verge',
            category: 'Technology',
            publishedAt: DateTime.parse('2026-03-16T00:00:00Z'),
            readTime: 3,
            thumbnailUrl: 'https://img.youtube.com/vi/VvGaDPViMKY/0.jpg',
            durationSeconds: 134,
          ),
          ...List<VideoFeedEntry>.generate(
            9,
            (index) {
              final id = index + 1;
              final publishedAt =
                  '2026-03-${(20 - index).toString().padLeft(2, '0')}T00:00:00Z';
              return VideoFeedEntry(
                id: id,
                title: 'Cached Video $id',
                summary: 'Cached summary $id',
                videoUrl: 'https://youtube.com/watch?v=cache$id',
                link: 'https://youtube.com/watch?v=cache$id',
                source: 'YouTube',
                category: 'Technology',
                publishedAt: DateTime.parse(publishedAt),
                readTime: 2,
                thumbnailUrl: 'https://img.youtube.com/vi/cache$id/0.jpg',
                durationSeconds: 120,
              );
            },
          ),
        ],
      );

      final api = FakeBackendApiClient(
        queuedResponses: {
          '/session/playlist': [
            _videosResponse(List<int>.generate(10, (index) => index + 1)),
          ],
        },
      );

      final container = ProviderContainer(
        overrides: [
          feedRepositoryProvider.overrideWithValue(FeedRepository(api)),
          feedCacheProvider.overrideWithValue(cache),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(videosFeedProvider, (_, __) {});
      addTearDown(sub.close);

      await _settle();

      final state = container.read(videosFeedProvider);
      expect(state.hasValue, isTrue);
      final entries = state.value!;
      expect(
        entries.map((entry) => entry.id),
        orderedEquals(List<int>.generate(10, (i) => i + 1)),
      );
      expect(entries.any((entry) => entry.id == 17171), isFalse);

      final cached = await cache.getCachedVideos(limit: 10);
      expect(
        cached.map((entry) => entry.id),
        orderedEquals(List<int>.generate(10, (i) => i + 1)),
      );
      expect(cached.any((entry) => entry.id == 17171), isFalse);
    },
  );
}
