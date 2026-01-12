# Quick Start: Video & Reels Testing

## Run Tests
```bash
cd blips-mobile
flutter test test/video_lifecycle_test.dart
```

## Check for Errors
```bash
flutter analyze
```

## Run on Device
```bash
# iPhone Simulator
flutter run

# Physical Device
flutter run -d <device-id>
```

## Quick Manual Test Sequence

### 1. Tab Switch (30 seconds)
1. Open **Videos** tab → Play video
2. Switch to **Articles** → Audio should STOP
3. Switch to **Chat** → Still no audio
4. Back to **Videos** → Video should be reset (not playing)

**✅ PASS**: No audio when not on video tabs  
**❌ FAIL**: Audio continues in background

### 2. Video Scrolling (30 seconds)
1. **Videos** tab → Play video #1
2. Swipe up to video #2
3. Video #1 should STOP immediately
4. Swipe back down to video #1
5. Video should require tap to play again

**✅ PASS**: Previous video stops, doesn't auto-resume  
**❌ FAIL**: Multiple videos playing, or auto-resume

### 3. Reels Tab Switch (30 seconds)
1. Open **Reels** tab → Reel plays automatically
2. Switch to **Videos** tab → Reel should STOP
3. Back to **Reels** → New reel plays from start

**✅ PASS**: Reel stops on tab switch, fresh load on return  
**❌ FAIL**: Reel continues in background

### 4. Memory Check (iOS only)
1. Xcode → Debug → Memory Report
2. Navigate through 10 videos
3. Switch to **Articles** tab
4. Memory should drop significantly (within 20% of baseline)

**✅ PASS**: Memory returns to baseline  
**❌ FAIL**: Memory stays elevated

## Debug Logs to Look For

When switching away from video tabs:
```
Released all videos: user left video tabs (index=0)
Releasing all video resources...
All video resources released
```

When disposing VideoCard:
```
VideoCard disposed for <url>, releasing resources
```

When hiding Reels:
```
Reels tab hidden: released all video resources
```

When FeedShellPage disposes:
```
FeedShellPage disposing: cleaning up all video resources
```

## Common Issues

### Issue: "Audio still playing after tab switch"
**Check**: Look for "Released all videos" in logs  
**Fix**: Ensure `feed_shell_page.dart` calls `releaseAll()` not `pauseAll()`

### Issue: "Videos auto-play when scrolling back"
**Check**: Look for "VideoCard disposed" in logs  
**Fix**: Ensure `video_card.dart` has cleanup callback in `useEffect`

### Issue: "Memory keeps growing"
**Check**: Run memory profiler  
**Fix**: Verify `releaseAll()` is being called, check for retained controllers

### Issue: "Tests fail with YouTube errors"
**Note**: YouTube URL resolution errors are expected in tests with fake URLs  
**Check**: Tests should still pass (12/12) despite URL errors in output

## Files Changed
1. `lib/features/feed/providers/video/video_player_manager.dart` - Added `releaseAll()`
2. `lib/features/feed/presentation/feed_shell_page.dart` - Tab switch cleanup
3. `lib/features/feed/presentation/cards/video_card.dart` - Disposal cleanup
4. `lib/features/feed/presentation/reels/optimized_reels_page.dart` - Visibility cleanup

## Full Documentation
- `VIDEO_FIXES_SUMMARY.md` - Complete technical summary
- `VIDEO_VERIFICATION_CHECKLIST.md` - Detailed testing guide

## Emergency Rollback
```bash
git log --oneline -5
git revert <commit-hash>
```

Or manually:
1. `feed_shell_page.dart` line 118: `releaseAll()` → `pauseAll()`
2. `optimized_reels_page.dart` line 89: `releaseAll()` → `pauseAll()`
3. `video_card.dart` line 62-63: Remove cleanup callback

## Status
✅ All automated tests passing (12/12)  
✅ No compilation errors  
⏳ Awaiting manual device testing  
⏳ Awaiting production deployment
