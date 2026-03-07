@Tags(['widget'])
library freshness_label_test;

import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:blips_mobile/features/feed/presentation/widgets/freshness_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildSubject(FreshnessLabel label) {
    return MaterialApp(
      home: Scaffold(body: Center(child: label)),
    );
  }

  group('FreshnessLabel', () {
    testWidgets('shows New badge when item is new since last seen', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          FreshnessLabel(
            publishedAt: DateTime.now().subtract(const Duration(hours: 3)),
            isNewSinceLastSeen: true,
          ),
        ),
      );

      expect(find.text('New'), findsOneWidget);
    });

    testWidgets('shows tier badge for recently added items', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          FreshnessLabel(
            publishedAt: DateTime.now().subtract(const Duration(days: 5)),
            addedAt: DateTime.now().subtract(const Duration(hours: 2)),
            freshnessTier: FreshnessTier.recentlyAdded,
          ),
        ),
      );

      expect(find.text('New to you'), findsOneWidget);
      expect(find.textContaining('Added'), findsOneWidget);
    });
  });
}
