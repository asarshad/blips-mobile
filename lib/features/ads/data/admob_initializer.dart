import 'dart:async';

import 'package:blips_mobile/core/error/error.dart';
import 'package:blips_mobile/features/ads/domain/ads_config.dart';
import 'package:blips_mobile/features/ads/domain/ads_runtime_config.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

abstract class MobileAdsClient {
  Future<void> initialize();

  Future<void> updateRequestConfiguration(RequestConfiguration configuration);
}

class GoogleMobileAdsClient implements MobileAdsClient {
  const GoogleMobileAdsClient();

  @override
  Future<void> initialize() async {
    await MobileAds.instance.initialize();
  }

  @override
  Future<void> updateRequestConfiguration(
    RequestConfiguration configuration,
  ) {
    return MobileAds.instance.updateRequestConfiguration(configuration);
  }
}

class AdMobInitializer {
  AdMobInitializer(this._client);

  final MobileAdsClient _client;
  Future<void>? _initializationFuture;
  bool _initialized = false;

  bool get isInitialized => _initialized;

  Future<void> ensureInitialized({
    required AdsRuntimeConfig runtimeConfig,
    required AdsConfig adsConfig,
  }) {
    if (!runtimeConfig.usesSdkAds) {
      logger.info(
        'AdMob skipped in mock ads mode',
        category: LogCategory.lifecycle,
      );
      return Future.value();
    }

    if (!adsConfig.showFeedAds || !adsConfig.hasAdMobProvider) {
      logger.info(
        'AdMob deferred until remote config enables feed ads',
        category: LogCategory.lifecycle,
      );
      return Future.value();
    }

    if (_initialized) {
      return Future.value();
    }

    final inFlight = _initializationFuture;
    if (inFlight != null) {
      return inFlight;
    }

    final future = _initialize(runtimeConfig);
    _initializationFuture = future;
    return future.whenComplete(() {
      if (!_initialized) {
        _initializationFuture = null;
      }
    });
  }

  Future<void> _initialize(AdsRuntimeConfig runtimeConfig) async {
    try {
      if (runtimeConfig.testDeviceIds.isNotEmpty) {
        await _client.updateRequestConfiguration(
          RequestConfiguration(testDeviceIds: runtimeConfig.testDeviceIds),
        );
      }
      await _client.initialize();
      _initialized = true;
      logger.info('AdMob initialized', category: LogCategory.lifecycle);
    } catch (e, stackTrace) {
      logger.warning(
        'AdMob initialization failed',
        category: LogCategory.app,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
