import 'package:blips_mobile/core/config/remote_app_config.dart';
import 'package:blips_mobile/core/error/error.dart';
import 'package:blips_mobile/core/network/backend_api_client.dart';
import 'package:blips_mobile/features/ads/domain/ads_config.dart';
import 'package:dio/dio.dart';

/// Fetches app configuration (including ad flags) from the backend.
class AppConfigRepository {
  AppConfigRepository(this._api);

  final BackendApiClient _api;
  RemoteAppConfig? _cachedConfig;
  DateTime? _lastFetchedAt;

  bool get isCacheStale {
    final cachedConfig = _cachedConfig;
    final lastFetchedAt = _lastFetchedAt;
    if (cachedConfig == null || lastFetchedAt == null) {
      return true;
    }
    return DateTime.now().toUtc().difference(lastFetchedAt) >=
        cachedConfig.cacheTtl;
  }

  /// Calls `GET /config` and returns the parsed remote app config.
  ///
  /// Returns safe defaults on any error so the app never accidentally enables
  /// server-controlled features when the backend is unreachable.
  Future<RemoteAppConfig> fetchAppConfig({bool force = false}) async {
    if (!force && !isCacheStale && _cachedConfig != null) {
      return _cachedConfig!;
    }

    try {
      final response = await _api.get('/config');
      final config = RemoteAppConfig.fromJson(response);
      _cachedConfig = config;
      _lastFetchedAt = DateTime.now().toUtc();
      return config;
    } on DioException catch (e, stack) {
      logger.warning(
        'Failed to fetch app config — remote features stay disabled',
        category: LogCategory.network,
        error: e,
        stackTrace: stack,
      );
      return _cachedConfig ?? const RemoteAppConfig();
    } catch (e, stack) {
      logger.warning(
        'Error parsing app config — remote features stay disabled',
        category: LogCategory.app,
        error: e,
        stackTrace: stack,
      );
      return _cachedConfig ?? const RemoteAppConfig();
    }
  }

  /// Compatibility layer for existing ads consumers.
  Future<AdsConfig> fetchAdsConfig({bool force = false}) async {
    final config = await fetchAppConfig(force: force);
    return config.ads;
  }

  /// Convenience helper for push-enabled flows.
  Future<PushConfig> fetchPushConfig({bool force = false}) async {
    final config = await fetchAppConfig(force: force);
    return config.push;
  }
}
