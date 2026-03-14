/// Supported ad surfaces in the app.
enum AdSurface {
  articles,
  videos,
  reels,
}

/// Per-surface ad configuration.
class AdSurfaceConfig {
  const AdSurfaceConfig({
    this.enabled = false,
    this.frequency = 0,
    this.firstSlotAfter = 0,
  });

  factory AdSurfaceConfig.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const <String, dynamic>{};
    return AdSurfaceConfig(
      enabled: data['enabled'] as bool? ?? false,
      frequency: data['frequency'] as int? ?? 0,
      firstSlotAfter: data['first_slot_after'] as int? ?? 0,
    );
  }

  final bool enabled;
  final int frequency;
  final int firstSlotAfter;
}

/// Surface bundle returned by the backend.
class AdsSurfacesConfig {
  const AdsSurfacesConfig({
    this.articles = const AdSurfaceConfig(),
    this.videos = const AdSurfaceConfig(),
    this.reels = const AdSurfaceConfig(),
  });

  factory AdsSurfacesConfig.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const <String, dynamic>{};
    return AdsSurfacesConfig(
      articles: AdSurfaceConfig.fromJson(
        data['articles'] as Map<String, dynamic>?,
      ),
      videos: AdSurfaceConfig.fromJson(
        data['videos'] as Map<String, dynamic>?,
      ),
      reels: AdSurfaceConfig.fromJson(
        data['reels'] as Map<String, dynamic>?,
      ),
    );
  }

  final AdSurfaceConfig articles;
  final AdSurfaceConfig videos;
  final AdSurfaceConfig reels;
}

/// Server-side ad configuration model.
///
/// Fetched from `GET /config` on app start and cached in memory. The backend
/// already applies device eligibility and surface toggles before returning it.
class AdsConfig {
  const AdsConfig({
    this.enabled = false,
    this.provider = 'admob_native',
    this.eligible = false,
    this.canaryPercent = 0,
    this.configTtlSeconds = 300,
    this.surfaces = const AdsSurfacesConfig(),
  });

  /// Parses from the `ads` sub-object of the `/config` response.
  factory AdsConfig.fromJson(Map<String, dynamic> json) {
    return AdsConfig(
      enabled: json['enabled'] as bool? ?? false,
      provider: json['provider'] as String? ?? 'admob_native',
      eligible: json['eligible'] as bool? ?? false,
      canaryPercent: json['canary_percent'] as int? ?? 0,
      configTtlSeconds: json['config_ttl_seconds'] as int? ?? 300,
      surfaces: AdsSurfacesConfig.fromJson(
        json['surfaces'] as Map<String, dynamic>?,
      ),
    );
  }

  /// Whether ads are globally enabled for this caller.
  final bool enabled;

  /// Ad provider selected by the backend control plane.
  final String provider;

  /// Whether the current device is eligible for ads after canary gating.
  final bool eligible;

  /// Percent of devices eligible to request ads.
  final int canaryPercent;

  /// TTL for config refreshes.
  final int configTtlSeconds;

  /// Surface-specific configuration.
  final AdsSurfacesConfig surfaces;

  Duration get configTtl => Duration(seconds: configTtlSeconds);

  /// Whether any feed surface should render ads for this caller.
  bool get showFeedAds => enabled && eligible;

  /// Banner surfaces are intentionally disabled in this rollout.
  bool get showBannerAds => false;

  AdSurfaceConfig surfaceConfig(AdSurface surface) {
    return switch (surface) {
      AdSurface.articles => surfaces.articles,
      AdSurface.videos => surfaces.videos,
      AdSurface.reels => surfaces.reels,
    };
  }

  bool isSurfaceEnabled(AdSurface surface) {
    return showFeedAds && surfaceConfig(surface).enabled;
  }
}
