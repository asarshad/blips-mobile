@Tags(['unit'])
library dio_provider_test;

import 'package:blips_mobile/core/network/dio_provider.dart';
import 'package:blips_mobile/core/services/device_country_service.dart';
import 'package:blips_mobile/core/services/device_id_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  test('adds device identity and coarse country headers to shared Dio',
      () async {
    final container = ProviderContainer(
      overrides: [
        deviceIdProvider.overrideWith((ref) async => 'device-abc'),
        deviceCountryCodeProvider.overrideWithValue('CA'),
      ],
    );
    addTearDown(container.dispose);

    final dio = container.read(dioProvider);
    await container.read(deviceIdProvider.future);

    expect(dio.options.headers['Content-Type'], 'application/json');
    expect(dio.options.headers['X-Device-ID'], 'device-abc');
    expect(dio.options.headers['X-Device-Country'], 'CA');
  });

  test('omits coarse country header when no region is available', () async {
    final container = ProviderContainer(
      overrides: [
        deviceIdProvider.overrideWith((ref) async => 'device-abc'),
        deviceCountryCodeProvider.overrideWithValue(null),
      ],
    );
    addTearDown(container.dispose);

    final dio = container.read(dioProvider);
    await container.read(deviceIdProvider.future);

    expect(dio.options.headers['X-Device-ID'], 'device-abc');
    expect(dio.options.headers.containsKey('X-Device-Country'), isFalse);
  });
}
