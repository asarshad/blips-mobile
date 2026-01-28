import 'package:dio/dio.dart';

/// Minimal API client abstraction used by repositories.
///
/// This keeps HTTP concerns (Dio) out of business logic and makes unit tests
/// independent from networking.
abstract interface class BackendApiClient {
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
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
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      path,
      queryParameters: queryParameters,
    );
    return response.data ?? const <String, dynamic>{};
  }
}
