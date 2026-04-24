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

  // A controller that is still loading while the iframe reports buffering is
  // usually wedged. Rebuild it so a tap gives the WebView a fresh load.
  if (playerState == YTPlayerState.loading &&
      controllerPlayerState == PlayerState.buffering) {
    return ReelPlaybackTapAction.retry;
  }

  // Controller is still loading or hasn't started yet — don't tear it down,
  // just nudge it. Retrying every idle/loading tap creates a spin-loop: each
  // rebuild races the previous one and can leave playback permanently stalled.
  if (playerState == YTPlayerState.loading ||
      playerState == YTPlayerState.idle) {
    return ReelPlaybackTapAction.play;
  }

  // Buffering is transient — tearing down the controller interrupts a video
  // that was about to play on its own. Nudge with play() at most.
  if (controllerPlayerState == PlayerState.buffering ||
      controllerPlayerState == PlayerState.unknown) {
    return ReelPlaybackTapAction.play;
  }

  if (controllerPlayerState == PlayerState.playing ||
      playerState == YTPlayerState.playing) {
    return ReelPlaybackTapAction.pause;
  }

  return ReelPlaybackTapAction.play;
}
