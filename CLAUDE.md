# Blips Mobile — Agent Context

## What Is This?

Flutter mobile app for Blips — an AI-curated tech news feed (articles, videos, reels).  
**iOS is live on the App Store. Android is in Play Console submission (in progress).**

Backend API: `https://api.blips.tech/api/v1`  
Current version in pubspec: `1.0.4+1`

---

## Non-Negotiable Agent Rules

- **Never claim a bug is fixed until `flutter test` passes in full.**
- **Never deploy to device until `flutter test` AND `flutter analyze --no-fatal-infos --no-fatal-warnings` pass.**
- If tests can't run, say so explicitly. Label unverified builds as unverified.
- For video/reel changes, also run the targeted video suite — see `AGENTS.md`.

---

## Platform Status

| Platform | Status | Notes |
|---|---|---|
| iOS | ✅ Live on App Store | Bundle ID: `com.blips.blipsnews`, flavor `Blips` |
| Android | 🔄 Play Store submission in progress | Package: `com.blips.blips_mobile` |

### iOS Build Command
```bash
flutter build ios --release --flavor Blips
ios-deploy --id <device-id> --bundle build/ios/iphoneos/Blips.app --timeout 60
```

### Android Build Command
```bash
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

---

## Android Build Constraints (DO NOT CHANGE without reading this)

These were resolved during the Android launch (May 2026). Changing them will break the build:

| Setting | Value | Why |
|---|---|---|
| AGP version | `8.9.1` | AGP 9.x breaks Flutter Gradle plugin in Flutter 3.41.6; deps require ≥8.9.1 |
| `kotlin-android` plugin | **Keep it** | Required for AGP 8.x; removed only in AGP 9+ |
| `coreLibraryDesugaringEnabled` | `true` | Required by `flutter_local_notifications` |
| `desugar_jdk_libs` | `2.1.4` | Must match desugaring flag |
| Signing | Reads `android/key.properties` at build time | Template at `android/key.properties.template` |

See `android/app/build.gradle.kts` and `android/settings.gradle.kts` for current state.

---

## Architecture Quick Reference

**State management:** Riverpod  
**Networking:** Dio (`core/network/dio_provider.dart`)  
**Navigation:** GoRouter (`lib/routes/`)  
**Local storage:** SharedPreferences + SQLite (chat history)

```
lib/
├── main.dart / app.dart / bootstrap.dart
├── core/           — API client, DI, theme, network
├── features/
│   ├── feed/       — Articles + Videos + Reels (main surfaces)
│   ├── chat/       — AI chat with article context
│   ├── ads/        — AdMob integration (LIVE — see ADS_ARCHITECTURE.md)
│   ├── notifications/ — FCM push notifications
│   ├── onboarding/ — First-run topic selection
│   └── settings/   — Preferences, diagnostics
└── routes/         — GoRouter route definitions
```

Each feature follows: `data/` → `domain/` → `presentation/` → `providers/`.  
Full detail: `docs/MOBILE_STRUCTURE.md`

---

## Key Docs Map

| What you need | Where to look |
|---|---|
| Full architecture + pipeline | `../blips-ai-news-backend/docs/ARCHITECTURE.md` |
| Mobile feature structure | `docs/MOBILE_STRUCTURE.md` |
| UI design system + typography | `docs/UI_SYSTEM.md` |
| Ads system (AdMob, live) | `docs/ADS_ARCHITECTURE.md` |
| Android signing setup | `android/app/signing.md` |
| Test commands + video tests | `AGENTS.md` |
| Testing guide | `docs/TESTING.md` |
| Production readiness | `docs/PRODUCTION_READINESS.md` |
| Play Store metadata | `store_metadata/play_store/listing.md` |
| Play Store assets | `store_metadata/play_store/` |
| Pre-launch checklist | `PRE_LAUNCH_CHECKLIST.md` |

---

## CI / GitHub Actions

All workflows live in `.github/workflows/` but are currently **disabled** (`.yml.disabled` extension) — intentionally, to avoid GitHub Actions billing costs. **Do not re-enable without confirming paid minutes are available.**

| Workflow | Trigger | What it does |
|---|---|---|
| `flutter_pr.yml` | PR on `*.dart` / `pubspec*` changes | `dart format` check, `flutter analyze`, critical interaction tests, unit/widget/golden tests |
| `flutter_integration.yml` | Push to `main` + daily 02:15 UTC | Full suite including macOS integration tests via `integration_test/app_smoke_test.dart` |

**Flutter version pin:** `3.41.6` (both workflows — updated May 2026)

Golden test failures are uploaded as artifacts (`golden-failures`, 14-day retention) when the workflows are active.

---

## Ads (AdMob) — LIVE

AdMob **is** integrated and live. AdMob App ID is in `AndroidManifest.xml` and `Info.plist`.  
The `ADS_ARCHITECTURE.md` doc describes the full ad injection pipeline.  
Ads are server-feature-flagged — `ADS_ENABLED` env var on backend controls whether ads appear.

---

## Firebase / Push Notifications

- `google-services.json` → `android/app/google-services.json` ✅
- `GoogleService-Info.plist` → `ios/Blips/` ✅
- FCM channel ID: `blips_news_updates`
- Topic subscriptions managed via backend `/api/v1/notifications/`

---

## Store Assets (Ready to Upload)

| Asset | Path | Spec |
|---|---|---|
| Play Store icon | `store_metadata/play_store/icon_512.png` | 512×512 RGB |
| Feature graphic | `store_metadata/play_store/feature_graphic.png` | 1024×500 RGB |
| Phone screenshots | `store_metadata/screenshots/play_store/` | 1320×2640 RGB (7 images) |

---

## Common Gotchas

- The iOS flavor is `Blips` — always pass `--flavor Blips` for iOS release builds.
- Android release build falls back to debug signing if `android/key.properties` is missing. This is intentional for CI — create `key.properties` locally to get a properly signed build.
- `flutter analyze` produces many info/warning-level issues that are acceptable — use `--no-fatal-infos --no-fatal-warnings` flags.
- Video pooling uses 5 pre-created players. Avoid creating `YoutubePlayerController` instances outside the pool.
