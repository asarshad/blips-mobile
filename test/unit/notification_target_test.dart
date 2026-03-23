@Tags(['unit'])
library notification_target_test;

import 'package:blips_mobile/features/notifications/domain/notification_target.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NotificationTarget', () {
    test('parses valid message data with payload_version fallback', () {
      final target = NotificationTarget.fromJson(const <String, dynamic>{
        'surface': 'videos',
        'contentId': '42',
        'payload_version': '2',
      });

      expect(target.surface, NotificationSurface.videos);
      expect(target.contentId, 42);
      expect(target.payloadVersion, 2);
    });

    test('round-trips encoded payload', () {
      const original = NotificationTarget(
        surface: NotificationSurface.articles,
        contentId: 99,
        payloadVersion: 3,
      );

      final restored = NotificationTarget.fromEncodedPayload(
        original.toEncodedPayload(),
      );

      expect(restored, original);
    });

    test('tryFromMessageData returns null for invalid target', () {
      final target = NotificationTarget.tryFromMessageData(
        const <String, dynamic>{
          'surface': 'reels',
          'contentId': 12,
        },
      );

      expect(target, isNull);
    });

    test('tryFromPayload returns null for blank or malformed payload', () {
      expect(NotificationTarget.tryFromPayload(null), isNull);
      expect(NotificationTarget.tryFromPayload('   '), isNull);
      expect(NotificationTarget.tryFromPayload('not-json'), isNull);
    });
  });
}
