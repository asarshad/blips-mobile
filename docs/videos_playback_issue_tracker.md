# Videos Playback Issue Tracker

Date: 2026-03-09
Owner: Mobile
Scope: Videos tab preload, autoplay, error recovery, URL contract

## Issues Reviewed

- Spinner-only/stuck load risk from conditional player mounting.
- No explicit in-card error UX/retry path for video failures.
- Duplicate controller preload orchestration (shell + tab).
- Shared preload tuning between reels and videos in the manager.
- Fragile playback URL usage (`source_url` used for playback by default).

## Fixes Applied

- [x] `VideoCard` now mounts `YoutubePlayer` whenever controller exists, so loading controllers can progress.
- [x] Added explicit video error overlay + retry-on-tap path (`retryVideo`).
- [x] Removed shell-level video controller preload; `FeedTab` is now the single preload owner for videos.
- [x] Added `MemoryConfig.videoPreloadCount` and wired videos tab to pass this into manager `onPageChanged`.
- [x] Updated videos playback to prefer `video_url` and fallback to `source_url` only when needed.

## Test Coverage Added

- [x] New widget tests for `VideoCard`:
  - mounts visible card and arms autoplay for playback URL
  - invisible card pauses current playback URL
  - error-state tap triggers retry on playback URL

## Validation Checklist

- [ ] Cold-open app -> enter Videos tab -> first video starts without dead spinner.
- [ ] Swipe through 6-10 videos rapidly, no persistent spinner-only card.
- [ ] Force playback error case and verify user sees error state + tap retry.
- [ ] Confirm pause/resume when leaving tab and returning.
