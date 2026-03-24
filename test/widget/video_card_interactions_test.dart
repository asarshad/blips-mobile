@Tags(['widget'])
library video_card_interactions_test;

import 'package:blips_mobile/features/chat/presentation/chat_detail_page.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:blips_mobile/features/feed/presentation/cards/video_card.dart';
import 'package:blips_mobile/features/feed/presentation/widgets/share_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../test_utils/fake_backend_api_client.dart';
import '../test_utils/feed_interaction_test_harness.dart';
import '../test_utils/recording_platforms.dart';

void main() {
  late VideoFeedEntry video;
  late FakeBackendApiClient api;
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
    api = delayedInteractionApi();
    video = VideoFeedEntry(
      id: 10,
      title: 'Video interaction contract',
      summary:
          'A video used to prove share/open/chat interactions are immediate.',
      videoUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      link: 'https://www.theverge.com/2026/03/20/video-story',
      source: 'YouTube',
      category: 'Technology',
      publishedAt: DateTime.utc(2026, 3, 1),
      readTime: 3,
      thumbnailUrl: 'https://example.com/thumb.jpg',
      conversationStarters: const [
        'Summarize the main point.',
        'Why does this matter?',
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
        api: api,
        child: VideoCard(
          entry: video,
          isVisible: false,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('content tap launches source immediately', (tester) async {
    await pumpHarness(tester);

    await tester.tap(find.text(video.title));
    await tester.pump(const Duration(milliseconds: 50));

    expect(recordingUrlLauncher.launches, hasLength(1));
    expect(
      recordingUrlLauncher.launches.single.url,
      'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
    );

    await settleDelayedInteraction(tester);
  });

  testWidgets('share action invokes share immediately', (tester) async {
    await pumpHarness(tester);

    await tester.tap(find.byIcon(Icons.share_outlined));
    await tester.pump(const Duration(milliseconds: 50));

    expect(recordingSharePlatform.shares, hasLength(1));
    final params = recordingSharePlatform.shares.single;
    expect(params.subject, video.title);
    expect(params.text, contains(video.link));
    expect(params.text, contains('Shared via Blips News'));

    await settleDelayedInteraction(tester);
  });

  testWidgets('bookmark toggle fills immediately and records save signal',
      (tester) async {
    await pumpHarness(tester);

    await tester.tap(find.byIcon(Icons.bookmark_border_rounded));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);

    final body = api.requests
        .lastWhere((request) => request.method == 'POST')
        .body as Map<String, dynamic>?;
    expect(body, isNotNull);
    expect(body!['event_type'], 'VIDEO_SAVE');

    await settleDelayedInteraction(tester);
  });

  testWidgets('chat button reveals conversation starters', (tester) async {
    await pumpHarness(tester);

    await tester.tap(find.byIcon(Icons.auto_awesome_rounded).first);
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Summarize the main point.'), findsOneWidget);
    expect(find.text('Ask something else...'), findsOneWidget);

    await settleDelayedInteraction(tester);
  });

  testWidgets('starter tap navigates to chat detail immediately',
      (tester) async {
    await pumpHarness(tester);

    await tester.tap(find.byIcon(Icons.auto_awesome_rounded).first);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Summarize the main point.'));
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
