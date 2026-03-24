@Tags(['widget'])
library saved_items_page_test;

import 'package:blips_mobile/features/feed/domain/saved_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../test_utils/app_ui_test_harness.dart';
import '../test_utils/fake_backend_api_client.dart';
import '../test_utils/fake_feed_cache.dart';
import '../test_utils/recording_platforms.dart';

void main() {
  late UrlLauncherPlatform originalUrlLauncher;
  late RecordingUrlLauncherPlatform recordingUrlLauncher;

  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    originalUrlLauncher = UrlLauncherPlatform.instance;
    recordingUrlLauncher = RecordingUrlLauncherPlatform();
    UrlLauncherPlatform.instance = recordingUrlLauncher;
  });

  tearDown(() {
    UrlLauncherPlatform.instance = originalUrlLauncher;
  });

  testWidgets('saved tab lists saved articles and videos and opens source url',
      (tester) async {
    final api = FakeBackendApiClient(
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
    final cache = FakeFeedCache();
    await cache.saveArticleBookmark(
      SavedArticleItem(
        contentId: 11,
        sourceUrl: 'https://example.com/article-saved',
        title: 'Saved article title',
        source: 'Example News',
        imageUrl: 'https://example.com/article.jpg',
        category: 'Technology',
        publishedAt: DateTime.utc(2026, 3, 20),
        savedAt: DateTime.utc(2026, 3, 21, 9),
      ),
    );
    await cache.saveVideoBookmark(
      SavedVideoItem(
        contentId: 22,
        sourceUrl: 'https://example.com/video-saved',
        title: 'Saved video title',
        source: 'Creator',
        thumbnailUrl: 'https://example.com/video.jpg',
        category: 'Technology',
        publishedAt: DateTime.utc(2026, 3, 20),
        savedAt: DateTime.utc(2026, 3, 21, 10),
      ),
    );

    await tester.pumpWidget(
      buildAppUiHarness(
        api: api,
        onboardingDone: true,
        cache: cache,
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('nav-Saved')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Saved article title'), findsOneWidget);
    expect(find.text('Example News'), findsOneWidget);

    await tester.tap(find.text('Saved article title'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(recordingUrlLauncher.launches, hasLength(1));
    expect(
      recordingUrlLauncher.launches.single.url,
      'https://example.com/article-saved',
    );

    await tester.tap(find.text('Videos'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Saved video title'), findsOneWidget);
    expect(find.text('Creator'), findsOneWidget);

    await tester.tap(find.text('Articles'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.byTooltip('Remove from saved'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Saved article title'), findsNothing);
    expect(find.text('No saved articles yet'), findsOneWidget);
  });
}
