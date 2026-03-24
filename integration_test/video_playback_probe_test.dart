@Tags(['integration', 'manual'])
library video_playback_probe_test;

import 'package:blips_mobile/app.dart';
import 'package:blips_mobile/core/diagnostics/app_diagnostics.dart';
import 'package:blips_mobile/features/ads/data/app_config_repository.dart';
import 'package:blips_mobile/features/ads/providers/ads_providers.dart';
import 'package:blips_mobile/features/chat/providers/chat_providers.dart';
import 'package:blips_mobile/features/feed/data/feed_repository.dart';
import 'package:blips_mobile/features/feed/providers/feed_providers.dart';
import 'package:blips_mobile/features/feed/providers/video/youtube_player_manager.dart';
import 'package:blips_mobile/features/feed/providers/video/youtube_player_manager_base.dart';
import 'package:blips_mobile/features/onboarding/providers/interests_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:integration_test/integration_test.dart';

import '../test/test_utils/fake_backend_api_client.dart';
import '../test/test_utils/fake_feed_cache.dart';

const _videoUrls = <String>[
  'https://www.youtube.com/watch?v=M7lc1UVf-VE',
  'https://www.youtube.com/watch?v=ScMzIvxBSi4',
  'https://www.youtube.com/watch?v=ysz5S6PUM-U',
  'https://www.youtube.com/watch?v=aqz-KE-bpKQ',
];

ProviderScope _buildProbeScope() {
  var articlePlaylistRequests = 0;
  final api = FakeBackendApiClient(
    responseResolver: (method, path, queryParameters, body) {
      if (method == 'GET' && path == '/config') {
        return const <String, dynamic>{
          'ads': {
            'enabled': false,
            'eligible': false,
            'provider': 'mock_native',
            'surfaces': {
              'articles': {
                'enabled': false,
                'frequency': 0,
                'first_slot_after': 0,
              },
              'videos': {
                'enabled': false,
                'frequency': 0,
                'first_slot_after': 0,
              },
              'reels': {
                'enabled': false,
                'frequency': 0,
                'first_slot_after': 0,
              },
            },
          },
          'push': {
            'enabled': false,
            'mode': 'disabled',
            'config_ttl_seconds': 300,
          },
        };
      }
      if (method == 'GET' && path == '/session/playlist') {
        final type = queryParameters?['type'] as String?;
        return switch (type) {
          'ARTICLE' => _buildArticlePlaylist(
              requestCount: ++articlePlaylistRequests,
            ),
          'VIDEO' => _buildVideoPlaylist(),
          _ => <String, dynamic>{'items': const <Map<String, dynamic>>[]},
        };
      }
      if (method == 'GET' && path == '/videos/reels') {
        return _buildReelsResponse();
      }
      if (method == 'POST' && path == '/session/interactions') {
        return const <String, dynamic>{};
      }
      return const <String, dynamic>{};
    },
  );
  final repository = FeedRepository(api);

  return ProviderScope(
    overrides: [
      onboardingDoneProvider.overrideWith((ref) async => true),
      feedRepositoryProvider.overrideWithValue(repository),
      feedCacheProvider.overrideWithValue(FakeFeedCache()),
      appConfigRepositoryProvider.overrideWithValue(AppConfigRepository(api)),
      chatListProvider.overrideWith((ref) async => const []),
    ],
    child: const BlipsApp(),
  );
}

Map<String, dynamic> _buildArticlePlaylist({
  required int requestCount,
}) {
  final ids = switch (requestCount) {
    1 => <int>[101, 102, 103],
    _ => <int>[104, 101, 102, 103],
  };
  return {
    'items': ids
        .map(
          (id) => {
            'id': id,
            'type': 'ARTICLE',
            'title': 'Probe article $id',
            'source': 'Example News',
            'source_url': 'https://example.com/article/$id',
            'summary': 'Article summary for playback probe item $id.',
            'image_url': 'https://example.com/article_$id.jpg',
            'published_at': '2026-03-22T12:00:00Z',
            'created_at': '2026-03-22T12:05:00Z',
            'topics': ['Technology'],
            'conversation_starters': {
              'starters': ['Summarize this article.'],
            },
          },
        )
        .toList(growable: false),
    'session_id': 'probe-articles-session',
    'cursor': ids.length,
    'has_more': true,
  };
}

