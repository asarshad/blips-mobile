import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Streams the current connectivity status.
///
/// Emits `true` when the device has an active network connection,
/// `false` when offline. Uses [Connectivity] under the hood.
final connectivityProvider = StreamProvider<bool>((ref) {
  final connectivity = Connectivity();
  return connectivity.onConnectivityChanged.map(
    (results) => results.any((r) => r != ConnectivityResult.none),
  );
});
