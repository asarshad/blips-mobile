import 'package:blips_mobile/core/config/app_config.dart';
import 'package:blips_mobile/core/network/interceptors.dart';
import 'package:blips_mobile/core/services/device_auth_service.dart';
import 'package:blips_mobile/core/services/device_country_service.dart';
import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

BaseOptions _baseOptions() {
  return BaseOptions(
    baseUrl: AppConfig.backendBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
    headers: const {
      'Content-Type': 'application/json',
    },
  );
}

void _bindCountryHeader(Ref ref, Dio dio) {
  ref.listen<String?>(deviceCountryCodeProvider, (_, next) {
    if (next == null) {
      dio.options.headers.remove('X-Device-Country');
      return;
    }
    dio.options.headers['X-Device-Country'] = next;
  }, fireImmediately: true);
}

final rawDioProvider = Provider<Dio>((ref) {
  final dio = Dio(_baseOptions());
  _bindCountryHeader(ref, dio);
  dio.interceptors.add(LoggingInterceptor());
  return dio;
});

final deviceAuthServiceProvider = Provider<DeviceAuthService>((ref) {
  final dio = ref.watch(rawDioProvider);
  return DeviceAuthService(dio);
});

final deviceAuthBundleProvider = FutureProvider<DeviceAuthBundle>((ref) async {
  final service = ref.watch(deviceAuthServiceProvider);
  return service.ensureAuthenticated();
});

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(_baseOptions());
  _bindCountryHeader(ref, dio);

  final authService = ref.watch(deviceAuthServiceProvider);
  dio.interceptors.add(
    AuthInterceptor(
      dio: dio,
      authService: authService,
    ),
  );
  dio.interceptors.add(RetryInterceptor(dio: dio));
  dio.interceptors.add(LoggingInterceptor());

  return dio;
});
