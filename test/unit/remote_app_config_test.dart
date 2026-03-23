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
  });
}
