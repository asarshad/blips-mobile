import 'package:blips_mobile/app.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:blips_mobile/features/feed/providers/feed_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  testWidgets('renders feed cards from provider data', (tester) async {
    final overrides = [
      feedItemsProvider.overrideWith(
        (ref) async => [
          ArticleFeedEntry(
            id: 1,
            title: 'AI beats gravity',
            summary: 'Scientists achieved a new milestone in AI hardware.',
            source: 'example.com',
            publishedAt: DateTime(2024, 5),
            url: 'https://example.com/article',
            imageUrl: 'https://images.unsplash.com/photo-1504384308090-c894fdcc538d?w=800',
            category: 'Technology',
            readTime: 4,
            tags: const ['AI'],
          ),
        ],
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: const BlipsApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('AI beats gravity'), findsOneWidget);
    expect(find.textContaining('example.com'), findsOneWidget);
  });
}
