@Tags(['integration', 'manual'])
library marketing_screenshots_test;

import 'package:blips_mobile/app.dart';
import 'package:blips_mobile/core/theme/app_theme.dart';
import 'package:blips_mobile/core/theme/debug_overlay.dart';
import 'package:blips_mobile/features/chat/domain/chat_models.dart';
import 'package:blips_mobile/features/feed/presentation/widgets/feed_status_overlay.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:blips_mobile/features/feed/domain/saved_item.dart';
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
import '../test/test_utils/fake_feed_cache.dart';
import '../test/test_utils/fake_youtube_player_manager.dart';
import '../test/test_utils/recording_chat_repository.dart';

// When BLIPS_MAX_LENGTH=true is passed via --dart-define, the feed article card
// fixture is swapped for a stress-test variant: title sized to fill its 2-line
// max, summary sized to the 70-word backend cap (ARTICLE_SUMMARY_MAX_OUTPUT_WORDS).
// Used for layout review across device sizes — does not affect live marketing
// screenshots on blips.tech (those run with BLIPS_MAX_LENGTH unset).
const _isMaxLength = bool.fromEnvironment('BLIPS_MAX_LENGTH');

const _feedTitleStandard =
    'OpenAI ships sharper memory controls as AI assistants move into daily work.';
const _feedTitleMax =
    'OpenAI ships sharper memory controls and personalization as AI assistants move into daily workflows.';
const _feedTitle = _isMaxLength ? _feedTitleMax : _feedTitleStandard;

const _videoTitle =
    'Nvidia, OpenAI, and Apple all just made the next AI device cycle easier to see.';
const _reelTitle =
    'Three clips that explain where AI products, chips, and distribution are heading.';
const _chatReply =
    'Here is the fast read: AI infrastructure, shipping cadence, and distribution economics are driving the story.';
// 70-word stress fixture (matches backend ARTICLE_SUMMARY_MAX_OUTPUT_WORDS cap).
const _articleSummaryMax =
    'OpenAI\'s new memory controls turn AI from a disposable prompt box into a tool people trust throughout the workday. Users no longer restate preferences, projects, and context each session, so assistants feel continuous, personal, and less repetitive. That shift reshapes retention, redesigns onboarding flows, and raises the bar for every product racing to become the interface people open first each morning before email, browser, or any traditional productivity software tool.';
const _articleSummaryStandard =
    'OpenAI\'s latest memory controls matter because they turn AI from a disposable prompt box into a tool people can trust throughout the workday. Instead of forcing users to restate preferences, projects, and context every time, the assistant can now feel more continuous, more personalized, and less repetitive. That shift changes retention, changes workflow design, and raises the bar for every product competing to become the interface people open first each morning.';
const _articleSummaryLong =
    _isMaxLength ? _articleSummaryMax : _articleSummaryStandard;
const _videoSummaryLong =
    'This video connects the dots between Nvidia\'s platform momentum, OpenAI\'s product cadence, and Apple\'s device strategy to explain why the next AI cycle may spread faster than the last one. It shows how hardware, distribution, and interface design are finally aligning in a way that makes mainstream adoption easier to imagine. For viewers, that means fewer isolated launches and a much clearer picture of where attention, consumer behavior, and product value are moving next.';
// MacBook opening with colorful glow — sleek, dark-mode-friendly
const _articleImage =
    'https://images.unsplash.com/photo-1531297484001-80022131f5a1?auto=format&fit=crop&w=1600&q=80';
// AI brain circuit board illustration — instantly reads as tech/AI news
const _articleImageSecondary =
    'https://images.unsplash.com/photo-1677442135703-1787eea5ce01?auto=format&fit=crop&w=1600&q=80';
// Tech conference audience — feels like watchable video content
const _videoThumbnailPrimary =
    'https://images.unsplash.com/photo-1540575467063-178a50c2df87?auto=format&fit=crop&w=1600&q=80';
// ChatGPT / AI logo 3D render — very recognisable tech-news visual
const _videoThumbnailSecondary =
    'https://images.unsplash.com/photo-1679083216051-aa510a1a2c0e?auto=format&fit=crop&w=1600&q=80';
// Earth at night from space — dramatic, cinematic; great for short-clip feel
const _reelThumbnailPrimary =
    'https://images.unsplash.com/photo-1451187580459-43490279c0fa?auto=format&fit=crop&w=1600&q=80';
