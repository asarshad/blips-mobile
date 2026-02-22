/// Server-side ad configuration model.
///
/// Fetched from `GET /config` on app start and cached. All flags
/// default to disabled so the app never shows ads unless the server
/// explicitly enables them.
class AdsConfig {
  const AdsConfig({
    this.adsEnabled = false,
    this.adsFeedCardEnabled = false,
    this.adsBannerEnabled = false,
    this.adsFeedFrequency = 0,
    this.adsCanaryPercent = 0,
  });

  /// Parses from the `ads` sub-object of the `/config` response.
  factory AdsConfig.fromJson(Map<String, dynamic> json) {
    return AdsConfig(
      adsEnabled: json['ads_enabled'] as bool? ?? false,
      adsFeedCardEnabled: json['ads_feed_card_enabled'] as bool? ?? false,
      adsBannerEnabled: json['ads_banner_enabled'] as bool? ?? false,
      adsFeedFrequency: json['ads_feed_frequency'] as int? ?? 0,
      adsCanaryPercent: json['ads_canary_percent'] as int? ?? 0,
    );
  }

  /// Global kill switch — if false, all ad surfaces are hidden.
  final bool adsEnabled;

  /// Whether feed-card ad slots are active.
  final bool adsFeedCardEnabled;

  /// Whether banner slots are active.
  final bool adsBannerEnabled;

  /// Insert one ad every N organic items (0 = disabled).
  final int adsFeedFrequency;

  /// Percent of requests that receive ads (gradual rollout).
  final int adsCanaryPercent;

  /// Convenience — returns true only when the full ad pipeline is active
  /// and the feed card surface specifically is enabled.
  bool get showFeedAds => adsEnabled && adsFeedCardEnabled;

  /// Returns true only when banner surface is active.
  bool get showBannerAds => adsEnabled && adsBannerEnabled;
}
