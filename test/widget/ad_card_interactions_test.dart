@Tags(['widget'])
library ad_card_interactions_test;

import 'package:dio/dio.dart';
import 'package:blips_mobile/features/ads/data/event_service.dart';
import 'package:blips_mobile/features/ads/domain/ad_entry.dart';
import 'package:blips_mobile/features/ads/presentation/ad_card.dart';
import 'package:blips_mobile/features/ads/providers/ads_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../test_utils/recording_platforms.dart';

void main() {
  late UrlLauncherPlatform originalUrlLauncher;
  late RecordingUrlLauncherPlatform recordingUrlLauncher;
  late AdFeedEntry entry;

  setUp(() {
    originalUrlLauncher = UrlLauncherPlatform.instance;
    recordingUrlLauncher = RecordingUrlLauncherPlatform();
    UrlLauncherPlatform.instance = recordingUrlLauncher;
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

  tearDown(() {
    UrlLauncherPlatform.instance = originalUrlLauncher;
  });

  Widget buildTestWidget() {
    return ProviderScope(
      overrides: [
        eventServiceProvider.overrideWithValue(_RecordingEventService()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 800,
            child: AdCard(entry: entry),
          ),
        ),
      ),
    );
  }

  testWidgets('learn more button launches the click URL', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Learn More'));
    await tester.pump();

    expect(recordingUrlLauncher.launches, hasLength(1));
    expect(
      recordingUrlLauncher.launches.single.url,
      'https://example.com/learn-more',
    );
  });

  testWidgets('tapping the card launches the click URL', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(AdCard));
    await tester.pump();

    expect(recordingUrlLauncher.launches, hasLength(1));
    expect(
      recordingUrlLauncher.launches.single.url,
      'https://example.com/learn-more',
    );
  });
}

final class _RecordingEventService extends EventService {
  _RecordingEventService() : super(Dio());

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
  }) async {}
}
