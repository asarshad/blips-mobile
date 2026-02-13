# Screenshot Requirements

## App Store (iOS)

### Required Sizes
| Device | Size (portrait) | Required |
|--------|-----------------|----------|
| iPhone 6.7" (15 Pro Max) | 1290 × 2796 | Yes |
| iPhone 6.5" (11 Pro Max) | 1242 × 2688 | Yes |
| iPad Pro 12.9" | 2048 × 2732 | If iPad supported |

### Count
- Minimum: 3 screenshots per device
- Maximum: 10 screenshots per device
- Recommended: 5-6

### Suggested Screenshots
1. **Feed view** — Article cards with headlines and sources
2. **Article detail** — Clean reading experience
3. **Reels view** — Short-form video content
4. **AI Chat** — Conversation about an article
5. **Category filter** — Topic-based browsing
6. **Dark mode** — Show the dark theme

## Play Store (Android)

### Required Sizes
| Type | Size | Required |
|------|------|----------|
| Phone | 1080 × 1920 (min 320px, max 3840px) | Yes |
| 7" Tablet | 1200 × 1920 | Recommended |
| 10" Tablet | 1600 × 2560 | Recommended |

### Count  
- Minimum: 2 screenshots
- Maximum: 8 screenshots
- Recommended: 5-6

### Feature Graphic
- Size: 1024 × 500
- Required for Play Store listing

## Generating Screenshots

### Using Flutter Integration Tests
```bash
# Take screenshots during test run
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshot_test.dart \
  --dart-define=SCREENSHOTS=true
```

### Manual Process
1. Run app on target simulator/device
2. Navigate to each screen
3. Take screenshot (Cmd+S in Simulator, or device screenshot)
4. Add text overlays in Figma/Canva
5. Export at required sizes
