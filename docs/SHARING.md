# Sharing Feature Documentation

## Overview

The Blips app implements a clean sharing system that generates 9:16 share card images **off-screen** rather than capturing the visible UI. This approach provides several benefits:

1. **Consistent output** - Share cards always look the same regardless of UI state
2. **No UI artifacts** - No buttons, scroll indicators, or loading states in shared images
3. **Correct aspect ratio** - Cards are always 9:16 for optimal social media display
4. **Fast rendering** - Off-screen rendering doesn't block the UI

## Architecture

```
lib/features/share/
├── share.dart              # Barrel export
├── share_models.dart       # Data models (ArticleShareData, VideoShareData, etc.)
├── share_card.dart         # Pure presentational 9:16 card widget
├── share_card_renderer.dart # Off-screen rendering engine
└── share_service.dart      # Public API (shareArticle, shareVideo, shareReel)
```

## Why We Don't Screenshot the UI

Screenshots of the visible UI have several problems:

1. **UI chrome included** - Buttons, icons, status bars captured
2. **Wrong aspect ratio** - Cards in-app are not 9:16
3. **State-dependent** - Loading spinners, errors visible
4. **Privacy issues** - May capture sensitive info
5. **Unpredictable** - Different on different devices

Instead, we render a dedicated `ShareCard` widget off-screen at a fixed 1080x1920 resolution.

## How Share Card Rendering Works

### 1. ShareCard Widget

`ShareCard` is a pure presentational widget designed ONLY for share images:

```dart
ShareCard(
  title: 'Article Title',
  summary: 'Summary text...',
  sourceName: 'TechCrunch',
  imageUrl: 'https://...',
  isVideo: false,
)
```

Layout (9:16 aspect ratio):
- Top 40%: Hero image (with gradient overlay)
- Middle: Source badge, title (2 lines max), summary (6 lines max)
- Bottom: Blips branding footer

### 2. ShareCardRenderer

The renderer creates an off-screen pipeline:

1. Wraps `ShareCard` in `RepaintBoundary`
2. Creates off-screen `RenderBox` container
3. Lays out at exact 1080x1920 pixels
4. Captures via `RenderRepaintBoundary.toImage()`
5. Exports as PNG to temp directory

Key code:
```dart
final image = await boundary.toImage(pixelRatio: 1.0);
final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
await File(path).writeAsBytes(byteData.buffer.asUint8List());
```

### 3. ShareService

Public API that coordinates everything:

```dart
// Article: image + URL
await ShareService.instance.shareArticle(ArticleShareData(...));

// Video: image + URL  
await ShareService.instance.shareVideo(VideoShareData(...));

// Reel: URL only (no image)
await ShareService.instance.shareReel(ReelShareData(...));
```

## Failure Modes & Fallbacks

The share system has multiple fallback layers:

### Level 1: Primary Rendering
- Off-screen `RepaintBoundary` capture
- If successful → share image + URL

### Level 2: Fallback Rendering
- Canvas-based text rendering
- Creates simpler card without network images
- If successful → share image + URL

### Level 3: Text-Only Fallback
- If all image generation fails
- Shares: `"Title\n\nURL"`
- Always works

### Error Handling

```dart
try {
  final imagePath = await _renderer.renderArticleCard(data);
  if (imagePath != null) {
    return _shareWithImage(...);
  } else {
    return _shareTextOnly(...);  // Fallback
  }
} catch (e) {
  return _shareTextOnly(...);    // Final fallback
}
```

## Platform Considerations

### iOS
- `share_plus` handles iOS share sheet correctly
- Both image and text appear together
- Temp files cleaned up after sharing

### Android
- URI permissions handled by `share_plus`
- Image shared via content provider
- Text always included

## File Cleanup

Temporary share images are cleaned up:
- 10 seconds after share completes (per-share)
- Periodic cleanup of files older than 1 hour

## Manual QA Checklist

### Article Share
- [ ] Tap share on an article card
- [ ] Share sheet opens
- [ ] Image shows:
  - Article image at top
  - Title (max 2 lines)
  - Summary text
  - Source name badge
  - "Blips" branding at bottom
- [ ] NO buttons or UI chrome in image
- [ ] URL text is included in share
- [ ] Share completes without crash

### Video Share
- [ ] Tap share on a video card
- [ ] Share sheet opens
- [ ] Image shows:
  - Video thumbnail at top
  - Play icon overlay on thumbnail
  - Title (max 2 lines)
  - Summary text
  - Channel name badge
  - "Blips" branding at bottom
- [ ] NO buttons or UI chrome in image
- [ ] Video URL text is included
- [ ] Share completes without crash

### Reel Share
- [ ] Tap share on a reel
- [ ] Share sheet opens
- [ ] NO image attached (text only)
- [ ] URL text is present
- [ ] Share completes without crash

### Edge Cases
- [ ] Share article with very long title (truncates)
- [ ] Share article with missing image (fallback shown)
- [ ] Share while video is playing (correct item shared)
- [ ] Rapid swipe then share (correct item shared)
- [ ] Share while offline (graceful failure)
- [ ] Double-tap share button (only one share sheet)

### Performance
- [ ] Share doesn't freeze UI
- [ ] Image generates in < 2 seconds
- [ ] Temp files cleaned up after sharing

## Troubleshooting

### "Share image is blank"
- Check network connectivity for image loading
- Verify image URLs are valid
- Fallback rendering should kick in

### "Share sheet doesn't open"
- Check `share_plus` package version
- Verify platform permissions
- Check debug console for errors

### "Wrong item shared after swiping"
- Verify card data is bound correctly
- Check that share captures current entry, not stale state

## Dependencies

- `share_plus: ^12.0.1` - Native share sheet
- `path_provider: ^2.1.5` - Temp directory access
- `path: ^1.9.0` - File path handling
