# Ads Architecture

> **Status**: AdMob is **live and integrated** on both iOS and Android. Surfaces are server-feature-flagged — `ADS_ENABLED` on the backend controls whether ads are shown without requiring an app update.

## Guiding Principles

| Principle | Detail |
|-----------|--------|
| **AdMob integrated** | `google_mobile_ads` SDK is bundled. AdMob App ID is declared in `AndroidManifest.xml` (`blipsAdMobAppId`) and `Info.plist`. |
| **Server-controlled** | Every flag defaults to `false` / `0`. The app never shows ads unless the backend `GET /config` response enables them. |
| **Single-swap integration** | A real ad provider can be enabled later by replacing **one** Riverpod provider (`adProviderProvider`). |
| **Zero UX degradation** | When ads are disabled, the feed, performance, and UX are completely unaffected. |
| **"Sponsored" label** | Every ad surface carries a clear `Sponsored` badge (or custom label). |

---

## System Overview

```
┌────────────────┐       GET /config        ┌────────────────┐
│  Flutter App   │ ◄──────────────────────── │  FastAPI        │
│                │                           │  Backend        │
│  AdsConfig     │       GET /articles       │                │
│  AdCard        │ ◄──── (with injected ads) │  ad_mixer.py   │
│  BannerSlot    │                           │                │
│  EventService  │ ──── POST /events/click ► │  events.py     │
└────────────────┘       POST /events/imp    └────────────────┘
```

---

## Backend Components

### Feature Flags (`app/core/config.py`)

| Setting | Type | Default | Purpose |
|---------|------|---------|---------|
| `ADS_ENABLED` | bool | `False` | Global kill switch |
| `ADS_FEED_CARD_ENABLED` | bool | `False` | Feed card surface |
| `ADS_BANNER_ENABLED` | bool | `False` | Banner surface |
| `ADS_FEED_FREQUENCY` | int | `0` | Insert 1 ad every N items (0 = disabled) |
| `ADS_CANARY_PERCENT` | int | `0` | % of requests receiving ads (gradual rollout) |

### Config Endpoint (`GET /config`)

Returns the current flag state so the app always reflects the latest server-side decisions without an app update.

### Ad Mixer (`app/services/ad_mixer.py`)

`inject_ads(items, settings, fingerprint)` places placeholder ad entries into a feed response.

**Hard rules**:
- First item is always organic (never an ad)
- No back-to-back ads
- Frequency gating: 1 ad per N organic items
- Canary rollout: deterministic bucketing by device fingerprint

### Event Endpoints

| Route | Purpose |
|-------|---------|
| `POST /events/impression` | Record that an item was displayed |
| `POST /events/click` | Record that an item was tapped |

Both accept `item_type`, optional `content_id` / `ad_id`, `surface`, `timestamp`, and `session_id`.

---

## Flutter Components

### Domain Layer

| File | Purpose |
|------|---------|
| `features/ads/domain/ads_config.dart` | `AdsConfig` model with `showFeedAds` / `showBannerAds` getters |
| `features/ads/domain/ad_provider.dart` | `AdProvider` abstract interface + `NoOpAdProvider` |
| `features/ads/domain/ad_entry.dart` | Re-exports `AdFeedEntry` from `feed_entry.dart` |
| `features/feed/domain/feed_entry.dart` | `AdFeedEntry` extends sealed `FeedEntry` |

### Data Layer

| File | Purpose |
|------|---------|
| `features/ads/data/app_config_repository.dart` | Fetches `GET /config` and parses `AdsConfig` |
| `features/ads/data/event_service.dart` | Fire-and-forget impression/click HTTP calls |

### Providers (`features/ads/providers/ads_providers.dart`)

| Provider | Type | Notes |
|----------|------|-------|
| `appConfigRepositoryProvider` | `Provider<AppConfigRepository>` | Singleton repo |
| `adsConfigProvider` | `FutureProvider<AdsConfig>` | Cached; `ref.invalidate()` to refresh |
| `adProviderProvider` | `Provider<AdProvider>` | **Swap point** — currently `NoOpAdProvider` |
| `eventServiceProvider` | `Provider<EventService>` | Analytics tracker |

### Presentation

