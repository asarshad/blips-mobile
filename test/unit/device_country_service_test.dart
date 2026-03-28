import 'dart:ui' show Locale;

import 'package:blips_mobile/core/services/device_country_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('loadDeviceCountryCode', () {
    test('returns the normalized locale country code when available', () {
      expect(
        loadDeviceCountryCode(locale: const Locale('en', 'ca')),
        'CA',
      );
    });

    test('falls back to the locale language tag when country code is missing',
        () {
      expect(
        loadDeviceCountryCode(
          locale: const Locale('en'),
          languageTag: 'en-GB',
        ),
        'GB',
      );
    });

    test('returns null when no country code can be resolved', () {
      expect(
        loadDeviceCountryCode(
          locale: const Locale('en'),
          languageTag: 'en-419',
        ),
        isNull,
      );
    });
  });

  group('normalizeCountryCode', () {
    test('trims and uppercases valid country codes', () {
      expect(normalizeCountryCode(' us '), 'US');
    });

    test('rejects values that are not alpha-2 country codes', () {
      expect(normalizeCountryCode('419'), isNull);
      expect(normalizeCountryCode('usa'), isNull);
    });
  });
}
