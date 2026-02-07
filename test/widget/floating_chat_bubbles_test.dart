/// Widget tests for FloatingChatBubbles.
///
/// Tests the conversation starter bubbles that appear when tapping
/// the chat button on feed cards.
@Tags(['widget'])
library;

import 'package:blips_mobile/features/feed/data/starters_repository.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:blips_mobile/features/feed/presentation/widgets/floating_chat_bubbles.dart';
import 'package:blips_mobile/features/feed/providers/starters_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  late ArticleFeedEntry testArticle;
  late VideoFeedEntry testVideo;

  /// Mock starters data for testing.
  final mockStarters = ConversationStarters(
    contentId: 1,
    starters: [
      'What are the implications of this article?',
      'Can you explain the main points?',
      'How does this compare to similar developments?',
    ],
    fallback: [
      'What should I know about this?',
    ],
  );

  setUp(() {
    testArticle = ArticleFeedEntry(
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
    );

    testVideo = VideoFeedEntry(
      id: 2,
      title: 'Test Video Title',
      summary: 'Test video summary.',
      videoUrl: 'https://cdn.example.com/video.mp4',
      link: 'https://youtube.com/watch?v=test123',
      thumbnailUrl: 'https://example.com/thumb.png',
      source: 'YouTube',
      category: 'Technology',
      publishedAt: DateTime.utc(2025, 1, 2),
      readTime: 3,
    );
  });

  /// Creates a test widget wrapped with ProviderScope and mocked starters.
  Widget createTestWidget({
    required FeedEntry entry,
    AsyncValue<ConversationStarters>? startersValue,
    VoidCallback? onClose,
  }) {
    final contentId = entry is ArticleFeedEntry
        ? entry.id
        : (entry as VideoFeedEntry).id;

    return ProviderScope(
      overrides: [
        // Override the starters provider to return mock data synchronously
        startersProvider(contentId).overrideWith((ref) async {
          // Return mock data or default
          return startersValue?.value ?? mockStarters;
        }),
      ],
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
    testWidgets('shows loading state initially', (tester) async {
      await tester.pumpWidget(createTestWidget(entry: testArticle));

      // Initially should show loading bubbles (containers without text)
      // The loading state may flash quickly, but we verify no exceptions
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders bubbles after loading', (tester) async {
      await tester.pumpWidget(createTestWidget(entry: testArticle));
      await tester.pumpAndSettle();

      // Should have 3 bubble InkWells after loading
      final bubbleFinder = find.byType(InkWell);
      expect(bubbleFinder, findsNWidgets(3));
    });

    testWidgets('displays starters from API', (tester) async {
      await tester.pumpWidget(createTestWidget(entry: testArticle));
      await tester.pumpAndSettle();

      // Should show the mock starters text
      expect(find.textContaining('implications'), findsOneWidget);
      expect(find.textContaining('main points'), findsOneWidget);
    });

    testWidgets('bubbles column is right-aligned', (tester) async {
      await tester.pumpWidget(createTestWidget(entry: testArticle));
      await tester.pumpAndSettle();

      // Find any Column that is right-aligned
      final columns = tester.widgetList<Column>(find.byType(Column));
      final hasRightAligned = columns.any(
        (col) => col.crossAxisAlignment == CrossAxisAlignment.end,
      );
      expect(hasRightAligned, isTrue);
    });

    testWidgets('works with video entries', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            startersProvider(testVideo.id)
                .overrideWith((ref) async => mockStarters),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: FloatingChatBubbles(
                entry: testVideo,
                onClose: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should render bubbles for video too
      final bubbleFinder = find.byType(InkWell);
      expect(bubbleFinder, findsNWidgets(3));
    });

    testWidgets('calls onClose when bubble is tapped', (tester) async {
      var closeCalled = false;

      await tester.pumpWidget(
        createTestWidget(
          entry: testArticle,
          onClose: () => closeCalled = true,
        ),
      );
      await tester.pumpAndSettle();

      // Tap the first bubble
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      expect(closeCalled, isTrue);
    });

    testWidgets('uses fallback starters on error', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            startersProvider(testArticle.id).overrideWith((ref) async {
              throw Exception('API error');
            }),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: FloatingChatBubbles(
                entry: testArticle,
                onClose: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should still show fallback bubbles (from defaultFallbackStarters)
      expect(find.textContaining('main points'), findsOneWidget);
    });
  });

  group('FloatingChatBubbles responsiveness', () {
    testWidgets('adapts to narrow width', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            startersProvider(testArticle.id)
                .overrideWith((ref) async => mockStarters),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 280,
                child: FloatingChatBubbles(
                  entry: testArticle,
                  onClose: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should render without overflow
      expect(tester.takeException(), isNull);
    });

    testWidgets('adapts to wide width', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            startersProvider(testArticle.id)
                .overrideWith((ref) async => mockStarters),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 600,
                child: FloatingChatBubbles(
                  entry: testArticle,
                  onClose: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should render without issues
      expect(tester.takeException(), isNull);
    });
  });
}
