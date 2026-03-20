@Tags(['unit'])
library backend_api_client_test;

import 'package:blips_mobile/core/network/backend_api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'manualRefresh requests keep the base timeout budget and carry the mode tag',
    () async {
      final dio = Dio(
        BaseOptions(
          baseUrl: 'https://example.com',
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 20),
        ),
      );

      RequestOptions? captured;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            captured = options;
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                data: const <String, dynamic>{},
                statusCode: 200,
              ),
            );
          },
        ),
      );

      final client = DioBackendApiClient(dio);
      await client.get(
        '/session/playlist',
        requestMode: RequestMode.manualRefresh,
      );

      expect(captured, isNotNull);
      expect(captured!.extra['requestMode'], 'manualRefresh');
      expect(captured!.connectTimeout, const Duration(seconds: 10));
      expect(captured!.receiveTimeout, const Duration(seconds: 30));
      expect(captured!.sendTimeout, const Duration(seconds: 20));
    },
  );
}
