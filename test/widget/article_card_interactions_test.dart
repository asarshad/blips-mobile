@Tags(['widget'])
library article_card_interactions_test;

import 'package:blips_mobile/features/chat/presentation/chat_detail_page.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:blips_mobile/features/feed/presentation/cards/article_card.dart';
import 'package:blips_mobile/features/feed/presentation/widgets/share_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../test_utils/fake_backend_api_client.dart';
import '../test_utils/feed_interaction_test_harness.dart';
import '../test_utils/recording_platforms.dart';

void main() {
  late ArticleFeedEntry article;
  late UrlLauncherPlatform originalUrlLauncher;
  late RecordingUrlLauncherPlatform recordingUrlLauncher;
  late RecordingSharePlatform recordingSharePlatform;

  FakeBackendApiClient delayedInteractionApi() {
    return FakeBackendApiClient(
      responseResolver: (method, path, queryParameters, body) async {
        if (method == 'POST' && path == '/session/interactions') {
          await Future<void>.delayed(const Duration(seconds: 5));
        }
        return const <String, dynamic>{};
      },
    );
  }

  setUp(() {
    article = ArticleFeedEntry(
      id: 1,
      title: 'Test Article Title',
      summary: 'This is a test summary for interaction coverage.',
      source: 'Test Source',
      publishedAt: DateTime.utc(2026, 3, 1),
      url: 'https://example.com/article',
      imageUrl: 'https://example.com/image.png',
      category: 'Technology',
      readTime: 5,
      conversationStarters: const [
        'What do you think?',
        'Is this accurate?',
      ],
    );
    originalUrlLauncher = UrlLauncherPlatform.instance;
    recordingUrlLauncher = RecordingUrlLauncherPlatform();
    UrlLauncherPlatform.instance = recordingUrlLauncher;
    recordingSharePlatform = RecordingSharePlatform();
    ShareService.debugOverride = ShareService.test(
      sharePlus: buildRecordingSharePlus(recordingSharePlatform),
      captureOverride: ({
        required context,
        required title,
        required summary,
        required source,
        required category,
        required date,
        required readTime,
        required imageUrl,
        required isVideo,
      }) async =>
          null,
    );
  });

  tearDown(() {
    UrlLauncherPlatform.instance = originalUrlLauncher;
    ShareService.debugOverride = null;
  });

  Future<void> settleDelayedInteraction(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
  }

  Future<void> pumpHarness(WidgetTester tester) async {
    await tester.pumpWidget(
      buildFeedInteractionHarness(
        api: delayedInteractionApi(),
        child: ArticleCard(entry: article),
      ),
    );
    await tester.pump();
  }

  testWidgets('card tap launches source immediately', (tester) async {
    await pumpHarness(tester);

    await tester.tap(find.byType(ArticleCard));
    await tester.pump(const Duration(milliseconds: 50));

    expect(recordingUrlLauncher.launches, hasLength(1));
    expect(recordingUrlLauncher.launches.single.url, article.url);

    await settleDelayedInteraction(tester);
  });

  testWidgets('open action launches source immediately', (tester) async {
    await pumpHarness(tester);

    await tester.tap(find.byIcon(Icons.open_in_new));
    await tester.pump(const Duration(milliseconds: 50));

    expect(recordingUrlLauncher.launches, hasLength(1));
    expect(recordingUrlLauncher.launches.single.url, article.url);

    await settleDelayedInteraction(tester);
  });

  testWidgets('share action invokes share immediately', (tester) async {
    await pumpHarness(tester);

    await tester.tap(find.byIcon(Icons.share_outlined));
    await tester.pump(const Duration(milliseconds: 50));

    expect(recordingSharePlatform.shares, hasLength(1));
    final params = recordingSharePlatform.shares.single;
    expect(params.subject, article.title);
    expect(params.text, contains(article.url));
    expect(params.text, contains('Shared via Blips News'));

    await settleDelayedInteraction(tester);
  });

  testWidgets('chat button reveals conversation starters', (tester) async {
    await pumpHarness(tester);

    await tester.tap(find.byIcon(Icons.auto_awesome_rounded).first);
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('What do you think?'), findsOneWidget);
    expect(find.text('Ask something else...'), findsOneWidget);

    await settleDelayedInteraction(tester);
  });

  testWidgets('starter tap navigates to chat detail immediately',
      (tester) async {
    await pumpHarness(tester);

    await tester.tap(find.byIcon(Icons.auto_awesome_rounded).first);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('What do you think?'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(ChatDetailPage), findsOneWidget);

    await settleDelayedInteraction(tester);
  });

  testWidgets('custom chat bubble navigates to chat detail immediately',
      (tester) async {
    await pumpHarness(tester);

    await tester.tap(find.byIcon(Icons.auto_awesome_rounded).first);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Ask something else...'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(ChatDetailPage), findsOneWidget);

    await settleDelayedInteraction(tester);
  });
}
