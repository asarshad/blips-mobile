@Tags(['widget'])
library reel_item_test;

import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:blips_mobile/features/feed/presentation/reels/reel_item.dart';
import 'package:blips_mobile/features/feed/providers/video/youtube_player_manager.dart';
import 'package:blips_mobile/features/feed/providers/video/youtube_player_manager_base.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

/// Mock video manager for testing reel items without actual playback.
class MockYoutubePlayerManager extends YoutubePlayerManagerBase {
  final Map<String, YTPlayerState> _mockStates = {};

  @override
  YoutubePlayerController? getController(String url) => null;

  @override
  YTPlayerState getState(String url) => _mockStates[url] ?? YTPlayerState.idle;

  @override
  YTPlayerError? getError(String url) => null;

  @override
  bool isReady(String url) => false;

  @override
  bool isPlaying(String url) => false;

  @override
  String? extractVideoId(String url) => 'test_video_id';

  @override
  Future<YoutubePlayerController?> initController(String url) async => null;

  @override
  Future<void> playVideo(String url) async {}

  @override
  Future<void> retryVideo(String url) async {}

  @override
  void pauseVideo(String url) {}

  @override
  void pauseAll() {}

  @override
  void onPageChanged({
    required int currentIndex,
    required List<String> videoUrls,
  }) {}

  void setMockState(String url, YTPlayerState state) {
    _mockStates[url] = state;
    notifyListeners();
  }
}

void main() {
  group('ReelItem', () {
    late ReelFeedEntry testReel;
    late MockYoutubePlayerManager mockManager;

    setUp(() {
      mockManager = MockYoutubePlayerManager();
      testReel = ReelFeedEntry(
        id: 100,
        title: 'Test Reel Title',
        summary: 'This is a short reel about technology.',
        videoUrl: 'https://youtube.com/watch?v=abc123',
        link: 'https://youtube.com/watch?v=abc123',
        source: 'TechChannel',
        publishedAt: DateTime(2025, 2, 10, 10, 0),
        addedAt: DateTime(2025, 2, 10, 11, 0),
        thumbnailUrl: 'https://i.ytimg.com/vi/abc123/hqdefault.jpg',
        conversationStarters: ['What did you learn?'],
      );
    });

    Widget buildTestWidget({
      required ReelFeedEntry entry,
      bool isActive = true,
      bool isVisible = true,
    }) {
      return ProviderScope(
        overrides: [
          youtubePlayerManagerProvider.overrideWith((ref) => mockManager),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 600,
              child: ReelItem(
                entry: entry,
                isActive: isActive,
                isVisible: isVisible,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('renders reel title', (tester) async {
      await tester.pumpWidget(buildTestWidget(entry: testReel));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Test Reel Title'), findsOneWidget);
    });

    testWidgets('renders source name', (tester) async {
      await tester.pumpWidget(buildTestWidget(entry: testReel));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('TechChannel'), findsOneWidget);
    });

    testWidgets('shows thumbnail while loading', (tester) async {
      await tester.pumpWidget(buildTestWidget(entry: testReel));
      await tester.pump();

      // Should have some image widget with the thumbnail
      final imageFinders = find.byType(Image);
      expect(imageFinders, findsWidgets);
    });

    testWidgets('has action buttons', (tester) async {
      await tester.pumpWidget(buildTestWidget(entry: testReel));
      await tester.pump(const Duration(milliseconds: 100));

      // Should have share and open_in_new action buttons
      expect(find.byIcon(Icons.share), findsOneWidget);
      expect(find.byIcon(Icons.open_in_new), findsOneWidget);
    });

    testWidgets('renders with inactive state', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        entry: testReel,
        isActive: false,
      ));
      await tester.pump(const Duration(milliseconds: 100));

      // Should still render content
      expect(find.text('Test Reel Title'), findsOneWidget);
    });

    testWidgets('renders when not visible', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        entry: testReel,
        isVisible: false,
      ));
      await tester.pump(const Duration(milliseconds: 100));

      // Should still render structure but video might not play
      expect(find.text('Test Reel Title'), findsOneWidget);
    });

    testWidgets('handles missing thumbnail gracefully', (tester) async {
      final reelNoThumbnail = ReelFeedEntry(
        id: 101,
        title: 'No Thumbnail Reel',
        summary: 'Reel without a thumbnail URL.',
        videoUrl: 'https://youtube.com/watch?v=xyz789',
        link: 'https://youtube.com/watch?v=xyz789',
        source: 'AnotherChannel',
        publishedAt: DateTime(2025, 2, 9),
        thumbnailUrl: null,
      );

      await tester.pumpWidget(buildTestWidget(entry: reelNoThumbnail));
      await tester.pump(const Duration(milliseconds: 100));

      // Should not crash and should still show title
      expect(find.text('No Thumbnail Reel'), findsOneWidget);
    });

    // ── Play-indicator state-sync (Bug 2 regression) ──────────────────────

    testWidgets('shows play indicator when active and state is not playing',
        (tester) async {
      mockManager.setMockState(testReel.link, YTPlayerState.paused);

      await tester.pumpWidget(buildTestWidget(entry: testReel, isActive: true));
      await tester.pump(const Duration(milliseconds: 100));

      // Play indicator (Icons.play_arrow) is visible when paused.
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });

    testWidgets('hides play indicator when state is playing', (tester) async {
      mockManager.setMockState(testReel.link, YTPlayerState.playing);

      await tester.pumpWidget(buildTestWidget(entry: testReel, isActive: true));
      await tester.pump(const Duration(milliseconds: 100));

      // Play indicator must be hidden when video is actually playing
      // (Bug 2: frozen "playing" state caused indicator to disappear even
      // though the video was not actually playing).
      expect(find.byIcon(Icons.play_arrow), findsNothing);
    });

    testWidgets('tap while paused calls playVideo (not pauseVideo)',
        (tester) async {
      // Track method calls.
      final calls = <String>[];
      final trackingManager = _TrackingYoutubePlayerManager(
        delegate: mockManager,
        onPlayVideo: (url) => calls.add('play:$url'),
        onPauseVideo: (url) => calls.add('pause:$url'),
      );
      mockManager.setMockState(testReel.link, YTPlayerState.paused);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            youtubePlayerManagerProvider.overrideWith((ref) => trackingManager),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 600,
                child: ReelItem(
                  entry: testReel,
                  isActive: true,
                  isVisible: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Tap the video area.
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump(const Duration(milliseconds: 100));

      // When paused, tap must trigger play — not pause.
      expect(
        calls,
        contains(startsWith('play:')),
        reason: 'tapping a paused reel must call playVideo, not pauseVideo',
      );
      expect(
        calls,
        isNot(contains(startsWith('pause:'))),
        reason: 'tapping a paused reel must not call pauseVideo',
      );
    });

    testWidgets('tap while in error state calls retryVideo', (tester) async {
      final calls = <String>[];
      final trackingManager = _TrackingYoutubePlayerManager(
        delegate: mockManager,
        onRetryVideo: (url) => calls.add('retry:$url'),
      );
      mockManager.setMockState(testReel.link, YTPlayerState.error);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            youtubePlayerManagerProvider.overrideWith((ref) => trackingManager),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 600,
                child: ReelItem(
                  entry: testReel,
                  isActive: true,
                  isVisible: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        calls,
        contains(startsWith('retry:')),
        reason: 'tapping an error reel must call retryVideo',
      );
    });
  });
}

