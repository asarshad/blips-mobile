@Tags(['unit'])
library feed_session_store_test;

import 'package:blips_mobile/features/feed/data/feed_session_store.dart';
import 'package:blips_mobile/features/feed/data/feed_repository.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_utils/fake_feed_cache.dart';

FeedSessionSnapshot _snapshot({
  required FeedSurface surface,
  required DateTime lastActiveAt,
  int currentItemId = 2,
}) {
  final items = <FeedEntry>[
    ArticleFeedEntry(
      id: 1,
      title: 'Article 1',
      summary: 'Summary 1',
      source: 'Source',
      publishedAt: DateTime.parse('2026-03-18T09:00:00Z'),
      url: 'https://example.com/1',
      imageUrl: 'https://example.com/1.jpg',
      category: 'Tech',
      readTime: 3,
    ),
    ArticleFeedEntry(
      id: 2,
      title: 'Article 2',
      summary: 'Summary 2',
      source: 'Source',
      publishedAt: DateTime.parse('2026-03-18T08:00:00Z'),
      url: 'https://example.com/2',
      imageUrl: 'https://example.com/2.jpg',
      category: 'Tech',
      readTime: 4,
    ),
  ];

  return FeedSessionSnapshot(
    surface: surface,
    items: items,
    currentItemId: currentItemId,
    lastActiveAt: lastActiveAt,
    headBaselineIds: const [1, 2],
    sessionId: 'session-1',
    continuationCursor: '15',
    hasMore: true,
    inventoryState: FeedInventoryState.healthy,
    pendingNewCount: 3,
  );
}

void main() {
  test('prepareRestore resumes same-day session within 2 hours', () async {
    final cache = FakeFeedCache();
    final store = FeedSessionStore(cache);
    final now = DateTime.parse('2026-03-18T18:00:00Z');

    await store.saveActiveSession(
      _snapshot(
        surface: FeedSurface.articles,
        lastActiveAt: now.subtract(const Duration(minutes: 55)),
      ),
    );

    final decision = await store.prepareRestore(
      FeedSurface.articles,
      now: now,
    );

    expect(decision.resumeSnapshot, isNotNull);
    expect(decision.resumeSnapshot!.items.map((entry) => entry.id), [1, 2]);
    expect(decision.resumeSnapshot!.currentItemId, 2);
  });

  test('prepareRestore expires sessions after resume window', () async {
    final cache = FakeFeedCache();
    final store = FeedSessionStore(cache);
    final now = DateTime.parse('2026-03-18T18:00:00Z');

    await store.saveActiveSession(
      _snapshot(
        surface: FeedSurface.articles,
        lastActiveAt: now.subtract(const Duration(hours: 3)),
      ),
    );

    final decision = await store.prepareRestore(
      FeedSurface.articles,
      now: now,
    );

    expect(decision.resumeSnapshot, isNull);
    expect(
      await store.getActiveSession(FeedSurface.articles),
      isNull,
    );
  });

  test('prepareRestore expires snapshots across local day boundary', () async {
    final cache = FakeFeedCache();
    final store = FeedSessionStore(cache);
    final now = DateTime.parse('2026-03-19T08:30:00Z');

    await store.saveActiveSession(
      _snapshot(
        surface: FeedSurface.articles,
        lastActiveAt: DateTime.parse('2026-03-18T23:30:00Z'),
      ),
    );

    final decision = await store.prepareRestore(
      FeedSurface.articles,
      now: now,
    );

    expect(decision.resumeSnapshot, isNull);
    expect(
      await store.getActiveSession(FeedSurface.articles),
      isNull,
    );
  });
}
