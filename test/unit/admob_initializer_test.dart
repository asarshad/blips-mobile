@Tags(['unit'])
library admob_initializer_test;

import 'package:blips_mobile/features/ads/data/admob_initializer.dart';
import 'package:blips_mobile/features/ads/domain/ads_config.dart';
import 'package:blips_mobile/features/ads/domain/ads_runtime_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class _FakeMobileAdsClient implements MobileAdsClient {
  int initializeCalls = 0;
  final List<RequestConfiguration> configurations = <RequestConfiguration>[];
  bool failInitialization = false;

  @override
  Future<void> initialize() async {
    initializeCalls++;
    if (failInitialization) {
      throw StateError('init failed');
    }
  }

  @override
  Future<void> updateRequestConfiguration(
    RequestConfiguration configuration,
  ) async {
    configurations.add(configuration);
  }
}

void main() {
  group('AdMobInitializer', () {
    test('does not initialize in production while backend ads remain off',
        () async {
      final client = _FakeMobileAdsClient();
      final initializer = AdMobInitializer(client);

      await initializer.ensureInitialized(
        runtimeConfig: const AdsRuntimeConfig(mode: AdsMode.production),
        adsConfig: const AdsConfig(),
      );

      expect(client.initializeCalls, 0);
      expect(client.configurations, isEmpty);
      expect(initializer.isInitialized, isFalse);
    });

    test('initializes once after backend enables AdMob feed ads', () async {
      final client = _FakeMobileAdsClient();
      final initializer = AdMobInitializer(client);
      const adsConfig = AdsConfig(
        enabled: true,
        eligible: true,
        provider: 'admob_native',
      );

      await initializer.ensureInitialized(
        runtimeConfig: const AdsRuntimeConfig(mode: AdsMode.production),
        adsConfig: adsConfig,
      );
      await initializer.ensureInitialized(
        runtimeConfig: const AdsRuntimeConfig(mode: AdsMode.production),
        adsConfig: adsConfig,
      );

      expect(client.initializeCalls, 1);
      expect(initializer.isInitialized, isTrue);
    });

    test('applies registered test device ids in admob test mode', () async {
      final client = _FakeMobileAdsClient();
      final initializer = AdMobInitializer(client);
      final adsConfig = const AdsConfig().forceEnableFeedAds();

      await initializer.ensureInitialized(
        runtimeConfig: const AdsRuntimeConfig(
          mode: AdsMode.admobTest,
          testDeviceIds: <String>['test-device-1', 'test-device-2'],
        ),
        adsConfig: adsConfig,
      );

      expect(client.initializeCalls, 1);
      expect(client.configurations, hasLength(1));
      expect(
        client.configurations.single.testDeviceIds,
        <String>['test-device-1', 'test-device-2'],
      );
    });

    test('skips initialization when runtime mode is mock', () async {
      final client = _FakeMobileAdsClient();
      final initializer = AdMobInitializer(client);

      await initializer.ensureInitialized(
        runtimeConfig: const AdsRuntimeConfig(mode: AdsMode.mock),
        adsConfig: const AdsConfig(
          enabled: true,
          eligible: true,
          provider: 'admob_native',
        ),
      );

      expect(client.initializeCalls, 0);
      expect(initializer.isInitialized, isFalse);
    });

    test('can retry after a failed initialization attempt', () async {
      final client = _FakeMobileAdsClient()..failInitialization = true;
      final initializer = AdMobInitializer(client);
      const adsConfig = AdsConfig(
        enabled: true,
        eligible: true,
        provider: 'admob_native',
      );

      await expectLater(
        initializer.ensureInitialized(
          runtimeConfig: const AdsRuntimeConfig(mode: AdsMode.production),
          adsConfig: adsConfig,
        ),
        throwsStateError,
      );

      client.failInitialization = false;
      await initializer.ensureInitialized(
        runtimeConfig: const AdsRuntimeConfig(mode: AdsMode.production),
        adsConfig: adsConfig,
      );

      expect(client.initializeCalls, 2);
      expect(initializer.isInitialized, isTrue);
    });
  });
}
