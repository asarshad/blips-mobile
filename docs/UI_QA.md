# UI Quality Assurance Checklist

## Device Test Matrix

### Required Devices for Manual QA

| Device Type | Screen Size | Examples | Priority |
|-------------|-------------|----------|----------|
| Small Phone | ~5.5" | iPhone SE, Pixel 4a | High |
| Standard Phone | ~6.1" | iPhone 14, Pixel 7 | High |
| Large Phone | ~6.7" | iPhone 14 Pro Max, Pixel 7 Pro | High |
| Foldable | Variable | Samsung Fold, Pixel Fold | Medium |
| Tablet | ~10"+ | iPad, Galaxy Tab | Medium |

### System Configuration Variants

- [ ] iOS with home indicator (Face ID models)
- [ ] iOS without home indicator (Touch ID models)
- [ ] Android gesture navigation
- [ ] Android 3-button navigation
- [ ] Android with display cutout
- [ ] Accessibility: Large text (1.5x scale)
- [ ] Accessibility: Extra large text (2.0x scale)

---

## Per-Screen Checklist

### Feed Tab (Articles)

- [ ] Card titles display without truncation (up to 3 lines)
- [ ] Card summaries display with proper ellipsis/fade
- [ ] Source name does not overlap with action icons
- [ ] Category badge text is legible
- [ ] Date and read time are visible in footer
- [ ] Chat button is fully visible and tappable
- [ ] Cards scroll smoothly
- [ ] Pull to refresh works
- [ ] No horizontal overflow on any card element

### Videos Tab

- [ ] Video thumbnails load and display correctly
- [ ] Play controls are accessible
- [ ] Video titles and metadata are legible
- [ ] Progress bar is visible above bottom nav
- [ ] Full-screen mode works correctly
- [ ] Landscape orientation handles safe areas

### Reels Tab

- [ ] Full-screen video playback works
- [ ] Title overlay is readable (contrast check)
- [ ] Source text is visible
- [ ] Action buttons (share, etc.) are tappable
- [ ] No UI clipped by system bars
- [ ] Swipe navigation works smoothly

### Chat Tab

- [ ] Chat list items display properly
- [ ] Thumbnails are correct size
- [ ] Chat titles truncate with ellipsis
- [ ] Last message preview shows 2 lines max
- [ ] Timestamps are visible
- [ ] Delete swipe gesture works
- [ ] Chat detail page keyboard handling

### Settings Tab

- [ ] All sections are visible
- [ ] Theme toggle works correctly
- [ ] Text is readable at all accessibility sizes
- [ ] Section headers are styled consistently
- [ ] Tap targets meet minimum size (44-48pt)

### Bottom Navigation

- [ ] All 5 icons are visible
- [ ] Icons do not overlap with system navigation
- [ ] Selected state is clearly indicated
- [ ] Tap targets are large enough
- [ ] Works with Android gesture navigation
- [ ] Works with Android 3-button navigation
- [ ] Works with iPhone home indicator
- [ ] Works on iPhone SE (no home indicator)

---

## Accessibility Checklist

### Text Scaling

- [ ] App remains usable at 1.5x text scale
- [ ] App remains usable at 2.0x text scale
- [ ] Critical UI elements (badges, nav) clamp scaling appropriately
- [ ] No text gets completely cut off
- [ ] Horizontal scroll doesn't appear unexpectedly

### Touch Targets

- [ ] All interactive elements ≥ 44pt (iOS) / 48dp (Android)
- [ ] Buttons have adequate padding
- [ ] List items are easy to tap

### Color Contrast

- [ ] Text meets WCAG AA contrast ratios
- [ ] Icons are distinguishable from backgrounds
- [ ] Dark mode maintains contrast

---

## Automated Tests

### Golden Tests (Screenshot Tests)

Run golden tests:
```bash
flutter test --update-goldens test/golden/
```

Verify golden tests:
```bash
flutter test test/golden/
```

### Test Configurations

| Configuration | Width | Height | Pixel Ratio | Text Scale |
|---------------|-------|--------|-------------|------------|
| small_phone | 375 | 667 | 2.0 | 1.0 |
| large_phone | 430 | 932 | 3.0 | 1.0 |
| tablet | 834 | 1194 | 2.0 | 1.0 |
| iphone_safe | 393 | 852 | 3.0 | 1.0 |
| android_gesture | 412 | 915 | 2.625 | 1.0 |
| large_text | 393 | 852 | 3.0 | 1.5 |

---

## Debug Overlay

In debug builds, tap the "DEBUG" badge in the top-right corner to see:

- Current screen dimensions
- Device pixel ratio
- Text scale factor
- viewPadding (system navigation insets)
- padding (safe area insets)
- viewInsets (keyboard height)

Use this to verify safe area handling is working correctly.

---

## Known Platform Differences

### Android vs iOS Text Rendering

Android's Roboto and iOS's SF Pro have different:
- x-heights (Android appears larger at same fontSize)
- Font weights (same weight looks different)
- Letter spacing defaults

**Solution**: Use Theme-driven TextStyles that look visually similar rather than pixel-identical.

### Safe Area Values

| Device | viewPadding.top | viewPadding.bottom |
|--------|-----------------|-------------------|
| iPhone 14 Pro | 59 | 34 |
| iPhone SE | 20 | 0 |
| Pixel 7 (gesture) | 24-50 | 20-48 |
| Pixel 7 (3-button) | 24-50 | 48 |
| Samsung Fold | varies | varies |

---

## Regression Prevention

Before releasing, verify:

1. [ ] No hardcoded fontSize values outside design system
2. [ ] No hardcoded padding/margin magic numbers
3. [ ] All new screens use AppSpacing and AppSizes
4. [ ] Bottom navigation works on target device matrix
5. [ ] Text scaling doesn't break layout
6. [ ] Dark mode renders correctly
