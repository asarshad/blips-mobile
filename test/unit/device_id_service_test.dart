import 'package:blips_mobile/core/services/device_id_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeDeviceIdStorage extends DeviceIdStorage {
  _FakeDeviceIdStorage();

  String? value;

  @override
  Future<void> delete() async {
    value = null;
  }

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String nextValue) async {
    value = nextValue;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('loadDeviceId', () {
    test('prefers secure storage when present', () async {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final storage = _FakeDeviceIdStorage()..value = 'secure-device-id';

      final id = await loadDeviceId(storage: storage, preferences: prefs);

      expect(id, 'secure-device-id');
      expect(prefs.containsKey('blips_device_id'), isFalse);
    });

    test('migrates a legacy shared preferences identifier', () async {
      SharedPreferences.setMockInitialValues(
        const <String, Object>{'blips_device_id': 'legacy-device-id'},
      );
      final prefs = await SharedPreferences.getInstance();
      final storage = _FakeDeviceIdStorage();

      final id = await loadDeviceId(storage: storage, preferences: prefs);

      expect(id, 'legacy-device-id');
      expect(storage.value, 'legacy-device-id');
      expect(prefs.containsKey('blips_device_id'), isFalse);
    });

    test('generates and persists a new secure identifier when missing',
        () async {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final storage = _FakeDeviceIdStorage();

      final id = await loadDeviceId(storage: storage, preferences: prefs);

      expect(id, isNotEmpty);
      expect(id.length, greaterThanOrEqualTo(8));
      expect(storage.value, id);
      expect(prefs.containsKey('blips_device_id'), isFalse);
    });
  });

  test('resetDeviceId clears secure storage and legacy preferences', () async {
    SharedPreferences.setMockInitialValues(
      const <String, Object>{'blips_device_id': 'legacy-device-id'},
    );
    final prefs = await SharedPreferences.getInstance();
    final storage = _FakeDeviceIdStorage()..value = 'secure-device-id';

    await resetDeviceId(storage: storage, preferences: prefs);

    expect(storage.value, isNull);
    expect(prefs.containsKey('blips_device_id'), isFalse);
  });
}
