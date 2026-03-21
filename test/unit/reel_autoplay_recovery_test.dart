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

    test('retries a stalled controller once loading is no longer pending', () {
      final action = resolveReelAutoplayRecoveryAction(
        isCurrentActive: true,
        controllerExists: true,
        isPendingInit: false,
        state: YTPlayerState.loading,
        attempt: 1,
        maxAttempts: 4,
      );

      expect(action, ReelAutoplayRecoveryAction.retry);
    });

    test('replays ready and paused reels', () {
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
