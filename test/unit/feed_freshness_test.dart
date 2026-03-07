@Tags(['unit'])
library feed_freshness_test;

import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:blips_mobile/features/feed/domain/feed_freshness.dart';
import 'package:flutter_test/flutter_test.dart';

ArticleFeedEntry _article({
  required int id,
  required DateTime publishedAt,
  DateTime? addedAt,
}) {
  return ArticleFeedEntry(
    id: id,
    title: 't$id',
    summary: 'summary',
    source: 'src',
    publishedAt: publishedAt,
    addedAt: addedAt,
    url: 'https://example.com/$id',
    imageUrl: 'https://example.com/$id.png',
    category: 'Technology',
    readTime: 1,
    tags: const ['Technology'],
  );
}

void main() {
  group('computeNewSinceLastSeenIds', () {
    test('returns empty when no last-seen timestamp exists', () {
      final ids = computeNewSinceLastSeenIds(
        entries: [_article(id: 1, publishedAt: DateTime.utc(2026, 3, 1))],
        lastSeenAt: null,
      );

      expect(ids, isEmpty);
    });

    test('prefers addedAt when deciding if an entry is new', () {
      final cutoff = DateTime.utc(2026, 3, 1, 12);
      final ids = computeNewSinceLastSeenIds(
        entries: [
          _article(
            id: 10,
            publishedAt: DateTime.utc(2026, 2, 20),
            addedAt: DateTime.utc(2026, 3, 2),
          ),
          _article(
            id: 11,
            publishedAt: DateTime.utc(2026, 2, 25),
            addedAt: DateTime.utc(2026, 2, 28),
          ),
        ],
        lastSeenAt: cutoff,
      );

      expect(ids, {10});
    });

    test('falls back to publishedAt when addedAt is absent', () {
      final cutoff = DateTime.utc(2026, 3, 1, 12);
      final ids = computeNewSinceLastSeenIds(
        entries: [
          _article(id: 20, publishedAt: DateTime.utc(2026, 3, 2)),
          _article(id: 21, publishedAt: DateTime.utc(2026, 2, 28)),
        ],
        lastSeenAt: cutoff,
      );

      expect(ids, {20});
    });
  });
}
