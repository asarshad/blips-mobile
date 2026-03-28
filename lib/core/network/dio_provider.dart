import 'package:blips_mobile/core/config/app_config.dart';
import 'package:blips_mobile/core/network/interceptors.dart';
import 'package:blips_mobile/core/services/device_country_service.dart';
import 'package:blips_mobile/core/services/device_id_service.dart';
import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Provides a configured [Dio] instance for REST calls.
///
/// Includes:
/// - X-Device-ID header for anonymous device identification
/// - X-Device-Country header for coarse region context
/// - Retry with exponential backoff
/// - Logging (debug mode only)
/// - Proper timeouts
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.backendBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: const {
        'Content-Type': 'application/json',
      },
    ),
  );

  // Attach X-Device-ID header once the future resolves.
  ref.listen<AsyncValue<String>>(deviceIdProvider, (_, next) {
    final id = next.valueOrNull;
    if (id != null) {
      dio.options.headers['X-Device-ID'] = id;
    }
  }, fireImmediately: true);

  ref.listen<String?>(deviceCountryCodeProvider, (_, next) {
    if (next == null) {
      dio.options.headers.remove('X-Device-Country');
      return;
    }
    dio.options.headers['X-Device-Country'] = next;
  }, fireImmediately: true);

  // Add retry interceptor for resilience
  dio.interceptors.add(RetryInterceptor(dio: dio));

  // Add logging always — in debug for full request/response output, in
  // release so network errors flow through AppLogger and reach Sentry.
  dio.interceptors.add(LoggingInterceptor());

  return dio;
});
