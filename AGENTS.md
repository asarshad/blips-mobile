# Agent Notes

## Verification Gate

- Do not say a mobile bug is fixed until the full automated Flutter test suite has passed locally.
- Do not deploy/install a build to a physical phone until the full automated Flutter test suite has passed locally.
- The default full-suite command is `flutter test` from the `blips-mobile` repo root.
- Also run `flutter analyze --no-fatal-infos --no-fatal-warnings` before claiming a fix is complete.
- If the full suite cannot be run, is blocked, or has any failing tests, say that clearly and do not call the work fixed.
- If a deploy is still requested while tests are failing, explicitly label it as an unverified build.

## Video Playback Changes

- For changes touching videos, reels, YouTube playback, `YoutubePlayerManager`, `FeedTab`, or feed/reels lifecycle behavior, run the playback-focused tests in addition to the full suite:

```bash
flutter test test/widget/video_card_test.dart test/widget/reel_item_test.dart test/widget/feed_tab_test.dart test/unit/youtube_player_manager_playback_test.dart test/unit/playback_rearm_test.dart test/unit/reel_autoplay_recovery_test.dart test/unit/reel_playback_tap_action_test.dart
```

- If the issue is only reproducible on device, prefer the existing device probe after the full local suite passes:

```bash
flutter test integration_test/video_playback_probe_test.dart
```

## Phone Deployment

- Build/deploy only after the verification gate passes.
- For iOS phone installs, prefer the known reliable path when Flutter/Xcode reports the device as busy:

```bash
flutter build ios --release --flavor Blips
ios-deploy --id 00008140-000C04563640801C --bundle build/ios/iphoneos/Blips.app --timeout 60
```
