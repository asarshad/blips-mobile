import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Key used to persist the device identifier across app launches.
const _kDeviceIdKey = 'blips_device_id';

/// Secure persistence abstraction for the stable device identifier.
abstract class DeviceIdStorage {
  /// Creates a storage adapter for the stable device identifier.
  const DeviceIdStorage();

  /// Reads the persisted device identifier, if one exists.
  Future<String?> read();

  /// Persists the stable device identifier.
  Future<void> write(String value);

  /// Deletes the persisted device identifier.
  Future<void> delete();
}

/// Production [DeviceIdStorage] backed by `flutter_secure_storage`.
class SecureDeviceIdStorage extends DeviceIdStorage {
  /// Creates a secure-storage-backed device ID adapter.
  const SecureDeviceIdStorage([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: _kDeviceIdKey);

  @override
  Future<void> write(String value) =>
      _storage.write(key: _kDeviceIdKey, value: value);

  @override
  Future<void> delete() => _storage.delete(key: _kDeviceIdKey);
}

const _defaultDeviceIdStorage = SecureDeviceIdStorage();

/// Provides a stable, anonymous device identifier.
///
/// On first launch a random UUID v4 is generated and persisted in secure
/// storage. Existing plaintext values in [SharedPreferences] are migrated once.
/// The identifier is sent to the backend as `X-Device-ID` header and is the
/// key used for server-side usage tracking and data deletion.
final deviceIdProvider = FutureProvider<String>((ref) async {
  return loadDeviceId();
});

/// Loads the stable device identifier from secure storage, migrating any
/// legacy plaintext value from [SharedPreferences] exactly once.
Future<String> loadDeviceId({
  DeviceIdStorage storage = _defaultDeviceIdStorage,
  SharedPreferences? preferences,
}) async {
  final prefs = preferences ?? await SharedPreferences.getInstance();
  var id = await storage.read();
  if (id == null || id.length < 8) {
    final legacyId = prefs.getString(_kDeviceIdKey);
    if (legacyId != null && legacyId.length >= 8) {
      id = legacyId;
    } else {
      id = const Uuid().v4();
    }
    await storage.write(id);
  }
  if (prefs.containsKey(_kDeviceIdKey)) {
    await prefs.remove(_kDeviceIdKey);
  }
  return id;
}

/// Clear the persisted device ID (called after data deletion so a fresh ID is
/// generated on next launch).
Future<void> resetDeviceId({
  DeviceIdStorage storage = _defaultDeviceIdStorage,
  SharedPreferences? preferences,
}) async {
  final prefs = preferences ?? await SharedPreferences.getInstance();
  await storage.delete();
  await prefs.remove(_kDeviceIdKey);
}
