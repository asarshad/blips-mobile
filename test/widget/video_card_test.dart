@Tags(['widget'])
library video_card_test;

import 'package:blips_mobile/features/feed/data/feed_repository.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:blips_mobile/features/feed/presentation/cards/video_card.dart';
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
  final Map<String, YTPlaybackOverlayState> _overlayStates = {};
  final List<String> calls = [];

  void setMockState(String url, YTPlayerState state) {
    _states[url] = state;
    notifyListeners();
  }

  void setMockError(String url, YTPlayerError? error) {
    _errors[url] = error;
    notifyListeners();
  }

  void setMockOverlayState(String url, YTPlaybackOverlayState state) {
    _overlayStates[url] = state;
    notifyListeners();
  }

  @override
  YoutubePlayerController? getController(String url) => null;

  @override
  YTPlayerState getState(String url) => _states[url] ?? YTPlayerState.idle;

  @override
  YTPlaybackOverlayState getPlaybackOverlayState(String url) {
    final state = getState(url);
    if (state == YTPlayerState.error) {
      return YTPlaybackOverlayState.error;
    }
    if (state == YTPlayerState.playing) {
      return YTPlaybackOverlayState.none;
    }
    final override = _overlayStates[url];
    if (override != null) {
      return override;
    }
    return switch (state) {
      YTPlayerState.paused => YTPlaybackOverlayState.manualPause,
      YTPlayerState.ready ||
      YTPlayerState.loading ||
      YTPlayerState.idle =>
        YTPlaybackOverlayState.autoplayPending,
      YTPlayerState.error ||
      YTPlayerState.playing =>
        YTPlaybackOverlayState.none,
    };
  }

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
  Future<void> ensurePlayback(String url) async {
    calls.add('ensure:$url');
    await playVideo(url);
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
              width: 400,
              child: VideoCard(
                entry: entry,
                isVisible: isVisible,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('visible card arms autoplay when video is idle',
        (tester) async {
      // Default state is idle — card should self-arm to handle push-notification
      // and scroll-restore paths where FeedTab's onPageChanged fires before the
      // card is mounted. Playback is routed through the manager recovery entrypoint.
      await tester
          .pumpWidget(buildTestWidget(entry: videoEntry, isVisible: true));
      await tester.pump();

      expect(
        mockManager.calls.where((call) => call.startsWith('play:')),
        isNotEmpty,
        reason: 'Card must self-arm when visible and video is idle, '
            'to cover push-notification and restore-scroll entry paths.',
      );

      await tester.pump();
    });

    testWidgets('visible card does not arm autoplay when already playing',
        (tester) async {
      mockManager.setMockState(videoEntry.videoUrl, YTPlayerState.playing);
      await tester
          .pumpWidget(buildTestWidget(entry: videoEntry, isVisible: true));
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        mockManager.calls.where((call) => call.startsWith('play:')),
        isEmpty,
        reason: 'No duplicate play request when video is already playing.',
      );
    });

    testWidgets('visible card does not arm autoplay when already loading',
        (tester) async {
      mockManager.setMockState(videoEntry.videoUrl, YTPlayerState.loading);
      await tester
          .pumpWidget(buildTestWidget(entry: videoEntry, isVisible: true));
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        mockManager.calls.where((call) => call.startsWith('play:')),
        isEmpty,
        reason: 'No duplicate play request when controller is still loading.',
      );
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

      await tester.tap(find.text('Video unavailable'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        mockManager.calls,
        contains('retry:${videoEntry.videoUrl}'),
        reason: 'Tap should retry errored playback sessions',
      );
    });

    testWidgets('autoplay-pending ready state shows spinner, not play button',
        (tester) async {
      mockManager.setMockState(videoEntry.videoUrl, YTPlayerState.ready);
      mockManager.setMockOverlayState(
        videoEntry.videoUrl,
        YTPlaybackOverlayState.autoplayPending,
      );

      await tester
          .pumpWidget(buildTestWidget(entry: videoEntry, isVisible: true));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    });

    testWidgets('manual pause shows play button', (tester) async {
      mockManager.setMockState(videoEntry.videoUrl, YTPlayerState.paused);
      mockManager.setMockOverlayState(
        videoEntry.videoUrl,
        YTPlaybackOverlayState.manualPause,
      );

      await tester
          .pumpWidget(buildTestWidget(entry: videoEntry, isVisible: true));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('stalled autoplay shows play button instead of spinner',
        (tester) async {
      mockManager.setMockState(videoEntry.videoUrl, YTPlayerState.ready);
      mockManager.setMockOverlayState(
        videoEntry.videoUrl,
        YTPlaybackOverlayState.autoplayStalled,
      );

      await tester
          .pumpWidget(buildTestWidget(entry: videoEntry, isVisible: true));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('tap on stalled autoplay uses manager recovery entrypoint',
        (tester) async {
      mockManager.setMockState(videoEntry.videoUrl, YTPlayerState.ready);
      mockManager.setMockOverlayState(
        videoEntry.videoUrl,
        YTPlaybackOverlayState.autoplayStalled,
      );

      await tester
          .pumpWidget(buildTestWidget(entry: videoEntry, isVisible: true));
      await tester.pump(const Duration(milliseconds: 100));
      mockManager.calls.clear();

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        mockManager.calls,
        contains('ensure:${videoEntry.videoUrl}'),
        reason: 'A visible play button must use the centralized recovery path.',
      );

      await tester.pump(const Duration(milliseconds: 1200));

      expect(
        mockManager.calls,
        isNot(contains('retry:${videoEntry.videoUrl}')),
        reason: 'Widget-level delayed retry timers should not compete with '
            'YoutubePlayerManager recovery.',
      );
    });

    testWidgets('tap during autoplay pending reissues play without waiting',
        (tester) async {
      mockManager.setMockState(videoEntry.videoUrl, YTPlayerState.loading);
      mockManager.setMockOverlayState(
        videoEntry.videoUrl,
        YTPlaybackOverlayState.autoplayPending,
      );

      await tester
          .pumpWidget(buildTestWidget(entry: videoEntry, isVisible: true));
      await tester.pump(const Duration(milliseconds: 100));
      mockManager.calls.clear();

      await tester.tap(find.byType(CircularProgressIndicator));
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        mockManager.calls,
        contains('ensure:${videoEntry.videoUrl}'),
        reason: 'A user tap during a spinner should use manager recovery.',
      );

      await tester.pump(const Duration(milliseconds: 1200));

      expect(
        mockManager.calls,
        isNot(contains('retry:${videoEntry.videoUrl}')),
        reason: 'Widget-level delayed retry timers should not compete with '
            'YoutubePlayerManager recovery.',
      );
    });

    testWidgets('falls back to source link when pausing a non-YouTube videoUrl',
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
        buildTestWidget(entry: fallbackEntry, isVisible: false),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        mockManager.calls,
        contains('pause:${fallbackEntry.link}'),
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

    testWidgets('renders source label below the summary block', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(entry: videoEntry, isVisible: false),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final summaryRect =
          tester.getRect(find.byKey(const Key('feed-card-summary-text')));
      final sourceRect =
          tester.getRect(find.byKey(const Key('feed-card-source-label')));

      expect(find.byKey(const Key('feed-card-source-label')), findsOneWidget);
      expect(sourceRect.top, greaterThan(summaryRect.bottom));
    });

    testWidgets('video summary text is not line-clamped in the UI',
        (tester) async {
      await tester.pumpWidget(
        buildTestWidget(entry: videoEntry, isVisible: false),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final summaryText = tester.widget<Text>(
        find.byKey(const Key('feed-card-summary-text')),
      );

      expect(summaryText.maxLines, isNull);
      expect(summaryText.overflow, isNull);
    });

    testWidgets('video source style is smaller and lighter than summary',
        (tester) async {
      await tester.pumpWidget(
        buildTestWidget(entry: videoEntry, isVisible: false),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final summaryText = tester.widget<Text>(
        find.byKey(const Key('feed-card-summary-text')),
      );
      final sourceText = tester.widget<Text>(
        find.byKey(const Key('feed-card-source-label')),
      );
      final summaryStyle = summaryText.style!;
      final sourceStyle = sourceText.style!;

      expect(sourceStyle.fontSize, lessThan(summaryStyle.fontSize!));
      expect(sourceStyle.color!.opacity, lessThan(summaryStyle.color!.opacity));
      expect(sourceStyle.color!.opacity, lessThan(0.45));
    });

    testWidgets('has bookmark toggle button', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(entry: videoEntry, isVisible: false),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);
    });

    testWidgets('does not show an open link action button', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(entry: videoEntry, isVisible: false),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.open_in_new), findsNothing);
    });

    testWidgets(
        'resume rearm only happens after a real background foreground cycle',
        (tester) async {
      await tester.pumpWidget(
        buildTestWidget(entry: videoEntry, isVisible: true),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Clear calls from initial self-arm; this test is about lifecycle cycles.
      mockManager.calls.clear();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 700));

      expect(
        mockManager.calls.where((call) => call.startsWith('play:')),
        isEmpty,
        reason: 'Initial resumed lifecycle should not trigger playback rearm.',
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 2));

      expect(
        mockManager.calls.where((call) => call.startsWith('play:')),
        isNotEmpty,
        reason: 'A real foreground resume should rearm playback.',
      );
    });
  });
}
