@Tags(['widget'])
library article_card_test;

import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:blips_mobile/features/feed/presentation/cards/article_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  group('ArticleCard', () {
    late ArticleFeedEntry testEntry;

    setUp(() {
      testEntry = ArticleFeedEntry(
        id: 1,
        title: 'Test Article Title',
        summary: 'This is a test summary for the article card widget test.',
        source: 'Test Source',
        publishedAt: DateTime(2025, 2, 10, 12, 0),
        addedAt: DateTime(2025, 2, 10, 13, 0),
        url: 'https://example.com/article',
        imageUrl: 'https://example.com/image.jpg',
        category: 'Technology',
        readTime: 5,
        tags: ['AI', 'Tech'],
        freshnessTier: FreshnessTier.fresh,
        conversationStarters: ['What do you think?', 'Is this accurate?'],
      );
    });

    Widget buildTestWidget(ArticleFeedEntry entry) {
      return ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 600,
              width: 400,
              child: ArticleCard(entry: entry),
            ),
          ),
        ),
      );
    }

    testWidgets('renders article title', (tester) async {
      await tester.pumpWidget(buildTestWidget(testEntry));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Test Article Title'), findsOneWidget);
    });

    testWidgets('renders article summary', (tester) async {
      await tester.pumpWidget(buildTestWidget(testEntry));
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.textContaining('This is a test summary'),
        findsOneWidget,
      );
    });

    testWidgets('renders source name', (tester) async {
      await tester.pumpWidget(buildTestWidget(testEntry));
      await tester.pump(const Duration(milliseconds: 100));

      // Source appears in the content header and may also appear in the
      // media placeholder when the network image fails to load in tests.
      expect(find.text('Test Source'), findsAtLeastNWidgets(1));
    });

    testWidgets('renders category badge', (tester) async {
      await tester.pumpWidget(buildTestWidget(testEntry));
      await tester.pump(const Duration(milliseconds: 100));

      // Category is displayed uppercased; may appear in both the content
      // header badge and the media placeholder when the image fails in tests.
      expect(find.text('TECHNOLOGY'), findsAtLeastNWidgets(1));
    });

    testWidgets('renders read time', (tester) async {
      await tester.pumpWidget(buildTestWidget(testEntry));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('5 min'), findsOneWidget);
    });

    testWidgets('has open link action button', (tester) async {
      await tester.pumpWidget(buildTestWidget(testEntry));
      await tester.pump(const Duration(milliseconds: 100));

      // Look for open_in_new icon button
      expect(
        find.byIcon(Icons.open_in_new),
        findsOneWidget,
      );
    });

    testWidgets('has share action button', (tester) async {
      await tester.pumpWidget(buildTestWidget(testEntry));
      await tester.pump(const Duration(milliseconds: 100));

      // Look for share icon button
      expect(
        find.byIcon(Icons.share_outlined),
        findsWidgets,
      );
    });

    testWidgets('chat bubbles hidden by default', (tester) async {
      await tester.pumpWidget(buildTestWidget(testEntry));
      await tester.pump(const Duration(milliseconds: 100));

      // Conversation starters should not be visible initially
      expect(find.text('What do you think?'), findsNothing);
    });

    testWidgets('renders with empty tags', (tester) async {
      final entryNoTags = ArticleFeedEntry(
        id: 2,
        title: 'No Tags Article',
        summary: 'Article without any tags.',
        source: 'Source',
        publishedAt: DateTime(2025, 2, 10),
        url: 'https://example.com/no-tags',
        imageUrl: 'https://example.com/img.jpg',
        category: 'General',
        readTime: 3,
        tags: [],
        freshnessTier: FreshnessTier.evergreen,
      );

      await tester.pumpWidget(buildTestWidget(entryNoTags));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('No Tags Article'), findsOneWidget);
    });

    testWidgets('renders recentlyAdded tier correctly', (tester) async {
      final recentEntry = ArticleFeedEntry(
        id: 3,
        title: 'Recently Added Article',
        summary: 'This was added recently but published earlier.',
        source: 'Source',
        publishedAt: DateTime(2025, 2, 5),
        addedAt: DateTime(2025, 2, 10),
        url: 'https://example.com/recent',
        imageUrl: 'https://example.com/img.jpg',
        category: 'News',
        readTime: 4,
        freshnessTier: FreshnessTier.recentlyAdded,
      );

      await tester.pumpWidget(buildTestWidget(recentEntry));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Recently Added Article'), findsOneWidget);
    });
  });
}
