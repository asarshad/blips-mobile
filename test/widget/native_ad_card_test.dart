@Tags(['widget'])
library native_ad_card_test;

import 'package:blips_mobile/features/ads/data/event_service.dart';
import 'package:blips_mobile/features/ads/domain/ads_config.dart';
import 'package:blips_mobile/features/ads/domain/ads_runtime_config.dart';
import 'package:blips_mobile/features/ads/domain/feed_page_item.dart';
import 'package:blips_mobile/features/ads/presentation/native_ad_card.dart';
import 'package:blips_mobile/features/ads/providers/ads_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  group('NativeAdCard', () {
    testWidgets('renders a local mock card in mock mode', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adsRuntimeConfigProvider.overrideWithValue(
              const AdsRuntimeConfig(mode: AdsMode.mock),
            ),
            eventServiceProvider.overrideWithValue(_RecordingEventService()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 800,
                child: NativeAdCard(
                  slot: NativeAdSlotFeedPageItem(
                    surface: AdSurface.articles,
                    slotIndex: 0,
                    sessionId: 'session-a',
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Mock Sponsored'), findsOneWidget);
      expect(find.text('Test native ad for articles'), findsOneWidget);
      expect(find.textContaining('Record mock click'), findsOneWidget);
    });

    testWidgets('mock mode tap records a click and shows feedback',
        (tester) async {
      final eventService = _RecordingEventService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adsRuntimeConfigProvider.overrideWithValue(
              const AdsRuntimeConfig(mode: AdsMode.mock),
            ),
            eventServiceProvider.overrideWithValue(eventService),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 800,
                child: NativeAdCard(
                  slot: NativeAdSlotFeedPageItem(
                    surface: AdSurface.videos,
                    slotIndex: 1,
                    sessionId: 'session-b',
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Record mock click'));
      await tester.pump();

      expect(eventService.clickCount, 1);
      expect(find.textContaining('Mock ad tap recorded'), findsOneWidget);
    });
  });
}

final class _RecordingEventService extends EventService {
  _RecordingEventService() : super(Dio());

  int clickCount = 0;

  @override
  Future<void> recordClick({
    required String itemType,
    int? contentId,
    String? adId,
    required String surface,
    String? sessionId,
    String? provider,
    String? adUnitId,
    int? slotIndex,
    String? loadStatus,
  }) async {
    clickCount += 1;
  }

  @override
  Future<void> recordImpression({
    required String itemType,
    int? contentId,
    String? adId,
    required String surface,
    String? sessionId,
    String? provider,
    String? adUnitId,
    int? slotIndex,
    String? loadStatus,
  }) async {}
}
