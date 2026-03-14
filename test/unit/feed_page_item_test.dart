@Tags(['unit'])
library feed_page_item_test;

import 'package:blips_mobile/features/ads/domain/ads_config.dart';
import 'package:blips_mobile/features/ads/domain/feed_page_item.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildFeedPageItems', () {
    const enabledConfig = AdsConfig(
      enabled: true,
      eligible: true,
      surfaces: AdsSurfacesConfig(
        articles: AdSurfaceConfig(
          enabled: true,
          frequency: 8,
          firstSlotAfter: 2,
        ),
      ),
    );

    test('does not inject an ad in the first two organic positions', () {
      final items = buildFeedPageItems(
        entries: _articles(3),
        adsConfig: enabledConfig,
        surface: AdSurface.articles,
        sessionId: 'session-a',
      );

      expect(items.length, 3);
      expect(items.whereType<NativeAdSlotFeedPageItem>(), isEmpty);
    });

    test('injects the first native slot after eight organic entries', () {
      final items = buildFeedPageItems(
        entries: _articles(10),
        adsConfig: enabledConfig,
        surface: AdSurface.articles,
        sessionId: 'session-a',
      );

      expect(items.length, 11);
      expect(items[8], isA<NativeAdSlotFeedPageItem>());
      expect(
        (items[8] as NativeAdSlotFeedPageItem).slotIndex,
        0,
      );
    });

    test('returns only organic items when the surface is disabled', () {
      const disabledConfig = AdsConfig(
        enabled: true,
        eligible: true,
        surfaces: AdsSurfacesConfig(
          articles: AdSurfaceConfig(
            enabled: false,
            frequency: 8,
            firstSlotAfter: 2,
          ),
        ),
      );

      final items = buildFeedPageItems(
        entries: _articles(12),
        adsConfig: disabledConfig,
        surface: AdSurface.articles,
      );

      expect(items.length, 12);
      expect(items.every((item) => item is OrganicFeedPageItem), isTrue);
    });

    test('never appends a terminal ad after the final organic entry', () {
      final items = buildFeedPageItems(
        entries: _articles(8),
        adsConfig: enabledConfig,
        surface: AdSurface.articles,
      );

      expect(items.length, 8);
      expect(items.last, isA<OrganicFeedPageItem>());
    });

    test('preserves sponsor cards without counting them as organic items', () {
      final items = buildFeedPageItems(
        entries: [
          ..._articles(7),
          const AdFeedEntry(
            adId: 'house-1',
            placementId: 'feed_fullpage',
            sponsorName: 'Blips Sponsor',
          ),
          ..._articles(2, startId: 100),
        ],
        adsConfig: enabledConfig,
        surface: AdSurface.articles,
      );

      expect(items.whereType<SponsorCardFeedPageItem>(), hasLength(1));
      expect(items.whereType<NativeAdSlotFeedPageItem>(), hasLength(1));
      expect(items.last, isA<OrganicFeedPageItem>());
    });
  });
}

List<ArticleFeedEntry> _articles(int count, {int startId = 1}) {
  return List.generate(
    count,
    (index) => ArticleFeedEntry(
      id: startId + index,
      title: 'Article ${startId + index}',
      summary: 'Summary ${startId + index}',
      source: 'Blips',
      publishedAt: DateTime.utc(2026, 1, 1).subtract(Duration(days: index)),
      url: 'https://example.com/${startId + index}',
      imageUrl: 'https://example.com/image-${startId + index}.jpg',
      category: 'AI',
      readTime: 3,
    ),
  );
}
