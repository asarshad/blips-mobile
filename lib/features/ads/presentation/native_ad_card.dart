import 'dart:async';

import 'package:blips_mobile/core/error/error.dart';
import 'package:blips_mobile/core/theme/theme.dart';
import 'package:blips_mobile/features/ads/domain/admob_config.dart';
import 'package:blips_mobile/features/ads/domain/feed_page_item.dart';
import 'package:blips_mobile/features/ads/providers/ads_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

enum _NativeAdRenderState {
  loading,
  loaded,
  failed,
  unsupported,
}

/// Full-page feed card backed by an AdMob native ad.
class NativeAdCard extends HookConsumerWidget {
  const NativeAdCard({
    super.key,
    required this.slot,
  });

  final NativeAdSlotFeedPageItem slot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runtimeConfig = ref.watch(adsRuntimeConfigProvider);
    final adState = useState(_NativeAdRenderState.loading);
    final nativeAd = useState<NativeAd?>(null);
    final adUnitId = useMemoized(() {
      if (!AdMobConfig.supportsNativeAds) {
        return null;
      }
      return AdMobConfig.nativeAdUnitIdForSurface(
        slot.surface,
        runtimeConfig: runtimeConfig,
      );
    }, [runtimeConfig, slot.surface]);

    useEffect(() {
      nativeAd.value?.dispose();
      nativeAd.value = null;

      if (runtimeConfig.usesMockAds) {
        adState.value = _NativeAdRenderState.unsupported;
        return null;
      }

      if (adUnitId == null || adUnitId.isEmpty) {
        adState.value = _NativeAdRenderState.unsupported;
        return null;
      }

      adState.value = _NativeAdRenderState.loading;
      final eventService = ref.read(eventServiceProvider);
      final ad = NativeAd(
        adUnitId: adUnitId,
        factoryId: AdMobConfig.nativeFactoryId,
        request: const AdRequest(),
        customOptions: <String, Object>{
          'surface': slot.surface.name,
          'slot_index': slot.slotIndex,
          if (slot.sessionId != null && slot.sessionId!.isNotEmpty)
            'session_id': slot.sessionId!,
        },
        listener: NativeAdListener(
          onAdLoaded: (ad) {
            if (nativeAd.value != ad) {
              return;
            }
            adState.value = _NativeAdRenderState.loaded;
            logger.debug(
              'Native ad loaded for ${slot.surface.name} slot ${slot.slotIndex}',
              category: LogCategory.ui,
            );
          },
          onAdFailedToLoad: (ad, error) {
            if (nativeAd.value == ad) {
              nativeAd.value = null;
            }
            ad.dispose();
            adState.value = _NativeAdRenderState.failed;
            logger.warning(
              'Native ad failed for ${slot.surface.name} slot ${slot.slotIndex}',
              category: LogCategory.network,
              error: error,
            );
          },
          onAdImpression: (_) {
            eventService.recordImpression(
              itemType: 'AD',
              adId: slot.placementId,
              surface: slot.surface.name,
              sessionId: slot.sessionId,
              provider: 'admob_native',
              adUnitId: adUnitId,
              slotIndex: slot.slotIndex,
              loadStatus: 'impression',
            );
          },
          onAdClicked: (_) {
            eventService.recordClick(
              itemType: 'AD',
              adId: slot.placementId,
              surface: slot.surface.name,
              sessionId: slot.sessionId,
              provider: 'admob_native',
              adUnitId: adUnitId,
              slotIndex: slot.slotIndex,
              loadStatus: 'clicked',
            );
          },
        ),
      );

      nativeAd.value = ad;
      unawaited(ad.load());

      return () {
        if (nativeAd.value == ad) {
          nativeAd.value = null;
        }
        ad.dispose();
      };
    }, [adUnitId, runtimeConfig, slot.sessionId, slot.slotIndex, slot.surface]);

    if (runtimeConfig.usesMockAds) {
      return _MockNativeAdCard(slot: slot);
    }

    final currentAd = nativeAd.value;
    if (adState.value == _NativeAdRenderState.loaded && currentAd != null) {
      return ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: AdWidget(ad: currentAd),
      );
    }

    return _NativeAdPlaceholderCard(
      surfaceName: slot.surface.name,
      state: adState.value,
    );
  }
}

class _MockNativeAdCard extends HookConsumerWidget {
  const _MockNativeAdCard({
    required this.slot,
  });

  final NativeAdSlotFeedPageItem slot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useEffect(() {
      unawaited(
        ref.read(eventServiceProvider).recordImpression(
              itemType: 'AD',
              adId: slot.placementId,
              surface: slot.surface.name,
              sessionId: slot.sessionId,
              provider: 'mock_native',
              slotIndex: slot.slotIndex,
              loadStatus: 'impression',
            ),
      );
      return null;
    }, [slot.placementId, slot.sessionId, slot.slotIndex, slot.surface]);

    Future<void> handleTap() async {
      await ref.read(eventServiceProvider).recordClick(
            itemType: 'AD',
            adId: slot.placementId,
            surface: slot.surface.name,
            sessionId: slot.sessionId,
            provider: 'mock_native',
            slotIndex: slot.slotIndex,
            loadStatus: 'clicked',
          );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Mock ad tap recorded for ${slot.surface.name} slot ${slot.slotIndex + 1}',
          ),
          duration: const Duration(milliseconds: 900),
        ),
      );
    }

    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.scaffoldBackgroundColor,
      child: InkWell(
        onTap: handleTap,
        child: Column(
          children: [
            Expanded(
              flex: 35,
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1D4ED8),
                      Color(0xFF0F172A),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 12,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Mock Sponsored',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white.withValues(alpha: 0.85),
                        size: 36,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 65,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mock ad placement',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Test native ad for ${slot.surface.name}',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Text(
                        'This build uses a local mock card instead of the Google Mobile Ads SDK. '
                        'Use it to verify slot cadence, swipe behavior, and click or impression tracking.',
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          height: 1.4,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: handleTap,
                        child: Text(
                            'Record mock click · slot ${slot.slotIndex + 1}'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NativeAdPlaceholderCard extends StatelessWidget {
  const _NativeAdPlaceholderCard({
    required this.surfaceName,
    required this.state,
  });

  final String surfaceName;
  final _NativeAdRenderState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final copy = switch (state) {
      _NativeAdRenderState.loading => (
          eyebrow: 'Sponsored',
          headline: 'Loading sponsor story',
          body:
              'This placement is reserved for a full-page sponsored card and remains fully swipeable while the ad request completes.',
        ),
      _NativeAdRenderState.failed => (
          eyebrow: 'Sponsored',
          headline: 'Sponsored story unavailable',
          body:
              'No fill came back for this $surfaceName slot, so the card stays lightweight and swipeable instead of blocking the feed.',
        ),
      _NativeAdRenderState.unsupported => (
          eyebrow: 'Sponsored',
          headline: 'Sponsored card unavailable',
          body:
              'This platform cannot render native feed ads, so this slot falls back to a neutral placeholder.',
        ),
      _NativeAdRenderState.loaded => (
          eyebrow: 'Sponsored',
          headline: '',
          body: '',
        ),
    };

    return ColoredBox(
      color: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          Expanded(
            flex: 35,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0E7490),
                    Color(0xFF0F172A),
                  ],
                ),
              ),
              child: Align(
                alignment: Alignment.topLeft,
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    copy.eyebrow,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 65,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sponsored placement',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    copy.headline,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    copy.body,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      height: 1.45,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Icon(
                        Icons.swipe_vertical_outlined,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Swipe to continue',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
