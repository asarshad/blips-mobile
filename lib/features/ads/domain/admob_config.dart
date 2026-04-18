import 'dart:io';

import 'package:blips_mobile/features/ads/domain/ads_config.dart';
import 'package:blips_mobile/features/ads/domain/ads_runtime_config.dart';
import 'package:flutter/foundation.dart';

/// Build-time AdMob configuration.
abstract final class AdMobConfig {
  static const nativeFactoryId = 'blipsFeedNative';

  static const _androidTestNativeAdUnitId =
      'ca-app-pub-3940256099942544/2247696110';
  static const _androidTestNativeVideoAdUnitId =
      'ca-app-pub-3940256099942544/1044960115';
  static const _iosTestNativeAdUnitId =
      'ca-app-pub-3940256099942544/3986624511';
  static const _iosTestNativeVideoAdUnitId =
      'ca-app-pub-3940256099942544/2521693316';

  static const _androidArticlesNativeAdUnitId = String.fromEnvironment(
    'BLIPS_ADMOB_ANDROID_ARTICLES_NATIVE_UNIT_ID',
    defaultValue: 'ca-app-pub-1680408170724576/6161377061',
  );
  static const _androidVideosNativeAdUnitId = String.fromEnvironment(
    'BLIPS_ADMOB_ANDROID_VIDEOS_NATIVE_UNIT_ID',
    defaultValue: 'ca-app-pub-1680408170724576/3131188345',
  );
  // Reels reuses the videos native ad unit until it has its own unit provisioned.
  // Override with --dart-define=BLIPS_ADMOB_ANDROID_REELS_NATIVE_UNIT_ID=... to
  // split reporting in AdMob.
  static const _androidReelsNativeAdUnitId = String.fromEnvironment(
    'BLIPS_ADMOB_ANDROID_REELS_NATIVE_UNIT_ID',
    defaultValue: 'ca-app-pub-1680408170724576/3131188345',
  );

  static const _iosArticlesNativeAdUnitId = String.fromEnvironment(
    'BLIPS_ADMOB_IOS_ARTICLES_NATIVE_UNIT_ID',
    defaultValue: 'ca-app-pub-1680408170724576/6225105608',
  );
  static const _iosVideosNativeAdUnitId = String.fromEnvironment(
    'BLIPS_ADMOB_IOS_VIDEOS_NATIVE_UNIT_ID',
    defaultValue: 'ca-app-pub-1680408170724576/8340133053',
  );
  // Reels reuses the videos native ad unit until it has its own unit provisioned.
  // Override with --dart-define=BLIPS_ADMOB_IOS_REELS_NATIVE_UNIT_ID=... to
  // split reporting in AdMob.
  static const _iosReelsNativeAdUnitId = String.fromEnvironment(
    'BLIPS_ADMOB_IOS_REELS_NATIVE_UNIT_ID',
    defaultValue: 'ca-app-pub-1680408170724576/8340133053',
  );

  static bool get supportsNativeAds {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  static String nativeAdUnitIdForSurface(
    AdSurface surface, {
    required AdsRuntimeConfig runtimeConfig,
  }) {
    if (runtimeConfig.usesTestAdUnits) {
      final useVideoTestUnit = switch (surface) {
        AdSurface.articles => false,
        AdSurface.videos => true,
        AdSurface.reels => true,
      };

      if (Platform.isIOS) {
        return useVideoTestUnit
            ? _iosTestNativeVideoAdUnitId
            : _iosTestNativeAdUnitId;
      }

      return useVideoTestUnit
          ? _androidTestNativeVideoAdUnitId
          : _androidTestNativeAdUnitId;
    }

    if (Platform.isIOS) {
      return switch (surface) {
        AdSurface.articles => _iosArticlesNativeAdUnitId,
        AdSurface.videos => _iosVideosNativeAdUnitId,
        AdSurface.reels => _iosReelsNativeAdUnitId,
      };
    }

    return switch (surface) {
      AdSurface.articles => _androidArticlesNativeAdUnitId,
      AdSurface.videos => _androidVideosNativeAdUnitId,
      AdSurface.reels => _androidReelsNativeAdUnitId,
    };
  }
}
