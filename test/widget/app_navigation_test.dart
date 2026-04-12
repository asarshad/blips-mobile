@Tags(['widget'])
library app_navigation_test;

import 'package:blips_mobile/features/feed/providers/video/youtube_player_manager_base.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_utils/app_ui_test_harness.dart';
import '../test_utils/fake_backend_api_client.dart';
import '../test_utils/fake_youtube_player_manager.dart';

void main() {
  const videoUrl = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';

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

    expect(find.text('App shell article'), findsOneWidget);

    await tester.drag(findShellPageView(), const Offset(-500, 0));
    await pumpUi(tester);
    expect(find.text('App shell video'), findsOneWidget);

    await tester.drag(findShellPageView(), const Offset(-500, 0));
    await pumpUi(tester);
    expect(find.text('App shell reel'), findsOneWidget);

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

  testWidgets('entering Videos activates the first visible video',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final manager = FakeYoutubePlayerManager();
    await tester.pumpWidget(
      buildAppUiHarness(
        api: buildApi(),
        onboardingDone: true,
        youtubeManager: manager,
      ),
    );
    await pumpUi(tester, const Duration(seconds: 2));

    await tester.drag(findShellPageView(), const Offset(-500, 0));
    await pumpUi(tester, const Duration(milliseconds: 350));
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('App shell video'), findsOneWidget);
    expect(manager.getState(videoUrl), YTPlayerState.playing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('entering Videos and Reels triggers a fresh backend revalidation',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = buildApi();
    await tester.pumpWidget(
      buildAppUiHarness(
        api: api,
        onboardingDone: true,
      ),
    );
    await pumpUi(tester, const Duration(seconds: 2));

    int videoRequests() => api.requests
        .where(
          (request) =>
              request.method == 'GET' &&
              request.path == '/session/playlist' &&
              request.queryParameters?['type'] == 'VIDEO',
        )
        .length;
    int reelRequests() => api.requests
        .where(
          (request) =>
              request.method == 'GET' && request.path == '/videos/reels',
        )
        .length;

    final initialVideoRequests = videoRequests();
    final initialReelRequests = reelRequests();

    await tester.tap(find.byIcon(Icons.play_circle_outline));
    await pumpUi(tester, const Duration(milliseconds: 500));

    expect(videoRequests(), greaterThan(initialVideoRequests));

    await tester.tap(find.byIcon(Icons.movie_filter_outlined));
    await pumpUi(tester, const Duration(milliseconds: 500));

    expect(reelRequests(), greaterThan(initialReelRequests));
  });

  testWidgets('app resume revalidates Articles, Videos, and Reels',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = buildApi();
    await tester.pumpWidget(
      buildAppUiHarness(
        api: api,
        onboardingDone: true,
      ),
    );
    await pumpUi(tester, const Duration(seconds: 2));

    int articleRequests() => api.requests
        .where(
          (request) =>
              request.method == 'GET' &&
              request.path == '/session/playlist' &&
              request.queryParameters?['type'] == 'ARTICLE',
        )
        .length;
    int videoRequests() => api.requests
        .where(
          (request) =>
              request.method == 'GET' &&
              request.path == '/session/playlist' &&
              request.queryParameters?['type'] == 'VIDEO',
        )
        .length;
    int reelRequests() => api.requests
        .where(
          (request) =>
              request.method == 'GET' && request.path == '/videos/reels',
        )
        .length;

    final initialArticleRequests = articleRequests();
    final initialVideoRequests = videoRequests();
    final initialReelRequests = reelRequests();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await pumpUi(tester, const Duration(milliseconds: 500));

    expect(articleRequests(), greaterThan(initialArticleRequests));
    expect(videoRequests(), greaterThan(initialVideoRequests));
    expect(reelRequests(), greaterThan(initialReelRequests));
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

    expect(find.text('App shell article 1'), findsOneWidget);

    await tester.drag(findVerticalFeedPageView().first, const Offset(0, -850));
    await pumpUi(tester, const Duration(milliseconds: 500));
    await tester.drag(findVerticalFeedPageView().first, const Offset(0, -850));
    await pumpUi(tester, const Duration(milliseconds: 500));

    expect(find.text('App shell article 3'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.article));
    await pumpUi(tester, const Duration(milliseconds: 900));

    expect(find.text('App shell article 3'), findsOneWidget);
    expect(find.text('View latest'), findsOneWidget);

    await tester.tap(find.text('View latest'));
    await tester.pump();
    await pumpUi(tester, const Duration(milliseconds: 400));

    expect(find.text('App shell article 1'), findsOneWidget);
    expect(find.text('View latest'), findsNothing);
  });
}
