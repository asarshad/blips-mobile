@Tags(['unit'])
library videos_notifier_cache_test;

import 'dart:async';

import 'package:blips_mobile/features/feed/data/feed_repository.dart';
import 'package:blips_mobile/features/ads/domain/feed_page_item.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:blips_mobile/features/feed/providers/feed_providers.dart';
import 'package:blips_mobile/features/feed/data/feed_session_store.dart';
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

VideoFeedEntry _videoEntry(int id) {
  final json = _videoJson(id);
  return VideoFeedEntry(
    id: id,
    title: json['title']! as String,
    summary: json['summary']! as String,
    videoUrl: json['video_url']! as String,
    link: json['source_url']! as String,
    source: json['source']! as String,
    category: 'Technology',
    publishedAt: DateTime.parse(json['published_at']! as String),
    readTime: 2,
    durationSeconds: json['duration_seconds']! as int,
    thumbnailUrl: json['image_url']! as String,
  );
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
    'ensureNotificationTargetLoaded fetches missing video and renders temporary overlay first',
    () async {
      final api = FakeBackendApiClient(
        responseResolver: (method, path, queryParameters, body) async {
          if (method == 'GET' && path == '/session/playlist') {
            return _videosResponse(
                List<int>.generate(10, (index) => index + 1));
          }
          if (method == 'GET' && path == '/videos/99') {
            return _videoJson(99);
          }
          return const <String, dynamic>{};
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

      final success = await container
          .read(videosFeedProvider.notifier)
          .ensureNotificationTargetLoaded(99);
      await _settle();

      expect(success, isTrue);
      final uiState =
          container.read(feedSurfaceUiStateProvider(FeedSurface.videos));
      expect(uiState.restoreItemId, 99);
      expect(uiState.restoreApproximateIndex, 0);
      expect(uiState.notificationOverlayEntry, isA<VideoFeedEntry>());

      final pageItems = container.read(videoFeedWithAdsProvider).valueOrNull!;
      final organic = pageItems
          .whereType<OrganicFeedPageItem>()
          .map((item) => item.entry.id)
          .toList(growable: false);
      expect(organic.first, 99);
      expect(organic.where((id) => id == 99), hasLength(1));
      expect(organic, contains(1));
    },
  );

  test(
    'ensureNotificationTargetLoaded rejects reel payload and surfaces unavailable message',
    () async {
      final api = FakeBackendApiClient(
        responseResolver: (method, path, queryParameters, body) async {
          if (method == 'GET' && path == '/session/playlist') {
            return _videosResponse(
                List<int>.generate(10, (index) => index + 1));
          }
          if (method == 'GET' && path == '/videos/404') {
            return {
              'id': 404,
              'type': 'REEL',
              'title': 'Reel',
              'video_url': 'https://youtube.com/watch?v=reel404',
              'source_url': 'https://youtube.com/watch?v=reel404',
              'source': 'YouTube',
              'published_at': '2026-03-20T00:00:00Z',
            };
          }
          return const <String, dynamic>{};
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

      final success = await container
          .read(videosFeedProvider.notifier)
          .ensureNotificationTargetLoaded(404);

      expect(success, isFalse);
      final uiState =
          container.read(feedSurfaceUiStateProvider(FeedSurface.videos));
      expect(uiState.notificationOverlayEntry, isNull);
      expect(uiState.restoreItemId, isNull);
      expect(uiState.restoreApproximateIndex, isNull);
      expect(uiState.unavailableTargetMessage, 'That video is unavailable.');
    },
  );

  test(
    'ensureNotificationTargetLoaded keeps resolved overlay when recovery fetch fails later',
    () async {
      final delayedTarget = Completer<Map<String, dynamic>>();
      final api = FakeBackendApiClient(
        responseResolver: (method, path, queryParameters, body) async {
          if (method == 'GET' && path == '/session/playlist') {
            return _videosResponse(
              List<int>.generate(10, (index) => index + 1),
            );
          }
          if (method == 'GET' && path == '/videos/99') {
            return delayedTarget.future;
          }
          return const <String, dynamic>{};
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

      final loadFuture = container
          .read(videosFeedProvider.notifier)
          .ensureNotificationTargetLoaded(99);
      await Future<void>.delayed(const Duration(milliseconds: 1));

      container
          .read(feedSurfaceUiStateProvider(FeedSurface.videos).notifier)
          .state = FeedSurfaceUiState(
        notificationOverlayEntry: _videoEntry(99),
      );

      delayedTarget.completeError(Exception('temporary failure'));
      final success = await loadFuture;

      expect(success, isTrue);
      final uiState =
          container.read(feedSurfaceUiStateProvider(FeedSurface.videos));
      expect(uiState.notificationOverlayEntry, isA<VideoFeedEntry>());
      expect(uiState.restoreItemId, 99);
      expect(uiState.restoreApproximateIndex, 0);
      expect(uiState.unavailableTargetMessage, isNull);
    },
  );

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

  test(
    'loadMore skips a duplicate continuation page and keeps advancing',
    () async {
      final api = FakeBackendApiClient(
        responseResolver: (method, path, queryParameters, body) {
          if (method != 'GET' || path != '/session/playlist') {
            return const <String, dynamic>{};
          }

          final cursor = queryParameters?['cursor'];
          if (cursor == null) {
            return _videosResponse(
                List<int>.generate(10, (index) => index + 1));
          }
          if (cursor == 10) {
            return {
              ..._videosResponse(List<int>.generate(10, (index) => index + 1)),
              'cursor': 20,
              'has_more': true,
            };
          }
          if (cursor == 20) {
            return {
              ..._videosResponse(List<int>.generate(10, (index) => index + 11)),
              'cursor': 30,
              'has_more': true,
            };
          }
          throw StateError('Unexpected cursor: $cursor');
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
      await container.read(videosFeedProvider.notifier).loadMore();
      await _settle();

      final entries = container.read(videosFeedProvider).value;
      expect(entries, isNotNull);
      expect(entries!.map((entry) => entry.id), [
        ...List<int>.generate(10, (index) => index + 1),
        ...List<int>.generate(10, (index) => index + 11),
      ]);
    },
  );
}
