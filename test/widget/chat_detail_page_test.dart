@Tags(['widget'])
library chat_detail_page_test;

import 'dart:async';

import 'package:blips_mobile/features/chat/domain/chat_models.dart';
import 'package:blips_mobile/features/chat/presentation/chat_detail_page.dart';
import 'package:blips_mobile/features/chat/providers/chat_providers.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../test_utils/recording_chat_repository.dart';

void main() {
  ArticleFeedEntry buildArticle({String? imageUrl}) {
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

  ChatConversation buildConversation({
    required ArticleFeedEntry article,
    int messageCount = 24,
  }) {
    return ChatConversation(
      articleId: article.id,
      article: article,
      messages: List<ChatMessage>.generate(
        messageCount,
        (index) => ChatMessage(
          id: 'msg-$index',
          role: index.isEven ? 'assistant' : 'user',
          content: 'Message $index',
          timestamp: DateTime.utc(2026, 3, 20, 12, index),
        ),
      ),
    );
  }

  Widget buildTestWidget({
    required ArticleFeedEntry article,
    RecordingChatRepository? repository,
    ChatConversation? existingConversation,
  }) {
    return ProviderScope(
      overrides: [
        chatRepositoryProvider.overrideWithValue(
          repository ?? RecordingChatRepository(),
        ),
      ],
      child: MaterialApp(
        home: ChatDetailPage(
          article: article,
          existingConversation: existingConversation,
        ),
      ),
    );
  }

  testWidgets(
    'renders placeholder thumbnail when the article image is missing',
    (tester) async {
      await tester.pumpWidget(
        buildTestWidget(article: buildArticle(imageUrl: null)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chat article'), findsOneWidget);
      expect(find.byIcon(Icons.devices_outlined), findsOneWidget);
    },
  );

  testWidgets('tapping outside the composer dismisses the keyboard', (
    tester,
  ) async {
    final article = buildArticle();

    await tester.pumpWidget(
      buildTestWidget(
        article: article,
        existingConversation: buildConversation(
          article: article,
          messageCount: 2,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.showKeyboard(find.byType(TextField));
    await tester.pump();

    final editableText = tester.state<EditableTextState>(
      find.byType(EditableText),
    );
    expect(editableText.widget.focusNode.hasFocus, isTrue);

    await tester.tapAt(tester.getCenter(find.byType(ListView)));
    await tester.pumpAndSettle();

    expect(editableText.widget.focusNode.hasFocus, isFalse);
  });

  testWidgets('dragging the chat list dismisses the keyboard', (tester) async {
    final article = buildArticle();

    await tester.pumpWidget(
      buildTestWidget(
        article: article,
        existingConversation: buildConversation(article: article),
      ),
    );
    await tester.pumpAndSettle();

    await tester.showKeyboard(find.byType(TextField));
    await tester.pump();

    final editableText = tester.state<EditableTextState>(
      find.byType(EditableText),
    );
    expect(editableText.widget.focusNode.hasFocus, isTrue);

    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();

    expect(editableText.widget.focusNode.hasFocus, isFalse);
  });

  testWidgets('chat list is wired as the primary iOS scroll-to-top target', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final article = buildArticle();

      await tester.pumpWidget(
        buildTestWidget(
          article: article,
          existingConversation: buildConversation(
            article: article,
            messageCount: 40,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final listController = PrimaryScrollController.of(
        tester.element(find.byType(ListView)),
      );
      final scaffoldController = PrimaryScrollController.of(
        tester.element(find.byType(Scaffold)),
      );

      expect(identical(scaffoldController, listController), isTrue);
      expect(scaffoldController.offset, greaterThan(0));

      unawaited(
        scaffoldController.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        ),
      );
      await tester.pumpAndSettle();

      expect(scaffoldController.offset, 0);
      expect(find.text('Message 0'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
