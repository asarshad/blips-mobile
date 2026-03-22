@Tags(['unit'])
library feed_freshness_test;

import 'package:blips_mobile/features/feed/domain/feed_freshness.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('countLeadingHeadNewItems', () {
    test('counts new items only before the first baseline overlap', () {
      expect(
        countLeadingHeadNewItems(
          baselineIds: const [100, 101, 102, 103],
          freshHeadIds: const [200, 201, 100, 101],
        ),
        2,
      );
    });

    test('does not count lower-head rotations when the top item is unchanged',
        () {
      expect(
        countLeadingHeadNewItems(
          baselineIds: const [100, 101, 102, 103],
          freshHeadIds: const [100, 101, 300, 102],
        ),
        0,
      );
    });

    test('returns zero when there is no baseline', () {
      expect(
        countLeadingHeadNewItems(
          baselineIds: const [],
          freshHeadIds: const [200, 201, 202],
        ),
        0,
      );
    });

    test('returns full fresh prefix when nothing overlaps yet', () {
      expect(
        countLeadingHeadNewItems(
          baselineIds: const [100, 101, 102],
          freshHeadIds: const [200, 201, 202],
        ),
        3,
      );
    });
  });
}