/// A [YoutubePlayerManagerBase] wrapper that records method invocations for
/// assertion in tests.
class _TrackingYoutubePlayerManager extends YoutubePlayerManagerBase {
  _TrackingYoutubePlayerManager({
    required this.delegate,
    this.onPlayVideo,
    this.onPauseVideo,
    this.onRetryVideo,
  });

  final MockYoutubePlayerManager delegate;
  final void Function(String url)? onPlayVideo;
  final void Function(String url)? onPauseVideo;
  final void Function(String url)? onRetryVideo;

  @override
  YoutubePlayerController? getController(String url) =>
      delegate.getController(url);

  @override
  YTPlayerState getState(String url) => delegate.getState(url);

  @override
  YTPlayerError? getError(String url) => delegate.getError(url);

  @override
  bool isReady(String url) => delegate.isReady(url);

  @override
  bool isPlaying(String url) => delegate.isPlaying(url);

  @override
  String? extractVideoId(String url) => delegate.extractVideoId(url);

  @override
  Future<YoutubePlayerController?> initController(String url) =>
      delegate.initController(url);

  @override
  Future<void> playVideo(String url) async {
    onPlayVideo?.call(url);
    await delegate.playVideo(url);
    notifyListeners();
  }

  @override
  Future<void> retryVideo(String url) async {
    onRetryVideo?.call(url);
    await delegate.retryVideo(url);
    notifyListeners();
  }

  @override
  void pauseVideo(String url) {
    onPauseVideo?.call(url);
    delegate.pauseVideo(url);
    notifyListeners();
  }

  @override
  void pauseAll() {
    delegate.pauseAll();
    notifyListeners();
  }

  @override
  void onPageChanged({
    required int currentIndex,
    required List<String> videoUrls,
  }) =>
      delegate.onPageChanged(currentIndex: currentIndex, videoUrls: videoUrls);
}
