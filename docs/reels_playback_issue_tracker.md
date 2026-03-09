# Reels Playback Issue Tracker

Date: 2026-03-09
Owners: Mobile + Backend
Scope: Reels preload, playback, manager lifecycle, backend feed guarantees

## Reported Symptoms

- Reel shows first frame (or spinner) and never starts.
- Taps sometimes do nothing (no play affordance shown).
- Swiping away and back often makes the same reel play.
- Pattern observed in session: first two reels stuck, next couple play, then stalls recur.

## Backend Answers (Code-Verified)

- `/videos/reels` serves `ContentType.REEL` from unified `content_items` via tiered feed service:
  - `src/backend/app/api/routes/videos.py`
  - `src/backend/app/services/tiered_feed_service.py`
- Reel payload uses `video_url` fallback (`item.video_url or item.source_url`) and always includes `source_url`:
  - `src/backend/app/api/routes/videos.py`
- `content_items.source_url` is `unique=True` and `nullable=False` (hard dedupe + non-null URL):
  - `src/backend/app/models/content.py`
- In YouTube ingestion, reels/video rows store normalized URL into both `source_url` and `video_url`, with dedupe by URL + `yt:<video_id>` key:
  - `src/backend/app/ingestion/service.py`

Conclusion: backend data quality/dedup looks structurally sound for this bug class; primary fault domain is mobile playback orchestration.

## Architecture Findings

- [x] Duplicate reels controller warm-up paths caused avoidable pool churn:
  - `FeedShellPage._useBackgroundReelsPreload`
  - `OptimizedReelsPage._useInitialPreload`
- [x] `onPageChanged` had a stale path where preloaded-but-not-ready controllers were not always re-armed with `playVideo`.
- [x] Manager auto-play callback could return before state mapping, leaving stale UI state (loading/playing mismatch).
- [x] `ReelItem` only mounted `YoutubePlayer` for ready/playing/paused states, increasing risk that loading controllers had delayed/no progression in-page.
- [ ] No integration-style test currently covers shell warm-up + reels page + real manager race behavior.

## Fixes Started (This Pass)

- [x] Removed shell-level reels controller preload. Shell now warms reels data only; reels page owns controller lifecycle.
- [x] Hardened manager state mapping and autoplay ordering in `_handleControllerUpdate`.
- [x] Updated `onPageChanged` to always re-arm playback through `playVideo(currentUrl)` and added a short recovery nudge.
- [x] Updated `ReelItem` to mount player whenever controller exists so loading controllers can progress.
- [ ] Add targeted race/regression tests for manager + reels page orchestration.

## Validation Checklist

- [ ] Cold app open -> Reels tab first item plays without swipe-away/back.
- [ ] Rapid vertical swipes do not leave spinner-only active reel.
- [ ] Tap on stuck reel triggers visible recovery (play or play indicator).
- [ ] Resume from background returns to active reel playback reliably.
- [ ] No audio bleed when switching tabs.

## Automated Verification (This Pass)

- [x] `flutter test test/widget/reel_item_test.dart`
- [x] `flutter test test/unit/youtube_player_manager_playback_test.dart`
- [x] `dart analyze` on touched reels/shell/manager files (info-level existing lints only, no errors)
