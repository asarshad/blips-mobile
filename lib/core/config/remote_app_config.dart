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
  });

  factory RemoteAppConfig.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const <String, dynamic>{};
    return RemoteAppConfig(
      ads: AdsConfig.fromJson(
        data['ads'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      push: PushConfig.fromJson(
        data['push'] as Map<String, dynamic>?,
      ),
    );
  }

  final AdsConfig ads;
  final PushConfig push;

  Duration get cacheTtl {
    final adTtl = ads.configTtl;
    final pushTtl = push.configTtl;
    return adTtl <= pushTtl ? adTtl : pushTtl;
  }
}
