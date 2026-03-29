import 'dart:async';
import 'dart:math' as math;

import 'package:blips_mobile/core/error/error.dart';
import 'package:blips_mobile/core/services/device_auth_service.dart';
import 'package:dio/dio.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required Dio dio,
    required DeviceAuthService authService,
  })  : _dio = dio,
        _authService = authService;

  final Dio _dio;
  final DeviceAuthService _authService;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra['skipAuth'] == true) {
      handler.next(options);
      return;
    }

    try {
      final bundle = await _authService.ensureAuthenticated();
      options.headers['Authorization'] = 'Bearer ${bundle.accessToken}';
      handler.next(options);
    } catch (error, stackTrace) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: error,
          stackTrace: stackTrace,
          type: DioExceptionType.unknown,
        ),
      );
    }
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final statusCode = err.response?.statusCode;
    final alreadyRetried = err.requestOptions.extra['authRetried'] == true;
    final skipAuth = err.requestOptions.extra['skipAuth'] == true;

    if (statusCode != 401 || alreadyRetried || skipAuth) {
      handler.next(err);
      return;
    }

    try {
      final bundle = await _authService.refresh();
      final options = err.requestOptions;
      options.headers['Authorization'] = 'Bearer ${bundle.accessToken}';
      options.extra['authRetried'] = true;

      final response = await _dio.fetch<dynamic>(options);
      handler.resolve(response);
    } catch (error, stackTrace) {
      await _authService.resetLocalState();
      handler.next(
        DioException(
          requestOptions: err.requestOptions,
          response: err.response,
          error: error,
          stackTrace: stackTrace,
          type: DioExceptionType.badResponse,
        ),
      );
    }
  }
}

/// Retry interceptor with exponential backoff.
///
/// Automatically retries failed requests for:
/// - Connection timeouts
/// - Network errors
/// - 5xx server errors
///
/// Does NOT retry:
/// - 4xx client errors (bad request, not found, etc.)
/// - Request cancellations
class RetryInterceptor extends Interceptor {
  RetryInterceptor({
    required Dio dio,
    this.maxRetries = 3,
    this.baseDelay = const Duration(milliseconds: 500),
    this.maxDelay = const Duration(seconds: 10),
  }) : _dio = dio;

  final Dio _dio;

  /// Maximum number of retry attempts.
  final int maxRetries;

  /// Base delay before first retry (doubles each attempt).
  final Duration baseDelay;

  /// Maximum delay between retries.
  final Duration maxDelay;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final mode = err.requestOptions.extra['requestMode'] as String?;
    final effectiveMaxRetries = mode == 'manualRefresh' ? 1 : maxRetries;
    final retryCount = err.requestOptions.extra['retryCount'] as int? ?? 0;

    if (_shouldRetry(err) && retryCount < effectiveMaxRetries) {
      final delay = _calculateDelay(retryCount);

      logger.debug(
        'Retrying request (${retryCount + 1}/$effectiveMaxRetries) '
        'after ${delay.inMilliseconds}ms: ${err.requestOptions.path}',
        category: LogCategory.network,
      );

      await Future<void>.delayed(delay);

      try {
        final options = err.requestOptions;
        options.extra['retryCount'] = retryCount + 1;

        final response = await _dio.request<dynamic>(
          options.path,
          data: options.data,
          queryParameters: options.queryParameters,
          options: Options(
            method: options.method,
            headers: options.headers,
            responseType: options.responseType,
            contentType: options.contentType,
            sendTimeout: options.sendTimeout,
            receiveTimeout: options.receiveTimeout,
            extra: options.extra,
          ),
        );

        return handler.resolve(response);
      } on DioException catch (retryErr) {
        retryErr.requestOptions.extra['retryCount'] = retryCount + 1;
        return onError(retryErr, handler);
      }
    }

    return handler.next(err);
  }

  bool _shouldRetry(DioException err) {
    return switch (err.type) {
      DioExceptionType.connectionTimeout => true,
      DioExceptionType.sendTimeout => true,
      DioExceptionType.receiveTimeout => true,
      DioExceptionType.connectionError => true,
      DioExceptionType.badResponse => _isRetryableStatus(
          err.response?.statusCode,
        ),
      DioExceptionType.cancel => false,
      _ => false,
    };
  }

  bool _isRetryableStatus(int? statusCode) {
    if (statusCode == null) return false;
    return statusCode >= 500 || statusCode == 429;
  }

  Duration _calculateDelay(int retryCount) {
    final exponentialDelay = baseDelay * math.pow(2, retryCount).toInt();
    final jitter = Duration(
      milliseconds: math.Random().nextInt(100),
    );
    final totalDelay = exponentialDelay + jitter;

    if (totalDelay > maxDelay) return maxDelay;
    return totalDelay;
  }
}

/// Logging interceptor for network requests.
class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    logger.debug(
      '→ ${options.method} ${options.path}',
      category: LogCategory.network,
    );
    handler.next(options);
  }

  @override
  void onResponse(
      Response<Object?> response, ResponseInterceptorHandler handler) {
    logger.debug(
      '← ${response.statusCode} ${response.requestOptions.path}',
      category: LogCategory.network,
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final statusCode = err.response?.statusCode ?? 'N/A';
    logger.warning(
      '✗ $statusCode ${err.requestOptions.path}: ${err.message}',
      category: LogCategory.network,
      error: err,
    );
    handler.next(err);
  }
}