// Dark server-room cables — moody infrastructure / tech backdrop
const _reelThumbnailSecondary =
    'https://images.unsplash.com/photo-1558494949-ef010cbdcc31?auto=format&fit=crop&w=1600&q=80';

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
      final cache = FakeFeedCache();
      final articleEntry = _marketingArticleEntry();
      final videoEntry = _marketingVideoEntry();
      final chatRepository = RecordingChatRepository(
        conversations: [
          ChatConversation(
            articleId: articleEntry.id,
            article: articleEntry,
            messages: [
              ChatMessage(
                id: 'user-1',
                role: 'user',
                content: 'What changed this morning?',
                timestamp: DateTime.utc(2026, 4, 8, 9, 42),
              ),
              ChatMessage(
                id: 'assistant-1',
                role: 'assistant',
                content:
                    'The biggest changes are around AI infra pricing and faster product releases.',
                timestamp: DateTime.utc(2026, 4, 8, 9, 43),
              ),
            ],
          ),
        ],
        responseContent: _chatReply,
      );

      await cache.saveArticleBookmark(
        SavedArticleItem.fromFeedEntry(articleEntry),
      );
      await cache.saveVideoBookmark(
        SavedVideoItem.fromFeedEntry(videoEntry),
      );

      await tester.pumpWidget(
        buildAppUiHarness(
          api: api,
          cache: cache,
          chatRepository: chatRepository,
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

      await tester.tap(find.byKey(const ValueKey<String>('nav-Chat')));
      await _waitFor(tester, find.text('Your Conversations'));
      await _waitFor(tester, find.text(articleEntry.title));
      await _settleUi(tester);
      await binding.takeScreenshot('screenshot-chat');

      await tester.tap(find.byKey(const ValueKey<String>('nav-Saved')));
      await _waitFor(tester, find.text('Saved'));
      await _waitFor(tester, find.text(articleEntry.title));
      await _settleUi(tester);
      await binding.takeScreenshot('screenshot-saved');

      await tester.tap(find.byKey(const ValueKey<String>('nav-Settings')));
      await _waitFor(tester, find.text('Settings'));
      await _waitFor(tester, find.text('Storage & privacy'));
      await _settleUi(tester);
      await binding.takeScreenshot('screenshot-settings');

      await tester.tap(find.byKey(const ValueKey<String>('nav-Feed')));
      await _waitFor(tester, find.text(_feedTitle));
      await tester.tap(find.byIcon(Icons.auto_awesome_rounded).first);
      await _waitFor(tester, find.text('Give me the fast read.'));
      await tester.tap(find.text('Give me the fast read.'));
      await _waitFor(tester, find.text(_chatReply));
      await _settleUi(tester);
      await binding.takeScreenshot('screenshot-ai-chat');
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
      'REEL' => _buildReelsResponse(),
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
        'summary': _articleSummaryLong,
        'image_url': _articleImage,
        'published_at': '2026-04-08T09:41:00Z',
        'created_at': '2026-04-08T09:41:00Z',
        'topics': ['Technology'],
        'conversation_starters': {
          'starters': ['Give me the fast read.'],
        },
      },
      {
        'id': 8102,
        'type': 'ARTICLE',
        'title': 'Why the best AI products now feel more like coworkers than search boxes.',
        'source': 'Blips Desk',
        'source_url': 'https://blips.tech/story/agent-workflows',
        'summary':
            'Teams are redesigning onboarding, memory, and interface speed so '
                'AI features become part of the daily workflow instead of a side panel.',
        'image_url': _articleImageSecondary,
        'published_at': '2026-04-08T09:28:00Z',
        'created_at': '2026-04-08T09:28:00Z',
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

ArticleFeedEntry _marketingArticleEntry() {
  return ArticleFeedEntry(
    id: 8101,
    title: _feedTitle,
    summary: _articleSummaryLong,
    source: 'Blips Desk',
    publishedAt: DateTime.utc(2026, 4, 8, 9, 41),
    url: 'https://blips.tech/story/morning-brief',
    imageUrl: _articleImage,
    category: 'Technology',
    readTime: 4,
    conversationStarters: const ['Give me the fast read.'],
  );
}

VideoFeedEntry _marketingVideoEntry() {
  return VideoFeedEntry(
    id: 9101,
    title: _videoTitle,
    summary: _videoSummaryLong,
    videoUrl: 'https://www.youtube.com/watch?v=aqz-KE-bpKQ',
    link: 'https://blips.tech/story/signal-over-noise',
    source: 'Blips Video',
    category: 'Technology',
    publishedAt: DateTime.utc(2026, 4, 8, 9, 33),
    readTime: 2,
    thumbnailUrl: _videoThumbnailPrimary,
    durationSeconds: 132,
    conversationStarters: const ['Summarize the key points.'],
  );
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
        'summary': _videoSummaryLong,
        'image_url': _videoThumbnailPrimary,
        'duration': 132,
        'published_at': '2026-04-08T09:33:00Z',
        'created_at': '2026-04-08T09:33:00Z',
        'topics': ['Technology'],
        'conversation_starters': {
          'starters': ['Summarize the key points.'],
        },
      },
      {
        'id': 9102,
        'type': 'VIDEO',
        'title': 'Why faster AI shipping now matters more than splashy launch events.',
        'video_url': 'https://www.youtube.com/watch?v=M7lc1UVf-VE',
        'source_url': 'https://blips.tech/story/release-cadence',
        'source': 'Blips Video',
        'summary':
            'A clear breakdown of how release cadence became the signal investors, '
                'developers, and creators are watching most closely.',
        'image_url': _videoThumbnailSecondary,
        'duration': 165,
        'published_at': '2026-04-08T08:58:00Z',
        'created_at': '2026-04-08T08:58:00Z',
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
        'type': 'REEL',
        'title': _reelTitle,
        'video_url': 'https://www.youtube.com/shorts/jcxgwl9NYFE',
        'source_url': 'https://blips.tech/story/meeting-clips',
        'source': 'Blips Clips',
        'summary':
            'Short takes on AI launches, chips, and creator tools, cut for '
                'the first minute of your day.',
        'thumbnail_url': _reelThumbnailPrimary,
        'duration_seconds': 34,
        'published_at': '2026-04-08T09:36:00Z',
        'created_at': '2026-04-08T09:36:00Z',
        'topics': ['Technology'],
      },
      {
        'id': 10102,
        'type': 'REEL',
        'title': 'New models are cheap. Distribution is not.',
        'video_url': 'https://www.youtube.com/shorts/aqz-KE-bpKQ',
        'source_url': 'https://blips.tech/story/distribution-cost',
        'source': 'Blips Clips',
        'summary': 'The fastest take on where attention still compounds.',
        'thumbnail_url': _reelThumbnailSecondary,
        'duration_seconds': 26,
        'published_at': '2026-04-08T09:12:00Z',
        'created_at': '2026-04-08T09:12:00Z',
        'topics': ['Technology'],
      },
    ],
    'session_id': 'marketing-reels',
    'cursor': 2,
    'has_more': false,
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
