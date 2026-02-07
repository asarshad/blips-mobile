/// Golden tests for FloatingChatBubbles.
///
/// Ensures visual consistency of conversation starter bubbles
/// across different screen sizes.
@Tags(['golden'])
library;

import 'package:blips_mobile/features/feed/data/starters_repository.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:blips_mobile/features/feed/presentation/widgets/floating_chat_bubbles.dart';
import 'package:blips_mobile/features/feed/providers/starters_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'golden_test_utils.dart';

/// Mock starters data for golden tests.
final _mockStarters = ConversationStarters(
  contentId: 1,
  starters: [
    'What are the main implications?',
    'Can you explain this in simpler terms?',
    'How does this compare to previous breakthroughs?',
  ],
  fallback: ['What should I know about this?'],
);

/// Wraps widget with ProviderScope and mocked starters.
Widget _goldenTestWrapper({
  required DeviceConfig device,
  required Widget child,
  required int contentId,
}) {
  return ProviderScope(
    overrides: [
      startersProvider(contentId).overrideWith((ref) async => _mockStarters),
    ],
    child: goldenTestWrapper(device: device, child: child),
  );
}

void main() {
  group('FloatingChatBubbles Golden Tests', () {
    final article = ArticleFeedEntry(
      id: 1,
      title: 'AI Breakthrough Revolutionizes Natural Language Processing',
      summary: 'Researchers achieve new milestone in AI development.',
      source: 'TechNews',
      publishedAt: DateTime.utc(2025, 1, 1),
      url: 'https://example.com/article',
      imageUrl: 'https://example.com/image.png',
      category: 'Technology',
      readTime: 5,
      tags: const ['AI', 'Technology'],
    );

    final cases = <({DeviceConfig device, String suffix})>[
      (device: GoldenDevices.smallPhone, suffix: 'small'),
      (device: GoldenDevices.largePhone, suffix: 'large'),
    ];

    for (final c in cases) {
      testWidgets('FloatingChatBubbles ${c.suffix}', (tester) async {
        await tester.setDeviceConfig(c.device);

        await tester.pumpWidget(
          _goldenTestWrapper(
            device: c.device,
            contentId: article.id,
            child: Scaffold(
              backgroundColor: Colors.grey[200],
              body: Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: FloatingChatBubbles(
                    entry: article,
                    onClose: () {},
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/chat_bubbles_${c.suffix}.png'),
        );
      });
    }

    testWidgets('FloatingChatBubbles with long title', (tester) async {
      await tester.setDeviceConfig(GoldenDevices.smallPhone);

      final longTitleArticle = ArticleFeedEntry(
        id: 2,
        title:
            'This Is A Very Long Article Title That Should Wrap Properly And Test Text Truncation Behavior In The Bubble',
        summary: 'Summary text.',
        source: 'Source',
        publishedAt: DateTime.utc(2025, 1, 1),
        url: 'https://example.com/article',
        imageUrl: 'https://example.com/image.png',
        category: 'Technology',
        readTime: 5,
        tags: const [],
      );

      // Create mock starters for the long title article
      final longTitleMockStarters = ConversationStarters(
        contentId: 2,
        starters: _mockStarters.starters,
        fallback: _mockStarters.fallback,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            startersProvider(longTitleArticle.id)
                .overrideWith((ref) async => longTitleMockStarters),
          ],
          child: goldenTestWrapper(
            device: GoldenDevices.smallPhone,
            child: Scaffold(
              backgroundColor: Colors.grey[200],
              body: Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: FloatingChatBubbles(
                    entry: longTitleArticle,
                    onClose: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/chat_bubbles_long_title.png'),
      );
    });
  });
}
