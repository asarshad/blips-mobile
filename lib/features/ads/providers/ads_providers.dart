import 'package:blips_mobile/core/network/backend_api_client.dart';
import 'package:blips_mobile/core/network/dio_provider.dart';
import 'package:blips_mobile/features/ads/data/app_config_repository.dart';
import 'package:blips_mobile/features/ads/data/event_service.dart';
import 'package:blips_mobile/features/ads/domain/ad_provider.dart';
import 'package:blips_mobile/features/ads/domain/ads_config.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Provides a singleton [AppConfigRepository].
final appConfigRepositoryProvider = Provider<AppConfigRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return AppConfigRepository(DioBackendApiClient(dio));
});

/// Fetches [AdsConfig] from the backend on first read and caches it.
///
/// Use `ref.invalidate(adsConfigProvider)` to force refetch.
/// On failure, returns a safe default with everything disabled.
final adsConfigProvider = FutureProvider<AdsConfig>((ref) {
  final repo = ref.watch(appConfigRepositoryProvider);
  return repo.fetchAdsConfig();
});

/// Provides the current [AdProvider] implementation.
///
/// Ships as [NoOpAdProvider]. When a real ad SDK is integrated,
/// swap this one provider — the rest of the app adapts automatically.
final adProviderProvider = Provider<AdProvider>((ref) {
  return const NoOpAdProvider();
});

/// Provides a fire-and-forget [EventService] for impression / click tracking.
final eventServiceProvider = Provider<EventService>((ref) {
  final dio = ref.watch(dioProvider);
  return EventService(dio);
});
