@Tags(['widget'])
library banner_slot_widget_test;

import 'package:blips_mobile/features/ads/domain/ads_config.dart';
import 'package:blips_mobile/features/ads/presentation/banner_slot_widget.dart';
import 'package:blips_mobile/features/ads/providers/ads_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  group('BannerSlotWidget', () {
    Widget buildTestWidget(AdsConfig config) {
      return ProviderScope(
        overrides: [
          adsConfigProvider.overrideWith((_) async => config),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Expanded(child: Placeholder()),
                BannerSlotWidget(),
              ],
            ),
          ),
        ),
      );
    }

    testWidgets('renders nothing when ads are disabled', (tester) async {
      await tester.pumpWidget(buildTestWidget(const AdsConfig()));
      await tester.pumpAndSettle();

      expect(find.text('Ad slot'), findsNothing);
    });

    testWidgets('renders nothing even when feed ads are enabled',
        (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          const AdsConfig(
            enabled: true,
            eligible: true,
            surfaces: AdsSurfacesConfig(
              articles: AdSurfaceConfig(
                  enabled: true, frequency: 8, firstSlotAfter: 2),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ad slot'), findsNothing);
    });

    testWidgets('renders nothing while config is loading', (tester) async {
      final widget = ProviderScope(
        overrides: [
          adsConfigProvider.overrideWith(
            (_) => Future<AdsConfig>.delayed(const Duration(days: 1)),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: BannerSlotWidget(),
          ),
        ),
      );

      await tester.pumpWidget(widget);

      expect(find.text('Ad slot'), findsNothing);
    });

    testWidgets('renders nothing when config loading fails', (tester) async {
      final widget = ProviderScope(
        overrides: [
          adsConfigProvider.overrideWith(
            (_) => Future<AdsConfig>.error(Exception('fail')),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: BannerSlotWidget(),
          ),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      expect(find.text('Ad slot'), findsNothing);
    });
  });
}
