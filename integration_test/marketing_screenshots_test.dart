@Tags(['integration', 'manual'])
library marketing_screenshots_test;

import 'package:blips_mobile/app.dart';
import 'package:blips_mobile/core/theme/app_theme.dart';
import 'package:blips_mobile/core/theme/debug_overlay.dart';
import 'package:blips_mobile/features/feed/presentation/widgets/feed_status_overlay.dart';
import 'package:blips_mobile/features/feed/providers/video/youtube_player_manager_base.dart';
import 'package:blips_mobile/features/notifications/data/push_notifications_controller.dart';
import 'package:blips_mobile/features/notifications/providers/push_notification_providers.dart';
import 'package:blips_mobile/features/settings/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:integration_test/integration_test.dart';

import '../test/test_utils/app_ui_test_harness.dart';
import '../test/test_utils/fake_backend_api_client.dart';
import '../test/test_utils/fake_youtube_player_manager.dart';

const _feedTitle = 'Your brief, before the rest of the timeline wakes up.';
const _videoTitle = 'Signal over noise, in one scroll.';
const _reelTitle = 'Three clips to catch up before the meeting starts.';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets(
    'captures fresh marketing screenshots for the website',
    (tester) async {
      addTearDown(() {
        DeviceDebugOverlay.suppress = false;
        FeedStatusOverlay.suppress = false;
      });

      DeviceDebugOverlay.suppress = true;
      FeedStatusOverlay.suppress = true;

      final youtubeManager = FakeYoutubePlayerManager();
      final api = FakeBackendApiClient(responseResolver: _resolveResponse);

      await tester.pumpWidget(
        buildAppUiHarness(
          api: api,
          youtubeManager: youtubeManager,
          overrides: [
            pushNotificationsControllerProvider.overrideWith(
              _NoopPushNotificationsController.new,
            ),
          ],
        ),
      );

      await _waitFor(tester, find.byKey(const ValueKey<String>('nav-Feed')));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(BlipsApp)),
      );
      await container
          .read(themeModeProvider.notifier)
          .setThemeMode(AppThemeMode.dark);

      await binding.convertFlutterSurfaceToImage();
      await _waitFor(tester, find.text(_feedTitle));

      youtubeManager
        ..setState(
          'https://www.youtube.com/watch?v=aqz-KE-bpKQ',
          YTPlayerState.ready,
        )
        ..setState(
          'https://www.youtube.com/shorts/jcxgwl9NYFE',
          YTPlayerState.playing,
        );

      await _settleUi(tester);
      await binding.takeScreenshot('screenshot-feed');

      await tester.tap(find.byKey(const ValueKey<String>('nav-Videos')));
      await _waitFor(tester, find.text(_videoTitle));
      await _settleUi(tester);
      await binding.takeScreenshot('screenshot-videos');

      await tester.tap(find.byKey(const ValueKey<String>('nav-Reels')));
      await _waitFor(tester, find.text(_reelTitle));
      await _settleUi(tester);
      await binding.takeScreenshot('screenshot-reels');
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

Future<void> _settleUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump(const Duration(milliseconds: 650));
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
}

Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await _settleUi(tester);
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }

  throw TestFailure('Timed out waiting for $finder');
}

Future<Map<String, dynamic>> _resolveResponse(
  String method,
  String path,
  Map<String, dynamic>? queryParameters,
  Object? _,
) async {
  if (method == 'GET' && path == '/session/playlist') {
    final type = queryParameters?['type'] as String?;
    return switch (type) {
      'ARTICLE' => _buildArticlePlaylistResponse(),
      'VIDEO' => _buildVideoPlaylistResponse(),
      _ => const <String, dynamic>{'items': <Map<String, dynamic>>[]},
    };
  }
  if (method == 'GET' && path == '/videos/reels') {
    return _buildReelsResponse();
  }
  if (method == 'POST' && path == '/session/interactions') {
    return const <String, dynamic>{};
  }
  return const <String, dynamic>{};
}

