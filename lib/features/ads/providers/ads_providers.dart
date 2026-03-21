import 'package:blips_mobile/core/network/backend_api_client.dart';
import 'package:blips_mobile/core/network/dio_provider.dart';
import 'package:blips_mobile/core/services/device_id_service.dart';
import 'package:blips_mobile/features/ads/data/app_config_repository.dart';
import 'package:blips_mobile/features/ads/data/event_service.dart';
import 'package:blips_mobile/features/ads/domain/ads_config.dart';
import 'package:blips_mobile/features/ads/domain/ads_runtime_config.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Provides a singleton [AppConfigRepository].
final appConfigRepositoryProvider = Provider<AppConfigRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return AppConfigRepository(DioBackendApiClient(dio));
});

/// Build-time ad runtime config used for local testing and SDK mode switching.
final adsRuntimeConfigProvider = Provider<AdsRuntimeConfig>((ref) {
  return AdsRuntimeConfig.fromEnvironment();
});

/// Fetches [AdsConfig] from the backend on first read and caches it.
///
/// Use `ref.invalidate(adsConfigProvider)` to force refetch.
/// On failure, returns a safe default with everything disabled.
final adsConfigProvider = FutureProvider<AdsConfig>((ref) async {
  final runtimeConfig = ref.watch(adsRuntimeConfigProvider);
  final deviceId = await ref.watch(deviceIdProvider.future);
  final dio = ref.read(dioProvider);
  dio.options.headers['X-Device-ID'] = deviceId;
  final repo = ref.watch(appConfigRepositoryProvider);
  final config = await repo.fetchAdsConfig();
  if (!runtimeConfig.shouldForceFeedAds) {
    return config;
  }
  return config.forceEnableFeedAds(
    provider: runtimeConfig.usesMockAds ? 'mock_native' : config.provider,
  );
});

/// Provides a fire-and-forget [EventService] for impression / click tracking.
final eventServiceProvider = Provider<EventService>((ref) {
  final dio = ref.watch(dioProvider);
  return EventService(dio);
});
