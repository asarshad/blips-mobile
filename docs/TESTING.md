# Testing

This repo uses a layered test strategy so we catch regressions early without slowing down development.

## Test layers

### Unit (`test/unit/`)
- Pure Dart logic: mappers, DTO parsing, repositories (with fakes), small helpers.
- **No** network, SQLite, WebViews, or platform plugins.

Run:
- `flutter test test/unit`

### Widget (`test/widget/`)
- Widget behavior and UI state in isolation.
- Use Riverpod overrides + fakes to avoid real backend/cache/video.

Run:
- `flutter test test/widget`

### Golden (`test/golden/`)
- Screenshot/layout regression tests.
- Goldens are stored in `test/golden/goldens/`.
- Golden device presets live in `test/golden/golden_test_utils.dart`.

Run:
- `flutter test test/golden`

Update baselines (only when intended UI changes):
- `flutter test --update-goldens test/golden`

### Integration (`integration_test/`)
- High-level “golden path” flows (app launches, tab navigation, basic surfaces).
- These tests should still avoid relying on the real backend: override providers with fakes.

Run:
- `flutter test integration_test`

## Tags (CI selection)

We tag tests so CI can include/exclude layers:
- `unit`
- `widget`
- `golden`
- `integration`
- `manual` (local-only; not suitable for CI)

Examples:
- Fast PR set (no integration/manual):
  - `flutter test --exclude-tags=integration --exclude-tags=manual`
- Only goldens:
  - `flutter test --tags=golden`

## Fakes and provider overrides

When tests need data or state:
- Use fakes under `test/test_utils/`.
- Override Riverpod providers via `ProviderScope(overrides: [...])`.

Common overrides:
- `feedRepositoryProvider` → override with a repository built on `FakeBackendApiClient`
- `feedCacheProvider` → override with `FakeFeedCache`
- `youtubePlayerManagerProvider` → override with `FakeYoutubePlayerManager`

## Video testing boundaries

We **do not** test video playback internals (WebView / YouTube player / `video_player` pipeline) in unit/widget/golden tests.
- Those are plugin/platform responsibilities and are too flaky for CI.
- UI tests should validate *our* surfaces (layout, state transitions, controls) using fakes.

Any platform-dependent video lifecycle tests should be tagged `manual` and run locally on a real device/simulator.

### Manual simulator playback probe

For the real iOS simulator/WebView playback path, run:

```bash
./tool/run_ios_playback_probe.sh
```

This boots an iPhone simulator, runs the app with:
- the real `YoutubePlayerManager`
- fake backend/feed data
- diagnostics enabled in release mode

The probe currently verifies:
- first open to Videos
- repeated upward swipes through multiple videos
- tab switch away/back
- jump-to-latest after retap refresh

On the iOS simulator, the probe treats `ready` as success once the app has
issued a real `playVideo` command for that URL. This is intentional: simulator
WebView/YouTube iframe autoplay is not the same contract as a real iPhone.

For a real-device autoplay proof, use the device runner:

```bash
./tool/run_ios_playback_probe_device.sh <device-id>
```

That path stays strict about the player reaching `playing`.

## CI

Workflows live in `.github/workflows/`:
- `flutter_pr.yml`: format + analyze + unit/widget/golden tests (excludes `integration` + `manual`).
- `flutter_integration.yml`: runs the above plus `integration_test/` on `main` and nightly.
