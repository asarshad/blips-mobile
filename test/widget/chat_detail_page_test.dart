@Tags(['widget'])
library chat_detail_page_test;

import 'package:blips_mobile/features/chat/presentation/chat_detail_page.dart';
import 'package:blips_mobile/features/chat/providers/chat_providers.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
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

  Widget buildTestWidget({
    required ArticleFeedEntry article,
    RecordingChatRepository? repository,
  }) {
    return ProviderScope(
      overrides: [
        chatRepositoryProvider.overrideWithValue(
          repository ?? RecordingChatRepository(),
        ),
      ],
      child: MaterialApp(
        home: ChatDetailPage(article: article),
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
}
