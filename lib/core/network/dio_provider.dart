import 'package:blips_mobile/core/config/app_config.dart';
import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Provides a configured [Dio] instance for REST calls.
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

  return dio;
});
