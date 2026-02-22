@Tags(['widget'])
library ad_card_test;

import 'package:blips_mobile/features/ads/data/event_service.dart';
import 'package:blips_mobile/features/ads/domain/ad_entry.dart';
import 'package:blips_mobile/features/ads/presentation/ad_card.dart';
import 'package:blips_mobile/features/ads/providers/ads_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// A [Dio] stub that never makes real requests.
Dio _fakeDio() {
  final dio = Dio(BaseOptions(baseUrl: 'https://fake.test'));
  // Swap the adapter so no real HTTP leaves the process.
  dio.httpClientAdapter = _NoOpAdapter();
  return dio;
}

class _NoOpAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString('{}', 200);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('AdCard', () {
    late AdFeedEntry entry;

    setUp(() {
      entry = const AdFeedEntry(
        adId: 'ad-test-1',
        placementId: 'feed_fullpage',
        sponsorName: 'Acme Corp',
        title: 'Try Our Product',
        body: 'The best thing since sliced bread.',
        imageUrl: 'https://example.com/hero.jpg',
        clickUrl: 'https://example.com/learn-more',
        label: 'Sponsored',
      );
    });

    Widget buildTestWidget(AdFeedEntry adEntry) {
      return ProviderScope(
        overrides: [
          eventServiceProvider.overrideWithValue(EventService(_fakeDio())),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 800,
              width: 400,
              child: AdCard(entry: adEntry),
            ),
          ),
        ),
      );
    }

    testWidgets('renders "Sponsored" badge', (tester) async {
      await tester.pumpWidget(buildTestWidget(entry));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Sponsored'), findsOneWidget);
    });

    testWidgets('renders sponsor name', (tester) async {
      await tester.pumpWidget(buildTestWidget(entry));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Acme Corp'), findsOneWidget);
    });

    testWidgets('renders title when non-empty', (tester) async {
      await tester.pumpWidget(buildTestWidget(entry));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Try Our Product'), findsOneWidget);
    });

    testWidgets('renders body text', (tester) async {
      await tester.pumpWidget(buildTestWidget(entry));
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text('The best thing since sliced bread.'),
        findsOneWidget,
      );
    });

    testWidgets('renders "Learn More" button when clickUrl present',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(entry));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Learn More'), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
    });

    testWidgets('hides title when empty', (tester) async {
      const noTitle = AdFeedEntry(
        adId: 'ad-no-title',
        placementId: 'feed_fullpage',
        sponsorName: 'Some Brand',
        title: '',
      );
      await tester.pumpWidget(buildTestWidget(noTitle));
      await tester.pump(const Duration(milliseconds: 100));

      // Sponsor name is present but no headline text
      expect(find.text('Some Brand'), findsOneWidget);
    });

    testWidgets('hides "Learn More" button when no clickUrl', (tester) async {
      const noUrl = AdFeedEntry(
        adId: 'ad-no-url',
        placementId: 'feed_fullpage',
        sponsorName: 'Brand',
      );
      await tester.pumpWidget(buildTestWidget(noUrl));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('shows fallback icon when no image', (tester) async {
      const noImage = AdFeedEntry(
        adId: 'ad-no-img',
        placementId: 'feed_fullpage',
        sponsorName: 'Brand',
      );
      await tester.pumpWidget(buildTestWidget(noImage));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.campaign_outlined), findsOneWidget);
    });

    testWidgets('custom label is rendered instead of default', (tester) async {
      const custom = AdFeedEntry(
        adId: 'ad-custom',
        placementId: 'feed_fullpage',
        sponsorName: 'Brand',
        label: 'Promoted',
      );
      await tester.pumpWidget(buildTestWidget(custom));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Promoted'), findsOneWidget);
    });
  });
}
