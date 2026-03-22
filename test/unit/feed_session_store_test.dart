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
    lastViewedIndex: 1,
    lastActiveAt: lastActiveAt,
    headBaselineIds: const [1, 2],
    sessionId: 'session-1',
    continuationCursor: '15',
    hasMore: true,
    inventoryState: FeedInventoryState.healthy,
    pendingNewCount: 3,
    lastFeedVersion: 'feed-v1',
  );
}

void main() {
  test('markExposed and markConsumed work with empty local history', () async {
    final cache = FakeFeedCache();
    final store = FeedSessionStore(cache);
    final now = DateTime.parse('2026-03-18T18:00:00Z');

    await store.markExposed(
      FeedSurface.articles,
      99,
      at: now,
    );
    await store.markConsumed(
      FeedSurface.videos,
      42,
      at: now,
    );

    expect(
      await store.getRecentlyExposedIds(FeedSurface.articles, now: now),
      contains(99),
    );
    expect(
      await store.getRecentlyExposedIds(FeedSurface.videos, now: now),
      contains(42),
    );
    expect(
      await store.getRecentlyConsumedIds(FeedSurface.videos, now: now),
      contains(42),
    );
  });

  test('prepareRestore resumes article session within the soft restore window',
      () async {
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
    expect(decision.resumeSnapshot!.lastViewedIndex, 1);
    expect(decision.resumeSnapshot!.lastFeedVersion, 'feed-v1');
  });

  test('prepareRestore expires article sessions after the soft restore window',
      () async {
    final cache = FakeFeedCache();
    final store = FeedSessionStore(cache);
    final now = DateTime.parse('2026-03-18T18:00:00Z');

    await store.saveActiveSession(
      _snapshot(
        surface: FeedSurface.articles,
        lastActiveAt: now.subtract(const Duration(hours: 96)),
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

  test('prepareRestore no longer expires snapshots across a day boundary',
      () async {
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

    expect(decision.resumeSnapshot, isNotNull);
    expect(decision.resumeSnapshot!.currentItemId, 2);
  });

  test('prepareRestore marks reels for latest bias after longer inactivity',
      () async {
    final cache = FakeFeedCache();
    final store = FeedSessionStore(cache);
    final now = DateTime.parse('2026-03-19T18:00:00Z');

    await store.saveActiveSession(
      _snapshot(
        surface: FeedSurface.reels,
        lastActiveAt: now.subtract(const Duration(hours: 8)),
      ),
    );

    final decision = await store.prepareRestore(
      FeedSurface.reels,
      now: now,
    );

    expect(decision.resumeSnapshot, isNotNull);
    expect(decision.preferLatestOnRefresh, isTrue);
    expect(
      store.isRemoteContinuationFresh(
        FeedSurface.reels,
        decision.resumeSnapshot!,
        now: now,
      ),
      isFalse,
    );
  });

  test('prepareRestore keeps reels exact-restore behavior for short inactivity',
      () async {
    final cache = FakeFeedCache();
    final store = FeedSessionStore(cache);
    final now = DateTime.parse('2026-03-19T18:00:00Z');

    await store.saveActiveSession(
      _snapshot(
        surface: FeedSurface.reels,
        lastActiveAt: now.subtract(const Duration(minutes: 45)),
      ),
    );

    final decision = await store.prepareRestore(
      FeedSurface.reels,
      now: now,
    );

    expect(decision.resumeSnapshot, isNotNull);
    expect(decision.preferLatestOnRefresh, isFalse);
    expect(
      store.isRemoteContinuationFresh(
        FeedSurface.reels,
        decision.resumeSnapshot!,
        now: now,
      ),
      isTrue,
    );
  });

  test('active session restores stable fallback image URLs', () async {
    final cache = FakeFeedCache();
    final store = FeedSessionStore(cache);
    final snapshot = FeedSessionSnapshot(
      surface: FeedSurface.articles,
      items: <FeedEntry>[
        ArticleFeedEntry(
          id: 1,
          title: 'Article 1',
          summary: 'Summary 1',
          source: 'Source',
          publishedAt: DateTime.parse('2026-03-18T09:00:00Z'),
          url: 'https://example.com/1',
          imageUrl: null,
          category: 'Technology',
          readTime: 3,
        ),
      ],
      currentItemId: 1,
      lastViewedIndex: 0,
      lastActiveAt: DateTime.parse('2026-03-18T18:00:00Z'),
      headBaselineIds: const [1],
      sessionId: 'session-1',
      continuationCursor: '15',
      hasMore: true,
      inventoryState: FeedInventoryState.healthy,
      lastFeedVersion: 'feed-v2',
    );

    await store.saveActiveSession(snapshot);
    final restored = await store.getActiveSession(FeedSurface.articles);

    expect(restored, isNotNull);
    final article = restored!.items.single as ArticleFeedEntry;
    expect(article.imageUrl, isNotNull);
    expect(article.imageUrl, contains('unsplash'));
  });
}
