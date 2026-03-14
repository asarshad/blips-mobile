@Tags(['unit'])
library ads_config_test;

import 'package:blips_mobile/features/ads/domain/ads_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdsConfig', () {
    test('default constructor is globally disabled', () {
      const config = AdsConfig();

      expect(config.enabled, isFalse);
      expect(config.eligible, isFalse);
      expect(config.provider, 'admob_native');
      expect(config.canaryPercent, 0);
      expect(config.configTtlSeconds, 300);
      expect(config.showFeedAds, isFalse);
      expect(config.showBannerAds, isFalse);
      expect(config.isSurfaceEnabled(AdSurface.articles), isFalse);
      expect(config.isSurfaceEnabled(AdSurface.videos), isFalse);
      expect(config.isSurfaceEnabled(AdSurface.reels), isFalse);
    });

    test('showFeedAds requires both enabled and eligible', () {
      const disabled = AdsConfig();
      const enabledOnly = AdsConfig(enabled: true);
      const eligibleOnly = AdsConfig(eligible: true);
      const enabledAndEligible = AdsConfig(enabled: true, eligible: true);

      expect(disabled.showFeedAds, isFalse);
      expect(enabledOnly.showFeedAds, isFalse);
      expect(eligibleOnly.showFeedAds, isFalse);
      expect(enabledAndEligible.showFeedAds, isTrue);
    });

    test('surface enablement respects the global gate', () {
      const config = AdsConfig(
        enabled: true,
        eligible: true,
        surfaces: AdsSurfacesConfig(
          articles:
              AdSurfaceConfig(enabled: true, frequency: 8, firstSlotAfter: 2),
          videos:
              AdSurfaceConfig(enabled: false, frequency: 8, firstSlotAfter: 2),
          reels:
              AdSurfaceConfig(enabled: true, frequency: 4, firstSlotAfter: 1),
        ),
      );

      expect(config.isSurfaceEnabled(AdSurface.articles), isTrue);
      expect(config.isSurfaceEnabled(AdSurface.videos), isFalse);
      expect(config.isSurfaceEnabled(AdSurface.reels), isTrue);
    });

    group('fromJson', () {
      test('parses the backend control-plane shape', () {
        final config = AdsConfig.fromJson({
          'enabled': true,
          'provider': 'admob_native',
          'eligible': true,
          'canary_percent': 20,
          'config_ttl_seconds': 120,
          'surfaces': {
            'articles': {
              'enabled': true,
              'frequency': 5,
              'first_slot_after': 2,
            },
            'videos': {
              'enabled': true,
              'frequency': 7,
              'first_slot_after': 3,
            },
            'reels': {
              'enabled': false,
              'frequency': 0,
              'first_slot_after': 0,
            },
          },
        });

        expect(config.enabled, isTrue);
        expect(config.provider, 'admob_native');
        expect(config.eligible, isTrue);
        expect(config.canaryPercent, 20);
        expect(config.configTtlSeconds, 120);
        expect(config.surfaceConfig(AdSurface.articles).frequency, 5);
        expect(config.surfaceConfig(AdSurface.videos).firstSlotAfter, 3);
        expect(config.surfaceConfig(AdSurface.reels).enabled, isFalse);
      });

      test('uses safe defaults for missing keys', () {
        final config = AdsConfig.fromJson({});

        expect(config.enabled, isFalse);
        expect(config.eligible, isFalse);
        expect(config.provider, 'admob_native');
        expect(config.configTtlSeconds, 300);
        expect(config.surfaceConfig(AdSurface.articles).frequency, 0);
        expect(config.surfaceConfig(AdSurface.videos).enabled, isFalse);
      });
    });
  });
}
