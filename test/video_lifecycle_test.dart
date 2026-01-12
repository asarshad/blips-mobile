import 'package:blips_mobile/features/feed/providers/video/video_player_manager.dart';
import 'package:flutter_test/flutter_test.dart';

/// Integration tests for video lifecycle management.
///
/// These tests verify that the video player manager properly:
/// 1. Releases resources when requested
/// 2. Cleans up player mappings
/// 3. Handles rapid operations without leaking
void main() {
  group('VideoPlayerManager Lifecycle', () {
    late OptimizedVideoPlayerManager manager;

    setUp(() {
      manager = OptimizedVideoPlayerManager();
    });

    tearDown(() {
      manager.dispose();
    });

    test('releaseAll() clears all player mappings', () async {
      // Preload some videos
      await manager.preload('https://youtube.com/watch?v=test1');
      await manager.preload('https://youtube.com/watch?v=test2');
      await manager.preload('https://youtube.com/watch?v=test3');

      // Give time for preload to assign players
      await Future.delayed(const Duration(milliseconds: 100));

      // Verify players are assigned (even if not ready, they should be in loading state)
      expect(manager.getPlayerState('https://youtube.com/watch?v=test1'),
          isNotNull);

      // Release all
      await manager.releaseAll();

      // Verify all mappings cleared
      expect(
          manager.getController('https://youtube.com/watch?v=test1'), isNull);
      expect(
          manager.getController('https://youtube.com/watch?v=test2'), isNull);
      expect(
          manager.getController('https://youtube.com/watch?v=test3'), isNull);

      expect(
          manager.getPlayerState('https://youtube.com/watch?v=test1'), isNull);
      expect(
          manager.getPlayerState('https://youtube.com/watch?v=test2'), isNull);
      expect(
          manager.getPlayerState('https://youtube.com/watch?v=test3'), isNull);
    });

    test('releaseVideo() only clears specific video', () async {
      // Preload some videos
      await manager.preload('https://youtube.com/watch?v=keep1');
      await manager.preload('https://youtube.com/watch?v=release');
      await manager.preload('https://youtube.com/watch?v=keep2');

      await Future.delayed(const Duration(milliseconds: 100));

      // Release specific video
      await manager.releaseVideo('https://youtube.com/watch?v=release');

      // Verify only the specific video is released
      expect(
          manager.getController('https://youtube.com/watch?v=release'), isNull);
      expect(manager.getPlayerState('https://youtube.com/watch?v=release'),
          isNull);

      // Others should still be there (even if in loading state)
      expect(manager.getPlayerState('https://youtube.com/watch?v=keep1'),
          isNotNull);
      expect(manager.getPlayerState('https://youtube.com/watch?v=keep2'),
          isNotNull);
    });

    test('rapid releaseAll() calls do not crash', () async {
      // Preload videos
      await manager.preload('https://youtube.com/watch?v=test1');
      await manager.preload('https://youtube.com/watch?v=test2');

      // Rapidly call releaseAll multiple times
      await Future.wait([
        manager.releaseAll(),
        manager.releaseAll(),
        manager.releaseAll(),
      ]);

      // Should not crash and all should be cleared
      expect(
          manager.getController('https://youtube.com/watch?v=test1'), isNull);
      expect(
          manager.getController('https://youtube.com/watch?v=test2'), isNull);
    });

    test('preload after releaseAll() works correctly', () async {
      // Preload and release
      await manager.preload('https://youtube.com/watch?v=test1');
      await Future.delayed(const Duration(milliseconds: 100));
      await manager.releaseAll();

      // Preload again
      await manager.preload('https://youtube.com/watch?v=test1');
      await Future.delayed(const Duration(milliseconds: 100));

      // Should be in loading state again
      expect(manager.getPlayerState('https://youtube.com/watch?v=test1'),
          isNotNull);
    });

    test('pauseAll() pauses but does not release', () async {
      // Note: This test is limited because we can't fully initialize controllers
      // without actual video URLs, but we can verify the method doesn't crash
      await manager.preload('https://youtube.com/watch?v=test1');
      await Future.delayed(const Duration(milliseconds: 100));

      // pauseAll should not crash
      await manager.pauseAll();

      // Player should still be assigned (state should exist)
      expect(manager.getPlayerState('https://youtube.com/watch?v=test1'),
          isNotNull);
    });

    test('player pool size is respected', () async {
      // Try to preload more videos than pool size (5)
      const poolSize = 5;
      final urls = List.generate(
        poolSize + 3,
        (i) => 'https://youtube.com/watch?v=test$i',
      );

      // Preload all
      for (final url in urls) {
        await manager.preload(url);
      }

      await Future.delayed(const Duration(milliseconds: 200));

      // Count how many have assigned states (should not exceed pool size)
      var assignedCount = 0;
      for (final url in urls) {
        if (manager.getPlayerState(url) != null) {
          assignedCount++;
        }
      }

      // Due to LRU recycling, only pool size should be active
      expect(assignedCount, lessThanOrEqualTo(poolSize));
    });
  });

  group('Video URL Management', () {
    late OptimizedVideoPlayerManager manager;

    setUp(() {
      manager = OptimizedVideoPlayerManager();
    });

    tearDown(() {
      manager.dispose();
    });

    test('same URL preloaded twice does not create duplicate', () async {
      const url = 'https://youtube.com/watch?v=test';

      // Preload same URL twice
      await manager.preload(url);
      await manager.preload(url);

      await Future.delayed(const Duration(milliseconds: 100));

      // Should only have one assignment
      final state = manager.getPlayerState(url);
      expect(state, isNotNull);

      // Release and verify only one cleanup needed
      await manager.releaseVideo(url);
      expect(manager.getPlayerState(url), isNull);
    });

    test('getController returns null for unassigned URLs', () {
      expect(manager.getController('https://youtube.com/watch?v=nonexistent'),
          isNull);
      expect(manager.getPlayerState('https://youtube.com/watch?v=nonexistent'),
          isNull);
    });

    test('isReady returns false for uninitialized videos', () {
      expect(manager.isReady('https://youtube.com/watch?v=test'), false);
    });

    test('isPlaying returns false for uninitialized videos', () {
      expect(manager.isPlaying('https://youtube.com/watch?v=test'), false);
    });
  });

  group('Performance Metrics', () {
    late OptimizedVideoPlayerManager manager;

    setUp(() {
      manager = OptimizedVideoPlayerManager();
    });

    tearDown(() {
      manager.dispose();
    });

    test('performance history is empty initially', () {
      expect(manager.performanceHistory, isEmpty);
    });

    test('averageTimeToFirstFrame is null when no metrics', () {
      expect(manager.averageTimeToFirstFrame, isNull);
    });
  });
}
