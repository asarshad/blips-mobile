@Tags(['widget'])
library app_navigation_test;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_utils/app_ui_test_harness.dart';
import '../test_utils/fake_backend_api_client.dart';

void main() {
  Future<void> pumpUi(WidgetTester tester,
      [Duration duration = const Duration(seconds: 1)]) async {
    await tester.pump(duration);
    await tester.pump();
  }

  Finder findShellPageView() => find.byWidgetPredicate(
        (widget) =>
            widget is PageView && widget.scrollDirection == Axis.horizontal,
      );

  Finder findVerticalFeedPageView() => find.byWidgetPredicate(
        (widget) =>
            widget is PageView && widget.scrollDirection == Axis.vertical,
      );

  Map<String, dynamic> buildArticlePlaylistResponseForIds(
    List<int> ids, {
    String feedVersion = 'article-v1',
  }) {
    return {
      'items': ids
          .map(
            (id) => {
              'id': id,
              'type': 'ARTICLE',
              'title': 'App shell article $id',
              'source': 'Example News',
              'source_url': 'https://example.com/article/$id',
              'summary':
                  'Article summary for shell navigation testing item $id.',
              'image_url': 'https://example.com/article_$id.jpg',
              'published_at': '2026-03-20T12:00:00Z',
              'created_at': '2026-03-20T12:05:00Z',
              'topics': ['Technology'],
              'conversation_starters': {
                'starters': ['Summarize this article.'],
              },
            },
          )
          .toList(growable: false),
      'session_id': 'articles-session',
      'cursor': ids.length,
      'has_more': true,
      'feed_version': feedVersion,
    };
  }

  FakeBackendApiClient buildApi() {
    return FakeBackendApiClient(
      responseResolver: (method, path, queryParameters, body) {
        if (method == 'GET' && path == '/session/playlist') {
          final type = queryParameters?['type'] as String?;
          return switch (type) {
            'ARTICLE' => buildArticlePlaylistResponse(),
            'VIDEO' => buildVideoPlaylistResponse(),
            _ => <String, dynamic>{'items': const <Map<String, dynamic>>[]},
          };
        }
        if (method == 'GET' && path == '/videos/reels') {
          return buildReelsResponse();
        }
        if (method == 'POST' && path == '/session/interactions') {
          return const <String, dynamic>{};
        }
        return const <String, dynamic>{};
      },
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
  });

  testWidgets('shell navigation reaches all primary app surfaces',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      buildAppUiHarness(
        api: buildApi(),
        onboardingDone: true,
      ),
    );
    await pumpUi(tester, const Duration(seconds: 2));

    expect(find.text('ART 1/1+'), findsOneWidget);

    await tester.drag(findShellPageView(), const Offset(-500, 0));
    await pumpUi(tester);
    expect(find.text('VID 1/1+'), findsOneWidget);

    await tester.drag(findShellPageView(), const Offset(-500, 0));
    await pumpUi(tester);
    expect(find.text('REEL 1/1+'), findsOneWidget);

    await tester.drag(findShellPageView(), const Offset(-500, 0));
    await pumpUi(tester);
    expect(find.text('Your Conversations'), findsOneWidget);

    await tester.drag(findShellPageView(), const Offset(-500, 0));
    await pumpUi(tester);
    expect(find.text('No saved articles yet'), findsOneWidget);

    await tester.drag(findShellPageView(), const Offset(-500, 0));
    await pumpUi(tester);
    expect(find.text('Settings'), findsWidgets);

    await pumpUi(tester, const Duration(milliseconds: 700));
  });

  testWidgets('re-tapping the current feed tab shows refresh feedback',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      buildAppUiHarness(
        api: buildApi(),
        onboardingDone: true,
      ),
    );
    await pumpUi(tester, const Duration(seconds: 2));

    await tester.tap(find.byIcon(Icons.article));
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.text('Refreshing feed...'), findsOneWidget);

    await pumpUi(tester, const Duration(milliseconds: 700));
  });

  testWidgets(
      're-tapping the current feed tab keeps position and surfaces View latest until tapped',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = FakeBackendApiClient(
      responseResolver: (method, path, queryParameters, body) {
        if (method == 'GET' && path == '/session/playlist') {
          final type = queryParameters?['type'] as String?;
          return switch (type) {
            'ARTICLE' => buildArticlePlaylistResponseForIds(
                List<int>.generate(15, (index) => index + 1),
              ),
            'VIDEO' => buildVideoPlaylistResponse(),
            _ => <String, dynamic>{'items': const <Map<String, dynamic>>[]},
          };
        }
        if (method == 'GET' && path == '/videos/reels') {
          return buildReelsResponse();
        }
        if (method == 'POST' && path == '/session/interactions') {
          return const <String, dynamic>{};
        }
        return const <String, dynamic>{};
      },
    );

    await tester.pumpWidget(
      buildAppUiHarness(
        api: api,
        onboardingDone: true,
      ),
    );
    await pumpUi(tester, const Duration(seconds: 2));

    expect(find.text('ART 1/15+'), findsOneWidget);

    await tester.drag(findVerticalFeedPageView().first, const Offset(0, -850));
    await pumpUi(tester, const Duration(milliseconds: 500));
    await tester.drag(findVerticalFeedPageView().first, const Offset(0, -850));
    await pumpUi(tester, const Duration(milliseconds: 500));

    expect(find.text('ART 3/15+'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.article));
    await pumpUi(tester, const Duration(milliseconds: 900));

    expect(find.text('ART 3/15+'), findsOneWidget);
    expect(find.text('View latest'), findsOneWidget);

    await tester.tap(find.text('View latest'));
    await tester.pump();
    await pumpUi(tester, const Duration(milliseconds: 400));

    expect(find.text('ART 1/15+'), findsOneWidget);
    expect(find.text('View latest'), findsNothing);
  });
}
