# Blips Mobile

A Flutter mobile app for consuming tech news and video content in a modern, engaging format.

## Features

- 📰 **Article Feed** - Swipeable card-based news feed with AI summaries
- 🎬 **Video Reels** - TikTok-style vertical video player for tech content
- 💬 **AI Chat** - Ask questions about articles using GPT
- 🎯 **Onboarding** - Interest selection and device-scoped personalization
- 🎨 **Dark/Light Theme** - System-aware theming
- 📱 **Native Mobile** - Flutter client for iOS and Android
- 📢 **Ads-Ready** - Google Mobile Ads with server-controlled placements. See [Ads Architecture](docs/ADS_ARCHITECTURE.md)

## Tech Stack

- **Framework**: Flutter
- **State Management**: Riverpod
- **Video Playback**: youtube_player_flutter with pooled controller management
- **HTTP Client**: Dio with interceptors
- **Local Storage**: SQLite + SharedPreferences
- **Architecture**: Feature-first with clean architecture layers

## Project Structure

```
lib/
├── core/                    # Config, database, network, services, theme
├── features/
│   ├── ads/                 # Ad placements and presentation
│   ├── chat/                # AI conversation
│   ├── feed/                # Articles, videos, reels, caching, playback
│   ├── onboarding/          # Interest selection and local persistence
│   └── settings/            # App preferences
├── routes/                  # App routing
└── main.dart
```

## Getting Started

### Prerequisites

- Flutter (`flutter --version`)
- Xcode 15+ (for iOS)
- CocoaPods (`pod --version`)

### Installation

```bash
# Clone the repository
git clone https://github.com/your-org/blips-mobile.git
cd blips-mobile

# Get dependencies
flutter pub get

# iOS: Install pods
cd ios && pod install && cd ..

# Run on simulator
flutter run
```

### Configuration

Runtime configuration is provided via `--dart-define`.

```bash
flutter run --dart-define=BLIPS_BACKEND_URL=http://localhost:8000/api/v1
```

Optional defines include `SENTRY_DSN` and the AdMob unit IDs described in [Ads Architecture](docs/ADS_ARCHITECTURE.md).

## Development

### Running the App

```bash
# List devices
flutter devices

# Run on specific device
flutter run -d "iPhone 16"

# Run with verbose logging
flutter run --verbose
```

### Hot Reload

- Press `r` for hot reload (UI changes)
- Press `R` for hot restart (state/provider changes)

### Testing

```bash
# Run unit tests
flutter test

# Run with coverage
flutter test --coverage

# Run specific test
flutter test test/unit/feed_repository_test.dart
```

### Linting

```bash
flutter analyze
```

## Architecture

The app follows a feature-first architecture:

```
Feature Module
├── data/           # DTOs, data sources
├── domain/         # Models, repository interfaces
├── application/    # Riverpod providers, state
└── presentation/   # Widgets, screens
```

### Key Components

- **YoutubePlayerManager**: Pooled iframe-based YouTube controller manager for feed and reels playback
- **FeedRepository**: Handles article/video fetching with pagination
- **FeedCache**: Persists feed responses in SQLite for fast local reads
- **DioBackendApiClient**: Typed backend client with interceptors and device-aware requests

## Documentation

- [Mobile Structure](docs/MOBILE_STRUCTURE.md) - Detailed architecture guide
- [Ads Architecture](docs/ADS_ARCHITECTURE.md) - Ads scaffold design & integration guide
- [Architecture](../blips-ai-news-backend/docs/ARCHITECTURE.md) - System overview
- [Development Guide](../blips-ai-news-backend/docs/DEVELOPMENT.md) - Full setup instructions

## Related Projects

- [blips-ai-news-backend](../blips-ai-news-backend) - FastAPI backend

## License

MIT
