# Slot-pool refactor plan: reuse WKWebViews instead of recreating them

## Scope: applies to BOTH Reels and Videos screens

This refactor targets the single shared `YoutubePlayerManager` instance behind `youtubePlayerManagerProvider`. Every YouTube WKWebView the app creates — whether on the Videos feed (`video_card.dart`, via `feed_tab.dart`) or the Reels feed (`reel_item.dart`, `optimized_reels_page.dart`, `feed_shell_page.dart`) — flows through this manager. Capping the slot pool inside the manager caps WebView count app-wide; both screens benefit automatically without any widget changes.

Do not split this into a Reels-only or Videos-only change. The manager is shared and the fix must be made there once.

## Goal

Replace the URL-keyed controller pool in `YoutubePlayerManager` with a fixed-size pool of reusable `YoutubePlayerController`s. Each slot is re-targeted to a new video via `controller.load(videoId)` instead of being disposed and recreated. This caps WKWebView count at `maxSlots` for the app's lifetime, regardless of feed size.

## Why

Each `YoutubePlayerController` wraps a `WKWebView` (~50–100 MB on iOS). Today we create one per URL and rely on `_managePoolSize` to dispose stale ones — but disposal is asynchronous and there's a brief window where multiple WebViews exist. Over time WebView memory accumulates (JS heap fragmentation) even with the cap. Reusing one WebView across many videos via `controller.load()` keeps memory bounded.

TikTok/Facebook can do this trivially because they use `AVPlayer` with their own video files. We can't (YouTube TOS forbids extracting streams without a partner deal), so reusing WKWebViews is our equivalent.

## Files affected

- `lib/features/feed/providers/video/youtube_player_manager.dart` — main rewrite (~600 LOC affected)
- `lib/features/feed/providers/video/youtube_player_manager_base.dart` — no public API changes
- `test/test_utils/fake_youtube_player_manager.dart` — keep URL-keyed (no internal slots needed)
- Widget code (`video_card.dart`, `reel_item.dart`, `feed_shell_page.dart`, `optimized_reels_page.dart`) — no changes expected; verify
- `test/widget/*` and `test/unit/*` — minor adjustments only
- New file: `test/unit/youtube_player_manager_slot_test.dart`

The base contract stays URL-keyed. The slot model is a private implementation detail.

## Internal data model

Replace the current per-URL maps with:

```dart
class _Slot {
  _Slot({required this.id, required this.controller});
  final int id;                      // monotonic, for diagnostics + listener identity
  final YoutubePlayerController controller;
  String? currentUrl;                // null when free
  YTPlayerState state = YTPlayerState.idle;
  YTPlayerError? error;
  int loadGeneration = 0;            // bumped on every load(); listener uses it
  int swapCount = 0;                 // when ≥ swapRecycleThreshold, dispose+recreate
  DateTime lastTouched = DateTime.now();
  bool pendingLoad = false;          // a load() is in flight; block re-entry
  String? pendingLoadUrl;            // most recent requested URL during a pending load
  VoidCallback? listener;
}

final List<_Slot> _slots = [];
final Map<String, _Slot> _slotByUrl = {};
int _nextSlotId = 0;

static const int _swapRecycleThreshold = 20;
```

`maxSlots = MemoryConfig.playerPoolSize` (3 today). Slots are created lazily on first `_acquireSlot`, not eagerly.

## Slot lifecycle and operations

### `_Slot _acquireSlot(String url)` — central entry point

1. If `_slotByUrl[url]` exists → touch `lastTouched`, return it. (Reuse already-loaded slot.)
2. Else if `_slots.length < maxSlots` → create a new slot with a fresh controller (initialized with the videoId; this is the only path that pays the full WebView cost). Wire the listener, store in `_slots`, register in `_slotByUrl[url]`. Return.
3. Else find the LRU slot whose `currentUrl != _currentActiveUrl`:
   - If that slot's `swapCount >= _swapRecycleThreshold` → call `_recycleSlot(slot)` first (dispose old controller, create a new one in place; slot is now free with a fresh controller). **Then fall through to `_swapSlotToUrl(slot, url)`** to bind the requested URL. Recycle alone does not satisfy the acquisition — every acquire path must end with the slot bound to `url`.
   - Else call `_swapSlotToUrl(slot, url)`.
   - Return the slot (now bound to `url`).

