import 'package:blips_mobile/app.dart';
import 'package:blips_mobile/features/ads/domain/ads_config.dart';
import 'package:blips_mobile/features/ads/providers/ads_providers.dart';
import 'package:blips_mobile/features/chat/data/chat_repository.dart';
import 'package:blips_mobile/features/chat/providers/chat_providers.dart';
import 'package:blips_mobile/features/feed/data/feed_repository.dart';
import 'package:blips_mobile/features/feed/providers/feed_providers.dart';
import 'package:blips_mobile/features/feed/providers/video/youtube_player_manager.dart';
import 'package:blips_mobile/features/feed/providers/video/youtube_player_manager_base.dart';
import 'package:blips_mobile/features/onboarding/providers/interests_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'fake_backend_api_client.dart';
import 'fake_chat_repository.dart';
import 'fake_feed_cache.dart';
import 'fake_youtube_player_manager.dart';

Widget buildAppUiHarness({
  required FakeBackendApiClient api,
  bool onboardingDone = true,
  FakeFeedCache? cache,
  ChatRepository? chatRepository,
  YoutubePlayerManagerBase? youtubeManager,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: [
      onboardingDoneProvider.overrideWith((ref) async => onboardingDone),
      adsConfigProvider.overrideWith((ref) async => const AdsConfig()),
      feedRepositoryProvider.overrideWithValue(FeedRepository(api)),
      feedCacheProvider.overrideWithValue(cache ?? FakeFeedCache()),
      chatRepositoryProvider
          .overrideWithValue(chatRepository ?? FakeChatRepository()),
      youtubePlayerManagerProvider.overrideWith(
        (ref) => youtubeManager ?? FakeYoutubePlayerManager(),
      ),
      ...overrides,
    ],
    child: const BlipsApp(),
  );
}

Map<String, dynamic> buildArticlePlaylistResponse() {
  return {
    'items': [
      {
        'id': 101,
        'type': 'ARTICLE',
        'title': 'App shell article',
        'source': 'Example News',
        'source_url': 'https://example.com/article',
        'summary': 'Article summary for shell navigation testing.',
        'image_url': 'https://example.com/article.jpg',
        'published_at': '2026-03-20T12:00:00Z',
        'created_at': '2026-03-20T12:05:00Z',
        'topics': ['Technology'],
        'conversation_starters': {
          'starters': ['Summarize this article.'],
        },
      },
    ],
    'session_id': 'articles-session',
    'cursor': 1,
    'has_more': true,
  };
}

Map<String, dynamic> buildVideoPlaylistResponse() {
  return {
    'items': [
      {
        'id': 202,
        'type': 'VIDEO',
        'title': 'App shell video',
        'video_url': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        'source_url': 'https://www.theverge.com/2026/03/20/video-story',
        'source': 'YouTube',
        'summary': 'Video summary for shell navigation testing.',
        'image_url': 'https://example.com/video.jpg',
        'duration': 180,
        'published_at': '2026-03-20T12:10:00Z',
        'created_at': '2026-03-20T12:15:00Z',
        'topics': ['Technology'],
        'conversation_starters': {
          'starters': ['What is the main point?'],
        },
      },
    ],
    'session_id': 'videos-session',
    'cursor': 1,
    'has_more': true,
  };
}

Map<String, dynamic> buildReelsResponse() {
  return {
    'items': [
      {
        'id': 303,
        'title': 'App shell reel',
        'video_url': 'https://www.youtube.com/shorts/jcxgwl9NYFE',
        'source_url': 'https://example.com/reel-source',
        'source': 'Creator',
        'summary': 'Reel summary for shell navigation testing.',
        'thumbnail_url': 'https://example.com/reel.jpg',
        'duration_seconds': 45,
        'published_at': '2026-03-20T12:20:00Z',
        'created_at': '2026-03-20T12:25:00Z',
      },
    ],
    'has_more': true,
    'next_cursor': '20',
  };
}
