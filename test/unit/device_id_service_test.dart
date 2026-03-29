import 'package:blips_mobile/core/services/device_auth_service.dart';
import 'package:blips_mobile/core/services/device_id_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeDeviceAuthStorage extends DeviceAuthStorage {
  DeviceAuthBundle? bundle;

  @override
  Future<void> delete() async {
    bundle = null;
  }

  @override
  Future<DeviceAuthBundle?> read() async => bundle;

  @override
  Future<void> write(DeviceAuthBundle nextBundle) async {
    bundle = nextBundle;
  }
}

DeviceAuthBundle _bundle(String deviceId) {
  return DeviceAuthBundle(
    deviceId: deviceId,
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 15)),
    platform: 'ios',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loadDeviceId reads the device id from the auth bundle', () async {
    final storage = _FakeDeviceAuthStorage()..bundle = _bundle('device-123');

    final id = await loadDeviceId(storage: storage);

    expect(id, 'device-123');
  });

  test('resetDeviceId clears the stored auth bundle', () async {
    final storage = _FakeDeviceAuthStorage()..bundle = _bundle('device-123');

    await resetDeviceId(storage: storage);

    expect(storage.bundle, isNull);
  });
}
