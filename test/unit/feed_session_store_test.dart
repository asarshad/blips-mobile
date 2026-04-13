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
  PendingFeedActionKind pendingActionKind = PendingFeedActionKind.newItems,
  String? lastFreshnessStrategy,
  int? resumeContinuationWindowMinutes,
  bool? resumeSnapshotAfterRemoteWindow,
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
    pendingActionKind: pendingActionKind,
    lastFeedVersion: 'feed-v1',
    lastFreshnessStrategy: lastFreshnessStrategy,
    resumeContinuationWindowMinutes: resumeContinuationWindowMinutes,
    resumeSnapshotAfterRemoteWindow: resumeSnapshotAfterRemoteWindow,
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
        lastActiveAt: now.subtract(const Duration(minutes: 8)),
        lastFreshnessStrategy: kFeedFreshnessStrategyArticleRecentHeadV1,
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
    expect(
      decision.resumeSnapshot!.pendingActionKind,
      PendingFeedActionKind.newItems,
    );
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

  test(
      'prepareRestore prefers latest for recent-head article sessions after 10 minutes',
      () async {
    final cache = FakeFeedCache();
    final store = FeedSessionStore(cache);
    final now = DateTime.parse('2026-03-19T08:30:00Z');

    await store.saveActiveSession(
      _snapshot(
        surface: FeedSurface.articles,
        lastActiveAt: now.subtract(const Duration(minutes: 14)),
        lastFreshnessStrategy: kFeedFreshnessStrategyArticleRecentHeadV1,
        resumeContinuationWindowMinutes: 10,
        resumeSnapshotAfterRemoteWindow: false,
      ),
    );

    final decision = await store.prepareRestore(
      FeedSurface.articles,
      now: now,
    );

    expect(decision.resumeSnapshot, isNull);
    expect(decision.preferLatestOnRefresh, isTrue);
    expect(
      await store.getActiveSession(FeedSurface.articles),
      isNull,
    );
  });

  test(
      'article remote continuation expires after 10 minutes for recent-head strategy',
      () async {
    final cache = FakeFeedCache();
    final store = FeedSessionStore(cache);
    final now = DateTime.parse('2026-03-19T08:30:00Z');
    final snapshot = _snapshot(
      surface: FeedSurface.articles,
      lastActiveAt: now.subtract(const Duration(minutes: 11)),
      lastFreshnessStrategy: kFeedFreshnessStrategyArticleRecentHeadV1,
      resumeContinuationWindowMinutes: 10,
      resumeSnapshotAfterRemoteWindow: false,
    );

    expect(
      store.isRemoteContinuationFresh(
        FeedSurface.articles,
        snapshot,
        now: now,
      ),
      isFalse,
    );
  });

  test(
      'article remote continuation uses backend window for recent-head strategy',
      () async {
    final cache = FakeFeedCache();
    final store = FeedSessionStore(cache);
    final now = DateTime.parse('2026-03-19T08:30:00Z');
    final snapshot = _snapshot(
      surface: FeedSurface.articles,
      lastActiveAt: now.subtract(const Duration(minutes: 9)),
      lastFreshnessStrategy: kFeedFreshnessStrategyArticleRecentHeadV1,
      resumeContinuationWindowMinutes: 10,
      resumeSnapshotAfterRemoteWindow: false,
    );

    expect(
      store.isRemoteContinuationFresh(
        FeedSurface.articles,
        snapshot,
        now: now,
      ),
      isTrue,
    );
  });

  test('article resume policy honors backend-provided continuation window',
      () async {
    final cache = FakeFeedCache();
    final store = FeedSessionStore(cache);
    final now = DateTime.parse('2026-03-19T08:30:00Z');

    await store.saveActiveSession(
      _snapshot(
        surface: FeedSurface.articles,
        lastActiveAt: now.subtract(const Duration(minutes: 14)),
        lastFreshnessStrategy: kFeedFreshnessStrategyArticleRecentHeadV1,
        resumeContinuationWindowMinutes: 10,
        resumeSnapshotAfterRemoteWindow: false,
      ),
    );

    final decision = await store.prepareRestore(
      FeedSurface.articles,
      now: now,
    );

    expect(decision.resumeSnapshot, isNull);
    expect(decision.preferLatestOnRefresh, isTrue);
  });

  test('prepareRestore keeps reels stable after longer inactivity',
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
    expect(decision.preferLatestOnRefresh, isFalse);
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

  test('getLastSurface restores a recent surface selection', () async {
    final cache = FakeFeedCache();
    final store = FeedSessionStore(cache);
    final now = DateTime.parse('2026-03-23T18:00:00Z');

    await store.setLastSurface(
      FeedSurface.reels,
      at: now.subtract(const Duration(minutes: 10)),
    );

    expect(
      await store.getLastSurface(now: now),
      FeedSurface.reels,
    );
  });

  test('getLastSurface expires stale surface selection', () async {
    final cache = FakeFeedCache();
    final store = FeedSessionStore(cache);
    final now = DateTime.parse('2026-03-23T18:00:00Z');

    await store.setLastSurface(
      FeedSurface.videos,
      at: now.subtract(const Duration(hours: 2)),
    );

    expect(
      await store.getLastSurface(now: now),
      isNull,
    );
    expect(await cache.getMeta('feed_last_surface'), isNull);
  });

  test('getLastSurface drops legacy plain-string values', () async {
    final cache = FakeFeedCache();
    final store = FeedSessionStore(cache);

    await cache.setMeta('feed_last_surface', FeedSurface.reels.storageKey);

    expect(
      await store.getLastSurface(now: DateTime.parse('2026-03-23T18:00:00Z')),
      isNull,
    );
    expect(await cache.getMeta('feed_last_surface'), isNull);
  });

  test('active session preserves null article image URLs', () async {
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
    expect(article.imageUrl, isNull);
  });

  test('active session preserves latest-bias pending action kind', () async {
    final cache = FakeFeedCache();
    final store = FeedSessionStore(cache);

    await store.saveActiveSession(
      _snapshot(
        surface: FeedSurface.reels,
        lastActiveAt: DateTime.parse('2026-03-18T18:00:00Z'),
        pendingActionKind: PendingFeedActionKind.latestBias,
      ),
    );

    final restored = await store.getActiveSession(FeedSurface.reels);

    expect(restored, isNotNull);
    expect(restored!.pendingActionKind, PendingFeedActionKind.latestBias);
  });
}
