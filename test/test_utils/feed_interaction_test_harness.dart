import 'package:blips_mobile/features/chat/providers/chat_providers.dart';
import 'package:blips_mobile/features/feed/data/feed_repository.dart';
import 'package:blips_mobile/features/feed/providers/feed_providers.dart';
import 'package:blips_mobile/features/feed/providers/video/youtube_player_manager.dart';
import 'package:blips_mobile/features/feed/providers/video/youtube_player_manager_base.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'fake_backend_api_client.dart';
import 'fake_chat_repository.dart';
import 'fake_feed_cache.dart';
import 'fake_youtube_player_manager.dart';

Widget buildFeedInteractionHarness({
  required Widget child,
  required FakeBackendApiClient api,
  FakeFeedCache? cache,
  FakeChatRepository? chatRepository,
  YoutubePlayerManagerBase? youtubeManager,
}) {
  final feedCache = cache ?? FakeFeedCache();
  final manager = youtubeManager ?? FakeYoutubePlayerManager();

  return ProviderScope(
    overrides: [
      feedRepositoryProvider.overrideWithValue(FeedRepository(api)),
      feedCacheProvider.overrideWithValue(feedCache),
      chatRepositoryProvider
          .overrideWithValue(chatRepository ?? FakeChatRepository()),
      youtubePlayerManagerProvider.overrideWith((ref) => manager),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 720,
          child: child,
        ),
      ),
    ),
  );
}
