@Tags(['widget'])
library chat_page_test;

import 'package:blips_mobile/features/chat/domain/chat_models.dart';
import 'package:blips_mobile/features/chat/presentation/chat_detail_page.dart';
import 'package:blips_mobile/features/chat/presentation/chat_page.dart';
import 'package:blips_mobile/features/chat/providers/chat_providers.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../test_utils/recording_chat_repository.dart';

void main() {
  ArticleFeedEntry buildArticle(
      {String? imageUrl = 'https://example.com/article.jpg'}) {
    return ArticleFeedEntry(
      id: 1,
      title: 'Chat article',
      summary: 'Summary',
      source: 'Example News',
      publishedAt: DateTime.utc(2026, 3, 20),
      url: 'https://example.com/article',
      imageUrl: imageUrl,
      category: 'Technology',
      readTime: 4,
    );
  }

  Widget buildTestWidget(RecordingChatRepository repository) {
    return ProviderScope(
      overrides: [
        chatRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(
        home: ChatPage(),
      ),
    );
  }

  testWidgets('renders the empty state when there are no conversations',
      (tester) async {
    final repository = RecordingChatRepository();

    await tester.pumpWidget(buildTestWidget(repository));
    await tester.pumpAndSettle();

    expect(find.text('No conversations yet.'), findsOneWidget);
  });

  testWidgets('tapping a conversation opens chat detail', (tester) async {
    final article = buildArticle();
    final repository = RecordingChatRepository(
      conversations: [
        ChatConversation(
          articleId: article.id,
          article: article,
          messages: [
            ChatMessage(
              id: 'm1',
              role: 'assistant',
              content: 'Latest answer',
              timestamp: DateTime.utc(2026, 3, 20, 8),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(buildTestWidget(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Chat article'));
    await tester.pumpAndSettle();

    expect(find.byType(ChatDetailPage), findsOneWidget);
  });

  testWidgets('delete icon removes a conversation after confirmation',
      (tester) async {
    final article = buildArticle();
    final repository = RecordingChatRepository(
      conversations: [
        ChatConversation(
          articleId: article.id,
          article: article,
          messages: [
            ChatMessage(
              id: 'm1',
              role: 'assistant',
              content: 'Latest answer',
              timestamp: DateTime.utc(2026, 3, 20, 8),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(buildTestWidget(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.text('Delete Chat'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(repository.deletedArticleIds, <int>[article.id]);
    expect(find.text('No conversations yet.'), findsOneWidget);
  });

  testWidgets('renders placeholder thumbnail when a chat article has no image',
      (tester) async {
    final article = buildArticle(imageUrl: null);
    final repository = RecordingChatRepository(
      conversations: [
        ChatConversation(
          articleId: article.id,
          article: article,
          messages: [
            ChatMessage(
              id: 'm1',
              role: 'assistant',
              content: 'Latest answer',
              timestamp: DateTime.utc(2026, 3, 20, 8),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(buildTestWidget(repository));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.devices_outlined), findsOneWidget);
    expect(find.text('Chat article'), findsOneWidget);
  });
}
