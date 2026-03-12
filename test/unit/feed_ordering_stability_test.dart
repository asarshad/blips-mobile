@Tags(['unit'])
library feed_ordering_stability_test;

import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:blips_mobile/features/feed/domain/feed_ordering.dart';
import 'package:flutter_test/flutter_test.dart';

ArticleFeedEntry _article(int id) {
  return ArticleFeedEntry(
    id: id,
    title: 'Title $id',
    summary: 'Summary $id',
    source: 'source',
    publishedAt: DateTime.utc(2026, 3, id.clamp(1, 28)),
    url: 'https://example.com/$id',
    imageUrl: 'https://example.com/$id.png',
    category: 'Technology',
    readTime: 1,
    tags: const ['Technology'],
  );
}

void main() {
  group('mergeFeedWithStableOrdering', () {
    test(
      'keeps current order when fresh contains same ids in different order',
      () {
        final current = [_article(1), _article(2), _article(3)];
        final fresh = [_article(3), _article(1), _article(2)];

        final merged = mergeFeedWithStableOrdering(
          currentItems: current,
          freshItems: fresh,
        );

        expect(merged.map((e) => e.id).toList(), [1, 2, 3]);
      },
    );

    test('prepends newly approved items while preserving old order', () {
      final current = [_article(1), _article(2), _article(3)];
      final fresh = [_article(9), _article(3), _article(2), _article(1)];

      final merged = mergeFeedWithStableOrdering(
        currentItems: current,
        freshItems: fresh,
      );

      expect(merged.map((e) => e.id).toList(), [9, 1, 2, 3]);
    });

    test('preserves deep-loaded items missing from page-1 refresh payload', () {
      final current = [_article(1), _article(2), _article(3)];
      final fresh = [_article(3), _article(1)];

      final merged = mergeFeedWithStableOrdering(
        currentItems: current,
        freshItems: fresh,
      );

      expect(merged.map((e) => e.id).toList(), [1, 2, 3]);
    });

    test('does not prepend new items when prependNewItems is false', () {
      final current = [_article(1), _article(2), _article(3)];
      final fresh = [_article(9), _article(3), _article(2), _article(1)];

      final merged = mergeFeedWithStableOrdering(
        currentItems: current,
        freshItems: fresh,
        prependNewItems: false,
      );

      expect(merged.map((e) => e.id).toList(), [1, 2, 3]);
    });
  });
}