### `_swapSlotToUrl(_Slot slot, String url)`

- If `slot.pendingLoad` → set `slot.pendingLoadUrl = url` and return; the in-flight load's completion picks it up. Only the most recent requested URL is honored; intermediate ones are dropped.
- Remove `_slotByUrl[slot.currentUrl]`.
- `slot.currentUrl = url`; `slot.loadGeneration += 1`; `slot.swapCount += 1`; `slot.state = loading`; `slot.error = null`.
- `_slotByUrl[url] = slot`.
- `slot.pendingLoad = true`; call `slot.controller.load(videoId)`. `pendingLoad` is cleared by the listener when `cued`/`unStarted` fires for the new load (see "Listener" below).

### `_freeSlot(String url)` — full teardown (preserves iOS audio-bleed safety)

**Important: `_freeSlot` is NOT pause-only.** iOS WKWebView intermittently ignores `controller.pause()`, so any path that leaves a freed slot's controller alive without immediately re-targeting it via `load()` can leak audio. The current manager handles this by synchronously disposing out-of-window controllers in `releaseVideo` (see `youtube_player_manager.dart` around line 774: *"Disposing now is the only reliable way to silence it"*). The slot pool MUST preserve that guarantee.

So `_freeSlot` does a full teardown:

1. Look up `_slotByUrl[url]`. If absent, no-op.
2. Mirror every per-URL cleanup that `releaseVideo` does today:
   - `_pendingInit.remove(url)`
   - `_cancelAutoplayWatchdog(url)`
   - `_userPausedUrls.remove(url)`
   - `_autoplayStalledUrls.remove(url)`
   - `_errors.remove(url)`
   - If `_currentActiveUrl == url`, set `_currentActiveUrl = null`
3. Detach the listener; `controller.dispose()` inside try/catch.
4. Remove `_slotByUrl[url]` and remove the slot from `_slots`.
5. `_notifySafe()`.

The reuse optimization is NOT in `_freeSlot` — it is in `_swapSlotToUrl`. The pool stays "fixed-size in steady state" because `onPageChanged`'s reconciliation pairs outgoing URLs with incoming URLs and routes them through `_swapSlotToUrl` (which calls `controller.load()` and never frees, so the controller never goes silent on its own — `load()` replaces the media synchronously). Only URLs without an incoming pair go through `_freeSlot` and lose their controller.

### `_swapSlotToUrl` per-URL cleanup

When swapping a slot from `oldUrl` to `newUrl`, the same per-URL cleanup must run for `oldUrl` as `_freeSlot` does (minus the dispose) — otherwise stale `_userPausedUrls`, `_autoplayStalledUrls`, `_errors`, `_pendingInit`, and watchdogs leak across URL bindings on the same slot. Specifically, before flipping `slot.currentUrl`:

- `_pendingInit.remove(oldUrl)`
- `_cancelAutoplayWatchdog(oldUrl)`
- `_userPausedUrls.remove(oldUrl)`
- `_autoplayStalledUrls.remove(oldUrl)`
- `_errors.remove(oldUrl)`
- `_slotByUrl.remove(oldUrl)`

### `_recycleSlot(_Slot slot)`

- Run the full per-URL cleanup for `slot.currentUrl` (same list as `_freeSlot` step 2).
- Dispose the old controller (best-effort try/catch); detach its listener.
- Create a new controller, wire a fresh listener with the new slot identity.
- Reset `swapCount = 0`, `loadGeneration = 0`, `pendingLoad = false`, `pendingLoadUrl = null`, `currentUrl = null`, `state = idle`, `error = null`.
- This is the safety valve for WKWebView JS-heap accumulation. Keep `_swapRecycleThreshold` configurable.

## Listener and stale-event handling

Each slot's listener captures `slot` (not just the URL). On every controller update:

