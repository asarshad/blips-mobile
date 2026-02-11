/// Widget tests for FloatingChatBubbles.
///
/// Tests the conversation starter bubbles that appear when tapping
/// the chat button on feed cards. Starters are pre-generated during
/// content ingestion and delivered inline in the feed response.
@Tags(['widget'])
library;

import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:blips_mobile/features/feed/presentation/widgets/floating_chat_bubbles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  late ArticleFeedEntry articleWithStarters;
  late ArticleFeedEntry articleWithoutStarters;
  late VideoFeedEntry videoWithStarters;

  setUp(() {
    articleWithStarters = ArticleFeedEntry(
      id: 1,
      title: 'Test Article Title',
      summary: 'Test article summary for testing purposes.',
      source: 'Test Source',
      publishedAt: DateTime.utc(2025, 1, 1),
      url: 'https://example.com/article',
      imageUrl: 'https://example.com/image.png',
      category: 'Technology',
      readTime: 5,
      tags: const ['Test'],
      conversationStarters: const [
        'What are the implications of this article?',
        'Can you explain the main points?',
        'How does this compare to similar developments?',
      ],
    );

    articleWithoutStarters = ArticleFeedEntry(
      id: 2,
      title: 'Article Without Starters',
      summary: 'No starters available.',
      source: 'Test Source',
      publishedAt: DateTime.utc(2025, 1, 1),
      url: 'https://example.com/article2',
      imageUrl: 'https://example.com/image2.png',
      category: 'Technology',
      readTime: 3,
      tags: const ['Test'],
    );

    videoWithStarters = VideoFeedEntry(
      id: 3,
      title: 'Test Video Title',
      summary: 'Test video summary.',
      videoUrl: 'https://cdn.example.com/video.mp4',
      link: 'https://youtube.com/watch?v=test123',
      thumbnailUrl: 'https://example.com/thumb.png',
      source: 'YouTube',
      category: 'Technology',
      publishedAt: DateTime.utc(2025, 1, 2),
      readTime: 3,
      conversationStarters: const [
        'What are the key takeaways from this video?',
        'Can you summarize the demo?',
        'How does this technology work?',
      ],
    );
  });

  Widget createTestWidget({
    required FeedEntry entry,
    VoidCallback? onClose,
  }) {
    return ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: FloatingChatBubbles(
            entry: entry,
            onClose: onClose ?? () {},
          ),
        ),
      ),
    );
  }

  group('FloatingChatBubbles', () {
    testWidgets('renders inline starters immediately (no loading)',
        (tester) async {
      await tester.pumpWidget(createTestWidget(entry: articleWithStarters));

      // Should render immediately — no loading state, no API call
      expect(find.textContaining('implications'), findsOneWidget);
      expect(find.textContaining('main points'), findsOneWidget);
      expect(find.textContaining('similar developments'), findsOneWidget);
    });

    testWidgets('shows "Ask something else..." bubble', (tester) async {
      await tester.pumpWidget(createTestWidget(entry: articleWithStarters));

      expect(find.textContaining('Ask something else'), findsOneWidget);
    });

    testWidgets('uses static defaults when no starters available',
        (tester) async {
      await tester.pumpWidget(
          createTestWidget(entry: articleWithoutStarters));

      // Should show the static defaults
      expect(find.textContaining('key takeaways'), findsOneWidget);
      expect(find.textContaining('main concepts'), findsOneWidget);
      expect(find.textContaining('everyday users'), findsOneWidget);
    });

    testWidgets('bubbles column is right-aligned', (tester) async {
      await tester.pumpWidget(createTestWidget(entry: articleWithStarters));

      final columns = tester.widgetList<Column>(find.byType(Column));
      final hasRightAligned = columns.any(
        (col) => col.crossAxisAlignment == CrossAxisAlignment.end,
      );
      expect(hasRightAligned, isTrue);
    });

    testWidgets('works with video entries', (tester) async {
      await tester.pumpWidget(createTestWidget(entry: videoWithStarters));

      expect(find.textContaining('key takeaways'), findsOneWidget);
      expect(find.textContaining('summarize the demo'), findsOneWidget);
    });

    testWidgets('calls onClose when bubble is tapped', (tester) async {
      var closeCalled = false;

      await tester.pumpWidget(
        createTestWidget(
          entry: articleWithStarters,
          onClose: () => closeCalled = true,
        ),
      );

      // Tap the first bubble
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      expect(closeCalled, isTrue);
    });

    testWidgets('limits to 3 starters max', (tester) async {
      await tester.pumpWidget(createTestWidget(entry: articleWithStarters));

      // 3 starter bubbles + 1 "Ask something else..." = 4 InkWell total
      expect(find.byType(InkWell), findsNWidgets(4));
    });
  });

  group('FloatingChatBubbles responsiveness', () {
    testWidgets('adapts to narrow width', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 280,
                child: FloatingChatBubbles(
                  entry: articleWithStarters,
                  onClose: () {},
                ),
              ),
            ),
          ),
        ),
      );

      // Should render without overflow
      expect(tester.takeException(), isNull);
    });

    testWidgets('adapts to wide width', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 600,
                child: FloatingChatBubbles(
                  entry: articleWithStarters,
                  onClose: () {},
                ),
              ),
            ),
          ),
        ),
      );

      // Should render without issues
      expect(tester.takeException(), isNull);
    });
  });
}
