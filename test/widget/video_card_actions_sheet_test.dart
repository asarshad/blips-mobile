@Tags(['widget'])
library video_card_actions_sheet_test;

import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:blips_mobile/features/feed/presentation/cards/video_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_utils/fake_backend_api_client.dart';
import '../test_utils/feed_interaction_test_harness.dart';

void main() {
  late VideoFeedEntry video;
  late FakeBackendApiClient api;

  Widget buildTestWidget() {
    return buildFeedInteractionHarness(
      api: api,
      child: VideoCard(
        entry: video,
        isVisible: false,
      ),
    );
  }

  setUp(() {
    api = FakeBackendApiClient(
      responses: const {
        '/session/interactions': <String, dynamic>{},
      },
    );
    video = VideoFeedEntry(
      id: 12,
      title: 'Action sheet video',
      summary: 'Summary',
      videoUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      link: 'https://example.com/video-source',
      source: 'Creator Name',
      category: 'Technology',
      publishedAt: DateTime.utc(2026, 3, 20),
      readTime: 3,
      thumbnailUrl: 'https://example.com/thumb.jpg',
    );
  });

  testWidgets('long press sheet no longer shows save video action',
      (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    await tester.longPress(find.byType(VideoCard));
    await tester.pumpAndSettle();

    expect(find.text('Save video'), findsNothing);
    expect(find.text('Block Creator Name'), findsOneWidget);
  });

  testWidgets('long press and choose less from creator records interaction',
      (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    await tester.longPress(find.byType(VideoCard));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Block Creator Name'));
    await tester.pumpAndSettle();

    final body = api.requests
        .lastWhere((request) => request.method == 'POST')
        .body as Map<String, dynamic>?;
    expect(body, isNotNull);
    expect(body!['event_type'], 'LESS_FROM_CREATOR');
    expect(
      find.text('Creator Name blocked and removed from your feed.'),
      findsOneWidget,
    );
  });
}
