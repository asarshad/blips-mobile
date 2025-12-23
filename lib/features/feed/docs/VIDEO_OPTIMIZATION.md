# Optimized Video Playback System

This document describes the optimized video playback system designed for TikTok/Instagram Reels-style vertical video feeds with near-instant playback.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                   OptimizedReelsPage                    │
│  - PageView.builder with vertical scrolling            │
│  - Manages current index and visibility                │
│  - Triggers preloading on page change                  │
└─────────────────────────┬───────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│              OptimizedVideoPlayerManager                │
│  - Maintains pool of 5 reusable players                │
│  - Resolves YouTube URLs to direct streams             │
│  - Tracks performance metrics                          │
│  - Manages preloading and disposal                     │
└─────────────────────────┬───────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│                   PooledVideoPlayer                     │
│  - Wraps VideoPlayerController                         │
│  - Tracks state (idle/loading/ready/playing/paused)    │
│  - Can be recycled for different videos                │
└─────────────────────────┬───────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│              Native iOS Optimizations                   │
│  - AVAudioSession configured for video                 │
│  - Video pipeline pre-warming                          │
│  - Method channel for Dart communication               │
└─────────────────────────────────────────────────────────┘
```

## Key Components

### 1. OptimizedVideoPlayerManager (`optimized_video_provider.dart`)

The core of the optimization system. Key features:

- **Player Pooling**: Maintains 5 `PooledVideoPlayer` instances that are recycled
- **URL Resolution Caching**: Caches resolved YouTube stream URLs
- **Smart Preloading**: Preloads next 2 videos, releases videos 2+ behind
- **Performance Tracking**: Measures time-to-first-frame for each video

```dart
// Usage
final videoManager = ref.watch(optimizedVideoManagerProvider);

// Preload a video
await videoManager.preload(youtubeUrl);

// Play a video
await videoManager.playVideo(youtubeUrl);

// Pause
await videoManager.pauseVideo(youtubeUrl);
```

### 2. PooledVideoPlayer

Individual player wrapper with states:
- `idle` - Available for reuse
- `loading` - Resolving URL or initializing controller
- `ready` - Initialized, waiting to play
- `playing` - Currently playing
- `paused` - Paused but ready
- `error` - Error occurred

### 3. VideoPerformanceMetrics

Tracks timing for each video:
- `urlResolutionTime` - Time to resolve YouTube URL
- `controllerCreatedTime` - Time to create controller
- `initializedTime` - Time for controller to initialize
- `firstFrameTime` - Time when first frame renders
- `playingTime` - Time when playback starts

### 4. iOS Native Optimizations (`AppDelegate.swift`)

- **Audio Session**: Configured for `.playback` category with `.moviePlayback` mode
- **Video Pipeline Pre-warming**: Creates temporary AVPlayer at startup to load decoder
- **Method Channel**: Exposes native APIs to Dart

## Performance Targets

| Metric | Target | Current |
|--------|--------|---------|
| Time to First Frame | <200ms | Tracked via metrics |
| Preload Buffer | 5 seconds | Configurable |
| Pool Size | 5 players | Configurable |

## Migration Guide

### Option A: Replace ReelsPage entirely

```dart
// Before
import 'package:blips_mobile/features/feed/presentation/reels_page.dart';

// After
import 'package:blips_mobile/features/feed/presentation/optimized_reels_page.dart';

// In your router/navigation
OptimizedReelsPage(isVisible: true)
```

### Option B: Gradual migration (use both)

Keep both implementations and A/B test:

```dart
// Feature flag
const useOptimizedReels = true;

child: useOptimizedReels 
  ? const OptimizedReelsPage() 
  : const ReelsPage(),
```

### Provider Changes

The new system uses a different provider:

```dart
// Old
final videoManager = ref.watch(videoPlayerManagerProvider);

// New
final videoManager = ref.watch(optimizedVideoManagerProvider);
```

## Why video_player + youtube_explode_dart?

The previous implementation used `youtube_player_flutter` which embeds a WebView. This has performance limitations:

| Aspect | youtube_player_flutter | video_player + youtube_explode |
|--------|----------------------|-------------------------------|
| Rendering | WebView (slow) | Native AVPlayer/ExoPlayer |
| Control | Limited | Full control |
| Preloading | Difficult | Native support |
| Memory | Heavy (WebView per video) | Lightweight |
| First frame | ~500-800ms | Target <200ms |

## Troubleshooting

### Video doesn't play
1. Check if the YouTube URL is valid
2. Check console for `youtube_explode_dart` errors
3. Verify network connectivity

### Performance still slow
1. Check performance overlay (shown in debug mode)
2. Review `averageTimeToFirstFrame` metric
3. Consider reducing video quality in `_resolveYoutubeUrl()`

### Audio issues
1. Verify iOS audio session is configured
2. Check `AppDelegate.swift` for errors
3. Test with device not on silent mode

## Files Structure

```
lib/features/feed/
├── providers/
│   ├── optimized_video_provider.dart  # Main optimization logic
│   ├── ios_video_optimizations.dart   # iOS-specific utilities
│   └── video_player_provider.dart     # Original (can be removed)
├── presentation/
│   ├── optimized_reels_page.dart      # New optimized UI
│   └── reels_page.dart                # Original (can be removed)
└── docs/
    └── VIDEO_OPTIMIZATION.md          # This file

ios/Runner/
└── AppDelegate.swift                  # Native iOS optimizations
```

## Future Improvements

1. **Adaptive Quality**: Automatically adjust quality based on network conditions
2. **Prefetch on Wi-Fi**: More aggressive preloading when on Wi-Fi
3. **Background Preloading**: Continue preloading when app is backgrounded briefly
4. **Caching**: Cache resolved stream URLs and video data locally
5. **Analytics**: Send performance metrics to backend for monitoring
