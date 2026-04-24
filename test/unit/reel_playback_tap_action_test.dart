@Tags(['unit'])
library reel_playback_tap_action_test;

import 'package:blips_mobile/features/feed/presentation/reels/reel_playback_tap_action.dart';
import 'package:blips_mobile/features/feed/providers/video/youtube_player_manager_base.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

void main() {
  group('resolveReelPlaybackTapAction', () {
    test('retries when the reel is in error state', () {
      final action = resolveReelPlaybackTapAction(
        hasController: true,
        isAutoplayStalled: false,
        playerState: YTPlayerState.error,
        controllerPlayerState: PlayerState.unknown,
      );

      expect(action, ReelPlaybackTapAction.retry);
    });

    test('plays when a controller is buffering during startup', () {
      final action = resolveReelPlaybackTapAction(
        hasController: true,
        isAutoplayStalled: false,
        playerState: YTPlayerState.loading,
        controllerPlayerState: PlayerState.buffering,
      );

      expect(action, ReelPlaybackTapAction.play);
    });

    test('plays when no controller exists yet', () {
      final action = resolveReelPlaybackTapAction(
        hasController: false,
        isAutoplayStalled: false,
        playerState: YTPlayerState.idle,
        controllerPlayerState: null,
      );

      expect(action, ReelPlaybackTapAction.play);
    });

    test('pauses when the reel is already playing', () {
      final action = resolveReelPlaybackTapAction(
        hasController: true,
        isAutoplayStalled: false,
        playerState: YTPlayerState.playing,
        controllerPlayerState: PlayerState.playing,
      );

      expect(action, ReelPlaybackTapAction.pause);
    });

    test('plays when the reel is ready or paused but not yet playing', () {
      final readyAction = resolveReelPlaybackTapAction(
        hasController: true,
        isAutoplayStalled: false,
        playerState: YTPlayerState.ready,
        controllerPlayerState: PlayerState.paused,
      );
      final pausedAction = resolveReelPlaybackTapAction(
        hasController: true,
        isAutoplayStalled: false,
        playerState: YTPlayerState.paused,
        controllerPlayerState: PlayerState.paused,
      );

      expect(readyAction, ReelPlaybackTapAction.play);
      expect(pausedAction, ReelPlaybackTapAction.play);
    });

    test('uses the user tap as a play gesture when autoplay has stalled', () {
      for (final controllerState in [
        PlayerState.unStarted,
        PlayerState.cued,
        PlayerState.paused,
        PlayerState.buffering,
      ]) {
        final action = resolveReelPlaybackTapAction(
          hasController: true,
          isAutoplayStalled: true,
          playerState: YTPlayerState.ready,
          controllerPlayerState: controllerState,
        );
        expect(
          action,
          ReelPlaybackTapAction.play,
          reason: 'controllerState=$controllerState',
        );
      }
    });
  });
}
