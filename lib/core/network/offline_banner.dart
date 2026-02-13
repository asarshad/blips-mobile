import 'package:blips_mobile/core/network/connectivity_provider.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// A banner displayed at the top of the screen when the device is offline.
///
/// Automatically appears/disappears based on [connectivityProvider].
class OfflineBanner extends ConsumerWidget {
  /// Creates an offline banner.
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivity = ref.watch(connectivityProvider);

    return connectivity.when(
      data: (isOnline) {
        if (isOnline) return const SizedBox.shrink();
        return MaterialBanner(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          content: const Text(
            'You are offline. Showing cached content.',
            style: TextStyle(color: Colors.white, fontSize: 13),
          ),
          leading: const Icon(Icons.wifi_off, color: Colors.white, size: 20),
          backgroundColor: Colors.black87,
          actions: const [SizedBox.shrink()],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
