import 'package:blips_mobile/features/ads/domain/ads_config.dart';

/// Server-side push configuration returned by `GET /config`.
class PushConfig {
  const PushConfig({
    this.enabled = false,
    this.mode = 'disabled',
    this.configTtlSeconds = 300,
  });

  factory PushConfig.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const <String, dynamic>{};
    return PushConfig(
      enabled: data['enabled'] as bool? ?? false,
      mode: data['mode'] as String? ?? 'disabled',
      configTtlSeconds: data['config_ttl_seconds'] as int? ?? 300,
    );
  }

  final bool enabled;
  final String mode;
  final int configTtlSeconds;

  Duration get configTtl => Duration(seconds: configTtlSeconds);
}

/// Combined remote application config returned by the backend.
class RemoteAppConfig {
  const RemoteAppConfig({
    this.ads = const AdsConfig(),
    this.push = const PushConfig(),
    this.minRecommendedVersion,
    this.iosAppStoreUrl,
    this.androidPlayStoreUrl,
  });

  factory RemoteAppConfig.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const <String, dynamic>{};
    final minVersion = data['min_recommended_version'] as String?;
    return RemoteAppConfig(
      ads: AdsConfig.fromJson(
        data['ads'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      push: PushConfig.fromJson(
        data['push'] as Map<String, dynamic>?,
      ),
      minRecommendedVersion:
          (minVersion != null && minVersion.isNotEmpty) ? minVersion : null,
      iosAppStoreUrl: _emptyToNull(data['ios_app_store_url'] as String?),
      androidPlayStoreUrl:
          _emptyToNull(data['android_play_store_url'] as String?),
    );
  }

  final AdsConfig ads;
  final PushConfig push;

  /// Semver string (e.g. "1.0.5") below which clients are nudged to update.
  /// Null or empty means the nudge is disabled.
  final String? minRecommendedVersion;

  /// App Store URL for the iOS update button (may be null if not configured).
  final String? iosAppStoreUrl;

  /// Play Store URL for the Android update button (may be null if not configured).
  final String? androidPlayStoreUrl;

  static String? _emptyToNull(String? s) =>
      (s == null || s.isEmpty) ? null : s;

  Duration get cacheTtl {
    final adTtl = ads.configTtl;
    final pushTtl = push.configTtl;
    return adTtl <= pushTtl ? adTtl : pushTtl;
  }
}
