import 'dart:async';

import 'package:blips_mobile/features/feed/providers/video/youtube_player_manager_base.dart';

final Expando<int> _managerNudgeGeneration = Expando<int>(
  'primaryPlaybackNudgeGeneration',
);

/// Re-arms the active video/reel and escalates to a full retry when the player
/// remains stuck in loading/idle after an initial play nudge.
Future<void> nudgePrimaryPlayback(
  YoutubePlayerManagerBase videoManager,
  String primaryUrl,
) async {
  if (primaryUrl.isEmpty) return;

  final generation = (_managerNudgeGeneration[videoManager] ?? 0) + 1;
  _managerNudgeGeneration[videoManager] = generation;

  bool isStale() => _managerNudgeGeneration[videoManager] != generation;

  await videoManager.initController(primaryUrl);
  if (isStale()) return;
  await Future<void>.delayed(Duration.zero);
  if (isStale()) return;

  var playIssued = false;
  final delays = const <Duration>[
    Duration(milliseconds: 180),
    Duration(milliseconds: 420),
    Duration(milliseconds: 900),
  ];
  for (var index = 0; index < delays.length; index += 1) {
    final delay = delays[index];
    await Future<void>.delayed(delay);
    if (isStale()) return;
    final state = videoManager.getState(primaryUrl);
    if (state == YTPlayerState.playing) {
      return;
    }

    final loadingLongEnough = playIssued &&
        state == YTPlayerState.loading &&
        index == delays.length - 1;
    final stalledAfterPlay = playIssued &&
        (state == YTPlayerState.idle ||
            state == YTPlayerState.ready ||
            state == YTPlayerState.paused ||
            loadingLongEnough);
    if (state == YTPlayerState.error || stalledAfterPlay) {
      await videoManager.retryVideo(primaryUrl);
      if (isStale()) return;
      playIssued = false;
      continue;
    }

    await videoManager.playVideo(primaryUrl);
    if (isStale()) return;
    playIssued = true;
  }
}
