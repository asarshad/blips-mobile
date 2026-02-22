/// Ad-provider interface — swap this implementation to integrate a
/// real ad SDK later (e.g. AdMob, AppLovin, etc.).
///
/// The default [NoOpAdProvider] returns nothing and makes no network
/// calls.  The contract exists so that enabling ads later is a single
/// implementation swap.
import 'package:blips_mobile/features/ads/domain/ad_entry.dart';

/// Abstract contract for fetching ad creatives.
abstract interface class AdProvider {
  /// Request an ad for the given [placementId].
  ///
  /// Returns `null` when no fill is available.
  Future<AdFeedEntry?> requestAd(String placementId);

  /// Notify the provider that an ad was displayed.
  Future<void> recordImpression(String adId);

  /// Notify the provider that an ad was tapped.
  Future<void> recordClick(String adId);

  /// Release resources held by the provider (if any).
  void dispose();
}

/// Default no-op implementation — ships with zero SDK dependencies.
class NoOpAdProvider implements AdProvider {
  const NoOpAdProvider();

  @override
  Future<AdFeedEntry?> requestAd(String placementId) async => null;

  @override
  Future<void> recordImpression(String adId) async {}

  @override
  Future<void> recordClick(String adId) async {}

  @override
  void dispose() {}
}
