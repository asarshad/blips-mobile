@Tags(['unit'])
library reels_notifier_stability_test;

import 'package:blips_mobile/features/feed/data/feed_repository.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:blips_mobile/features/feed/providers/feed_providers.dart';
import 'package:flutter_test/flutter_test.dart';

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

List<ReelFeedEntry> _entries(ReelsNotifier notifier) {
  final entries = notifier.state.value;
  expect(entries, isNotNull);
  return entries!;
}

List<int> _ids(ReelsNotifier notifier) {
  return _entries(notifier).map((entry) => entry.id).toList(growable: false);
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

        final notifier = ReelsNotifier(
          FeedRepository(api),
          FakeFeedCache(),
        );
        addTearDown(notifier.dispose);

        await _settle();
        expect(notifier.state.hasValue, isTrue);
        expect(
          _ids(notifier),
          List<int>.generate(20, (index) => index + 1),
        );

        await notifier.loadMore();
        await _settle();
        final afterLoadMore = _entries(notifier);
        expect(afterLoadMore.length, 40);
        expect(afterLoadMore[25].id, 26);

        await notifier.refreshSilently();
        await _settle();

        final afterRefreshIds = _ids(notifier);
        expect(afterRefreshIds.length, 40);
        expect(afterRefreshIds[25], 26);
        expect(afterRefreshIds, isNot(contains(101)));

        await notifier.loadMore();
        await _settle();

        final requestCursors = api.requests
            .where((request) => request.path == '/videos/reels')
            .map((request) => request.queryParameters?['cursor'])
            .toList(growable: false);
        expect(requestCursors.last, '40');
        expect(
          _ids(notifier),
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

        final notifier = ReelsNotifier(
          FeedRepository(api),
          FakeFeedCache(),
        );
        addTearDown(notifier.dispose);

        await _settle();
        await notifier.refreshSilently();
        await _settle();

        expect(
          _ids(notifier),
          List<int>.generate(20, (index) => index + 1),
        );
      },
    );
  });
}
