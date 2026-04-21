import 'package:blips_mobile/features/feed/providers/video/youtube_player_manager_base.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

enum ReelPlaybackTapAction {
  play,
  pause,
  retry,
}

ReelPlaybackTapAction resolveReelPlaybackTapAction({
  required bool hasController,
  required bool isAutoplayStalled,
  required YTPlayerState playerState,
  required PlayerState? controllerPlayerState,
}) {
  if (playerState == YTPlayerState.error) {
    return ReelPlaybackTapAction.retry;
  }

  if (!hasController) {
    return ReelPlaybackTapAction.play;
  }

  // Controller is stuck in a state where play() cannot unstick it — tear it
  // down and rebuild so the fresh WebView can load cleanly.
  if (isAutoplayStalled) {
    return ReelPlaybackTapAction.retry;
  }

  if (playerState == YTPlayerState.loading ||
      playerState == YTPlayerState.idle) {
    return ReelPlaybackTapAction.retry;
  }

  if (controllerPlayerState == PlayerState.buffering ||
      controllerPlayerState == PlayerState.unknown) {
    return ReelPlaybackTapAction.retry;
  }

  if (controllerPlayerState == PlayerState.playing ||
      playerState == YTPlayerState.playing) {
    return ReelPlaybackTapAction.pause;
  }

  return ReelPlaybackTapAction.play;
}
