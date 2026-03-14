import 'package:blips_mobile/features/ads/domain/ads_config.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';

/// Presentation-layer item rendered in swipe feeds.
sealed class FeedPageItem {
  const FeedPageItem();

  int get stableId;

  FeedEntry? get organicEntry;

  VideoFeedEntry? get videoEntry {
    final entry = organicEntry;
    return entry is VideoFeedEntry ? entry : null;
  }
}

/// Organic content item from the feed repository.
class OrganicFeedPageItem extends FeedPageItem {
  const OrganicFeedPageItem(this.entry);

  final FeedEntry entry;

  @override
  int get stableId => entry.id;

  @override
  FeedEntry get organicEntry => entry;
}

/// SDK-backed native ad slot injected on-device.
class NativeAdSlotFeedPageItem extends FeedPageItem {
  const NativeAdSlotFeedPageItem({
    required this.surface,
    required this.slotIndex,
    this.sessionId,
  });

  final AdSurface surface;
  final int slotIndex;
  final String? sessionId;

  String get placementId => '${surface.name}_native_slot';

  @override
  int get stableId => Object.hash(surface, slotIndex, sessionId ?? '');

  @override
  FeedEntry? get organicEntry => null;
}

/// Future-facing direct-sold sponsorship card.
class SponsorCardFeedPageItem extends FeedPageItem {
  const SponsorCardFeedPageItem(this.entry);

  final AdFeedEntry entry;

  @override
  int get stableId => entry.id;

  @override
  FeedEntry? get organicEntry => null;
}

/// Convert organic feed entries into swipe-page items with deterministic slots.
List<FeedPageItem> buildFeedPageItems({
  required List<FeedEntry> entries,
  required AdsConfig adsConfig,
  required AdSurface surface,
  String? sessionId,
}) {
  final items = <FeedPageItem>[];
  final surfaceConfig = adsConfig.surfaceConfig(surface);

  if (!adsConfig.isSurfaceEnabled(surface)) {
    return entries.map(_wrapEntry).toList(growable: false);
  }

  var organicCount = 0;
  var slotIndex = 0;

  for (var i = 0; i < entries.length; i++) {
    final entry = entries[i];
    items.add(_wrapEntry(entry));

    if (entry is AdFeedEntry) {
      continue;
    }

    organicCount += 1;

    if (_shouldInsertNativeAdSlot(
      organicCount: organicCount,
      surfaceConfig: surfaceConfig,
      hasMoreOrganicEntries: i < entries.length - 1,
    )) {
      items.add(
        NativeAdSlotFeedPageItem(
          surface: surface,
          slotIndex: slotIndex,
          sessionId: sessionId,
        ),
      );
      slotIndex += 1;
    }
  }

  return List.unmodifiable(items);
}

FeedPageItem _wrapEntry(FeedEntry entry) {
  if (entry is AdFeedEntry) {
    return SponsorCardFeedPageItem(entry);
  }
  return OrganicFeedPageItem(entry);
}

bool _shouldInsertNativeAdSlot({
  required int organicCount,
  required AdSurfaceConfig surfaceConfig,
  required bool hasMoreOrganicEntries,
}) {
  if (!hasMoreOrganicEntries || !surfaceConfig.enabled) {
    return false;
  }
  if (surfaceConfig.frequency <= 0) {
    return false;
  }
  if (organicCount <= surfaceConfig.firstSlotAfter) {
    return false;
  }
  return organicCount % surfaceConfig.frequency == 0;
}
