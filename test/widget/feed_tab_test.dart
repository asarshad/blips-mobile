@Tags(['widget'])
library feed_tab_test;

import 'package:blips_mobile/features/ads/domain/feed_page_item.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:blips_mobile/features/feed/presentation/tabs/feed_tab.dart';
import 'package:blips_mobile/features/feed/providers/video/youtube_player_manager.dart';
import 'package:blips_mobile/features/feed/providers/video/youtube_player_manager_base.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../test_utils/fake_youtube_player_manager.dart';

void main() {
  const playbackUrl = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';

  VideoFeedEntry buildVideo() {
    return VideoFeedEntry(
      id: 202,
      title: 'Tab activation video',
      summary: 'Summary',
      videoUrl: playbackUrl,
      link: playbackUrl,
      source: 'YouTube',
      category: 'Technology',
      publishedAt: DateTime.parse('2026-03-23T10:00:00Z'),
      readTime: 3,
      thumbnailUrl: 'https://example.com/video.jpg',
    );
  }

  Widget buildHarness({
    required YoutubePlayerManagerBase manager,
    required bool isActive,
  }) {
    return ProviderScope(
      overrides: [
        youtubePlayerManagerProvider.overrideWith((ref) => manager),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: FeedTab<FeedPageItem>(
            feed: AsyncValue.data(
              <FeedPageItem>[OrganicFeedPageItem(buildVideo())],
            ),
            builder: (entry, isCurrentPage) => const SizedBox.expand(),
            emptyLabel: 'No content',
            onRefresh: () {},
            overlayLabel: 'VID',
            containsVideos: true,
            isActive: isActive,
          ),
        ),
      ),
    );
  }

  testWidgets('activating a video tab re-arms the visible video',
      (tester) async {
    final manager = FakeYoutubePlayerManager();

    await tester.pumpWidget(
      buildHarness(
        manager: manager,
        isActive: false,
      ),
    );
    await tester.pump();

    expect(manager.getState(playbackUrl), isNot(YTPlayerState.playing));

    await tester.pumpWidget(
      buildHarness(
        manager: manager,
        isActive: true,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(manager.getState(playbackUrl), YTPlayerState.playing);
  });
}
