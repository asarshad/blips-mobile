@Tags(['widget'])
library chat_detail_page_test;

import 'dart:async';

import 'package:blips_mobile/features/chat/data/chat_repository.dart';
import 'package:blips_mobile/features/chat/domain/chat_models.dart';
import 'package:blips_mobile/features/chat/presentation/chat_detail_page.dart';
import 'package:blips_mobile/features/chat/providers/chat_providers.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../test_utils/fake_chat_repository.dart';
import '../test_utils/recording_chat_repository.dart';

final class _ArticleQuotaErrorChatRepository extends FakeChatRepository {
  _ArticleQuotaErrorChatRepository();

  @override
  Future<ChatResponse> sendMessage(
    int articleId,
    String message, {
    bool starterPrompt = false,
  }) async {
    throw DioException(
      requestOptions: RequestOptions(path: '/ai/respond'),
      response: Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: '/ai/respond'),
        statusCode: 429,
        data: <String, dynamic>{
          'detail': 'Article message quota exceeded',
          'quota_type': 'article',
          'message':
              'You have reached today\'s limit for this item. Try another story or come back tomorrow.',
        },
      ),
      type: DioExceptionType.badResponse,
    );
  }
}

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
    ChatRepository? repository,
    ChatConversation? existingConversation,
    String? initialPrompt,
    bool initialPromptIsStarter = false,
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
          initialPrompt: initialPrompt,
          initialPromptIsStarter: initialPromptIsStarter,
        ),
      ),
    );
  }

  testWidgets('renders placeholder thumbnail when the article image is missing',
      (tester) async {
    await tester.pumpWidget(
      buildTestWidget(
        article: buildArticle(imageUrl: null),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chat article'), findsOneWidget);
    expect(find.byIcon(Icons.devices_outlined), findsOneWidget);
  });

  testWidgets('starter prompt sends immediately and follow-up can be sent',
      (tester) async {
    final repository = RecordingChatRepository(
      responseContent: 'Initial AI answer',
      responseId: null,
      usedCachedStarterResponse: true,
    );

    await tester.pumpWidget(
      buildTestWidget(
        article: buildArticle(),
        repository: repository,
        initialPrompt: 'What are the key takeaways?',
        initialPromptIsStarter: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      repository.sentMessages
          .map((entry) => (entry.message, entry.starterPrompt)),
      [('What are the key takeaways?', true)],
    );

    await tester.enterText(find.byType(TextField), 'what else?');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(
      repository.sentMessages
          .map((entry) => (entry.message, entry.starterPrompt)),
      [('What are the key takeaways?', true), ('what else?', false)],
    );
    expect(find.text('Initial AI answer'), findsWidgets);
  });

  testWidgets('article quota errors keep the limit scoped to this item',
      (tester) async {
    await tester.pumpWidget(
      buildTestWidget(
        article: buildArticle(),
        repository: _ArticleQuotaErrorChatRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'what else?');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(find.text('Chat limit reached for this item today'), findsOneWidget);
    expect(find.text('what else?'), findsOneWidget);
    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.enabled, isFalse);
  });

  testWidgets('tapping outside the composer dismisses the keyboard',
      (tester) async {
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

  testWidgets('chat list is wired as the primary iOS scroll-to-top target',
      (tester) async {
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
