import 'package:dio/dio.dart';

/// Controls timeout and retry behavior per request.
enum RequestMode {
  /// Default behavior: standard timeouts, retries enabled.
  normal,

  /// User-initiated refresh: same timeout budget as normal traffic, but tagged
  /// so interceptors can recognize it.
  manualRefresh,
}

/// Minimal API client abstraction used by repositories.
///
/// This keeps HTTP concerns (Dio) out of business logic and makes unit tests
/// independent from networking.
abstract interface class BackendApiClient {
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    RequestMode requestMode,
  });

  Future<Map<String, dynamic>> post(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    RequestMode requestMode,
  });
}

/// Production implementation backed by Dio.
final class DioBackendApiClient implements BackendApiClient {
  const DioBackendApiClient(this._dio);

  final Dio _dio;

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    RequestMode requestMode = RequestMode.normal,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      path,
      queryParameters: queryParameters,
      options: _optionsFor(requestMode),
    );
    return response.data ?? const <String, dynamic>{};
  }

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    RequestMode requestMode = RequestMode.normal,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: _optionsFor(requestMode),
    );
    return response.data ?? const <String, dynamic>{};
  }

  Options? _optionsFor(RequestMode mode) {
    if (mode == RequestMode.normal) return null;
    return Options(
      extra: {'requestMode': 'manualRefresh'},
    );
  }
}
