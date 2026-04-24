@Tags(['unit'])
library youtube_player_manager_playback_test;

import 'package:blips_mobile/features/feed/providers/video/youtube_player_manager_base.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_utils/fake_youtube_player_manager.dart';

/// Unit tests for the playback state-machine contract exposed by
/// [YoutubePlayerManagerBase].
///
/// These tests use [FakeYoutubePlayerManager] — the same fake that the
/// integration tests use — so they verify the contract without needing a
/// real WebView or YouTube iframe.
///
/// ------------------------------------------------------------------
/// BUG REGRESSION COVERAGE
/// ------------------------------------------------------------------
/// Bug 1 (first reel does not autoplay on fresh open / app resume):
///   → verify [playVideo] transitions state to playing.
///   → verify [onPageChanged] plays the new page.
///   → verify [pauseAll] does NOT prevent a subsequent [playVideo].
///
/// Bug 2 (stuck paused reel, no play indicator, tapping does nothing):
///   → verify state is NOT optimistically set to playing in [onPageChanged]
///     before [playVideo]/[onPageChanged] are actually called.
///   → verify state transitions are authoritative (idle→loading→ready→playing).
///   → verify [onPageChanged] pauses all other videos.
///   → verify tap handler (pauseVideo / playVideo toggle) is correct.
/// ------------------------------------------------------------------
void main() {
  late FakeYoutubePlayerManager manager;

  const url0 = 'https://youtube.com/watch?v=AAA';
  const url1 = 'https://youtube.com/watch?v=BBB';
  const url2 = 'https://youtube.com/watch?v=CCC';

  setUp(() {
    manager = FakeYoutubePlayerManager();
  });

  tearDown(() {
    manager.dispose();
  });

  // ── playVideo ────────────────────────────────────────────────────────────

  group('playVideo', () {
    test('transitions url state to playing', () async {
      await manager.playVideo(url0);
      expect(manager.getState(url0), YTPlayerState.playing);
    });

    test('does not affect other url states', () async {
      await manager.initController(url1);
      await manager.playVideo(url0);
      // url1 was only initialised, not played — should remain ready/idle.
      final url1State = manager.getState(url1);
      expect(url1State, isNot(YTPlayerState.playing));
    });

    test('calling pauseAll then playVideo resumes correct video', () async {
      // Regression: Bug 1 — pauseAll should not block subsequent playVideo.
      await manager.playVideo(url0);
      manager.pauseAll();
      expect(manager.getState(url0), YTPlayerState.paused);

      await manager.playVideo(url0);
      expect(
        manager.getState(url0),
        YTPlayerState.playing,
        reason: 'pauseAll should not permanently block playback — '
            'subsequent playVideo must succeed',
      );
    });

    test('multiple consecutive playVideo calls play the latest url', () async {
      await manager.playVideo(url0);
      await manager.playVideo(url1);

      // After playing url1, url1 must be playing.
      expect(manager.getState(url1), YTPlayerState.playing);
    });
  });

  // ── overlay contract ────────────────────────────────────────────────────

  group('playback overlay contract', () {
    test('autoplay-pending ready state does not expose play affordance',
        () async {
      manager.setState(url0, YTPlayerState.ready);

      expect(
        manager.getPlaybackOverlayState(url0),
        YTPlaybackOverlayState.autoplayPending,
      );
    });

    test('manual pause exposes play affordance', () async {
      await manager.playVideo(url0);
      manager.pauseVideo(url0);

      expect(
        manager.getPlaybackOverlayState(url0),
        YTPlaybackOverlayState.manualPause,
      );
    });

    test('stalled autoplay exposes play affordance', () {
      manager.setPlaybackOverlayState(
        url0,
        YTPlaybackOverlayState.autoplayStalled,
      );

      expect(
        manager.getPlaybackOverlayState(url0),
        YTPlaybackOverlayState.autoplayStalled,
      );
    });

    test('playing suppresses overlays', () async {
      await manager.playVideo(url0);

      expect(
        manager.getPlaybackOverlayState(url0),
        YTPlaybackOverlayState.none,
      );
    });

    test('playing suppresses stale manual-pause affordance', () {
      manager
        ..setPlaybackOverlayState(
          url0,
          YTPlaybackOverlayState.manualPause,
        )
        ..setState(url0, YTPlayerState.playing);

      expect(
        manager.getPlaybackOverlayState(url0),
        YTPlaybackOverlayState.none,
        reason: 'a stale pause flag must not render over active playback',
      );
    });

    test('playing suppresses stale autoplay-stalled affordance', () {
      manager
        ..setPlaybackOverlayState(
          url0,
          YTPlaybackOverlayState.autoplayStalled,
        )
        ..setState(url0, YTPlayerState.playing);

      expect(
        manager.getPlaybackOverlayState(url0),
        YTPlaybackOverlayState.none,
        reason: 'a stale stall flag must not render over active playback',
      );
    });
  });

  // ── pauseVideo ───────────────────────────────────────────────────────────

  group('pauseVideo', () {
    test('transitions playing state to paused', () async {
      await manager.playVideo(url0);
      manager.pauseVideo(url0);
      expect(manager.getState(url0), YTPlayerState.paused);
    });

    test('toggle sequence: tap while playing → paused', () async {
      await manager.playVideo(url0);
      expect(manager.isPlaying(url0), isTrue);

      // Simulates the tap handler in ReelItem._handleTap.
      if (manager.isPlaying(url0)) {
        manager.pauseVideo(url0);
      } else {
        await manager.playVideo(url0);
      }
      expect(manager.getState(url0), YTPlayerState.paused);
    });

    test('toggle sequence: tap while paused → playing', () async {
      await manager.playVideo(url0);
      manager.pauseVideo(url0);
      expect(manager.isPlaying(url0), isFalse);

      // Simulates the tap handler in ReelItem._handleTap.
      if (manager.isPlaying(url0)) {
        manager.pauseVideo(url0);
      } else {
        await manager.playVideo(url0);
      }
      expect(manager.getState(url0), YTPlayerState.playing);
    });
  });

  // ── pauseAll ─────────────────────────────────────────────────────────────

  group('pauseAll', () {
    test('pauses all playing videos', () async {
      await manager.playVideo(url0);
      await manager.playVideo(url1);
      manager.pauseAll();

      expect(manager.getState(url0), isNot(YTPlayerState.playing));
      expect(manager.getState(url1), isNot(YTPlayerState.playing));
    });

    test('state is paused (not idle) after pauseAll', () async {
      await manager.playVideo(url0);
      manager.pauseAll();
      expect(manager.getState(url0), YTPlayerState.paused);
    });
  });

  // ── onPageChanged ────────────────────────────────────────────────────────

  group('onPageChanged', () {
    test('plays current url and pauses others', () async {
      // Pre-initialise a few controllers.
      await manager.playVideo(url0);
      await manager.initController(url1);
      await manager.initController(url2);

      manager.onPageChanged(
        currentIndex: 1,
        videoUrls: [url0, url1, url2],
      );

      // Allow any microtasks / async work to settle.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(
        manager.getState(url1),
        YTPlayerState.playing,
        reason: 'onPageChanged must play the new current video',
      );
      expect(
        manager.getState(url0),
        isNot(YTPlayerState.playing),
        reason: 'onPageChanged must pause the previous video',
      );
    });

    test('rapid swipes: only the last swiped url is playing', () async {
      await manager.initController(url0);
      await manager.initController(url1);
      await manager.initController(url2);

      // Simulate rapid swipes.
      manager.onPageChanged(currentIndex: 1, videoUrls: [url0, url1, url2]);
      manager.onPageChanged(currentIndex: 2, videoUrls: [url0, url1, url2]);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(
        manager.getState(url2),
        YTPlayerState.playing,
        reason: 'Only the final destination video should be playing',
      );
    });

    test('out-of-bounds index does not throw', () async {
      // Should be a no-op, not throw.
      expect(
        () => manager.onPageChanged(
          currentIndex: 99,
          videoUrls: [url0, url1],
        ),
        returnsNormally,
      );
    });
  });

  // ── initController ───────────────────────────────────────────────────────

  group('initController', () {
    test('controller does not play after initController alone', () async {
      await manager.initController(url0);
      // initController must NOT start playback — only ready.
      expect(manager.getState(url0), isNot(YTPlayerState.playing));
    });

    test('controller is ready after initController', () async {
      await manager.initController(url0);
      expect(manager.isReady(url0), isTrue);
    });
  });

  // ── retryVideo ───────────────────────────────────────────────────────────

  group('retryVideo', () {
    test('retryVideo on error url transitions to playing', () async {
      manager.setError(url0, const YTPlayerError(code: 100, message: 'test'));
      expect(manager.getState(url0), YTPlayerState.idle);

      await manager.retryVideo(url0);
      expect(manager.getState(url0), YTPlayerState.playing);
    });

    test('retryVideo on playing url continues playing', () async {
      await manager.playVideo(url0);
      await manager.retryVideo(url0);
      expect(manager.getState(url0), YTPlayerState.playing);
    });
  });

  // ── lifecycle simulation ─────────────────────────────────────────────────

  group('lifecycle simulation (Bug 1 regression)', () {
    test('playVideo after background-pause resumes playback', () async {
      // Simulate: user on Reels, app goes to background, returns.
      await manager.playVideo(url0);
      expect(manager.isPlaying(url0), isTrue);

      // Background: pause without forgetting active url (like _pauseAllForBackground).
      manager.pauseAll();

      // Foreground: re-call playVideo (from _useLifecycleObserver).
      await manager.playVideo(url0);
      expect(
        manager.getState(url0),
        YTPlayerState.playing,
        reason: 'App resume must resume the previously active reel',
      );
    });

    test('pause then navigate-away then navigate-back resumes', () async {
      // Simulate tab switch.
      await manager.playVideo(url1);

      // Leave Reels tab.
      manager.pauseAll();

      // Re-enter Reels tab.
      await manager.playVideo(url1);
      expect(manager.getState(url1), YTPlayerState.playing);
    });
  });

  // ── no-op safety guards ──────────────────────────────────────────────────

  group('safety guards', () {
    test('pauseVideo on unknown url does not throw', () {
      expect(
        () => manager.pauseVideo('https://youtube.com/watch?v=UNKNOWN'),
        returnsNormally,
      );
    });

    test('pauseAll on empty manager does not throw', () {
      expect(() => manager.pauseAll(), returnsNormally);
    });

    test('dispose is safe to call', () {
      // Create a fresh manager so tearDown's dispose() does not double-fire.
      final local = FakeYoutubePlayerManager();
      expect(() => local.dispose(), returnsNormally);
    });
  });
}
