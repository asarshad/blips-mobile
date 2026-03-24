import 'package:blips_mobile/features/feed/providers/video/youtube_player_manager_base.dart';

/// Possible recovery actions for an active reel that failed to autoplay.
enum ReelAutoplayRecoveryAction {
  /// No further recovery should be attempted.
  stop,

  /// Wait and check again on the next recovery tick.
  wait,

  /// Retry the reel by rebuilding and re-arming playback.
  retry,

  /// Re-issue a play request without rebuilding the controller.
  play,
}

/// Decides how autoplay recovery should proceed for the current reel.
ReelAutoplayRecoveryAction resolveReelAutoplayRecoveryAction({
  required bool isCurrentActive,
  required bool controllerExists,
  required bool isPendingInit,
  required YTPlayerState state,
  required int attempt,
  required int maxAttempts,
}) {
  if (!isCurrentActive || attempt >= maxAttempts) {
    return ReelAutoplayRecoveryAction.stop;
  }

  switch (state) {
    case YTPlayerState.playing:
      return ReelAutoplayRecoveryAction.stop;
    case YTPlayerState.error:
      return ReelAutoplayRecoveryAction.retry;
    case YTPlayerState.loading:
      if (isPendingInit) {
        return ReelAutoplayRecoveryAction.wait;
      }
      if (!controllerExists) {
        return ReelAutoplayRecoveryAction.play;
      }
      return attempt < 3
          ? ReelAutoplayRecoveryAction.wait
          : ReelAutoplayRecoveryAction.retry;
    case YTPlayerState.ready:
      return attempt == 0
          ? ReelAutoplayRecoveryAction.play
          : ReelAutoplayRecoveryAction.wait;
    case YTPlayerState.paused:
      return attempt < 2
          ? ReelAutoplayRecoveryAction.play
          : ReelAutoplayRecoveryAction.retry;
    case YTPlayerState.idle:
      if (!controllerExists) {
        return isPendingInit
            ? ReelAutoplayRecoveryAction.wait
            : ReelAutoplayRecoveryAction.play;
      }
      return attempt < 2
          ? ReelAutoplayRecoveryAction.play
          : ReelAutoplayRecoveryAction.retry;
  }
}
