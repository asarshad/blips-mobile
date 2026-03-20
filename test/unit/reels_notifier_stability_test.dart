@Tags(['unit'])
library reels_notifier_stability_test;

import 'dart:async';

import 'package:blips_mobile/features/feed/data/feed_repository.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:blips_mobile/features/feed/providers/feed_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../test_utils/fake_backend_api_client.dart';
import '../test_utils/fake_feed_cache.dart';

Map<String, dynamic> _reelJson(int id) {
  final day = ((id - 1) % 28) + 1;
  return {
    'id': id,
    'title': 'Reel $id',
    'video_url': 'https://youtube.com/watch?v=vid$id',
    'source_url': 'https://youtube.com/watch?v=vid$id',
    'summary': 'Summary $id',
    'thumbnail_url': 'https://img.youtube.com/vi/vid$id/0.jpg',
    'source': 'YouTube',
    'duration_seconds': 30,
    'created_at': '2026-03-${day.toString().padLeft(2, '0')}T00:00:00Z',
    'published_at': '2026-03-${day.toString().padLeft(2, '0')}T00:00:00Z',
  };
}

Map<String, dynamic> _reelsResponse({
  required List<int> ids,
  required bool hasMore,
  required String? nextCursor,
}) {
  return {
    'items': ids.map(_reelJson).toList(growable: false),
    'has_more': hasMore,
    'next_cursor': nextCursor,
    'inventory_state': 'healthy',
    'served_at': '2026-03-17T00:00:00Z',
  };
}

Future<void> _settle() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

List<ReelFeedEntry> _entries(ProviderContainer container) {
  final entries = container.read(reelsFeedProvider).value;
  expect(entries, isNotNull);
  return entries!;
}

List<int> _ids(ProviderContainer container) {
  return _entries(container).map((entry) => entry.id).toList(growable: false);
}

