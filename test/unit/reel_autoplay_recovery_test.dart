@Tags(['unit'])
library reel_autoplay_recovery_test;

import 'package:blips_mobile/features/feed/providers/video/reel_autoplay_recovery.dart';
import 'package:blips_mobile/features/feed/providers/video/youtube_player_manager_base.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveReelAutoplayRecoveryAction', () {
    test('stops when reel is no longer active', () {
      final action = resolveReelAutoplayRecoveryAction(
        isCurrentActive: false,
        controllerExists: true,
        isPendingInit: false,
        state: YTPlayerState.loading,
        attempt: 0,
        maxAttempts: 4,
      );

      expect(action, ReelAutoplayRecoveryAction.stop);
    });

    test('stops once max attempts are exhausted', () {
      final action = resolveReelAutoplayRecoveryAction(
        isCurrentActive: true,
        controllerExists: true,
        isPendingInit: false,
        state: YTPlayerState.ready,
        attempt: 4,
        maxAttempts: 4,
      );

      expect(action, ReelAutoplayRecoveryAction.stop);
    });

    test('waits while init is still pending', () {
      final action = resolveReelAutoplayRecoveryAction(
        isCurrentActive: true,
        controllerExists: false,
        isPendingInit: true,
        state: YTPlayerState.loading,
        attempt: 1,
        maxAttempts: 4,
      );

      expect(action, ReelAutoplayRecoveryAction.wait);
    });

    test('waits longer before retrying a slow loading controller', () {
      final firstAction = resolveReelAutoplayRecoveryAction(
        isCurrentActive: true,
        controllerExists: true,
        isPendingInit: false,
        state: YTPlayerState.loading,
        attempt: 1,
        maxAttempts: 4,
      );
      final secondAction = resolveReelAutoplayRecoveryAction(
        isCurrentActive: true,
        controllerExists: true,
        isPendingInit: false,
        state: YTPlayerState.loading,
        attempt: 2,
        maxAttempts: 4,
      );
      final eventualAction = resolveReelAutoplayRecoveryAction(
        isCurrentActive: true,
        controllerExists: true,
        isPendingInit: false,
        state: YTPlayerState.loading,
        attempt: 3,
        maxAttempts: 4,
      );

      expect(firstAction, ReelAutoplayRecoveryAction.wait);
      expect(secondAction, ReelAutoplayRecoveryAction.wait);
      expect(eventualAction, ReelAutoplayRecoveryAction.retry);
    });

    test('replays ready and paused reels on the first recovery tick', () {
      final readyAction = resolveReelAutoplayRecoveryAction(
        isCurrentActive: true,
        controllerExists: true,
        isPendingInit: false,
        state: YTPlayerState.ready,
        attempt: 0,
        maxAttempts: 4,
      );
      final pausedAction = resolveReelAutoplayRecoveryAction(
        isCurrentActive: true,
        controllerExists: true,
        isPendingInit: false,
        state: YTPlayerState.paused,
        attempt: 0,
        maxAttempts: 4,
      );

      expect(readyAction, ReelAutoplayRecoveryAction.play);
      expect(pausedAction, ReelAutoplayRecoveryAction.play);
    });

    test('lets ready reels settle instead of tearing them down', () {
      final readyAction = resolveReelAutoplayRecoveryAction(
        isCurrentActive: true,
        controllerExists: true,
        isPendingInit: false,
        state: YTPlayerState.ready,
        attempt: 1,
        maxAttempts: 4,
      );
      final laterReadyAction = resolveReelAutoplayRecoveryAction(
        isCurrentActive: true,
        controllerExists: true,
        isPendingInit: false,
        state: YTPlayerState.ready,
        attempt: 3,
        maxAttempts: 4,
      );

      expect(readyAction, ReelAutoplayRecoveryAction.wait);
      expect(laterReadyAction, ReelAutoplayRecoveryAction.wait);
    });

    test('escalates paused reels to retry after repeated play attempts', () {
      final pausedAction = resolveReelAutoplayRecoveryAction(
        isCurrentActive: true,
        controllerExists: true,
        isPendingInit: false,
        state: YTPlayerState.paused,
        attempt: 2,
        maxAttempts: 4,
      );

      expect(pausedAction, ReelAutoplayRecoveryAction.retry);
    });

    test('escalates idle reels with a controller to retry after a failed play',
        () {
      final firstAction = resolveReelAutoplayRecoveryAction(
        isCurrentActive: true,
        controllerExists: true,
        isPendingInit: false,
        state: YTPlayerState.idle,
        attempt: 0,
        maxAttempts: 4,
      );
      final secondAction = resolveReelAutoplayRecoveryAction(
        isCurrentActive: true,
        controllerExists: true,
        isPendingInit: false,
        state: YTPlayerState.idle,
        attempt: 1,
        maxAttempts: 4,
      );

      expect(firstAction, ReelAutoplayRecoveryAction.play);
      expect(secondAction, ReelAutoplayRecoveryAction.play);
    });

    test('stops once reel is playing', () {
      final action = resolveReelAutoplayRecoveryAction(
        isCurrentActive: true,
        controllerExists: true,
        isPendingInit: false,
        state: YTPlayerState.playing,
        attempt: 1,
        maxAttempts: 4,
      );

      expect(action, ReelAutoplayRecoveryAction.stop);
    });
  });
}
