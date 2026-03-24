@Tags(['unit'])
library playback_rearm_test;

import 'dart:async';

import 'package:blips_mobile/features/feed/providers/video/playback_rearm.dart';
import 'package:blips_mobile/features/feed/providers/video/youtube_player_manager_base.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class _PlaybackRearmTestManager extends YoutubePlayerManagerBase {
  _PlaybackRearmTestManager({
    this.retrySucceeds = true,
  });

  final bool retrySucceeds;

  final Map<String, YTPlayerState> _states = <String, YTPlayerState>{};
  final List<String> calls = <String>[];

  @override
  YoutubePlayerController? getController(String url) => null;

  @override
  YTPlayerError? getError(String url) => null;

  @override
  YTPlayerState getState(String url) => _states[url] ?? YTPlayerState.idle;

  @override
  bool isPlaying(String url) => getState(url) == YTPlayerState.playing;

  @override
  bool isReady(String url) => getState(url) != YTPlayerState.idle;

  @override
  String? extractVideoId(String url) => YoutubePlayer.convertUrlToId(url);

  @override
  Future<YoutubePlayerController?> initController(String url) async {
    calls.add('init:$url');
    _states[url] = YTPlayerState.ready;
    return null;
  }

  @override
  void onPageChanged({
    required int currentIndex,
    required List<String> videoUrls,
    int? preloadAhead,
  }) {}

  @override
  void pauseAll() {}

  @override
  void pauseVideo(String url) {}

  @override
  Future<void> playVideo(String url) async {
    calls.add('play:$url');
  }

  @override
  Future<void> retryVideo(String url) async {
    calls.add('retry:$url');
    if (retrySucceeds) {
      _states[url] = YTPlayerState.playing;
    }
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  group('nudgePrimaryPlayback', () {
    test('escalates a ready-but-stalled player to retry', () async {
      const url = 'https://www.youtube.com/watch?v=M7lc1UVf-VE';
      final manager = _PlaybackRearmTestManager();

      await nudgePrimaryPlayback(manager, url);

      expect(manager.calls, contains('play:$url'));
      expect(manager.calls, contains('retry:$url'));
      expect(manager.getState(url), YTPlayerState.playing);
    });

    test('latest nudge cancels stale retries from the previous url', () async {
      const urlA = 'https://www.youtube.com/watch?v=M7lc1UVf-VE';
      const urlB = 'https://www.youtube.com/watch?v=ScMzIvxBSi4';
      final manager = _PlaybackRearmTestManager(retrySucceeds: false);

      unawaited(nudgePrimaryPlayback(manager, urlA));
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await nudgePrimaryPlayback(manager, urlB);

      final retriesForA =
          manager.calls.where((call) => call == 'retry:$urlA').length;
      final retriesForB =
          manager.calls.where((call) => call == 'retry:$urlB').length;

      expect(retriesForA, 0);
      expect(retriesForB, greaterThan(0));
    });
  });
}