void main() {
  group('ReelsNotifier silent refresh stability', () {
    test(
      'preserves deep-scroll ordering and pagination cursor across silent refresh',
      () async {
        var page1CallCount = 0;
        final api = FakeBackendApiClient(
          responseResolver: (method, path, queryParameters, body) {
            if (method != 'GET' || path != '/videos/reels') {
              return const <String, dynamic>{};
            }

            final cursor = queryParameters?['cursor'] as String?;
            if (cursor == null) {
              page1CallCount++;
              if (page1CallCount == 1) {
                return _reelsResponse(
                  ids: List<int>.generate(20, (index) => index + 1),
                  hasMore: true,
                  nextCursor: '20',
                );
              }
              return _reelsResponse(
                ids: [101, ...List<int>.generate(19, (index) => index + 1)],
                hasMore: true,
                nextCursor: '20',
              );
            }

            if (cursor == '20') {
              return _reelsResponse(
                ids: List<int>.generate(20, (index) => index + 21),
                hasMore: true,
                nextCursor: '40',
              );
            }

            if (cursor == '40') {
              return _reelsResponse(
                ids: List<int>.generate(20, (index) => index + 41),
                hasMore: false,
                nextCursor: null,
              );
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
        final sub = container.listen(reelsFeedProvider, (_, __) {});
        addTearDown(sub.close);

        await _settle();
        expect(container.read(reelsFeedProvider).hasValue, isTrue);
        expect(
          _ids(container),
          List<int>.generate(20, (index) => index + 1),
        );

        await container.read(reelsFeedProvider.notifier).loadMore();
        await _settle();
        final afterLoadMore = _entries(container);
        expect(afterLoadMore.length, 40);
        expect(afterLoadMore[25].id, 26);

        await container.read(reelsFeedProvider.notifier).refreshSilently();
        await _settle();

        final afterRefreshIds = _ids(container);
        expect(afterRefreshIds.length, 40);
        expect(afterRefreshIds[25], 26);
        expect(afterRefreshIds, isNot(contains(101)));

        await container.read(reelsFeedProvider.notifier).loadMore();
        await _settle();

        final requestCursors = api.requests
            .where((request) => request.path == '/videos/reels')
            .map((request) => request.queryParameters?['cursor'])
            .toList(growable: false);
        expect(requestCursors.last, '40');
        expect(
          _ids(container),
          List<int>.generate(60, (index) => index + 1),
        );
      },
    );

    test(
      'does not prepend new page-1 reels during silent refresh near the top',
      () async {
        var page1CallCount = 0;
        final api = FakeBackendApiClient(
          responseResolver: (method, path, queryParameters, body) {
            if (method != 'GET' || path != '/videos/reels') {
              return const <String, dynamic>{};
            }

            final cursor = queryParameters?['cursor'] as String?;
            if (cursor == null) {
              page1CallCount++;
              if (page1CallCount == 1) {
                return _reelsResponse(
                  ids: List<int>.generate(20, (index) => index + 1),
                  hasMore: true,
                  nextCursor: '20',
                );
              }
              return _reelsResponse(
                ids: [101, ...List<int>.generate(19, (index) => index + 1)],
                hasMore: true,
                nextCursor: '20',
              );
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
        final sub = container.listen(reelsFeedProvider, (_, __) {});
        addTearDown(sub.close);

        await _settle();
        await container.read(reelsFeedProvider.notifier).refreshSilently();
        await _settle();

        expect(
          _ids(container),
          List<int>.generate(20, (index) => index + 1),
        );
      },
    );
  });

  test(
    'ReelsNotifier manualRefresh failure preserves current reels and returns false',
    () async {
      var page1CallCount = 0;
      final api = FakeBackendApiClient(
        responseResolver: (method, path, queryParameters, body) {
          if (method != 'GET' || path != '/videos/reels') {
            return const <String, dynamic>{};
          }

          final cursor = queryParameters?['cursor'] as String?;
          if (cursor != null) {
            throw StateError('Unexpected cursor: $cursor');
          }

          page1CallCount += 1;
          if (page1CallCount == 1) {
            return _reelsResponse(
              ids: List<int>.generate(20, (index) => index + 1),
              hasMore: true,
              nextCursor: '20',
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
      final sub = container.listen(reelsFeedProvider, (_, __) {});
      addTearDown(sub.close);

      await _settle();

      final refreshResult =
          await container.read(reelsFeedProvider.notifier).manualRefresh();
      await _settle();

      expect(refreshResult, isFalse);
      expect(
        _ids(container),
        List<int>.generate(20, (index) => index + 1),
      );
    },
  );

  test(
    'ReelsNotifier manualRefresh keeps current reels visible until replacement arrives',
    () async {
      final delayedResponse = Completer<Map<String, dynamic>>();
      var page1CallCount = 0;
      final api = FakeBackendApiClient(
        responseResolver: (method, path, queryParameters, body) async {
          if (method != 'GET' || path != '/videos/reels') {
            return const <String, dynamic>{};
          }

          final cursor = queryParameters?['cursor'] as String?;
          if (cursor != null) {
            throw StateError('Unexpected cursor: $cursor');
          }

          page1CallCount += 1;
          if (page1CallCount == 1) {
            return _reelsResponse(
              ids: List<int>.generate(20, (index) => index + 1),
              hasMore: true,
              nextCursor: '20',
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
      final sub = container.listen(reelsFeedProvider, (_, __) {});
      addTearDown(sub.close);

      await _settle();

      final refreshFuture =
          container.read(reelsFeedProvider.notifier).manualRefresh();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(
        _ids(container),
        List<int>.generate(20, (index) => index + 1),
      );

      delayedResponse.complete(
        _reelsResponse(
          ids: List<int>.generate(20, (index) => index + 51),
          hasMore: true,
          nextCursor: '20',
        ),
      );
      expect(await refreshFuture, isTrue);
      await _settle();

      expect(
        _ids(container),
        List<int>.generate(20, (index) => index + 51),
      );
    },
  );

  test(
    'ReelsNotifier coalesces overlapping manual refresh calls',
    () async {
      final delayedResponse = Completer<Map<String, dynamic>>();
      var page1CallCount = 0;
      final api = FakeBackendApiClient(
        responseResolver: (method, path, queryParameters, body) async {
          if (method != 'GET' || path != '/videos/reels') {
            return const <String, dynamic>{};
          }

          final cursor = queryParameters?['cursor'] as String?;
          if (cursor != null) {
            throw StateError('Unexpected cursor: $cursor');
          }

          page1CallCount += 1;
          if (page1CallCount == 1) {
            return _reelsResponse(
              ids: List<int>.generate(20, (index) => index + 1),
              hasMore: true,
              nextCursor: '20',
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
      final sub = container.listen(reelsFeedProvider, (_, __) {});
      addTearDown(sub.close);

      await _settle();

      final notifier = container.read(reelsFeedProvider.notifier);
      final first = notifier.manualRefresh();
      final second = notifier.manualRefresh();

      expect(identical(first, second), isTrue);

      delayedResponse.complete(
        _reelsResponse(
          ids: List<int>.generate(20, (index) => index + 41),
          hasMore: true,
          nextCursor: '20',
        ),
      );
      expect(await first, isTrue);
      await _settle();

      expect(
        api.requests
            .where(
              (request) =>
                  request.method == 'GET' && request.path == '/videos/reels',
            )
            .length,
        2,
      );
    },
  );
}
