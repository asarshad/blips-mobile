@Tags(['unit'])
library feed_mappers_test;

import 'package:blips_mobile/features/feed/data/mappers/feed_mappers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolvePublishedDate', () {
    test('uses published when parseable', () {
      final dt = resolvePublishedDate(
        '2025-01-02T03:04:05Z',
        null,
        now: () => DateTime(2000, 1, 1),
      );
      expect(dt.toUtc(), DateTime.parse('2025-01-02T03:04:05Z'));
    });

    test('falls back to now when published is unparseable', () {
      final fakeNow = DateTime.utc(2030, 1, 1, 12, 0, 0);
      final dt = resolvePublishedDate(
        'not-a-date',
        null,
        now: () => fakeNow,
      );
      expect(dt, fakeNow);
    });

    test('uses created when published missing', () {
      final dt = resolvePublishedDate(
        null,
        '2024-06-01T00:00:00Z',
        now: () => DateTime.utc(2030, 1, 1),
      );
      expect(dt.toUtc(), DateTime.parse('2024-06-01T00:00:00Z'));
    });

    test('falls back to now when both missing', () {
      final fakeNow = DateTime.utc(2040, 2, 3, 4, 5, 6);
      final dt = resolvePublishedDate(null, null, now: () => fakeNow);
      expect(dt, fakeNow);
    });
  });
}
