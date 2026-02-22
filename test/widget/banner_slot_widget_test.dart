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

    testWidgets('renders nothing when ads disabled (default)', (tester) async {
      await tester.pumpWidget(buildTestWidget(const AdsConfig()));
      // Wait for the FutureProvider to resolve.
      await tester.pumpAndSettle();

      // The widget tree should contain a SizedBox.shrink (width/height 0)
      // and NOT the "Ad slot" text.
      expect(find.text('Ad slot'), findsNothing);
    });

    testWidgets('renders nothing when master on but banner off',
        (tester) async {
      await tester.pumpWidget(
        buildTestWidget(const AdsConfig(adsEnabled: true)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ad slot'), findsNothing);
    });

    testWidgets('renders reserved slot when banner ads enabled',
        (tester) async {
      const config = AdsConfig(adsEnabled: true, adsBannerEnabled: true);
      await tester.pumpWidget(buildTestWidget(config));
      await tester.pumpAndSettle();

      expect(find.text('Ad slot'), findsOneWidget);

      // The container should have the standard banner height.
      final container = tester.widget<Container>(find.byType(Container).last);
      expect(
        container.constraints?.maxHeight,
        BannerSlotWidget.bannerHeight,
      );
    });

    testWidgets('renders nothing while loading', (tester) async {
      // Use a Completer-based override that never resolves to test loading state.
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
      // Don't pump extra — stays in loading state.
      expect(find.text('Ad slot'), findsNothing);
    });

    testWidgets('renders nothing on error', (tester) async {
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
