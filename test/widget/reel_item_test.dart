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
  YTPlayerState getState(String url) =>
      _mockStates[url] ?? YTPlayerState.idle;

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
  });
}

