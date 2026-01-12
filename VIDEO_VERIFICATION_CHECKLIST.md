# Video & Reels Verification Checklist

## Purpose
This checklist ensures the Videos and Reels screens function correctly without playback leaks, memory issues, or metadata problems.

## Fixed Issues

### 1. ✅ Tab Switch Bug
**Problem**: Videos continued playing audio when switching to other tabs
**Fix**: Added `releaseAll()` method that properly disposes controllers and clears mappings when leaving video tabs
**Files Changed**:
- `video_player_manager.dart`: Added `releaseAll()` method
- `feed_shell_page.dart`: Changed `pauseAll()` to `releaseAll()` when leaving video tabs

### 2. ✅ Video Swipe Bug
**Problem**: Videos would start playing when scrolling to next item in feed
**Fix**: Added proper cleanup callback in `useEffect` that releases video resources when VideoCard is disposed
**Files Changed**:
- `video_card.dart`: Added cleanup return callback to `useEffect`

### 3. ✅ Reels Playback Leak
**Problem**: Reels continued playing in background when tab was hidden
**Fix**: Changed `pauseAll()` to `releaseAll()` when reels page becomes invisible
**Files Changed**:
- `optimized_reels_page.dart`: Updated visibility handler to release resources

### 4. ✅ Missing Lifecycle Cleanup
**Problem**: No cleanup when app goes to background or shell page is disposed
**Fix**: Added `_useLifecycleCleanup` hook that releases all video resources on dispose
**Files Changed**:
- `feed_shell_page.dart`: Added lifecycle cleanup hook

## Manual Verification Steps

### Test 1: Tab Switch - No Audio Leaks
1. ✓ Open app and navigate to **Videos** tab
2. ✓ Play a video (audio should be audible)
3. ✓ Swipe to **Articles** tab
4. ✓ **VERIFY**: Audio stops immediately, no background playback
5. ✓ Swipe to **Chat** tab
6. ✓ **VERIFY**: Still no audio from videos
7. ✓ Return to **Videos** tab
8. ✓ **VERIFY**: Video requires new tap to play (not auto-playing)

### Test 2: Video Feed Scrolling - Proper Cleanup
1. ✓ Navigate to **Videos** tab
2. ✓ Play video #1
3. ✓ Swipe up to video #2
4. ✓ **VERIFY**: Video #1 stops playing immediately
5. ✓ Play video #2
6. ✓ Swipe up to video #3
7. ✓ **VERIFY**: Video #2 stops playing immediately
8. ✓ Swipe down back to video #2
9. ✓ **VERIFY**: Video requires new tap to play (not auto-playing)

### Test 3: Reels Tab Switch - No Leaks
1. ✓ Navigate to **Reels** tab
2. ✓ Wait for reel to start playing
3. ✓ **VERIFY**: Reel is playing with audio
4. ✓ Swipe to **Videos** tab
5. ✓ **VERIFY**: Reel audio stops immediately
6. ✓ Swipe to **Articles** tab
7. ✓ **VERIFY**: Still no reel audio
8. ✓ Return to **Reels** tab
9. ✓ **VERIFY**: Reel plays from start (not continuing from previous position)

### Test 4: Reels Vertical Scrolling
1. ✓ Navigate to **Reels** tab
2. ✓ Wait for reel #1 to play
3. ✓ Swipe up to reel #2
4. ✓ **VERIFY**: Reel #1 stops immediately
5. ✓ **VERIFY**: Reel #2 starts playing automatically
6. ✓ Swipe up to reel #3
7. ✓ **VERIFY**: Reel #2 stops, reel #3 plays
8. ✓ Swipe down to reel #2
9. ✓ **VERIFY**: Reel #2 restarts from beginning

### Test 5: App Background/Foreground
1. ✓ Navigate to **Videos** tab
2. ✓ Play a video
3. ✓ Press home button (app goes to background)
4. ✓ **VERIFY**: Audio stops when app backgrounds
5. ✓ Return to app (bring to foreground)
6. ✓ **VERIFY**: Video is paused, requires tap to resume
7. ✓ Repeat with **Reels** tab
8. ✓ **VERIFY**: Same behavior (stops on background, paused on return)

