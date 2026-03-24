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
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../test_utils/fake_youtube_player_manager.dart';

class _StubbornSwipeYoutubePlayerManager extends YoutubePlayerManagerBase {
  final Map<String, YTPlayerState> _states = <String, YTPlayerState>{};
  final Set<String> _recoveredUrls = <String>{};
  final List<String> calls = <String>[];

  void _notifySafe() {
    Future<void>.microtask(notifyListeners);
  }

  @override
  YoutubePlayerController? getController(String url) => null;

  @override
  YTPlayerError? getError(String url) => null;

  @override
  YTPlayerState getState(String url) => _states[url] ?? YTPlayerState.idle;

  @override
  bool isPlaying(String url) => getState(url) == YTPlayerState.playing;

  @override
  bool isReady(String url) => getState(url) != YTPlayerState.idle;

  @override
  String? extractVideoId(String url) => YoutubePlayer.convertUrlToId(url);

  @override
  Future<YoutubePlayerController?> initController(String url) async {
    calls.add('init:$url');
    _states[url] = _recoveredUrls.contains(url)
        ? YTPlayerState.playing
        : YTPlayerState.loading;
    _notifySafe();
    return null;
  }

  @override
  void onPageChanged({
    required int currentIndex,
    required List<String> videoUrls,
    int? preloadAhead,
  }) {
    if (currentIndex < 0 || currentIndex >= videoUrls.length) return;
    final currentUrl = videoUrls[currentIndex];
    calls.add('page:$currentUrl');
    for (final url in videoUrls) {
      if (url != currentUrl && _states[url] == YTPlayerState.playing) {
        _states[url] = YTPlayerState.paused;
      }
    }
    _states[currentUrl] = YTPlayerState.loading;
    _notifySafe();
  }

  @override
  void pauseAll() {}

  @override
  void pauseVideo(String url) {
    calls.add('pause:$url');
    _states[url] = YTPlayerState.paused;
    _notifySafe();
  }

  @override
  Future<void> playVideo(String url) async {
    calls.add('play:$url');
    _states[url] = _recoveredUrls.contains(url)
        ? YTPlayerState.playing
        : YTPlayerState.loading;
    _notifySafe();
  }

  @override
  Future<void> retryVideo(String url) async {
    calls.add('retry:$url');
    _recoveredUrls.add(url);
    _states[url] = YTPlayerState.playing;
    _notifySafe();
  }
}

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
    PageController? controller,
    List<FeedPageItem>? items,
  }) {
    return ProviderScope(
      overrides: [
        youtubePlayerManagerProvider.overrideWith((ref) => manager),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: FeedTab<FeedPageItem>(
            feed: AsyncValue.data(
              items ?? <FeedPageItem>[OrganicFeedPageItem(buildVideo())],
            ),
            builder: (entry, isCurrentPage) => const SizedBox.expand(),
            emptyLabel: 'No content',
            onRefresh: () {},
            overlayLabel: 'VID',
            containsVideos: true,
            isActive: isActive,
            controller: controller,
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
    await tester.pump(const Duration(seconds: 2));

    expect(manager.getState(playbackUrl), YTPlayerState.playing);
  });

  testWidgets('activation follows the controller page after a jump to top',
      (tester) async {
    final manager = FakeYoutubePlayerManager();
    final controller = PageController(initialPage: 1);
    const secondUrl = 'https://www.youtube.com/watch?v=jcxgwl9NYFE';

    final items = <FeedPageItem>[
      OrganicFeedPageItem(buildVideo()),
      OrganicFeedPageItem(
        VideoFeedEntry(
          id: 303,
          title: 'Second visible video',
          summary: 'Summary',
          videoUrl: secondUrl,
          link: secondUrl,
          source: 'YouTube',
          category: 'Technology',
          publishedAt: DateTime.parse('2026-03-23T11:00:00Z'),
          readTime: 3,
          thumbnailUrl: 'https://example.com/video-2.jpg',
        ),
      ),
    ];

    await tester.pumpWidget(
      buildHarness(
        manager: manager,
        isActive: true,
        controller: controller,
        items: items,
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(manager.getState(secondUrl), YTPlayerState.playing);
    expect(manager.getState(playbackUrl), isNot(YTPlayerState.playing));
  });

  testWidgets('vertical swipes re-arm each newly visible video',
      (tester) async {
    final manager = _StubbornSwipeYoutubePlayerManager();
    final controller = PageController();
    const secondUrl = 'https://www.youtube.com/watch?v=jcxgwl9NYFE';
    const thirdUrl = 'https://www.youtube.com/watch?v=oHg5SJYRHA0';

    final items = <FeedPageItem>[
      OrganicFeedPageItem(buildVideo()),
      OrganicFeedPageItem(
        VideoFeedEntry(
          id: 303,
          title: 'Second visible video',
          summary: 'Summary',
          videoUrl: secondUrl,
          link: secondUrl,
          source: 'YouTube',
          category: 'Technology',
          publishedAt: DateTime.parse('2026-03-23T11:00:00Z'),
          readTime: 3,
          thumbnailUrl: 'https://example.com/video-2.jpg',
        ),
      ),
      OrganicFeedPageItem(
        VideoFeedEntry(
          id: 404,
          title: 'Third visible video',
          summary: 'Summary',
          videoUrl: thirdUrl,
          link: thirdUrl,
          source: 'YouTube',
          category: 'Technology',
          publishedAt: DateTime.parse('2026-03-23T12:00:00Z'),
          readTime: 3,
          thumbnailUrl: 'https://example.com/video-3.jpg',
        ),
      ),
    ];

    await tester.pumpWidget(
      buildHarness(
        manager: manager,
        isActive: true,
        controller: controller,
        items: items,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(manager.getState(playbackUrl), YTPlayerState.playing);

    await tester.drag(find.byType(PageView), const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));

    expect(manager.calls, contains('page:$secondUrl'));
    expect(manager.calls, contains('retry:$secondUrl'));
    expect(manager.getState(secondUrl), YTPlayerState.playing);

    await tester.drag(find.byType(PageView), const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));

    expect(manager.calls, contains('page:$thirdUrl'));
    expect(manager.calls, contains('retry:$thirdUrl'));
    expect(manager.getState(thirdUrl), YTPlayerState.playing);
  });
}
