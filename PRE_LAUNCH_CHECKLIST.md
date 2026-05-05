# Pre-Launch Checklist

Complete all items before submitting to app stores.

---

## Backend Readiness

### Infrastructure
- [ ] Render service on paid plan (prevents cold start sleep)
- [ ] PostgreSQL on paid plan (data persistence guaranteed)
- [ ] Redis on paid plan (rate limiting reliability)
- [ ] `RENDER_HEALTH_URL` secret set in GitHub repo
- [ ] Keepalive workflow running (check GitHub Actions)

### Configuration
- [ ] `ADMIN_API_KEY` set to strong random value
- [ ] `DEBUG_ROUTES_ENABLED=false` in production
- [ ] `DOCS_ENABLED=false` in production
- [ ] `CORS_ORIGINS` set to production domains only
- [ ] `LLM_DAILY_COST_CEILING` set appropriately
- [ ] `ALERT_ENABLED=true` and `ALERT_WEBHOOK_URL` configured

### Monitoring
- [ ] `/health` returns 200
- [ ] `/metrics` returns valid JSON (with admin key)
- [ ] `/api/v1/metrics/sources` shows active feeds
- [ ] Ingestion health check running (30min interval)
- [ ] Alerting tested (trigger a test alert)

### Data
- [ ] At least 50 articles ingested and scored
- [ ] At least 20 videos ingested
- [ ] AI summaries generated for >80% of articles
- [ ] No stale data (newest content < 2h old)

---

## iOS Submission

### App Store Connect
- [x] App registered in App Store Connect
- [ ] Bundle ID matches: check Xcode project
- [ ] App name: "Blips News"
- [ ] Subtitle: "AI-Curated Tech News"
- [ ] Description filled (see `store_metadata/app_store/description.md`)
- [ ] Keywords set
- [ ] Category: News / Entertainment

### Screenshots
- [ ] iPhone 6.7" screenshots (iPhone 15 Pro Max) — min 3
- [ ] iPhone 6.5" screenshots (iPhone 11 Pro Max) — min 3
- [ ] App icon 1024×1024 uploaded

### Privacy & Legal
- [ ] Privacy policy URL: https://blips.tech/privacy
- [ ] Support URL: https://blips.tech/support
- [ ] Data collection declarations completed
- [ ] No user accounts → declare accordingly
- [ ] App Tracking Transparency declaration matches shipped ad/SDK behavior

### Build
- [x] Version bumped in `pubspec.yaml` (currently 1.0.3+14)
- [ ] Run `flutter build ipa --release`
- [ ] Upload via Xcode Organizer or `xcrun altool`
- [ ] App Store build uploaded and processed

### Review
- [ ] Demo notes prepared (no login needed, explain AI features)
- [ ] Review information filled (contact name, email, phone)
- [ ] Submit for review

---

## Android Submission

### Play Console
- [x] App registered in Google Play Console
- [ ] Application ID: `com.blips.blips_mobile`
- [ ] App name: "Blips News"
- [ ] Short description filled (see `store_metadata/play_store/listing.md`)
- [ ] Full description filled
- [ ] Category: News & Magazines

### Signing
- [ ] Generate keystore: `keytool -genkey -v -keystore ~/blips-release.keystore -alias blips -keyalg RSA -keysize 2048 -validity 10000`
- [ ] Copy `android/key.properties.template` → `android/key.properties` and fill in paths/passwords
- [x] `build.gradle.kts` updated with release signing config (reads `key.properties` if present)
- [ ] Back up keystore somewhere safe (losing it = can never update the app)
- [ ] `google-services.json` present at `android/app/google-services.json` ✓

### Screenshots
- [x] Phone screenshots processed for Play Store → `store_metadata/screenshots/play_store/` (1320×2640, RGB)
- [x] Feature graphic 1024×500 → `store_metadata/play_store/feature_graphic.png`
- [ ] App icon auto-generated from Flutter config (already set via `mipmap-*` resources)

### Content Rating
- [ ] IARC questionnaire completed in Play Console
- [ ] Rating received (expected: Everyone)

### Privacy & Legal
- [ ] Privacy policy URL: https://blips.tech/privacy
- [ ] Data safety section completed in Play Console
- [ ] Declare: no user data collected, AdMob serves ads (advertising ID used)
- [ ] Ads declaration: app contains ads ✓

### Build
- [ ] Version bumped in `pubspec.yaml` if needed (currently 1.0.4+1)
- [ ] Run `flutter build appbundle --release`
- [ ] Upload AAB to internal testing track first
- [ ] Smoke test on a physical Android device from internal track
- [ ] Promote to production once stable

---

## Soft Launch

### Pre-Release Validation (iOS)
- [ ] App Store processing finished for the release build
- [ ] Final smoke test completed from the processed build

### Internal Testing (Android)
- [ ] Internal test track published
- [ ] Testers added via email/Google Group
- [ ] Opt-in URL shared with testers

### Feedback
- [ ] Feedback form created (Google Forms / Typeform)
- [ ] Link added to app settings or about screen
- [ ] Support email configured for `blips.tech`

### Monitoring (7-day checkpoint)
- [ ] Crash-free rate >99% (both platforms)
- [ ] No P1 incidents
- [ ] API response times <500ms p95
- [ ] Memory usage <300MB after extended use
- [ ] No ingestion stalls >2h
- [ ] Collect at least 10 feedback responses

---

## Go / No-Go Decision

All items must be checked:
- [ ] Backend stable for 7 days
- [ ] Crash-free rate >99%
- [ ] At least 10 beta tester feedback responses reviewed
- [ ] No blocking bugs reported
- [ ] Content pipeline running smoothly
- [ ] Escalation path documented (incident runbooks)
- [ ] Proceed to public release