Map<String, dynamic> _buildArticlePlaylistResponse() {
  return {
    'items': [
      {
        'id': 8101,
        'type': 'ARTICLE',
        'title': _feedTitle,
        'source': 'Blips Desk',
        'source_url': 'https://blips.tech/story/morning-brief',
        'summary': 'A tighter news stack for the day: AI infrastructure, '
            'product moves, and the market context behind them.',
        'image_url': '',
        'published_at': '2026-03-24T09:41:00Z',
        'created_at': '2026-03-24T09:41:00Z',
        'topics': ['Technology'],
        'conversation_starters': {
          'starters': ['Give me the fast read.'],
        },
      },
      {
        'id': 8102,
        'type': 'ARTICLE',
        'title': 'Agent workflows are moving from demo to operating system.',
        'source': 'Blips Desk',
        'source_url': 'https://blips.tech/story/agent-workflows',
        'summary':
            'Why the best product teams are treating AI orchestration as '
                'core UX, not a bolt-on feature.',
        'image_url': '',
        'published_at': '2026-03-24T09:28:00Z',
        'created_at': '2026-03-24T09:28:00Z',
        'topics': ['Technology'],
        'conversation_starters': {
          'starters': ['What changed this week?'],
        },
      },
    ],
    'session_id': 'marketing-articles',
    'cursor': 2,
    'has_more': false,
  };
}

Map<String, dynamic> _buildVideoPlaylistResponse() {
  return {
    'items': [
      {
        'id': 9101,
        'type': 'VIDEO',
        'title': _videoTitle,
        'video_url': 'https://www.youtube.com/watch?v=aqz-KE-bpKQ',
        'source_url': 'https://blips.tech/story/signal-over-noise',
        'source': 'Blips Video',
        'summary':
            'Catch the most important product and platform moves without '
                'leaving the feed.',
        'image_url': 'https://i.ytimg.com/vi/aqz-KE-bpKQ/hqdefault.jpg',
        'duration': 132,
        'published_at': '2026-03-24T09:33:00Z',
        'created_at': '2026-03-24T09:33:00Z',
        'topics': ['Technology'],
        'conversation_starters': {
          'starters': ['Summarize the key points.'],
        },
      },
      {
        'id': 9102,
        'type': 'VIDEO',
        'title': 'The release cadence is now the product strategy.',
        'video_url': 'https://www.youtube.com/watch?v=M7lc1UVf-VE',
        'source_url': 'https://blips.tech/story/release-cadence',
        'source': 'Blips Video',
        'summary':
            'Why shipping rhythm now signals platform confidence more than '
                'blog posts do.',
        'image_url': 'https://i.ytimg.com/vi/M7lc1UVf-VE/hqdefault.jpg',
        'duration': 165,
        'published_at': '2026-03-24T08:58:00Z',
        'created_at': '2026-03-24T08:58:00Z',
        'topics': ['Technology'],
        'conversation_starters': {
          'starters': ['What should I watch for next?'],
        },
      },
    ],
    'session_id': 'marketing-videos',
    'cursor': 2,
    'has_more': false,
  };
}

Map<String, dynamic> _buildReelsResponse() {
  return {
    'items': [
      {
        'id': 10101,
        'title': _reelTitle,
        'video_url': 'https://www.youtube.com/shorts/jcxgwl9NYFE',
        'source_url': 'https://blips.tech/story/meeting-clips',
        'source': 'Blips Clips',
        'summary':
            'Short takes on AI launches, chips, and creator tools, cut for '
                'the first minute of your day.',
        'thumbnail_url': 'https://i.ytimg.com/vi/jcxgwl9NYFE/hqdefault.jpg',
        'duration_seconds': 34,
        'published_at': '2026-03-24T09:36:00Z',
        'created_at': '2026-03-24T09:36:00Z',
      },
      {
        'id': 10102,
        'title': 'New models are cheap. Distribution is not.',
        'video_url': 'https://www.youtube.com/shorts/aqz-KE-bpKQ',
        'source_url': 'https://blips.tech/story/distribution-cost',
        'source': 'Blips Clips',
        'summary': 'The fastest take on where attention still compounds.',
        'thumbnail_url': 'https://i.ytimg.com/vi/aqz-KE-bpKQ/hqdefault.jpg',
        'duration_seconds': 26,
        'published_at': '2026-03-24T09:12:00Z',
        'created_at': '2026-03-24T09:12:00Z',
      },
    ],
    'has_more': false,
    'next_cursor': null,
  };
}

final class _NoopPushNotificationsController
    extends PushNotificationsController {
  // ignore: use_super_parameters
  _NoopPushNotificationsController(Ref ref) : super(ref);

  @override
  Future<void> ensureStarted() async {}

  @override
  Future<void> onEligibleShellEntered() async {}

  @override
  Future<void> handleAppResume() async {}

  @override
  Future<void> unregisterCurrentSubscription() async {}

  @override
  Future<void> dispose() async {}
}
