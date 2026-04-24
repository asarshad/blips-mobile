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

  // Controller is still loading or hasn't started yet — don't tear it down,
  // just nudge it. Retrying every idle/loading/buffering tap creates a
  // spin-loop: each rebuild races the previous one and can leave playback
  // permanently stalled.
  if (playerState == YTPlayerState.loading ||
      playerState == YTPlayerState.idle) {
    return ReelPlaybackTapAction.play;
  }

  // When the UI shows a play affordance, the user's tap must first be used as
  // a real play gesture against the existing WebView. Rebuilding first can
  // move the eventual play() outside the gesture and leave iOS stuck.
  if (isAutoplayStalled) {
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