| Widget | Surface | Behavior when disabled |
|--------|---------|----------------------|
| `AdCard` | Full-screen feed card | Never instantiated |
| `BannerSlotWidget` | Bottom banner slot | Renders `SizedBox.shrink()` |

### Feed Integration

- `FeedRepository._parseMixedList()` detects `item_type: "AD"` and creates `AdFeedEntry` instances
- `FeedShellPage` uses ad-aware providers and conditionally renders `AdCard` for ad entries
- `FeedEntryMatch.when()` extension has an optional `ad` callback; throws `StateError` if unhandled

---

## How to Enable Ads Later

### Step 1 — Server flags

Set environment variables on the backend:

```env
ADS_ENABLED=true
ADS_FEED_CARD_ENABLED=true
ADS_FEED_FREQUENCY=5          # 1 ad per 5 organic items
ADS_CANARY_PERCENT=10         # 10% of users first
```

The app will pick up the changes on next `GET /config` — no app update needed.

### Step 2 — Real ad provider (optional)

Replace `NoOpAdProvider` in `ads_providers.dart`:

```dart
final adProviderProvider = Provider<AdProvider>((ref) {
  // return const NoOpAdProvider();       // ← old
  return RealAdProvider(apiKey: '...');   // ← new
});
```

Implement `AdProvider` to return real `AdFeedEntry` objects from your ad network. The rest of the app (card rendering, event tracking, badge labeling) works automatically.

### Step 3 — Banner SDK (optional)

For real banner ads, replace the placeholder `Container` in `BannerSlotWidget._buildSlot()` with a platform ad view (e.g., `google_mobile_ads` `BannerAd`).

---

## Test Coverage

### Backend (`tests/unit/test_ad_mixer.py`) — 19 tests

- Kill switch / default settings
- Frequency logic (0, negative, 1, N, fewer items)
- Hard rules (first item organic, no back-to-back)
- Placeholder field validation & determinism
- Canary bucketing (0%, 100%, deterministic, range)
- Edge cases (empty list, single item)

### Flutter Unit Tests — 14 tests

- `test/unit/ads_config_test.dart` — `AdsConfig` construction, `fromJson`, flag logic
- `test/unit/ad_feed_entry_test.dart` — `AdFeedEntry` construction, `fromJson`, `when()` dispatch

### Flutter Widget Tests — 14 tests

- `test/widget/ad_card_test.dart` — badge, sponsor, title, body, CTA button, fallback icon
- `test/widget/banner_slot_widget_test.dart` — disabled / loading / error → hidden; enabled → visible slot

---

## File Map

```
Backend (blips-ai-news-backend/src/backend/)
├── app/core/config.py               # Feature flags
├── app/schemas/ads.py               # Pydantic models
├── app/schemas/events.py            # Event payload models
├── app/services/ad_mixer.py         # Feed injection logic
├── app/api/routes/config.py         # GET /config
├── app/api/routes/events.py         # POST /events/*
├── app/api/routes/articles.py       # Ad injection on article feed
├── app/api/routes/videos.py         # Ad injection on video feed
└── tests/unit/test_ad_mixer.py      # 19 unit tests

Flutter (blips-mobile/)
├── lib/features/ads/
│   ├── domain/ads_config.dart
│   ├── domain/ad_provider.dart
│   ├── domain/ad_entry.dart
│   ├── data/app_config_repository.dart
│   ├── data/event_service.dart
│   ├── providers/ads_providers.dart
│   ├── presentation/ad_card.dart
│   └── presentation/banner_slot_widget.dart
├── lib/features/feed/
│   ├── domain/feed_entry.dart        # AdFeedEntry + when() extension
│   ├── data/feed_repository.dart     # _parseMixedList()
│   ├── data/mappers/feed_mappers.dart
│   ├── providers/feed_providers.dart  # Ad-aware providers
│   └── presentation/
│       ├── feed_shell_page.dart      # Tab builders with AdCard
│       └── tabs/feed_tab.dart        # containsVideos flag
└── test/
    ├── unit/ads_config_test.dart
    ├── unit/ad_feed_entry_test.dart
    ├── widget/ad_card_test.dart
    └── widget/banner_slot_widget_test.dart
```
