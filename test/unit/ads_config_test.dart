@Tags(['unit'])
library ads_config_test;

import 'package:blips_mobile/features/ads/domain/ads_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdsConfig', () {
    test('default constructor has everything disabled', () {
      const config = AdsConfig();
      expect(config.adsEnabled, isFalse);
      expect(config.adsFeedCardEnabled, isFalse);
      expect(config.adsBannerEnabled, isFalse);
      expect(config.adsFeedFrequency, 0);
      expect(config.adsCanaryPercent, 0);
      expect(config.showFeedAds, isFalse);
      expect(config.showBannerAds, isFalse);
    });

    test('showFeedAds requires both flags true', () {
      const bothOff = AdsConfig();
      expect(bothOff.showFeedAds, isFalse);

      const masterOnly = AdsConfig(adsEnabled: true);
      expect(masterOnly.showFeedAds, isFalse);

      const feedOnly = AdsConfig(adsFeedCardEnabled: true);
      expect(feedOnly.showFeedAds, isFalse);

      const bothOn = AdsConfig(adsEnabled: true, adsFeedCardEnabled: true);
      expect(bothOn.showFeedAds, isTrue);
    });

    test('showBannerAds requires both flags true', () {
      const bothOff = AdsConfig();
      expect(bothOff.showBannerAds, isFalse);

      const masterOnly = AdsConfig(adsEnabled: true);
      expect(masterOnly.showBannerAds, isFalse);

      const bannerOnly = AdsConfig(adsBannerEnabled: true);
      expect(bannerOnly.showBannerAds, isFalse);

      const bothOn = AdsConfig(adsEnabled: true, adsBannerEnabled: true);
      expect(bothOn.showBannerAds, isTrue);
    });

    group('fromJson', () {
      test('parses all fields', () {
        final config = AdsConfig.fromJson({
          'ads_enabled': true,
          'ads_feed_card_enabled': true,
          'ads_banner_enabled': true,
          'ads_feed_frequency': 5,
          'ads_canary_percent': 20,
        });

        expect(config.adsEnabled, isTrue);
        expect(config.adsFeedCardEnabled, isTrue);
        expect(config.adsBannerEnabled, isTrue);
        expect(config.adsFeedFrequency, 5);
        expect(config.adsCanaryPercent, 20);
      });

      test('uses defaults for missing keys', () {
        final config = AdsConfig.fromJson({});
        expect(config.adsEnabled, isFalse);
        expect(config.adsFeedCardEnabled, isFalse);
        expect(config.adsBannerEnabled, isFalse);
        expect(config.adsFeedFrequency, 0);
        expect(config.adsCanaryPercent, 0);
      });

      test('handles null values gracefully', () {
        final config = AdsConfig.fromJson({
          'ads_enabled': null,
          'ads_feed_card_enabled': null,
        });
        expect(config.adsEnabled, isFalse);
        expect(config.adsFeedCardEnabled, isFalse);
      });
    });
  });
}
