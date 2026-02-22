import 'package:blips_mobile/core/error/error.dart';
import 'package:blips_mobile/core/network/backend_api_client.dart';
import 'package:blips_mobile/features/ads/domain/ads_config.dart';
import 'package:dio/dio.dart';

/// Fetches app configuration (including ad flags) from the backend.
class AppConfigRepository {
  const AppConfigRepository(this._api);

  final BackendApiClient _api;

  /// Calls GET /config and returns parsed [AdsConfig].
  ///
  /// Returns [AdsConfig] defaults (everything off) on any error so the
  /// app never accidentally enables ads when the server is unreachable.
  Future<AdsConfig> fetchAdsConfig() async {
    try {
      final response = await _api.get('/config');
      final adsJson = response['ads'] as Map<String, dynamic>? ?? const {};
      return AdsConfig.fromJson(adsJson);
    } on DioException catch (e, stack) {
      logger.warning(
        'Failed to fetch app config — ads stay disabled',
        category: LogCategory.network,
        error: e,
        stackTrace: stack,
      );
      return const AdsConfig();
    } catch (e, stack) {
      logger.warning(
        'Error parsing app config — ads stay disabled',
        category: LogCategory.app,
        error: e,
        stackTrace: stack,
      );
      return const AdsConfig();
    }
  }
}
