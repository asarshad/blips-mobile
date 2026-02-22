# Blips Mobile

A Flutter mobile app for consuming tech news and video content in a modern, engaging format.

## Features

- 📰 **Article Feed** - Swipeable card-based news feed with AI summaries
- 🎬 **Video Reels** - TikTok-style vertical video player for tech content
- 💬 **AI Chat** - Ask questions about articles using GPT
- 🔖 **Bookmarks** - Save articles and videos for later
- 🎨 **Dark/Light Theme** - System-aware theming
- 📱 **iOS Native** - Built with Capacitor for native iOS deployment
- 📢 **Ads-Ready** - Server-controlled ad scaffold (disabled by default, no SDK bundled). See [Ads Architecture](docs/ADS_ARCHITECTURE.md)

## Tech Stack

- **Framework**: Flutter 3.16+
- **State Management**: Riverpod
- **Video Playback**: video_player + youtube_explode_dart
- **HTTP Client**: Dio with interceptors
- **Local Storage**: SharedPreferences
- **Architecture**: Feature-first with clean architecture layers

## Project Structure

```
lib/
├── core/                    # Shared utilities, theme, constants
├── features/
│   ├── ads/                 # Ads scaffold (off by default, no SDK)
│   ├── feed/                # Article feed (cards, pagination)
│   ├── reels/               # Video player (pooling, preload)
│   ├── chat/                # AI conversation
│   ├── bookmarks/           # Saved content
│   └── settings/            # App preferences
├── shared/
│   ├── models/              # Domain models
│   ├── repositories/        # Data access layer
│   └── widgets/             # Reusable UI components
└── main.dart
```

## Getting Started

### Prerequisites

- Flutter 3.16+ (`flutter --version`)
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

Create `lib/config/env.dart`:

```dart
class Env {
  static const String apiBaseUrl = 'http://localhost:8000/api/v1';
}
```

For production, update to your deployed backend URL.

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
flutter test test/features/feed/feed_repository_test.dart
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

- **VideoPlayerManager**: Pool of 5 recycled video players for smooth scrolling
- **YouTubeUrlResolver**: Resolves YouTube URLs to direct streams with caching
- **FeedRepository**: Handles article/video fetching with pagination
- **EngagementTracker**: Tracks user interactions for ranking

## Documentation

- [Mobile Structure](docs/MOBILE_STRUCTURE.md) - Detailed architecture guide
- [Ads Architecture](docs/ADS_ARCHITECTURE.md) - Ads scaffold design & integration guide
- [Architecture](../blips-ai-news-backend/docs/ARCHITECTURE.md) - System overview
- [Development Guide](../blips-ai-news-backend/docs/DEVELOPMENT_GUIDE.md) - Full setup instructions

## Related Projects

- [blips-ai-news-backend](../blips-ai-news-backend) - FastAPI backend

## License

MIT
