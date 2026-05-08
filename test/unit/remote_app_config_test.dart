@Tags(['unit'])
library remote_app_config_test;

import 'package:blips_mobile/core/config/remote_app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RemoteAppConfig', () {
    test('defaults to disabled-safe config when payload is null', () {
      final config = RemoteAppConfig.fromJson(null);

      expect(config.ads.enabled, isFalse);
      expect(config.push.enabled, isFalse);
      expect(config.push.mode, 'disabled');
      expect(config.cacheTtl, const Duration(seconds: 300));
      expect(config.minRecommendedVersion, isNull);
      expect(config.iosAppStoreUrl, isNull);
      expect(config.androidPlayStoreUrl, isNull);
    });

    test('parses push block and uses minimum ttl between ads and push', () {
      final config = RemoteAppConfig.fromJson(<String, dynamic>{
        'ads': <String, dynamic>{
          'enabled': true,
          'eligible': true,
          'config_ttl_seconds': 600,
        },
        'push': <String, dynamic>{
          'enabled': true,
          'mode': 'manual',
          'config_ttl_seconds': 120,
        },
      });

      expect(config.push.enabled, isTrue);
      expect(config.push.mode, 'manual');
      expect(config.push.configTtlSeconds, 120);
      expect(config.cacheTtl, const Duration(seconds: 120));
    });

    group('update nudge fields', () {
      test('parses min_recommended_version when present and non-empty', () {
        final config = RemoteAppConfig.fromJson(<String, dynamic>{
          'min_recommended_version': '1.0.5',
          'ios_app_store_url': 'https://apps.apple.com/app/id1234567890',
          'android_play_store_url':
              'https://play.google.com/store/apps/details?id=com.blips.blips_mobile',
        });

        expect(config.minRecommendedVersion, '1.0.5');
        expect(
          config.iosAppStoreUrl,
          'https://apps.apple.com/app/id1234567890',
        );
        expect(
          config.androidPlayStoreUrl,
          'https://play.google.com/store/apps/details?id=com.blips.blips_mobile',
        );
      });

      test('treats empty string min_recommended_version as null (nudge off)',
          () {
        final config = RemoteAppConfig.fromJson(<String, dynamic>{
          'min_recommended_version': '',
        });

        expect(config.minRecommendedVersion, isNull);
      });

      test('missing update nudge fields default to null', () {
        final config = RemoteAppConfig.fromJson(<String, dynamic>{
          'ads': <String, dynamic>{'enabled': true},
        });

        expect(config.minRecommendedVersion, isNull);
        expect(config.iosAppStoreUrl, isNull);
        expect(config.androidPlayStoreUrl, isNull);
      });

      test('normalises empty store URL strings to null', () {
        final config = RemoteAppConfig.fromJson(<String, dynamic>{
          'min_recommended_version': '1.0.5',
          'ios_app_store_url': '',
          'android_play_store_url': '',
        });

        expect(config.iosAppStoreUrl, isNull);
        expect(config.androidPlayStoreUrl, isNull);
      });
    });
  });
}
