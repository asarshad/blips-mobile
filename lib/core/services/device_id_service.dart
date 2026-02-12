import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Key used to persist the device identifier across app launches.
const _kDeviceIdKey = 'blips_device_id';

/// Provides a stable, anonymous device identifier.
///
/// On first launch a random UUID v4 is generated and persisted in
/// [SharedPreferences].  Subsequent calls return the same value.
/// The identifier is sent to the backend as `X-Device-ID` header and is the
/// key used for server-side usage tracking and data deletion.
final deviceIdProvider = FutureProvider<String>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  var id = prefs.getString(_kDeviceIdKey);
  if (id == null || id.length < 8) {
    id = const Uuid().v4();
    await prefs.setString(_kDeviceIdKey, id);
  }
  return id;
});

/// Clear the persisted device ID (called after data deletion so a fresh ID is
/// generated on next launch).
Future<void> resetDeviceId() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_kDeviceIdKey);
}
