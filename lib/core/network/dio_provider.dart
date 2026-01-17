import 'package:blips_mobile/core/config/app_config.dart';
import 'package:blips_mobile/core/network/interceptors.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Provides a configured [Dio] instance for REST calls.
///
/// Includes:
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

  // Add retry interceptor for resilience
  dio.interceptors.add(RetryInterceptor());

  // Add logging in debug mode
  if (kDebugMode) {
    dio.interceptors.add(LoggingInterceptor());
  }

  return dio;
});
