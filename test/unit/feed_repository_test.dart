@Tags(['unit'])
library feed_repository_test;

import 'package:blips_mobile/features/feed/data/feed_repository.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_utils/fake_backend_api_client.dart';

void main() {
  group('FeedRepository', () {
    test('fetchFeed merges and sorts by publishedAt desc', () async {
      final api = FakeBackendApiClient(
        responses: {
          '/articles/recent': {
            'articles': [
              {
                'id': 1,
                'title': 'Old article',
                'source_url': 'https://example.com/a1',
                'summary': 'Summary',
                'image_url': 'https://example.com/image.png',
                'published_date': '2025-01-01T00:00:00Z',
                'created_at': '2025-01-01T00:00:00Z',
                'read_time_minutes': 3,
                'tags': [
                  {'name': 'Technology'},
                ],
              },
            ],
          },
          '/videos/recent': {
            'videos': [
              {
                'id': 2,
                'title': 'New video',
                'video_url': 'https://cdn.example.com/v.mp4',
                'source_url': 'https://youtube.com/watch?v=abc',
                'summary': 'Video summary',
                'thumbnail_url': 'https://example.com/thumb.png',
                'source': 'YouTube',
                'category': 'Technology',
                'duration_seconds': 60,
                'created_at': '2025-01-02T00:00:00Z',
              },
            ],
          },
        },
      );

      final repo = FeedRepository(api);
      final items =
          await repo.fetchFeed(articleLimit: 15, videoLimit: 10, page: 1);

      expect(api.requests.length, 2);
      expect(api.requests[0].path, '/articles/recent');
      expect(api.requests[1].path, '/videos/recent');

      expect(items, hasLength(2));
      expect(items.first, isA<VideoFeedEntry>());
      expect(items.last, isA<ArticleFeedEntry>());
      expect(items.first.publishedAt.isAfter(items.last.publishedAt), isTrue);
    });
  });
}