```dart
void _onSlotUpdate(_Slot slot) {
  if (_isDisposed) return;

  // Slot may have been freed mid-event.
  final url = slot.currentUrl;
  if (url == null) return;

  // Errors first.
  final errorCode = slot.controller.value.errorCode;
  if (errorCode != 0) {
    _handleSlotError(slot, errorCode);
    return;
  }

  // Map iframe state to YTPlayerState (existing logic, but on slot).
  final playerState = slot.controller.value.playerState;
  final newState = _mapPlayerState(playerState, slot.state, slot.controller.value.isReady);

  // The brief paused/unStarted/cued sequence during load() must not be misread
  // as a user pause. While pendingLoad is true, ignore terminal pause events.
  if (slot.pendingLoad) {
    if (playerState == PlayerState.cued || playerState == PlayerState.unStarted) {
      slot.pendingLoad = false;
      // If a swap was queued during the load, apply it now.
      final queuedUrl = slot.pendingLoadUrl;
      if (queuedUrl != null && queuedUrl != url) {
        slot.pendingLoadUrl = null;
        _swapSlotToUrl(slot, queuedUrl);
        return;
      }
    } else if (playerState == PlayerState.paused) {
      return; // ignore the paused tick that load() emits before cued
    }
  }

  // ... existing _handleControllerUpdate logic, but reading/writing slot.state
  // and computing autoplay decisions against url == _currentActiveUrl.
}
```

Critical rules:
- **Autoplay decisions must check `slot.currentUrl == _currentActiveUrl`**, not a captured URL. The slot may have been reassigned.
- **`loadGeneration` is the freshness key for any deferred work** (e.g. a `Future.delayed` followup spawned from inside the listener). Capture the generation at the start; bail if `slot.loadGeneration != captured` when the deferred work runs.
- **The `pendingLoad` flag must be cleared in exactly one place** (the listener, when `cued`/`unStarted` fires after the corresponding `load()`). Don't clear it elsewhere.

## Race conditions

| # | Race | Mitigation |
|---|------|------------|
| 1 | Two rapid `_swapSlotToUrl` calls on the same slot | `pendingLoad` flag blocks the second; latest URL wins via `pendingLoadUrl`. Document: only the most recent requested URL is honored. |
| 2 | Listener fires for the URL the slot was JUST reassigned away from | Listener reads `slot.currentUrl`, which has already been updated. The `pendingLoad` gate above stops the brief `paused` event during `load()` from being misinterpreted. |
| 3 | Caller asks `getController(A)` after slot was reassigned to B | Returns null (because `_slotByUrl[A]` is gone). Widget falls back to thumbnail. Same as today's release behavior. |
| 4 | `releaseVideo(A)` while `_acquireSlot(A)` is mid-load | `_freeSlot(A)` detaches the listener and disposes the controller, then removes the slot from `_slots` and `_slotByUrl`. Any in-flight `load(A)` events are silenced because the listener is gone with the controller. No need to consult `currentUrl` — the listener simply doesn't exist anymore. |
| 5 | `onPageChanged` while a previous one is still in its async tail | The async tail rechecks `_currentActiveUrl != currentUrl` and bails. Existing pattern, preserved. |
| 6 | `_recycleSlot` while a listener is mid-execution | Recycle disposes the old controller (which detaches the listener) before creating the new one. Any in-flight listener call uses the old slot.controller reference and finishes harmlessly. The new controller gets a new listener. |

## Public API mapping

The base interface in `youtube_player_manager_base.dart` does not change. Only the implementation changes:

