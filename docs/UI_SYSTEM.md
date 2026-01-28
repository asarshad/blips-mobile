# UI Design System

## Overview

This document describes the UI system architecture for achieving consistent, cross-platform rendering on iOS and Android.

## Key Decisions

### Text Scaling Policy

**Decision: Respect system scaling, but clamp for fixed-layout surfaces**

- The app respects system text scaling by default (accessibility)
- Feed cards use `MediaQuery.withClampedTextScaling(maxScaleFactor: 1.15)` to prevent layout overflow
- Badges/labels may use tighter clamping where layout is critical
- **Rationale**: Users who need larger text can still benefit, but we prevent catastrophic layout breaks

### Cross-Platform Font Rendering

**Decision: Do NOT use platform-specific scale hacks**

Previous approach (REMOVED):
```dart
// BAD - Don't do this!
static double get platformScale => Platform.isAndroid ? 0.91 : 1.0;
```

Current approach:
- Use consistent font sizes across platforms
- Use `TextHeightBehavior` for consistent line metrics
- Use explicit `height` on all TextStyles (1.35 for body)
- Let layout be flexible (Expanded, Flexible) to handle size differences

---

## Typography System

### Design Tokens

| Token | Base Size | Line Height | Usage |
|-------|-----------|-------------|-------|
| `displayLarge` | 32 | 1.2 | Hero headlines |
| `displayMedium` | 28 | 1.2 | Page titles |
| `headlineSmall` | 18 | 1.35 | Section headers |
| `titleLarge` | 16 | 1.35 | Card titles |
| `bodySmall` | 13 | 1.35 | Summaries |
| `labelSmall` | 11 | 1.35 | Timestamps |

### TextHeightBehavior

Applied globally via theme:
// CORRECT: Use viewPadding for persistent bottom navigation
final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

// The nav bar includes:
// 1. Content area (56dp standard height)
// 2. Bottom safe area padding (device-specific)
Container(
  padding: EdgeInsets.only(bottom: bottomPadding),
  child: SizedBox(
    height: AppSizes.bottomNavHeight, // 56
    child: /* nav content */,
  ),
)
```

### Device Coverage

This approach handles:
- ✅ iPhone with home indicator (Face ID models)
- ✅ iPhone without home indicator (Touch ID models)  
- ✅ Android gesture navigation
- ✅ Android 3-button navigation
- ✅ Android with/without display cutouts
- ✅ Tablets (iPad, Android tablets)
- ✅ Foldables (Samsung Fold)

---

## Implementation Checklist

- [x] Create `lib/core/theme/` directory
- [x] Implement `typography.dart` 
- [x] Implement `spacing.dart`
- [x] Implement `sizes.dart`
- [x] Implement `app_theme.dart`
- [x] Update `app.dart` to use new theme
- [x] Refactor `feed_card_frame.dart`
- [x] Refactor `chat_page.dart`
- [x] Refactor `settings_page.dart`
- [x] Refactor `nav_bar_icon.dart`
- [x] Refactor `feed_shell_page.dart` bottom nav
- [x] Add debug overlay for dev builds
- [x] Create golden test structure
