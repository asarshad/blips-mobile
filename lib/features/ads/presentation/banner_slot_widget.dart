import 'package:blips_mobile/features/ads/domain/ads_config.dart';
import 'package:blips_mobile/features/ads/providers/ads_providers.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// A placeholder slot for banner-style ads (e.g. bottom of screen).
///
/// Renders **nothing** when banner ads are disabled (the default).
/// When enabled, shows a minimal reserved slot that a real ad SDK
/// implementation can fill later.
///
/// Usage:
/// ```dart
/// Column(children: [
///   Expanded(child: feedContent),
///   const BannerSlotWidget(),
/// ])
/// ```
class BannerSlotWidget extends ConsumerWidget {
  const BannerSlotWidget({super.key});

  /// Standard mobile banner height (320 × 50).
  static const double bannerHeight = 50;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(adsConfigProvider);

    return configAsync.when(
      data: (config) => _buildSlot(context, config),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildSlot(BuildContext context, AdsConfig config) {
    if (!config.showBannerAds) return const SizedBox.shrink();

    // Reserved space — a real SDK would fill this via a platform view.
    return Container(
      height: bannerHeight,
      width: double.infinity,
      alignment: Alignment.center,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Text(
        'Ad slot',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}
