# Per-Surface Manual Refresh Fix v2

## Summary

Manual refresh should become explicitly surface-specific for **articles, videos, and reels**. A successful manual refresh always moves the user to the first item on that surface; background refresh never changes position.

The current `paginatedFeedProvider` design is the main cause of slow-feeling article/video refresh, because each manual refresh can fetch both playlists. The backend is fast enough today, so this fix stays app-side. The implementation must also guarantee that manual refresh never leaves the user staring at a spinner for tens of seconds.

## Implementation Changes

### Networking and request policy

- Add `enum RequestMode { normal, manualRefresh }`.
- Extend `BackendApiClient.get/post` to accept an optional `requestMode`.
- In `DioBackendApiClient`, map `manualRefresh` to per-request `Options`:
  - `connectTimeout = 5s`
  - `sendTimeout = 5s`
  - `receiveTimeout = 8s`
  - `extra['requestMode'] = 'manualRefresh'`
- Update `RetryInterceptor` to take the app's configured `Dio` instance in its constructor and retry via that same instance, not a new bare `Dio()`.
- `RetryInterceptor` must skip retries entirely when `requestMode == manualRefresh`.
- Keep existing retry behavior for `normal` requests only.
- Each provider's manual-refresh path wraps the fetch in an `8s` outer timeout and treats timeout as failure with no state mutation.

### Repository and providers

- In `feed_repository.dart`, add:
  - `fetchArticlesPage(...)`
  - `fetchVideosPage(...)`
- Keep `fetchReelsPage(...)` as the reels fetch entrypoint.
- The legacy `fetchFeed()` and `fetchFeedPage()` path has been removed.
- Replace the shared article/video chain in `feed_providers.dart`:
  - remove `FeedNotifier`
  - remove `paginatedFeedProvider`
  - remove `filteredArticleFeedProvider`
  - remove `filteredVideoFeedProvider`
  - add `ArticlesNotifier` + `articlesFeedProvider`
  - add `VideosNotifier` + `videosFeedProvider`
  - keep `ReelsNotifier` + `reelsFeedProvider`
- Keep one shared `feedLastSeenAt` cutoff across articles and videos.
- `articleFeedWithAdsProvider` derives from `articlesFeedProvider`.
- `videoFeedWithAdsProvider` derives from `videosFeedProvider`.
- Providers stay warm because the shell watches article/video ad-wrapped providers directly; reels stay warm through the kept-alive reels page.

### Manual refresh behavior

- Add `Future<bool> manualRefresh()` to `ArticlesNotifier`, `VideosNotifier`, and `ReelsNotifier`.
- `manualRefresh()` semantics are identical across all three surfaces:
  - keep current content visible while fetching
  - fetch only page 1 for that surface using `RequestMode.manualRefresh`
  - on success:
    - replace state with the fresh first page
    - reset that surface's session/cursor continuation state
    - update cache
    - set `_currentViewIndex = 0`
    - return `true`
  - on failure or timeout:
    - leave current content and cursor state unchanged
    - return `false`
- `refreshSilently()` remains the background-only path for polling, resume, and stale-while-revalidate.
- Remove or stop using current `forceRefresh()` methods once `manualRefresh()` is wired everywhere.

### PageController ownership and UI wiring

- Move the vertical `PageController` for each surface into `feed_shell_page.dart`:
  - `articleFeedController`
  - `videoFeedController`
  - `reelsFeedController`
- Update `feed_tab.dart` to accept:
  - external `PageController`
  - `Future<void> Function()` for manual refresh actions
- Update `optimized_reels_page.dart` to accept an external controller.
- Add shell-scoped async helpers:
  - `_refreshArticlesManually()`
  - `_refreshVideosManually()`
  - `_refreshReelsManually()`
- Each shell helper:
  - awaits the notifier's `manualRefresh()`
  - on success: `jumpToPage(0)` on that surface controller
  - on failure: show retryable snackbar and keep current page
- Use those same helpers for:
  - tab retap refresh
  - visible empty-state refresh button
  - visible error retry button
- `_useResumeRefresh()` dispatches per active surface and remains silent:
  - articles -> `articlesFeedProvider.notifier.refreshSilently()`
  - videos -> `videosFeedProvider.notifier.refreshSilently()`
  - reels -> `reelsFeedProvider.notifier.refreshSilently()`

### Polling

- Keep articles and videos on 90-second polling, but stagger starts:
  - articles start immediately
  - videos start with a 45-second initial offset
- Keep reels polling at its current cadence.
- Background polling continues to preserve position and never jumps to top.

## Test Plan

- Repository tests:
  - article manual refresh hits only article playlist fetch
  - video manual refresh hits only video playlist fetch
  - reels manual refresh remains reels-only
  - `manualRefresh` request mode applies short timeouts and disables retries
- Provider tests:
  - `manualRefresh()` success returns `true`, replaces first page, and resets `_currentViewIndex`
  - `manualRefresh()` failure returns `false` and preserves visible state/index
  - video refresh no longer waits on article latency
  - background refresh preserves current position on all surfaces
  - staggered article/video polling does not fire on the same tick
- Widget tests:
  - successful manual refresh on articles jumps to page `0`
  - successful manual refresh on videos jumps to page `0`
  - successful manual refresh on reels jumps to page `0`
  - failed manual refresh keeps the current item visible and shows retry snackbar
  - empty/error refresh buttons use the same manual-refresh path as retap
- Live validation:
  - article/video/reel manual refresh should usually complete in under `3s`
  - manual refresh must fail visibly by `8s`
  - new top items must become visible immediately after successful manual refresh
  - background resume refresh must not move the user

## Assumptions

- "Manual refresh" includes tab retap and any visible refresh/retry buttons.
- On manual refresh success, the app always jumps to the first item, even if the refreshed first page is unchanged.
- Background refresh is strictly non-disruptive.
- No backend contract or ranking changes are included in this fix.
