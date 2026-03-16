import 'dart:async';
import 'dart:math' as math;

import 'package:blips_mobile/core/error/error.dart';
import 'package:dio/dio.dart';

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
    // Never retry manual-refresh requests.
    final mode = err.requestOptions.extra['requestMode'] as String?;
    if (mode == 'manualRefresh') {
      return handler.next(err);
    }

    final retryCount = err.requestOptions.extra['retryCount'] as int? ?? 0;

    if (_shouldRetry(err) && retryCount < maxRetries) {
      final delay = _calculateDelay(retryCount);

      logger.debug(
        'Retrying request (${retryCount + 1}/$maxRetries) '
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
        // Copy retry count to new error for next attempt
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
    // Retry 5xx server errors, 429 rate limit
    return statusCode >= 500 || statusCode == 429;
  }

  Duration _calculateDelay(int retryCount) {
    // Exponential backoff with jitter
    final exponentialDelay = baseDelay * math.pow(2, retryCount).toInt();
    final jitter = Duration(
      milliseconds: math.Random().nextInt(100),
    );
    final totalDelay = exponentialDelay + jitter;

    // Cap at max delay
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
  void onResponse(Response response, ResponseInterceptorHandler handler) {
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
