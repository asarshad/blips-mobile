@Tags(['unit'])
library videos_notifier_cache_test;

import 'dart:async';

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
    'VideosNotifier keeps cached items visible while fresh session loads',
    () async {
      final cache = FakeFeedCache();
      await cache.replaceVideosSnapshot(
        [
          VideoFeedEntry(
            id: 1,
            title: 'Cached Video 1',
            summary: 'Cached summary 1',
            videoUrl: 'https://youtube.com/watch?v=cache1',
            link: 'https://youtube.com/watch?v=cache1',
            source: 'YouTube',
            category: 'Technology',
            publishedAt: DateTime.parse('2026-03-20T00:00:00Z'),
            readTime: 2,
            thumbnailUrl: 'https://img.youtube.com/vi/cache1/0.jpg',
            durationSeconds: 120,
          ),
        ],
      );

      final delayedResponse = Completer<Map<String, dynamic>>();
      final api = FakeBackendApiClient(
        responseResolver: (method, path, queryParameters, body) async {
          if (method == 'GET' && path == '/session/playlist') {
            return delayedResponse.future;
          }
          return const <String, dynamic>{};
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

      var state = container.read(videosFeedProvider);
      expect(state.hasValue, isTrue);
      expect(state.value!.map((entry) => entry.id), orderedEquals([1]));

      delayedResponse.complete(
        _videosResponse(List<int>.generate(10, (index) => index + 11)),
      );
      await _settle();

      state = container.read(videosFeedProvider);
      expect(state.hasValue, isTrue);
      expect(
        state.value!.map((entry) => entry.id),
        orderedEquals(List<int>.generate(10, (index) => index + 11)),
      );
    },
  );

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

  test(
    'manualRefresh keeps current items visible until replacement arrives',
    () async {
      final delayedResponse = Completer<Map<String, dynamic>>();
      var playlistCallCount = 0;
      final api = FakeBackendApiClient(
        responseResolver: (method, path, queryParameters, body) async {
          if (method != 'GET' || path != '/session/playlist') {
            return const <String, dynamic>{};
          }
          playlistCallCount += 1;
          if (playlistCallCount == 1) {
            return _videosResponse(
                List<int>.generate(10, (index) => index + 1));
          }
          return delayedResponse.future;
        },
      );

      final container = ProviderContainer(
        overrides: [
          feedRepositoryProvider.overrideWithValue(FeedRepository(api)),
          feedCacheProvider.overrideWithValue(FakeFeedCache()),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(videosFeedProvider, (_, __) {});
      addTearDown(sub.close);

      await _settle();

      var state = container.read(videosFeedProvider);
      expect(state.hasValue, isTrue);
      expect(
        state.value!.map((entry) => entry.id),
        orderedEquals(List<int>.generate(10, (index) => index + 1)),
      );

      final refreshFuture =
          container.read(videosFeedProvider.notifier).manualRefresh();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      state = container.read(videosFeedProvider);
      expect(state.hasValue, isTrue);
      expect(
        state.value!.map((entry) => entry.id),
        orderedEquals(List<int>.generate(10, (index) => index + 1)),
      );

      delayedResponse.complete(
        _videosResponse(List<int>.generate(10, (index) => index + 21)),
      );
      expect(await refreshFuture, isTrue);
      await _settle();

      state = container.read(videosFeedProvider);
      expect(state.hasValue, isTrue);
      expect(
        state.value!.map((entry) => entry.id),
        orderedEquals(List<int>.generate(10, (index) => index + 21)),
      );
    },
  );

  test(
    'manualRefresh failure preserves current items and returns false',
    () async {
      var playlistCallCount = 0;
      final api = FakeBackendApiClient(
        responseResolver: (method, path, queryParameters, body) async {
          if (method != 'GET' || path != '/session/playlist') {
            return const <String, dynamic>{};
          }
          playlistCallCount += 1;
          if (playlistCallCount == 1) {
            return _videosResponse(
                List<int>.generate(10, (index) => index + 1));
          }
          throw Exception('refresh failed');
        },
      );

      final container = ProviderContainer(
        overrides: [
          feedRepositoryProvider.overrideWithValue(FeedRepository(api)),
          feedCacheProvider.overrideWithValue(FakeFeedCache()),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(videosFeedProvider, (_, __) {});
      addTearDown(sub.close);

      await _settle();

      final refreshResult =
          await container.read(videosFeedProvider.notifier).manualRefresh();
      await _settle();

      expect(refreshResult, isFalse);
      final state = container.read(videosFeedProvider);
      expect(state.hasValue, isTrue);
      expect(
        state.value!.map((entry) => entry.id),
        orderedEquals(List<int>.generate(10, (index) => index + 1)),
      );
    },
  );

  test(
    'manualRefresh coalesces overlapping refresh calls',
    () async {
      final delayedResponse = Completer<Map<String, dynamic>>();
      var playlistCallCount = 0;
      final api = FakeBackendApiClient(
        responseResolver: (method, path, queryParameters, body) async {
          if (method != 'GET' || path != '/session/playlist') {
            return const <String, dynamic>{};
          }
          playlistCallCount += 1;
          if (playlistCallCount == 1) {
            return _videosResponse(
                List<int>.generate(10, (index) => index + 1));
          }
          return delayedResponse.future;
        },
      );

      final container = ProviderContainer(
        overrides: [
          feedRepositoryProvider.overrideWithValue(FeedRepository(api)),
          feedCacheProvider.overrideWithValue(FakeFeedCache()),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(videosFeedProvider, (_, __) {});
      addTearDown(sub.close);

      await _settle();

      final notifier = container.read(videosFeedProvider.notifier);
      final first = notifier.manualRefresh();
      final second = notifier.manualRefresh();

      expect(identical(first, second), isTrue);

      delayedResponse.complete(
        _videosResponse(List<int>.generate(10, (index) => index + 21)),
      );
      expect(await first, isTrue);
      await _settle();

      expect(
        api.requests
            .where(
              (request) =>
                  request.method == 'GET' &&
                  request.path == '/session/playlist',
            )
            .length,
        2,
      );
    },
  );
}