Map<String, dynamic> _buildVideoPlaylist() {
  final ids = <int>[202, 203, 204, 205];
  return {
    'items': ids.asMap().entries.map((entry) {
      final index = entry.key;
      final id = entry.value;
      final url = _videoUrls[index % _videoUrls.length];
      return <String, dynamic>{
        'id': id,
        'type': 'VIDEO',
        'title': 'Playback probe video $id',
        'video_url': url,
        'source_url': 'https://example.com/video/$id',
        'source': 'YouTube',
        'summary': 'Video summary for playback probe item $id.',
        'image_url': 'https://example.com/video_$id.jpg',
        'duration': 180,
        'published_at': '2026-03-22T12:10:00Z',
        'created_at': '2026-03-22T12:15:00Z',
        'topics': ['Technology'],
        'conversation_starters': {
          'starters': ['What is the main point?'],
        },
      };
    }).toList(growable: false),
    'session_id': 'probe-videos-session',
    'cursor': ids.length,
    'has_more': true,
  };
}

Map<String, dynamic> _buildReelsResponse() {
  return {
    'items': [
      {
        'id': 303,
        'title': 'Probe reel',
        'video_url': 'https://www.youtube.com/shorts/jcxgwl9NYFE',
        'source_url': 'https://example.com/reel-source',
        'source': 'Creator',
        'summary': 'Reel summary for playback probe.',
        'thumbnail_url': 'https://example.com/reel.jpg',
        'duration_seconds': 45,
        'published_at': '2026-03-22T12:20:00Z',
        'created_at': '2026-03-22T12:25:00Z',
      },
    ],
    'has_more': true,
    'next_cursor': '20',
  };
}

Finder _findVerticalFeedPageView() => find.byWidgetPredicate(
      (widget) => widget is PageView && widget.scrollDirection == Axis.vertical,
    );

ProviderContainer _containerOf(WidgetTester tester) {
  return ProviderScope.containerOf(tester.element(find.byType(BlipsApp)));
}

Future<void> _pumpUi(
  WidgetTester tester, [
  Duration duration = const Duration(seconds: 1),
]) async {
  await tester.pump(duration);
  await tester.pump();
}

Future<void> _waitForVideoPlaying(
  WidgetTester tester,
  ProviderContainer container,
  String url,
) async {
  final diagnostics = container.read(appDiagnosticsProvider);
  for (var attempt = 0; attempt < 28; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 700));
    final manager = container.read(youtubePlayerManagerProvider);
    if (manager.getState(url) == YTPlayerState.playing) {
      return;
    }
  }

  final manager = container.read(youtubePlayerManagerProvider);
  fail(
    'Video never reached playing for $url.\n'
    'Final state: ${manager.getState(url).name}\n'
    'Diagnostics:\n${diagnostics.exportText(limit: 160)}',
  );
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'videos probe: first open, repeated swipes, tab switch, and '
    'jump-to-latest recover playback',
    (tester) async {
      binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildProbeScope());
      await _pumpUi(tester, const Duration(seconds: 4));

      final container = _containerOf(tester);

      await tester.tap(find.byIcon(Icons.play_circle_outline));
      await _pumpUi(tester, const Duration(seconds: 2));

      await _waitForVideoPlaying(tester, container, _videoUrls[0]);

      for (final url in _videoUrls.skip(1).take(2)) {
        await tester.drag(
          _findVerticalFeedPageView().first,
          const Offset(0, -820),
        );
        await _pumpUi(tester, const Duration(seconds: 2));
        await _waitForVideoPlaying(tester, container, url);
      }

      await tester.tap(find.byIcon(Icons.article));
      await _pumpUi(tester);
      await tester.tap(find.byIcon(Icons.play_circle_outline));
      await _pumpUi(tester, const Duration(seconds: 2));

      await _waitForVideoPlaying(tester, container, _videoUrls[2]);

      await tester.tap(find.byIcon(Icons.play_circle_outline));
      await _pumpUi(tester, const Duration(milliseconds: 900));
      expect(find.text('View latest'), findsOneWidget);

      await tester.tap(find.text('View latest'));
      await _pumpUi(tester, const Duration(seconds: 2));

      await _waitForVideoPlaying(tester, container, _videoUrls[0]);

      final diagnostics = container.read(appDiagnosticsProvider);
      expect(
        diagnostics.exportText(limit: 160),
        contains('video.player.onPageChanged.start'),
      );
    },
  );
}
