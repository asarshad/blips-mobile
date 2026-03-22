@Tags(['unit'])
library articles_notifier_refresh_test;

import 'dart:async';

import 'package:blips_mobile/features/feed/data/feed_repository.dart';
import 'package:blips_mobile/features/feed/data/feed_session_store.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:blips_mobile/features/feed/providers/feed_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../test_utils/fake_backend_api_client.dart';
import '../test_utils/fake_feed_cache.dart';

Map<String, dynamic> _articleJson(int id) {
  final day = ((id - 1) % 28) + 1;
  return {
    'id': id,
    'type': 'ARTICLE',
    'title': 'Article $id',
    'source_url': 'https://example.com/articles/$id',
    'summary': 'Summary $id',
    'source': 'Source $id',
    'image_url': 'https://example.com/article_$id.jpg',
    'published_at': '2026-03-${day.toString().padLeft(2, '0')}T00:00:00Z',
    'topics': ['Technology'],
  };
}

Map<String, dynamic> _articlesResponse(
  List<int> ids, {
  String feedVersion = 'article-v1',
}) {
  return {
    'items': ids.map(_articleJson).toList(growable: false),
    'session_id': 'article-session',
    'cursor': ids.length,
    'has_more': true,
    'inventory_state': 'healthy',
    'feed_version': feedVersion,
  };
}

Future<void> _settle() async {
  for (var i = 0; i < 12; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

void main() {
  test(
    'ArticlesNotifier manualRefresh keeps current items visible until replacement arrives',
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
            return _articlesResponse(
              List<int>.generate(15, (index) => index + 1),
            );
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
      final sub = container.listen(articlesFeedProvider, (_, __) {});
      addTearDown(sub.close);

      await _settle();

      var state = container.read(articlesFeedProvider);
      expect(state.hasValue, isTrue);
      expect(
        state.value!.map((entry) => entry.id),
        orderedEquals(List<int>.generate(15, (index) => index + 1)),
      );

      final refreshFuture =
          container.read(articlesFeedProvider.notifier).manualRefresh();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      state = container.read(articlesFeedProvider);
      expect(state.hasValue, isTrue);
      expect(
        state.value!.map((entry) => entry.id),
        orderedEquals(List<int>.generate(15, (index) => index + 1)),
      );

      delayedResponse.complete(
        _articlesResponse(List<int>.generate(15, (index) => index + 31)),
      );
      expect(await refreshFuture, isTrue);
      await _settle();

      state = container.read(articlesFeedProvider);
      expect(state.hasValue, isTrue);
      expect(
        state.value!.map((entry) => entry.id),
        orderedEquals(List<int>.generate(15, (index) => index + 31)),
      );
    },
  );

  test(
    'ArticlesNotifier manualRefresh failure preserves current items and returns false',
    () async {
      var playlistCallCount = 0;
      final api = FakeBackendApiClient(
        responseResolver: (method, path, queryParameters, body) async {
          if (method != 'GET' || path != '/session/playlist') {
            return const <String, dynamic>{};
          }
          playlistCallCount += 1;
          if (playlistCallCount == 1) {
            return _articlesResponse(
              List<int>.generate(15, (index) => index + 1),
            );
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
      final sub = container.listen(articlesFeedProvider, (_, __) {});
      addTearDown(sub.close);

      await _settle();

      final refreshResult =
          await container.read(articlesFeedProvider.notifier).manualRefresh();
      await _settle();

      expect(refreshResult, isFalse);
      final state = container.read(articlesFeedProvider);
      expect(state.hasValue, isTrue);
      expect(
        state.value!.map((entry) => entry.id),
        orderedEquals(List<int>.generate(15, (index) => index + 1)),
      );
    },
  );

  test(
    'ArticlesNotifier coalesces overlapping manual refresh calls',
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
            return _articlesResponse(
              List<int>.generate(15, (index) => index + 1),
            );
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
      final sub = container.listen(articlesFeedProvider, (_, __) {});
      addTearDown(sub.close);

      await _settle();

      final notifier = container.read(articlesFeedProvider.notifier);
      final first = notifier.manualRefresh();
      final second = notifier.manualRefresh();

      expect(identical(first, second), isTrue);

      delayedResponse.complete(
        _articlesResponse(List<int>.generate(15, (index) => index + 21)),
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
    'ArticlesNotifier refreshes resumed article metadata when preview returns the same ids',
    () async {
      final cache = FakeFeedCache();
      final sessionStore = FeedSessionStore(cache);
      await sessionStore.saveActiveSession(
        FeedSessionSnapshot(
          surface: FeedSurface.articles,
          items: <FeedEntry>[
            ArticleFeedEntry(
              id: 1,
              title: 'Article 1',
              summary: 'Summary 1',
              source: 'example.com',
              publishedAt: DateTime.parse('2026-03-01T00:00:00Z'),
              url: 'https://example.com/articles/1',
              imageUrl: null,
              category: 'Technology',
              readTime: 1,
            ),
          ],
          currentItemId: 1,
          lastActiveAt: DateTime.now().toUtc(),
          headBaselineIds: const [1],
          sessionId: 'restored-session',
          continuationCursor: '1',
          hasMore: true,
          inventoryState: FeedInventoryState.healthy,
        ),
      );

      final api = FakeBackendApiClient(
        responses: {
          '/session/playlist': _articlesResponse(const [1]),
        },
      );

      final container = ProviderContainer(
        overrides: [
          feedRepositoryProvider.overrideWithValue(FeedRepository(api)),
          feedCacheProvider.overrideWithValue(cache),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(articlesFeedProvider, (_, __) {});
      addTearDown(sub.close);

      await _settle();

      final state = container.read(articlesFeedProvider);
      expect(state.hasValue, isTrue);
      expect(state.value, hasLength(1));
      expect(state.value!.single.id, 1);
      expect(
        state.value!.single.imageUrl,
        equals('https://example.com/article_1.jpg'),
      );
    },
  );

  test(
    'ArticlesNotifier surfaces pending new items when feed version changes at the head',
    () async {
      var playlistCallCount = 0;
      final api = FakeBackendApiClient(
        responseResolver: (method, path, queryParameters, body) async {
          if (method != 'GET' || path != '/session/playlist') {
            return const <String, dynamic>{};
          }
          playlistCallCount += 1;
          if (playlistCallCount == 1) {
            return _articlesResponse(
              List<int>.generate(15, (index) => index + 1),
              feedVersion: 'article-v1',
            );
          }
          return _articlesResponse(
            [101, ...List<int>.generate(14, (index) => index + 1)],
            feedVersion: 'article-v2',
          );
        },
      );

      final container = ProviderContainer(
        overrides: [
          feedRepositoryProvider.overrideWithValue(FeedRepository(api)),
          feedCacheProvider.overrideWithValue(FakeFeedCache()),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(articlesFeedProvider, (_, __) {});
      addTearDown(sub.close);

      await _settle();
      await container.read(articlesFeedProvider.notifier).refreshSilently();
      await _settle();

      final uiState =
          container.read(feedSurfaceUiStateProvider(FeedSurface.articles));
      expect(uiState.pendingNewCount, 1);
    },
  );
}