| Public method | New behavior |
|---|---|
| `getController(url)` | `_slotByUrl[url]?.controller` |
| `getState(url)` | `_slotByUrl[url]?.state ?? YTPlayerState.idle` |
| `getError(url)` | `_slotByUrl[url]?.error` |
| `initController(url)` | `_acquireSlot(url)` and return the controller |
| `playVideo(url)` | `_acquireSlot(url)`; then `controller.play()`. Same `_currentActiveUrl` and `_armAutoplayAttempt` semantics as today. |
| `pauseVideo(url)` | If slot exists, `controller.pause()`, set state, add to `_userPausedUrls`. |
| `retryVideo(url)` | **Keep today's contract: `_freeSlot(url)` then `playVideo(url)`.** This works whether or not the URL currently owns a slot — if no slot exists, `_freeSlot` is a no-op and `playVideo` falls through to `_acquireSlot`, which creates or swaps as needed. Don't map retry to `_recycleSlot` directly: a retry on an unbound URL would have no slot to recycle and would silently no-op. The internal `_swapRecycleThreshold` still triggers full teardown periodically; that's separate from user-facing retry. |
| `releaseVideo(url)` | `_freeSlot(url)` — full teardown (NOT pause-only). |
| `ensurePlayback(url)` | Unchanged outer logic; internally goes through `_acquireSlot` instead of `initController`. |
| `onPageChanged` | Compute the same keep-window as today (`keepBehind = maxControllers - preloadAhead - 1`, clamped at 0; current + ahead always kept). The synchronous reconciliation pairs each outgoing URL (currently bound but outside the keep window) with an incoming URL (in the keep window but unbound) and routes the pair through `_swapSlotToUrl` (no dispose, the slot's controller stays alive and `load()` replaces media). Any unpaired outgoing URLs go through `_freeSlot` (full teardown) so audio can't leak. Any unpaired incoming URLs go through `_acquireSlot` — which only creates a new controller when the pool is below `maxSlots`. Steady-state scrolling produces only swaps; cold start produces creates; jumps produce a mix of swaps and full teardowns. |
| `pauseAll`, `pauseAllForBackground`, `dispose` | Iterate `_slots` instead of `_controllers`. |
| `getPlaybackOverlayState` | Unchanged logic; now reads slot-state via the URL keys. |

## Behavioral changes worth flagging

1. **`getController(url)` may return null briefly during a swap** even for a URL that was previously loaded. Today this happens after `releaseVideo`; the difference is that today the controller is gone forever, whereas tomorrow it may come back when a slot is reassigned. UI is identical (falls back to thumbnail).
2. **`controller.value.position` continuity**: today, scrolling away and back creates a new controller starting at position 0. With slot reuse, scrolling back may land on a slot whose previous URL was different — `load()` resets position to 0. So position behavior is identical to today.
3. **Cold-start vs warm**: first 3 reels pay the WebView creation cost (same as today). Reels 4+ are pure `load()` calls — much faster, much less memory.

## Test plan

### Unit tests — new file `test/unit/youtube_player_manager_slot_test.dart`

The current `FakeYoutubePlayerManager` is for widget tests and stays URL-keyed; this new file tests the real manager logic with a fake controller factory.

**Required prep:** add a `typedef ControllerFactory = YoutubePlayerController Function(String videoId);` and thread it through `YoutubePlayerManager`'s constructor (default to a real factory that creates `YoutubePlayerController` with the existing flags).

Coverage:
1. Pool grows to `maxSlots` then stops; further acquires reuse via LRU.
2. `_acquireSlot(A)` twice in a row returns the same slot.
3. After 4 distinct URLs on a 3-slot pool, the LRU URL has no controller; `getController(LRU)` is null.
4. Listener for a stale generation does not mutate state.
5. After `_swapRecycleThreshold` swaps, a slot is disposed+recreated; `dispose()` was called exactly once on the old controller.
6. `retryVideo(url)` calls `_freeSlot(url)` then `playVideo(url)`. Cover both subcases: (a) URL currently bound to a slot — assert the old controller's `dispose()` was called once and a new controller is bound after retry; (b) URL not bound to any slot — assert no dispose, but the URL still ends up bound and playing after retry. (This is what protects against the "retry no-ops on unbound URL" regression.)
7. `onPageChanged` with a 5-URL list at index 2 (`preloadAhead=2`, `maxSlots=3`) leaves slots bound to indices 2, 3, 4; index 0 and 1 unbound. (`keepBehind = maxSlots - preloadAhead - 1 = 0` in this configuration, so the kept window is current plus two ahead — verify by reading `youtube_player_manager.dart` around line 779 before writing the assertion.) Also assert: outgoing slots that pair with incoming URLs are swapped (not disposed); unpaired outgoing slots are fully torn down (controller `dispose()` was called).
8. App-lifecycle pause: `_currentActiveUrl` preserved, all controllers paused, no slots disposed.
9. Two rapid swaps on the same slot: only the second `load()` is issued (or the first finishes then the queued URL is loaded); end state binds the slot to the second URL.
10. `pendingLoad` paused-event suppression: a `paused` tick during `load()` does not flip `state` to paused or set `_userPausedUrls`.

### Existing widget tests

`test/widget/reel_item_test.dart`, `test/widget/video_card_test.dart`, `test/widget/app_navigation_test.dart` should still pass without modification because the public API behavior is preserved. Run them as a regression check.

### Manual QA on a real iOS device

- Scroll 50 reels → memory should plateau, not climb. Use Xcode Instruments → Allocations.
- Scroll back to a reel from earlier → loads from network/cache, plays.
- Background and foreground the app → current reel resumes.
- Tap pause/play repeatedly → no stuck overlay.
- Swipe rapidly through 10 reels in 2 seconds → no audio bleed, no orphan WebViews.

## Implementation sequence

Land in 4 commits, each compilable and test-passing:

1. **Introduce the slot model behind the scenes.** Add `_Slot`, `_slots`, `_slotByUrl`. Implement `_acquireSlot`, `_freeSlot`, `_swapSlotToUrl` with `loadGeneration` and `pendingLoad`. Rewrite `initController`, `releaseVideo`, `getController`, `getState`, `getError` to delegate to slot operations. Don't add recycling yet. All existing tests must pass.

2. **Rewrite `_handleControllerUpdate` as `_onSlotUpdate`.** Update `playVideo`, `pauseVideo`, `retryVideo`, `ensurePlayback`, `onPageChanged`, `pauseAll`, `releaseAll`, `dispose`, lifecycle hooks. All existing tests must pass.

3. **Add `_recycleSlot` and the swap-count threshold.** Wire it into `_acquireSlot`'s LRU path: when `swapCount >= _swapRecycleThreshold`, recycle then swap (see "Slot lifecycle and operations"). `retryVideo` does NOT change in this commit — it stays as `_freeSlot + playVideo`. Recycle is purely an internal optimization keyed on swap count; it must not change the public retry contract. New unit tests for recycle.

4. **Add the controller factory injection and the new unit-test file.** Cover the cases listed above.

After all four land, manual QA on iOS device.

## Risk assessment

Medium-high. The state machine is small but the order-of-operations during `load()` is subtle and platform-specific. The biggest unknown is how `youtube_player_flutter`'s `load()` interacts with iOS WKWebView under rapid swap scenarios — spend 30 minutes reading the package source for `load()` and `cue()` before starting. In particular, verify what events the controller emits during a `load()` call and in what order, so the `pendingLoad` gate in the listener is correct.

## Out of scope (do not touch)

- The position-advancement signal in `getPlaybackOverlayState`, `_armAutoplayWatchdog`, and `ensurePlayback` — already in place.
- The synchronous eager-evict step in `onPageChanged` — preserved. Outgoing URLs are still resolved synchronously; the only change is that pairs route through `_swapSlotToUrl` instead of dispose+create, while unpaired outgoing URLs still go through `_freeSlot` (full teardown).
- The URL resolution in `feed_shell_page.dart`'s `_rearmFirstReelPlayback` — already fixed.
- Any widget-level changes — verify behavior by running widget tests, but don't edit widget files.

## Non-goals / common misreads to avoid

- **Do not implement `_freeSlot` as pause-only.** It must dispose the controller. Audio bleed safety on iOS depends on this.
- **Do not map `retryVideo` to a bare `_recycleSlot`.** Retry must work on URLs that have no slot. Use `_freeSlot + playVideo`.
- **Do not skip per-URL state cleanup on swap.** Every per-URL map (`_pendingInit`, `_userPausedUrls`, `_autoplayStalledUrls`, `_errors`, autoplay watchdog) must be cleared for the outgoing URL during `_swapSlotToUrl`, `_freeSlot`, and `_recycleSlot`.
- **Do not assume `keepBehind > 0` in the test plan.** With the default `preloadAhead=2` and `maxSlots=3`, `keepBehind = 0`. Read the live keep-window math in `youtube_player_manager.dart` and mirror it.
