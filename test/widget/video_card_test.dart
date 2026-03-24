@Tags(['widget'])
library video_card_test;

import 'package:blips_mobile/features/feed/data/feed_repository.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:blips_mobile/features/feed/presentation/cards/video_card.dart';
import 'package:blips_mobile/features/feed/presentation/widgets/widgets.dart';
import 'package:blips_mobile/features/feed/providers/feed_providers.dart';
import 'package:blips_mobile/features/feed/providers/video/youtube_player_manager.dart';
import 'package:blips_mobile/features/feed/providers/video/youtube_player_manager_base.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../test_utils/fake_backend_api_client.dart';
import '../test_utils/fake_feed_cache.dart';

class MockYoutubePlayerManager extends YoutubePlayerManagerBase {
  final Map<String, YTPlayerState> _states = {};
  final Map<String, YTPlayerError?> _errors = {};
  final List<String> calls = [];

  void setMockState(String url, YTPlayerState state) {
    _states[url] = state;
    notifyListeners();
  }

  void setMockError(String url, YTPlayerError? error) {
    _errors[url] = error;
    notifyListeners();
  }

  @override
  YoutubePlayerController? getController(String url) => null;

  @override
  YTPlayerState getState(String url) => _states[url] ?? YTPlayerState.idle;

  @override
  YTPlayerError? getError(String url) => _errors[url];

  @override
  bool isReady(String url) {
    final state = getState(url);
    return state == YTPlayerState.ready ||
        state == YTPlayerState.playing ||
        state == YTPlayerState.paused;
  }

  @override
  bool isPlaying(String url) => getState(url) == YTPlayerState.playing;

  @override
  String? extractVideoId(String url) => YoutubePlayer.convertUrlToId(url);

  @override
  Future<YoutubePlayerController?> initController(String url) async => null;

  @override
  Future<void> playVideo(String url) async {
    calls.add('play:$url');
  }

  @override
  Future<void> retryVideo(String url) async {
    calls.add('retry:$url');
  }

  @override
  void pauseVideo(String url) {
    calls.add('pause:$url');
  }

  @override
  void pauseAll() {}

  @override
  void onPageChanged({
    required int currentIndex,
    required List<String> videoUrls,
    int? preloadAhead,
  }) {}
}

void main() {
  group('VideoCard', () {
    late MockYoutubePlayerManager mockManager;
    late VideoFeedEntry videoEntry;
    late FakeFeedCache cache;

    setUp(() {
      mockManager = MockYoutubePlayerManager();
      cache = FakeFeedCache();
      videoEntry = VideoFeedEntry(
        id: 10,
        title: 'Video playback contract test',
        summary: 'Summary',
        videoUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        link: 'https://www.youtube.com/watch?v=aaaaaaaaaaa',
        source: 'YouTube',
        category: 'Technology',
        publishedAt: DateTime(2025, 2, 10),
        readTime: 3,
        thumbnailUrl: '',
      );
    });

    Widget buildTestWidget({
      required VideoFeedEntry entry,
      bool isVisible = true,
    }) {
      return ProviderScope(
        overrides: [
          youtubePlayerManagerProvider.overrideWith((ref) => mockManager),
          feedRepositoryProvider.overrideWithValue(
            FeedRepository(
              FakeBackendApiClient(
                responses: const {
                  '/session/interactions': {'success': true},
                },
              ),
            ),
          ),
          feedCacheProvider.overrideWithValue(cache),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 700,
              child: VideoCard(
                entry: entry,
                isVisible: isVisible,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('visible card arms autoplay using videoUrl', (tester) async {
      await tester
          .pumpWidget(buildTestWidget(entry: videoEntry, isVisible: true));
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        mockManager.calls,
        contains('play:${videoEntry.videoUrl}'),
        reason:
            'Videos tab playback should use videoUrl when it is YouTube-playable',
      );
      expect(mockManager.calls, isNot(contains('play:${videoEntry.link}')));
    });

    testWidgets('invisible card pauses using videoUrl', (tester) async {
      await tester
          .pumpWidget(buildTestWidget(entry: videoEntry, isVisible: false));
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        mockManager.calls,
        contains('pause:${videoEntry.videoUrl}'),
      );
      expect(mockManager.calls, isNot(contains('pause:${videoEntry.link}')));
    });

    testWidgets('error state shows message and tap retries playback URL',
        (tester) async {
      mockManager.setMockState(videoEntry.videoUrl, YTPlayerState.error);
      mockManager.setMockError(
        videoEntry.videoUrl,
        const YTPlayerError(code: 100, message: 'unavailable'),
      );

      await tester
          .pumpWidget(buildTestWidget(entry: videoEntry, isVisible: true));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Video unavailable'), findsOneWidget);

      await tester.tap(find.byType(FeedCardFrame));
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        mockManager.calls,
        contains('retry:${videoEntry.videoUrl}'),
        reason: 'Tap should retry errored playback sessions',
      );
    });

    testWidgets('falls back to source link when videoUrl is not YouTube',
        (tester) async {
      final fallbackEntry = VideoFeedEntry(
        id: 11,
        title: 'Fallback test',
        summary: 'Summary',
        videoUrl: 'https://cdn.example.com/video.mp4',
        link: 'https://www.youtube.com/watch?v=jcxgwl9NYFE',
        source: 'YouTube',
        category: 'Technology',
        publishedAt: DateTime(2025, 2, 11),
        readTime: 2,
        thumbnailUrl: '',
      );

      await tester.pumpWidget(
        buildTestWidget(entry: fallbackEntry, isVisible: true),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        mockManager.calls,
        contains('play:${fallbackEntry.link}'),
        reason:
            'Source link should be used when videoUrl is not YouTube-playable',
      );
    });

    testWidgets('shows explicit watch duration when durationSeconds is known',
        (tester) async {
      final durationEntry = VideoFeedEntry(
        id: 12,
        title: 'Duration label test',
        summary: 'Summary',
        videoUrl: 'https://www.youtube.com/watch?v=jcxgwl9NYFE',
        link: 'https://www.youtube.com/watch?v=jcxgwl9NYFE',
        source: 'YouTube',
        category: 'Technology',
        publishedAt: DateTime(2025, 2, 12),
        readTime: 1,
        durationSeconds: 185,
        thumbnailUrl: '',
      );

      await tester.pumpWidget(
        buildTestWidget(entry: durationEntry, isVisible: false),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('4 min watch'), findsOneWidget);
    });

    testWidgets('shows neutral label when duration is unknown', (tester) async {
      final unknownDurationEntry = VideoFeedEntry(
        id: 13,
        title: 'Unknown duration label test',
        summary: 'Short summary',
        videoUrl: 'https://www.youtube.com/watch?v=unknown12345',
        link: 'https://www.youtube.com/watch?v=unknown12345',
        source: 'YouTube',
        category: 'Technology',
        publishedAt: DateTime(2025, 2, 13),
        readTime: 1,
        thumbnailUrl: '',
      );

      await tester.pumpWidget(
        buildTestWidget(entry: unknownDurationEntry, isVisible: false),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Watch video'), findsOneWidget);
      expect(find.text('1 min watch'), findsNothing);
    });

    testWidgets('has bookmark toggle button', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(entry: videoEntry, isVisible: false),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);
    });
  });
}
