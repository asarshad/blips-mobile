import 'package:blips_mobile/core/network/dio_provider.dart';
import 'package:blips_mobile/core/services/device_auth_service.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Compatibility provider for the stable anonymous device identifier.
///
/// The identifier now comes from the stored auth bundle.
final deviceIdProvider = FutureProvider<String>((ref) async {
  final bundle = await ref.watch(deviceAuthBundleProvider.future);
  return bundle.deviceId;
});

/// Reads the current device identifier from secure storage.
Future<String> loadDeviceId({
  DeviceAuthStorage storage = defaultDeviceAuthStorage,
}) async {
  final bundle = await storage.read();
  if (bundle == null) {
    throw StateError('No stored auth bundle found');
  }
  return bundle.deviceId;
}

/// Clears the persisted auth bundle so a new anonymous session is created.
Future<void> resetDeviceId({
  DeviceAuthStorage storage = defaultDeviceAuthStorage,
}) async {
  await storage.delete();
}
