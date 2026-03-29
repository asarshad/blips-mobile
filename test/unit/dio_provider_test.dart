@Tags(['unit'])
library dio_provider_test;

import 'dart:convert';

import 'package:blips_mobile/core/network/dio_provider.dart';
import 'package:blips_mobile/core/services/device_auth_service.dart';
import 'package:blips_mobile/core/services/device_country_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class _FakeDeviceAuthService extends DeviceAuthService {
  _FakeDeviceAuthService({
    required this.bundle,
    this.refreshedBundle,
    this.refreshError,
  }) : super(Dio());

  DeviceAuthBundle bundle;
  final DeviceAuthBundle? refreshedBundle;
  final Exception? refreshError;
  int ensureCalls = 0;
  int refreshCalls = 0;
  int resetCalls = 0;

  @override
  Future<DeviceAuthBundle> ensureAuthenticated() async {
    ensureCalls += 1;
    return bundle;
  }

  @override
  Future<DeviceAuthBundle> refresh() async {
    refreshCalls += 1;
    if (refreshError != null) {
      throw refreshError!;
    }
    final nextBundle = refreshedBundle ?? bundle;
    bundle = nextBundle;
    return nextBundle;
  }

  @override
  Future<void> resetLocalState() async {
    resetCalls += 1;
  }
}

class _QueuedResponseAdapter implements HttpClientAdapter {
  _QueuedResponseAdapter(this._responses);

  final List<_QueuedResponse> _responses;
  final List<_CapturedRequest> requests = <_CapturedRequest>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(
      _CapturedRequest(
        path: options.path,
        headers: Map<String, dynamic>.from(options.headers),
      ),
    );
    if (_responses.isEmpty) {
      throw StateError(
          'No queued Dio response for ${options.method} ${options.path}');
    }
    final response = _responses.removeAt(0);
    return ResponseBody.fromString(
      jsonEncode(response.body),
      response.statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json'],
      },
    );
  }
}

class _QueuedResponse {
  const _QueuedResponse(this.statusCode, this.body);

  final int statusCode;
  final Map<String, dynamic> body;
}

class _CapturedRequest {
  const _CapturedRequest({
    required this.path,
    required this.headers,
  });

  final String path;
  final Map<String, dynamic> headers;
}

DeviceAuthBundle _bundle(
  String accessToken, {
  String deviceId = 'device-123',
  String refreshToken = 'refresh-token',
}) {
  return DeviceAuthBundle(
    deviceId: deviceId,
    accessToken: accessToken,
    refreshToken: refreshToken,
    expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 15)),
    platform: 'ios',
  );
}

ProviderContainer _container({
  required _FakeDeviceAuthService authService,
  String? countryCode = 'CA',
}) {
  return ProviderContainer(
    overrides: [
      deviceAuthServiceProvider.overrideWithValue(authService),
      deviceCountryCodeProvider.overrideWithValue(countryCode),
    ],
  );
}

void main() {
  test('adds coarse country header to shared Dio', () async {
    final authService = _FakeDeviceAuthService(bundle: _bundle('access-token'));
    final container = _container(authService: authService);
    addTearDown(container.dispose);

    final dio = container.read(dioProvider);

    expect(dio.options.headers['Content-Type'], 'application/json');
    expect(dio.options.headers['X-Device-Country'], 'CA');
  });

  test('omits coarse country header when no region is available', () async {
    final authService = _FakeDeviceAuthService(bundle: _bundle('access-token'));
    final container = _container(authService: authService, countryCode: null);
    addTearDown(container.dispose);

    final dio = container.read(dioProvider);

    expect(dio.options.headers.containsKey('X-Device-Country'), isFalse);
  });

  test('attaches bearer auth from the shared auth service', () async {
    final authService = _FakeDeviceAuthService(bundle: _bundle('access-token'));
    final container = _container(authService: authService);
    addTearDown(container.dispose);

    final dio = container.read(dioProvider);
    final adapter = _QueuedResponseAdapter(
      <_QueuedResponse>[
        const _QueuedResponse(200, <String, dynamic>{'ok': true})
      ],
    );
    dio.httpClientAdapter = adapter;

    final response =
        await dio.get<Map<String, dynamic>>('/preferences/categories');

    expect(response.statusCode, 200);
    expect(authService.ensureCalls, 1);
    expect(
      adapter.requests.single.headers['Authorization'],
      'Bearer access-token',
    );
  });

  test('retries once with a refreshed bearer token after a 401', () async {
    final authService = _FakeDeviceAuthService(
      bundle: _bundle('access-token'),
      refreshedBundle: _bundle('refreshed-token'),
    );
    final container = _container(authService: authService);
    addTearDown(container.dispose);

    final dio = container.read(dioProvider);
    final adapter = _QueuedResponseAdapter(
      <_QueuedResponse>[
        const _QueuedResponse(401, <String, dynamic>{'detail': 'expired'}),
        const _QueuedResponse(200, <String, dynamic>{'ok': true}),
      ],
    );
    dio.httpClientAdapter = adapter;

    final response = await dio.get<Map<String, dynamic>>('/session/playlist');

    expect(response.statusCode, 200);
    expect(authService.refreshCalls, 1);
    expect(adapter.requests, hasLength(2));
    expect(
        adapter.requests.first.headers['Authorization'], 'Bearer access-token');
    expect(adapter.requests.last.headers['Authorization'],
        'Bearer refreshed-token');
  });

  test('clears local auth state when refresh fails during a 401 retry',
      () async {
    final authService = _FakeDeviceAuthService(
      bundle: _bundle('access-token'),
      refreshError: Exception('refresh failed'),
    );
    final container = _container(authService: authService);
    addTearDown(container.dispose);

    final dio = container.read(dioProvider);
    final adapter = _QueuedResponseAdapter(
      <_QueuedResponse>[
        const _QueuedResponse(401, <String, dynamic>{'detail': 'expired'}),
      ],
    );
    dio.httpClientAdapter = adapter;

    await expectLater(
      dio.get<Map<String, dynamic>>('/usage'),
      throwsA(isA<DioException>()),
    );

    expect(authService.refreshCalls, 1);
    expect(authService.resetCalls, 1);
  });
}
