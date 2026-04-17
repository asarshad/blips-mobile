@Tags(['widget'])
library feed_shell_cold_start_test;

import 'dart:async';

import 'package:blips_mobile/features/ads/domain/ads_config.dart';
import 'package:blips_mobile/features/ads/providers/ads_providers.dart';
import 'package:blips_mobile/features/chat/providers/chat_providers.dart';
import 'package:blips_mobile/features/feed/data/feed_repository.dart';
import 'package:blips_mobile/features/feed/presentation/feed_shell_page.dart';
import 'package:blips_mobile/features/feed/providers/feed_providers.dart';
import 'package:blips_mobile/features/feed/providers/video/youtube_player_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_utils/app_ui_test_harness.dart';
import '../test_utils/fake_backend_api_client.dart';
import '../test_utils/fake_chat_repository.dart';
import '../test_utils/fake_feed_cache.dart';
import '../test_utils/fake_youtube_player_manager.dart';

void main() {
  Future<void> pumpUi(
    WidgetTester tester, [
    Duration duration = const Duration(seconds: 1),
  ]) async {
    await tester.pump(duration);
    await tester.pump();
  }

  Future<void> pumpUntil(
    WidgetTester tester,
    bool Function() condition, {
    int maxTicks = 40,
  }) async {
    for (var i = 0; i < maxTicks; i++) {
      if (condition()) {
        break;
      }
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump();
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
  });

  testWidgets(
    'cold startup keeps the shell blocked until the startup feed finishes loading',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final articleResponse = Completer<Map<String, dynamic>>();
      final api = FakeBackendApiClient(
        responseResolver: (method, path, queryParameters, body) {
          if (method == 'GET' && path == '/session/playlist') {
            final type = queryParameters?['type'] as String?;
            return switch (type) {
              'ARTICLE' => articleResponse.future,
              'VIDEO' => buildVideoPlaylistResponse(),
              'REEL' => buildReelsResponse(),
              _ => <String, dynamic>{'items': const <Map<String, dynamic>>[]},
            };
          }
          if (method == 'POST' && path == '/session/interactions') {
            return const <String, dynamic>{};
          }
          return const <String, dynamic>{};
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adsConfigProvider.overrideWith((ref) async => const AdsConfig()),
            feedRepositoryProvider.overrideWithValue(FeedRepository(api)),
            feedCacheProvider.overrideWithValue(FakeFeedCache()),
            chatRepositoryProvider.overrideWithValue(FakeChatRepository()),
            youtubePlayerManagerProvider.overrideWith(
              (ref) => FakeYoutubePlayerManager(),
            ),
          ],
          child: const MaterialApp(
            home: FeedShellPage(),
          ),
        ),
      );
      await pumpUntil(
        tester,
        () => find.byKey(FeedShellPage.startupLoaderKey).evaluate().isNotEmpty,
      );

      expect(find.byKey(FeedShellPage.startupLoaderKey), findsOneWidget);
      expect(find.text('App shell article'), findsNothing);

      articleResponse.complete(buildArticlePlaylistResponse());
      await pumpUntil(
        tester,
        () => find.byKey(FeedShellPage.startupLoaderKey).evaluate().isEmpty,
      );

      expect(find.byKey(FeedShellPage.startupLoaderKey), findsNothing);
      expect(find.text('App shell article'), findsOneWidget);
    },
  );
}
