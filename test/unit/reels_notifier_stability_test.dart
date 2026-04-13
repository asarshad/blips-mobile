@Tags(['unit'])
library reels_notifier_stability_test;

import 'dart:async';

import 'package:blips_mobile/features/ads/domain/ads_config.dart';
import 'package:blips_mobile/features/ads/domain/feed_page_item.dart';
import 'package:blips_mobile/features/ads/providers/ads_providers.dart';
import 'package:blips_mobile/features/feed/data/feed_repository.dart';
import 'package:blips_mobile/features/feed/data/feed_session_store.dart';
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
    'type': 'REEL',
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
    'session_id': 'reel-session',
    'cursor': nextCursor == null ? null : int.parse(nextCursor),
    'inventory_state': 'healthy',
    'served_at': '2026-03-17T00:00:00Z',
    'feed_version': 'reel-v${nextCursor ?? 'head'}',
    'newest_created_at': '2026-03-17T00:00:00Z',
  };
}

Map<String, dynamic> _reelsMetadataResponse({
  required String feedVersion,
  String newestCreatedAt = '2026-03-17T00:00:00Z',
}) {
  return {
    'served_at': '2026-03-17T00:00:00Z',
    'feed_version': feedVersion,
    'newest_created_at': newestCreatedAt,
    'newest_published_at': newestCreatedAt,
    'freshness_strategy': 'article_recent_head_v1',
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
    test('reels feed with ads injects native slots when enabled', () async {
      final api = FakeBackendApiClient(
        responses: {
          '/session/playlist': _reelsResponse(
            ids: List<int>.generate(10, (index) => index + 1),
            hasMore: true,
            nextCursor: '10',
          ),
        },
      );

      final container = ProviderContainer(
        overrides: [
          feedRepositoryProvider.overrideWithValue(FeedRepository(api)),
          feedCacheProvider.overrideWithValue(FakeFeedCache()),
          adsConfigProvider.overrideWith(
            (_) async => const AdsConfig(
              enabled: true,
              eligible: true,
              surfaces: AdsSurfacesConfig(
                reels: AdSurfaceConfig(
                  enabled: true,
                  frequency: 8,
                  firstSlotAfter: 2,
                ),
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(reelsFeedWithAdsProvider, (_, __) {});
      addTearDown(sub.close);

      await _settle();

      final items = container.read(reelsFeedWithAdsProvider).value;
      expect(items, isNotNull);
      expect(items!.length, 11);
      expect(items.whereType<NativeAdSlotFeedPageItem>(), hasLength(1));
      expect(items[8], isA<NativeAdSlotFeedPageItem>());
    });

    test('ensureNotificationTargetLoaded stages a reel overlay entry',
        () async {
      final api = FakeBackendApiClient(
        responses: {
          '/session/playlist': _reelsResponse(
            ids: [1, 2, 3],
            hasMore: true,
            nextCursor: '3',
          ),
          '/videos/77': {
            'id': 77,
            'type': 'REEL',
            'title': 'Reel 77',
            'video_url': 'https://youtube.com/watch?v=reel77',
            'source_url': 'https://youtube.com/watch?v=reel77',
            'summary': 'Summary 77',
            'thumbnail_url': 'https://img.youtube.com/vi/reel77/0.jpg',
            'source': 'YouTube',
            'duration_seconds': 30,
            'created_at': '2026-03-20T00:00:00Z',
            'published_at': '2026-03-20T00:00:00Z',
          },
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

      final loaded = await container
          .read(reelsFeedProvider.notifier)
          .ensureNotificationTargetLoaded(77);
      await _settle();

      expect(loaded, isTrue);

      final uiState =
          container.read(feedSurfaceUiStateProvider(FeedSurface.reels));
      expect(uiState.restoreItemId, 77);
      expect(uiState.restoreApproximateIndex, 0);
      expect(uiState.notificationOverlayEntry, isA<ReelFeedEntry>());

      final items = container.read(reelsFeedWithAdsProvider).value;
      expect(items, isNotNull);
      expect(items!.first.organicEntry, isA<ReelFeedEntry>());
      expect((items.first.organicEntry as ReelFeedEntry).id, 77);
    });

    test(
      'preserves deep-scroll ordering and pagination cursor across silent refresh',
      () async {
        var page1CallCount = 0;
        final api = FakeBackendApiClient(
          responseResolver: (method, path, queryParameters, body) {
            if (method == 'GET' && path == '/session/playlist/meta') {
              return _reelsMetadataResponse(
                feedVersion: page1CallCount >= 2 ? 'reel-vrefresh' : 'reel-v20',
                newestCreatedAt: page1CallCount >= 2
                    ? '2026-03-18T00:00:00Z'
                    : '2026-03-17T00:00:00Z',
              );
            }
            if (method != 'GET' ||
                path != '/session/playlist' ||
                queryParameters?['type'] != 'REEL') {
              return const <String, dynamic>{};
            }

            final cursor = queryParameters?['cursor']?.toString();
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
            .where((request) => request.path == '/session/playlist')
            .map((request) => request.queryParameters?['cursor'])
            .toList(growable: false);
        expect(requestCursors.last, 40);
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
            if (method == 'GET' && path == '/session/playlist/meta') {
              return _reelsMetadataResponse(
                feedVersion: page1CallCount == 0 ? 'reel-vhead' : 'reel-v20',
              );
            }
            if (method != 'GET' ||
                path != '/session/playlist' ||
                queryParameters?['type'] != 'REEL') {
              return const <String, dynamic>{};
            }

            final cursor = queryParameters?['cursor']?.toString();
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
          if (method != 'GET' ||
              path != '/session/playlist' ||
              queryParameters?['type'] != 'REEL') {
            return const <String, dynamic>{};
          }

          final cursor = queryParameters?['cursor']?.toString();
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
          if (method != 'GET' ||
              path != '/session/playlist' ||
              queryParameters?['type'] != 'REEL') {
            return const <String, dynamic>{};
          }

          final cursor = queryParameters?['cursor']?.toString();
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
          if (method != 'GET' ||
              path != '/session/playlist' ||
              queryParameters?['type'] != 'REEL') {
            return const <String, dynamic>{};
          }

          final cursor = queryParameters?['cursor']?.toString();
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
                  request.method == 'GET' &&
                  request.path == '/session/playlist',
            )
            .length,
        2,
      );
    },
  );

  test(
    'ReelsNotifier loadMore skips a duplicate continuation page and keeps advancing',
    () async {
      final api = FakeBackendApiClient(
        responseResolver: (method, path, queryParameters, body) {
          if (method != 'GET' ||
              path != '/session/playlist' ||
              queryParameters?['type'] != 'REEL') {
            return const <String, dynamic>{};
          }

          final cursor = queryParameters?['cursor']?.toString();
          if (cursor == null) {
            return _reelsResponse(
              ids: List<int>.generate(20, (index) => index + 1),
              hasMore: true,
              nextCursor: '20',
            );
          }
          if (cursor == '20') {
            return _reelsResponse(
              ids: List<int>.generate(20, (index) => index + 1),
              hasMore: true,
              nextCursor: '40',
            );
          }
          if (cursor == '40') {
            return _reelsResponse(
              ids: List<int>.generate(20, (index) => index + 21),
              hasMore: true,
              nextCursor: '60',
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
      await container.read(reelsFeedProvider.notifier).loadMore();
      await _settle();

      expect(
        _ids(container),
        [
          ...List<int>.generate(20, (index) => index + 1),
          ...List<int>.generate(20, (index) => index + 21),
        ],
      );
    },
  );

  test(
    'ReelsNotifier manualRefresh waits for in-flight loadMore before replacing reels',
    () async {
      final loadMoreResponse = Completer<Map<String, dynamic>>();
      var headCallCount = 0;
      final api = FakeBackendApiClient(
        responseResolver: (method, path, queryParameters, body) async {
          if (method != 'GET' ||
              path != '/session/playlist' ||
              queryParameters?['type'] != 'REEL') {
            return const <String, dynamic>{};
          }

          final cursor = queryParameters?['cursor']?.toString();
          if (cursor == '20') {
            return loadMoreResponse.future;
          }

          if (cursor != null) {
            throw StateError('Unexpected cursor: $cursor');
          }

          headCallCount += 1;
          if (headCallCount == 1) {
            return _reelsResponse(
              ids: List<int>.generate(20, (index) => index + 1),
              hasMore: true,
              nextCursor: '20',
            );
          }

          return _reelsResponse(
            ids: List<int>.generate(20, (index) => index + 101),
            hasMore: true,
            nextCursor: '20',
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
      final sub = container.listen(reelsFeedProvider, (_, __) {});
      addTearDown(sub.close);

      await _settle();

      final notifier = container.read(reelsFeedProvider.notifier);
      final loadMoreFuture = notifier.loadMore();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final refreshFuture = notifier.manualRefresh();
      final earlyResult = await Future.any<Object?>([
        refreshFuture.then<Object?>((_) => 'completed'),
        Future<Object?>.delayed(
          const Duration(milliseconds: 30),
          () => 'waiting',
        ),
      ]);
      expect(earlyResult, 'waiting');

      loadMoreResponse.complete(
        _reelsResponse(
          ids: List<int>.generate(20, (index) => index + 21),
          hasMore: true,
          nextCursor: '40',
        ),
      );

      await loadMoreFuture;
      expect(await refreshFuture, isTrue);
      await _settle();

      expect(
        _ids(container),
        List<int>.generate(20, (index) => index + 101),
      );

      final requestCursors = api.requests
          .where((request) => request.method == 'GET')
          .map((request) => request.queryParameters?['cursor'])
          .toList(growable: false);
      expect(requestCursors, [null, 20, null]);
    },
  );
}
