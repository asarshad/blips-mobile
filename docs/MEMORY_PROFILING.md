# Memory Profiling Guide

This document covers memory profiling techniques and best practices for the Blips mobile app.

## Overview

Memory management is critical for a smooth user experience, especially when:
- Scrolling through reels with embedded video players
- Loading high-resolution images in article cards
- Managing multiple tabs with cached content

## Memory Targets

| Scenario | Target | Maximum |
|----------|--------|---------|
| Fresh app launch | < 100MB | 150MB |
| After 50 article scrolls | < 180MB | 220MB |
| After 100 reel scrolls | < 250MB | 300MB |
| Background (10 min) | < 80MB | 120MB |

## Profiling Tools

### 1. Flutter DevTools

```bash
# Start app in profile mode
flutter run --profile

# Open DevTools
flutter pub global run devtools
```

Navigate to the **Memory** tab to:
- Monitor real-time heap usage
- Take heap snapshots
- Track allocations
- Identify memory leaks

### 2. Xcode Instruments (iOS)

1. Build profile archive: `flutter build ios --profile`
2. Open Xcode → Product → Profile
3. Select **Leaks** or **Allocations** template
4. Run and analyze

### 3. Android Studio Profiler

1. Run app: `flutter run --profile`
2. View → Tool Windows → Profiler
3. Select **Memory** section
4. Use heap dump and allocation tracking

## Key Areas to Monitor

### Video Player Pool

Location: `lib/features/reels/presentation/video_player_pool.dart`

```dart
// Current pool configuration
static const int maxPoolSize = 3;  // Configurable via settings
```

**Why it matters:** Each `youtube_player_flutter` instance holds:
- WebView instance (~15-20MB)
- Video frame buffer (~5-10MB per frame)
- JavaScript engine state

**Best practices:**
- Pool size of 3 is optimal for most devices
- Dispose players when leaving reels tab
- Re-use players instead of creating new ones

### Image Caching

Location: `lib/core/widgets/cached_network_image.dart`

```dart
// Memory cache bounds
final _imageCache = ImageCache()
  ..maximumSize = 100       // Max images in memory
  ..maximumSizeBytes = 50 * 1024 * 1024;  // 50MB max
```

**Best practices:**
- Use `CachedNetworkImage` for all network images
- Specify `memCacheWidth`/`memCacheHeight` for large images
- Clear cache when memory pressure occurs

### Widget State

Location: `lib/features/feed/presentation/feed_shell_page.dart`

```dart
class _KeepAliveWrapper extends StatefulWidget {
  // Keeps tab content alive during switches
}
```

**Considerations:**
- `AutomaticKeepAliveClientMixin` preserves state but increases memory
- Consider disposing heavy resources when tab not visible
- Use `visibility_detector` package for smart resource management

## Memory Leak Detection

### Common Leak Patterns

1. **StreamSubscription not cancelled**
   ```dart
   // BAD
   initState() {
     _subscription = stream.listen(handler);
   }
   
   // GOOD
   dispose() {
     _subscription?.cancel();
     super.dispose();
   }
   ```

2. **Riverpod listener without autoDispose**
   ```dart
   // BAD - keeps provider alive forever
   final dataProvider = StateNotifierProvider<...>((ref) => ...);
   
   // GOOD - auto-disposes when unused
   final dataProvider = StateNotifierProvider.autoDispose<...>((ref) => ...);
   ```

3. **Timer not cancelled**
   ```dart
   // Always cancel timers in dispose()
   Timer? _refreshTimer;
   
   @override
   void dispose() {
     _refreshTimer?.cancel();
     super.dispose();
   }
   ```

## Memory Reduction Strategies

### 1. Lazy Loading

```dart
// Load images only when visible
ListView.builder(
  itemBuilder: (context, index) {
    return VisibilityDetector(
      key: Key('item-$index'),
      onVisibilityChanged: (info) {
        if (info.visibleFraction > 0) {
          // Start loading
        } else {
          // Cancel loading, dispose resources
        }
      },
      child: ArticleCard(item: items[index]),
    );
  },
)
```

### 2. Image Resolution Scaling

```dart
// Scale down based on display size
CachedNetworkImage(
  imageUrl: url,
  memCacheWidth: (MediaQuery.of(context).size.width * 
                  MediaQuery.of(context).devicePixelRatio).toInt(),
)
```

### 3. Reel Preloading Limits

```dart
// Only preload adjacent reels
class ReelViewport {
  static const preloadBefore = 1;
  static const preloadAfter = 1;
  
  void updateViewport(int currentIndex) {
    // Dispose distant players, preload nearby
  }
}
```

## Configuration Options

Add to `lib/core/config/memory_config.dart`:

```dart
class MemoryConfig {
  /// Maximum number of video player instances in pool
  static int playerPoolSize = 3;
  
  /// Maximum images in memory cache
  static int imageCacheMaxImages = 100;
  
  /// Maximum memory for image cache (bytes)
  static int imageCacheMaxBytes = 50 * 1024 * 1024;
  
  /// Number of reels to preload
  static int reelPreloadCount = 1;
  
  /// Enable memory logging
  static bool enableMemoryLogging = false;
}
```

## Testing Memory Behavior

### Automated Test

```dart
// integration_test/memory_test.dart
void main() {
  testWidgets('Memory stays under 300MB after 100 reel scrolls', (tester) async {
    app.main();
    await tester.pumpAndSettle();
    
    // Navigate to reels
    await tester.tap(find.byIcon(Icons.play_circle));
    await tester.pumpAndSettle();
    
    // Scroll through reels
    for (var i = 0; i < 100; i++) {
      await tester.fling(find.byType(PageView), Offset(0, -500), 1000);
      await tester.pumpAndSettle();
    }
    
    // Memory check would be done via DevTools or platform API
    // This test primarily verifies no crashes occur
  });
}
```

### Manual Test Checklist

1. [ ] Launch app, note initial memory
2. [ ] Scroll 50 articles, check memory
3. [ ] Switch to reels, scroll 50 reels
4. [ ] Switch to articles again, scroll 50 more
5. [ ] Final memory should be < 300MB
6. [ ] No visible lag or jank

## Logging

Enable memory logging for debugging:

```dart
// In debug mode
if (kDebugMode) {
  Timer.periodic(Duration(seconds: 30), (_) {
    developer.log(
      'Memory: ${ProcessInfo.currentRss ~/ (1024 * 1024)}MB',
      name: 'Memory',
    );
  });
}
```

## Related Files

- `lib/features/reels/presentation/reel_player_controller.dart`
- `lib/features/feed/presentation/article_card.dart`
- `lib/core/providers/image_cache_provider.dart`
- `lib/core/utils/memory_utils.dart` (to create)
