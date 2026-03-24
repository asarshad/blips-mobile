import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:blips_mobile/features/feed/providers/video/youtube_player_manager_base.dart';

/// Re-arms the active video/reel and escalates to a full retry when the player
/// remains stuck in loading/idle after an initial play nudge.
Future<void> nudgePrimaryPlayback(
  YoutubePlayerManagerBase videoManager,
  String primaryUrl,
) async {
  if (primaryUrl.isEmpty) return;

  await videoManager.initController(primaryUrl);
  await WidgetsBinding.instance.endOfFrame;

  var playIssued = false;
  for (final delay in const <Duration>[
    Duration(milliseconds: 180),
    Duration(milliseconds: 420),
    Duration(milliseconds: 900),
  ]) {
    await Future<void>.delayed(delay);
    final state = videoManager.getState(primaryUrl);
    if (state == YTPlayerState.playing) {
      return;
    }

    final stuckLoading = playIssued &&
        (state == YTPlayerState.loading || state == YTPlayerState.idle);
    if (state == YTPlayerState.error || stuckLoading) {
      await videoManager.retryVideo(primaryUrl);
      playIssued = false;
      continue;
    }

    await videoManager.playVideo(primaryUrl);
    playIssued = true;
  }
}
