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
}
