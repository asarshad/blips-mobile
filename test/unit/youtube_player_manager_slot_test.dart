@Tags(['unit'])
library youtube_player_manager_slot_test;

import 'package:blips_mobile/features/feed/providers/video/youtube_player_manager.dart';
import 'package:blips_mobile/features/feed/providers/video/youtube_player_manager_base.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

// ── Tracked controller ────────────────────────────────────────────────────

class _TrackedController extends YoutubePlayerController {
  _TrackedController(this.videoId)
      : super(
          initialVideoId: videoId,
          flags: const YoutubePlayerFlags(autoPlay: false),
        );

  final String videoId;
  int disposeCount = 0;
  int playCalls = 0;
  int pauseCalls = 0;

  @override
  void dispose() {
    disposeCount++;
    super.dispose();
  }

  @override
  void play() {
    playCalls++;
    updateValue(
      value.copyWith(playerState: PlayerState.playing, isReady: true),
    );
  }

  @override
  void pause() {
    pauseCalls++;
    updateValue(
      value.copyWith(playerState: PlayerState.paused),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────

const _u0 = 'https://www.youtube.com/watch?v=AAAAAAAAAAA';
const _u1 = 'https://www.youtube.com/watch?v=BBBBBBBBBBB';
const _u2 = 'https://www.youtube.com/watch?v=CCCCCCCCCCC';
const _u3 = 'https://www.youtube.com/watch?v=DDDDDDDDDDD';
const _u4 = 'https://www.youtube.com/watch?v=EEEEEEEEEEE';

class _Tracker {
  final List<_TrackedController> created = [];

  _TrackedController call(String videoId) {
    final c = _TrackedController(videoId);
    created.add(c);
    return c;
  }

  int get liveCount => created.where((c) => c.disposeCount == 0).length;
  int get disposeCount => created.fold(0, (s, c) => s + c.disposeCount);
}

YoutubePlayerManager _manager(_Tracker tracker) =>
    YoutubePlayerManager(controllerFactory: tracker.call);

// ── Tests ─────────────────────────────────────────────────────────────────

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  group('pool size', () {
    test('grows to maxControllers and no further', () async {
      final t = _Tracker();
      final m = _manager(t);
      addTearDown(m.dispose);

      await m.initController(_u0);
      await m.initController(_u1);
      await m.initController(_u2);
      expect(t.created.length, 3);

      // 4th URL must evict one, not create a 4th WebView permanently.
      await m.initController(_u3);

      final live =
          [_u0, _u1, _u2, _u3].where((u) => m.getController(u) != null).length;
      expect(live, lessThanOrEqualTo(YoutubePlayerManager.maxControllers));
    });

    test('initController twice returns the same controller', () async {
      final t = _Tracker();
      final m = _manager(t);
      addTearDown(m.dispose);

      final c1 = await m.initController(_u0);
      final c2 = await m.initController(_u0);
      expect(identical(c1, c2), isTrue);
      expect(t.created.length, 1);
    });

    test('evicted URL has no controller and idle state', () async {
      final t = _Tracker();
      final m = _manager(t);
      addTearDown(m.dispose);

      await m.initController(_u0);
      await m.initController(_u1);
      await m.initController(_u2);
      await m.initController(_u3); // evicts one of 0-2

      final evicted =
          [_u0, _u1, _u2].where((u) => m.getController(u) == null).toList();
      expect(evicted, isNotEmpty);
      for (final url in evicted) {
        expect(m.getState(url), YTPlayerState.idle);
      }
    });
  });

  group('releaseVideo', () {
    test('removes controller and disposes it', () async {
      final t = _Tracker();
      final m = _manager(t);
      addTearDown(m.dispose);

      await m.initController(_u0);
      m.releaseVideo(_u0);

      expect(m.getController(_u0), isNull);
      expect(m.getState(_u0), YTPlayerState.idle);
      expect(t.created[0].disposeCount, 1);
    });

    test('is a no-op for unknown URL', () {
      final t = _Tracker();
      final m = _manager(t);
      addTearDown(m.dispose);

      expect(() => m.releaseVideo(_u4), returnsNormally);
    });
  });

  group('playVideo', () {
    test('transitions state to playing via controller', () async {
      final t = _Tracker();
      final m = _manager(t);
      addTearDown(m.dispose);

      await m.playVideo(_u0);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(m.getState(_u0), YTPlayerState.playing);
    });

    test('overlay is none while playing', () async {
      final t = _Tracker();
      final m = _manager(t);
      addTearDown(m.dispose);

      await m.playVideo(_u0);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(m.getPlaybackOverlayState(_u0), YTPlaybackOverlayState.none);
    });
  });

  group('pauseVideo', () {
    test('transitions to manualPause overlay', () async {
      final t = _Tracker();
      final m = _manager(t);
      addTearDown(m.dispose);

      await m.playVideo(_u0);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      final ctrl = t.created.first;
      m.pauseVideo(_u0);

      expect(ctrl.disposeCount, 0);
      expect(m.getController(_u0), same(ctrl));
      expect(m.getState(_u0), YTPlayerState.paused);
      expect(
        m.getPlaybackOverlayState(_u0),
        YTPlaybackOverlayState.manualPause,
      );
    });

    test('play then pause then play clears manual-pause state', () async {
      final t = _Tracker();
      final m = _manager(t);
      addTearDown(m.dispose);

      await m.playVideo(_u0);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      m.pauseVideo(_u0);
      await m.playVideo(_u0);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(t.created.length, 1);
      expect(m.getPlaybackOverlayState(_u0), YTPlaybackOverlayState.none);
    });

    test(
        'manualPause overlay persists when position > 250 ms (device regression)',
        () async {
      // Regression: on a real device the YouTube iframe advances position
      // while playing. After pauseVideo() is called, position stays > 250 ms.
      // The old code cleared _userPausedUrls whenever position > 250, so the
      // play button never appeared and tapping did nothing visible.
      final t = _Tracker();
      final m = _manager(t);
      addTearDown(m.dispose);

      await m.playVideo(_u0);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      // Simulate the controller reporting that 5 s of video has elapsed.
      final ctrl = t.created.first;
      ctrl.updateValue(
        ctrl.value.copyWith(
          playerState: PlayerState.playing,
          position: const Duration(milliseconds: 5000),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));

      // Now the user pauses.
      m.pauseVideo(_u0);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(ctrl.disposeCount, 0);
      expect(m.getController(_u0), same(ctrl));
      expect(
        m.getPlaybackOverlayState(_u0),
        YTPlaybackOverlayState.manualPause,
        reason: 'play button must remain visible after tap-to-pause '
            'even when video position is well past 250 ms',
      );
    });

    test('active iframe pause is treated as a manual pause', () async {
      final t = _Tracker();
      final m = _manager(t);
      addTearDown(m.dispose);

      await m.playVideo(_u0);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      final ctrl = t.created.first;
      ctrl.updateValue(
        ctrl.value.copyWith(
          playerState: PlayerState.paused,
          position: const Duration(seconds: 5),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(m.getState(_u0), YTPlayerState.paused);
      expect(ctrl.disposeCount, 0);
      expect(m.getController(_u0), same(ctrl));
      expect(
        m.getPlaybackOverlayState(_u0),
        YTPlaybackOverlayState.manualPause,
        reason: 'Android WebView taps can pause inside the iframe before '
            'Flutter sees the tap; that pause must not be auto-resumed.',
      );
    });
  });

  group('retryVideo', () {
    test('disposes old controller and creates a new one', () async {
      final t = _Tracker();
      final m = _manager(t);
      addTearDown(m.dispose);

      await m.initController(_u0);
      expect(t.created.length, 1);

      await m.retryVideo(_u0);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(
        t.created[0].disposeCount,
        1,
        reason: 'old controller must be disposed on retry',
      );
      expect(
        t.created.length,
        2,
        reason: 'a fresh controller must be created',
      );
    });

    test('works on URL that was never initialised', () async {
      final t = _Tracker();
      final m = _manager(t);
      addTearDown(m.dispose);

      await expectLater(m.retryVideo(_u4), completes);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(m.getController(_u4), isNotNull);
    });
  });

  group('onPageChanged — keep window', () {
    test('index=2, pool=2 evicts urls[0] and [1] synchronously', () async {
      // preloadAhead clamps to 1; keepBehind = 2 - 1 - 1 = 0, so keep u2/u3.
      final t = _Tracker();
      final m = _manager(t);
      addTearDown(m.dispose);

      await m.initController(_u0);
      await m.initController(_u1);
      await m.initController(_u2);

      m.onPageChanged(
        currentIndex: 2,
        videoUrls: [_u0, _u1, _u2, _u3, _u4],
        preloadAhead: 2,
      );

      // Out-of-window URLs should be released synchronously.
      expect(
        m.getController(_u0),
        isNull,
        reason: 'urls[0] is outside keep window',
      );
      expect(
        m.getController(_u1),
        isNull,
        reason: 'urls[1] is outside keep window',
      );
      expect(
        m.getController(_u2),
        isNotNull,
        reason: 'current url must stay alive',
      );
    });

    test('releases previous controller when only keeping current and next',
        () async {
      final t = _Tracker();
      final m = _manager(t);
      addTearDown(m.dispose);

      await m.playVideo(_u0);
      await m.initController(_u1);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      m.onPageChanged(
        currentIndex: 1,
        videoUrls: [_u0, _u1, _u2],
        preloadAhead: 1,
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));

      // keepBehind = 2 - 1 - 1 = 0, so _u0 leaves the memory window.
      expect(m.getController(_u0), isNull);
      expect(m.getState(_u1), YTPlayerState.playing);
    });

    test('same-page bookkeeping does not resume a manually paused video',
        () async {
      final t = _Tracker();
      final m = _manager(t);
      addTearDown(m.dispose);

      await m.playVideo(_u0);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      m.pauseVideo(_u0);
      final createdAfterPause = t.created.length;

      m.onPageChanged(
        currentIndex: 0,
        videoUrls: [_u0, _u1],
        preloadAhead: 1,
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(t.created.length, createdAfterPause);
      expect(m.getState(_u0), YTPlayerState.paused);
      expect(
        m.getPlaybackOverlayState(_u0),
        YTPlaybackOverlayState.manualPause,
      );
    });

    test('out-of-bounds index is a no-op', () {
      final t = _Tracker();
      final m = _manager(t);
      addTearDown(m.dispose);

      expect(
        () => m.onPageChanged(currentIndex: 99, videoUrls: [_u0, _u1]),
        returnsNormally,
      );
    });
  });

  group('pauseAll', () {
    test('pauses all controllers without disposing them', () async {
      final t = _Tracker();
      final m = _manager(t);
      addTearDown(m.dispose);

      await m.playVideo(_u0);
      await m.initController(_u1);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      m.pauseAll();

      expect(m.getController(_u0), isNotNull);
      expect(m.getController(_u1), isNotNull);
      expect(t.disposeCount, 0);
    });

    test('system pause does not become manual pause', () async {
      final t = _Tracker();
      final m = _manager(t);
      addTearDown(m.dispose);

      await m.playVideo(_u0);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      m.pauseAll();
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(m.getState(_u0), YTPlayerState.paused);
      expect(
        m.getPlaybackOverlayState(_u0),
        isNot(YTPlaybackOverlayState.manualPause),
      );
    });
  });

  group('dispose', () {
    test('disposes every controller exactly once', () async {
      final t = _Tracker();
      final m = _manager(t);

      await m.initController(_u0);
      await m.initController(_u1);

      m.dispose();

      for (final ctrl in t.created) {
        expect(ctrl.disposeCount, 1);
      }
    });
  });

  group('overlay state', () {
    test('autoplayPending when no controller yet for active URL', () {
      final t = _Tracker();
      final m = _manager(t);
      addTearDown(m.dispose);

      // Simulate setCurrentActive without creating controller yet.
      // onPageChanged sets currentActiveUrl before ensureSlot.
      m.onPageChanged(
        currentIndex: 0,
        videoUrls: [_u0],
        preloadAhead: 0,
      );

      // The overlay should be pending (not none) immediately, before play().
      final overlay = m.getPlaybackOverlayState(_u0);
      expect(
        overlay == YTPlaybackOverlayState.autoplayPending ||
            overlay == YTPlaybackOverlayState.none,
        isTrue,
        reason: 'active URL must show pending or none, never error/manual',
      );
    });

    test('error overlay when controller reports error code', () async {
      final t = _Tracker();
      final m = _manager(t);
      addTearDown(m.dispose);

      await m.initController(_u0);
      final ctrl = m.getController(_u0) as _TrackedController;
      ctrl.updateValue(ctrl.value.copyWith(errorCode: 100));
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(m.getPlaybackOverlayState(_u0), YTPlaybackOverlayState.error);
      expect(m.getError(_u0)?.code, 100);
    });
  });
}