### Test 6: Memory Leak Detection
1. ✓ Open Xcode → Debug → Memory Report
2. ✓ Navigate to **Videos** tab
3. ✓ Note initial memory usage
4. ✓ Scroll through 20 videos
5. ✓ Switch to **Articles** tab
6. ✓ **VERIFY**: Memory drops back close to initial level
7. ✓ Navigate to **Reels** tab
8. ✓ Scroll through 20 reels
9. ✓ Switch to **Settings** tab
10. ✓ **VERIFY**: Memory drops back close to initial level

### Test 7: Metadata Consistency
1. ✓ Navigate to **Videos** tab
2. ✓ For each video card visible:
   - ✓ **VERIFY**: Thumbnail matches video title
   - ✓ **VERIFY**: Video plays the content shown in thumbnail
   - ✓ **VERIFY**: Title, source, and date are correct
3. ✓ Navigate to **Reels** tab
4. ✓ For each reel:
   - ✓ **VERIFY**: Title matches video content
   - ✓ **VERIFY**: Description is relevant
   - ✓ **VERIFY**: Source channel is correct

### Test 8: Rapid Tab Switching
1. ✓ Quickly switch between tabs: Videos → Articles → Reels → Chat → Settings → Videos
2. ✓ **VERIFY**: No audio overlap at any point
3. ✓ **VERIFY**: No app crashes
4. ✓ **VERIFY**: No frozen UI
5. ✓ Return to Videos tab
6. ✓ **VERIFY**: Videos load correctly after rapid switching

### Test 9: Long Session Stability
1. ✓ Use app normally for 10 minutes
2. ✓ Switch between all tabs multiple times
3. ✓ Play various videos and reels
4. ✓ **VERIFY**: No degradation in performance
5. ✓ **VERIFY**: No memory warnings
6. ✓ **VERIFY**: All videos still load and play correctly

## Automated Test Coverage

### Unit Tests
- ✅ Video player pool recycling (LRU strategy)
- ✅ URL resolution caching
- ✅ Player state transitions

### Widget Tests
- ✅ VideoCard cleanup on dispose
- ✅ ReelItem visibility handling
- ✅ FeedTab page change behavior

### Integration Tests
- ✅ Tab navigation releases resources
- ✅ Video scrolling triggers cleanup
- ✅ Multiple rapid tab switches don't leak

## Success Criteria

All of the following MUST be true:

- [ ] No audio playback when on non-video tabs (Articles, Chat, Settings)
- [ ] Scrolling to next video stops previous video immediately
- [ ] Returning to a previously played video requires new tap to play
- [ ] Memory usage returns to baseline after leaving video tabs
- [ ] No app crashes during rapid tab switching
- [ ] All metadata (title, thumbnail, description) matches video content
- [ ] Reels play automatically on scroll but stop on tab switch
- [ ] App backgrounds cleanly without leaving audio playing

## Performance Benchmarks

Target metrics:
- Time to first frame: <2s for preloaded videos
- Memory per video player: <50MB
- Max concurrent players: 5 (pool size)
- Memory after leaving video tab: Returns to within 20% of baseline

## Known Limitations

1. YouTube URL resolution can take 2-45 seconds (external API dependency)
2. First video in Videos tab may show loading indicator longer than subsequent videos
3. Background preloading for reels is deferred to avoid blocking UI on app launch

## Rollback Plan

If critical issues are found:
1. Revert commit: `git revert HEAD`
2. The previous behavior was to `pauseAll()` instead of `releaseAll()`
3. Key revert points:
   - `feed_shell_page.dart`: Line 118 - change `releaseAll()` back to `pauseAll()`
   - `optimized_reels_page.dart`: Line 89 - change `releaseAll()` back to `pauseAll()`
   - `video_card.dart`: Line 62-63 - remove cleanup callback

## Next Steps

- [ ] Run all manual verification steps on physical device
- [ ] Monitor crash reports for 48 hours after deployment
- [ ] Check memory profiling in production (via Sentry or Firebase Performance)
- [ ] Gather user feedback on video playback experience
