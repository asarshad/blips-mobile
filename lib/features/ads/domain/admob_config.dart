import 'dart:io';

import 'package:blips_mobile/features/ads/domain/ads_config.dart';
import 'package:flutter/foundation.dart';

/// Build-time AdMob configuration.
abstract final class AdMobConfig {
  static const nativeFactoryId = 'blipsFeedNative';

  static const _androidTestNativeAdUnitId =
      'ca-app-pub-3940256099942544/2247696110';
  static const _iosTestNativeAdUnitId =
      'ca-app-pub-3940256099942544/3986624511';

  static const _androidArticlesNativeAdUnitId = String.fromEnvironment(
    'BLIPS_ADMOB_ANDROID_ARTICLES_NATIVE_UNIT_ID',
    defaultValue: _androidTestNativeAdUnitId,
  );
  static const _androidVideosNativeAdUnitId = String.fromEnvironment(
    'BLIPS_ADMOB_ANDROID_VIDEOS_NATIVE_UNIT_ID',
    defaultValue: _androidTestNativeAdUnitId,
  );
  static const _androidReelsNativeAdUnitId = String.fromEnvironment(
    'BLIPS_ADMOB_ANDROID_REELS_NATIVE_UNIT_ID',
    defaultValue: _androidTestNativeAdUnitId,
  );

  static const _iosArticlesNativeAdUnitId = String.fromEnvironment(
    'BLIPS_ADMOB_IOS_ARTICLES_NATIVE_UNIT_ID',
    defaultValue: 'ca-app-pub-1680408170724576/6225105608',
  );
  static const _iosVideosNativeAdUnitId = String.fromEnvironment(
    'BLIPS_ADMOB_IOS_VIDEOS_NATIVE_UNIT_ID',
    defaultValue: 'ca-app-pub-1680408170724576/8340133053',
  );
  static const _iosReelsNativeAdUnitId = String.fromEnvironment(
    'BLIPS_ADMOB_IOS_REELS_NATIVE_UNIT_ID',
    defaultValue: _iosTestNativeAdUnitId,
  );

  static bool get supportsNativeAds {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  static String nativeAdUnitIdForSurface(AdSurface surface) {
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
