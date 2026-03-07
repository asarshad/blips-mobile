@Tags(['unit'])
library feed_repository_test;

import 'package:blips_mobile/features/feed/data/feed_repository.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_utils/fake_backend_api_client.dart';

void main() {
  group('FeedRepository', () {
    test(
      'fetchFeed reads session playlist and sorts by publishedAt desc',
      () async {
        final api = FakeBackendApiClient(
          queuedResponses: {
            '/session/playlist': [
              {
                'items': [
                  {
                    'id': 1,
                    'type': 'ARTICLE',
                    'title': 'Old article',
                    'source': 'TechCrunch',
                    'source_url': 'https://example.com/a1',
                    'summary': 'Summary',
                    'image_url': 'https://example.com/image.png',
                    'published_at': '2025-01-01T00:00:00Z',
                    'topics': ['Technology'],
                  },
                ],
                'session_id': 'article-session',
                'cursor': 1,
                'has_more': true,
              },
              {
                'items': [
                  {
                    'id': 2,
                    'type': 'VIDEO',
                    'title': 'New video',
                    'video_url': 'https://cdn.example.com/v.mp4',
                    'source_url': 'https://youtube.com/watch?v=abc',
                    'source': 'YouTube',
                    'summary': 'Video summary',
                    'image_url': 'https://example.com/thumb.png',
                    'duration': 60,
                    'published_at': '2025-01-02T00:00:00Z',
                    'topics': ['Technology'],
                  },
                ],
                'session_id': 'video-session',
                'cursor': 1,
                'has_more': true,
              },
            ],
          },
        );

        final repo = FeedRepository(api);
        final items = await repo.fetchFeed();

        expect(api.requests.length, 2);
        expect(api.requests[0].path, '/session/playlist');
        expect(api.requests[1].path, '/session/playlist');
        expect(api.requests[0].queryParameters?['type'], 'ARTICLE');
        expect(api.requests[1].queryParameters?['type'], 'VIDEO');

        expect(items, hasLength(2));
        expect(items.first, isA<VideoFeedEntry>());
        expect(items.last, isA<ArticleFeedEntry>());
        expect(items.first.publishedAt.isAfter(items.last.publishedAt), isTrue);
      },
    );

    test(
      'fetchFeed page 2 reuses session_id and cursor continuation',
      () async {
        final api = FakeBackendApiClient(
          queuedResponses: {
            '/session/playlist': [
              {
                'items': [
                  {
                    'id': 10,
                    'type': 'ARTICLE',
                    'title': 'Article p1',
                    'source_url': 'https://example.com/a10',
                    'source': 'TechCrunch',
                    'published_at': '2025-01-03T00:00:00Z',
                  },
                ],
                'session_id': 'article-session',
                'cursor': 25,
              },
              {
                'items': [
                  {
                    'id': 20,
                    'type': 'VIDEO',
                    'title': 'Video p1',
                    'video_url': 'https://cdn.example.com/v20.mp4',
                    'source_url': 'https://example.com/v20',
                    'source': 'YouTube',
                    'published_at': '2025-01-03T00:00:00Z',
                  },
                ],
                'session_id': 'video-session',
                'cursor': 30,
              },
              {
                'items': [
                  {
                    'id': 11,
                    'type': 'ARTICLE',
                    'title': 'Article p2',
                    'source_url': 'https://example.com/a11',
                    'source': 'TechCrunch',
                    'published_at': '2025-01-02T00:00:00Z',
                  },
                ],
                'session_id': 'article-session',
                'cursor': 25,
              },
              {
                'items': [
                  {
                    'id': 21,
                    'type': 'VIDEO',
                    'title': 'Video p2',
                    'video_url': 'https://cdn.example.com/v21.mp4',
                    'source_url': 'https://example.com/v21',
                    'source': 'YouTube',
                    'published_at': '2025-01-02T00:00:00Z',
                  },
                ],
                'session_id': 'video-session',
                'cursor': 30,
              },
            ],
          },
        );

        final repo = FeedRepository(api);
        await repo.fetchFeed();
        await repo.fetchFeed(page: 2);

        expect(api.requests.length, 4);
        final articlePage2 = api.requests[2].queryParameters!;
        final videoPage2 = api.requests[3].queryParameters!;

        expect(articlePage2['type'], 'ARTICLE');
        expect(articlePage2['session_id'], 'article-session');
        expect(articlePage2['cursor'], 25);

        expect(videoPage2['type'], 'VIDEO');
        expect(videoPage2['session_id'], 'video-session');
        expect(videoPage2['cursor'], 30);
      },
    );
  });
}
