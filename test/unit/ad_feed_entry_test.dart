@Tags(['unit'])
library ad_feed_entry_test;

import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdFeedEntry', () {
    test('constructs with required fields', () {
      const entry = AdFeedEntry(
        adId: 'ad-001',
        placementId: 'feed_fullpage',
        sponsorName: 'Acme Corp',
      );

      expect(entry.adId, 'ad-001');
      expect(entry.placementId, 'feed_fullpage');
      expect(entry.sponsorName, 'Acme Corp');
      expect(entry.title, '');
      expect(entry.label, 'Sponsored');
      expect(entry.body, isNull);
      expect(entry.imageUrl, isNull);
      expect(entry.clickUrl, isNull);
      expect(entry.impressionUrl, isNull);
      expect(entry.campaignId, isNull);
      expect(entry.priority, isNull);
    });

    test('FeedEntry contract returns correct sentinel values', () {
      const entry = AdFeedEntry(
        adId: 'ad-002',
        placementId: 'feed_fullpage',
        sponsorName: 'Test Sponsor',
      );

      expect(entry.id, 'ad-002'.hashCode);
      expect(entry.summary, '');
      expect(
        entry.publishedAt,
        DateTime.fromMillisecondsSinceEpoch(0),
      );
      expect(entry.addedAt, isNull);
      expect(entry.freshnessTier, FreshnessTier.fresh);
      expect(entry.freshnessReason, isNull);
      expect(entry.conversationStarters, isEmpty);
    });

    test('summary returns body when present', () {
      const entry = AdFeedEntry(
        adId: 'ad-003',
        placementId: 'feed_fullpage',
        sponsorName: 'Test',
        body: 'Great product!',
      );

      expect(entry.summary, 'Great product!');
    });

    group('fromJson', () {
      test('parses a full payload', () {
        final entry = AdFeedEntry.fromJson({
          'ad_id': 'ad-100',
          'placement_id': 'feed_fullpage',
          'sponsor_name': 'Sponsor Inc',
          'title': 'Check this out',
          'body': 'Best thing ever',
          'image_url': 'https://example.com/img.png',
          'click_url': 'https://example.com/click',
          'label': 'Ad',
          'tracking': {
            'impression_url': 'https://example.com/imp',
          },
          'metadata': {
            'campaign_id': 'camp-1',
            'priority': 5,
          },
        });

        expect(entry.adId, 'ad-100');
        expect(entry.placementId, 'feed_fullpage');
        expect(entry.sponsorName, 'Sponsor Inc');
        expect(entry.title, 'Check this out');
        expect(entry.body, 'Best thing ever');
        expect(entry.imageUrl, 'https://example.com/img.png');
        expect(entry.clickUrl, 'https://example.com/click');
        expect(entry.label, 'Ad');
        expect(entry.impressionUrl, 'https://example.com/imp');
        expect(entry.campaignId, 'camp-1');
        expect(entry.priority, 5);
      });

      test('uses defaults for missing optional fields', () {
        final entry = AdFeedEntry.fromJson({
          'ad_id': 'ad-200',
          'placement_id': 'banner_top',
          'sponsor_name': 'Some Brand',
        });

        expect(entry.title, '');
        expect(entry.label, 'Sponsored');
        expect(entry.body, isNull);
        expect(entry.imageUrl, isNull);
        expect(entry.clickUrl, isNull);
        expect(entry.impressionUrl, isNull);
        expect(entry.campaignId, isNull);
        expect(entry.priority, isNull);
      });

      test('handles missing tracking and metadata maps', () {
        final entry = AdFeedEntry.fromJson({
          'ad_id': 'ad-300',
          'placement_id': 'banner_top',
          'sponsor_name': 'Brand',
          'tracking': null,
          'metadata': null,
        });

        expect(entry.impressionUrl, isNull);
        expect(entry.campaignId, isNull);
        expect(entry.priority, isNull);
      });
    });
  });

  group('FeedEntryMatch.when()', () {
    test('dispatches to ad callback for AdFeedEntry', () {
      const FeedEntry entry = AdFeedEntry(
        adId: 'ad-w1',
        placementId: 'feed_fullpage',
        sponsorName: 'Test',
      );

      final result = entry.when(
        article: (_) => 'article',
        video: (_) => 'video',
        reel: (_) => 'reel',
        ad: (ad) => 'ad:${ad.adId}',
      );

      expect(result, 'ad:ad-w1');
    });

    test('throws StateError when ad callback is omitted', () {
      const FeedEntry entry = AdFeedEntry(
        adId: 'ad-w2',
        placementId: 'feed_fullpage',
        sponsorName: 'Test',
      );

      expect(
        () => entry.when(
          article: (_) => 'article',
          video: (_) => 'video',
          reel: (_) => 'reel',
        ),
        throwsStateError,
      );
    });
  });
}
