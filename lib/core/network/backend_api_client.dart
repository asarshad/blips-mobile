import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

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
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: queryParameters,
        options: _optionsFor(requestMode),
      );
      return response.data ?? const <String, dynamic>{};
    } on DioException catch (e) {
      _rethrowKeychainLocked(e);
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    RequestMode requestMode = RequestMode.normal,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: _optionsFor(requestMode),
      );
      return response.data ?? const <String, dynamic>{};
    } on DioException catch (e) {
      _rethrowKeychainLocked(e);
      rethrow;
    }
  }

  /// iOS returns -25308 (errSecInteractionNotAllowed) when the app tries to
  /// read a Keychain item while the device is locked. Dio surfaces this as a
  /// DioExceptionType.unknown wrapping a PlatformException. Convert it to a
  /// retryable NetworkException so the caller can handle it gracefully and it
  /// never reaches Sentry as an unexpected crash.
  static void _rethrowKeychainLocked(DioException e) {
    if (e.type == DioExceptionType.unknown) {
      final inner = e.error;
      if (inner is PlatformException && inner.code == '-25308') {
        throw DioException(
          requestOptions: e.requestOptions,
          type: DioExceptionType.connectionError,
          message: 'Keychain locked (device screen off) — request skipped.',
          error: inner,
        );
      }
    }
  }

  Options? _optionsFor(RequestMode mode) {
    if (mode == RequestMode.normal) return null;
    return Options(
      extra: {'requestMode': 'manualRefresh'},
    );
  }
}
