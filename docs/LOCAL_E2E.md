# Local End-to-End Mobile Testing Guide

This document describes how to run the Flutter mobile app against a local backend for end-to-end testing.

## Prerequisites

- Flutter 3.19+ installed and configured
- Xcode (for iOS) or Android Studio (for Android)
- The backend running locally (see [Backend LOCAL_E2E.md](../../blips-ai-news-backend/src/backend/docs/LOCAL_E2E.md))
- A physical device or simulator

## Quick Start

### Step 1: Start the Local Backend

From the backend directory:

```bash
cd ../blips-ai-news-backend/src/backend
./scripts/e2e_local.sh
```

This starts the backend on `http://localhost:8001` with:
- FakeLLM (no real API calls)
- Seeded test content
- Isolated test database

### Step 2: Run the Flutter App with Local Backend

```bash
# For iOS Simulator (localhost works)
flutter run --dart-define=BLIPS_BACKEND_URL=http://localhost:8001/api/v1

# For Android Emulator (use special IP for host)
flutter run --dart-define=BLIPS_BACKEND_URL=http://10.0.2.2:8001/api/v1

# For physical device (use your machine's local IP)
flutter run --dart-define=BLIPS_BACKEND_URL=http://192.168.1.XXX:8001/api/v1
```

The app will now connect to your local backend instead of the production API.

## Testing Modes

### 1. Manual E2E Verification

Run the app and manually verify:

- [ ] Feed loads with articles and videos
- [ ] Tapping content cards opens detail view
- [ ] Chat bubbles appear when tapping the ⚡ button
- [ ] Tapping a bubble navigates to chat with the question
- [ ] Chat responses work (uses FakeLLM on backend)

### 2. Widget Tests (No Backend Required)

```bash
flutter test test/widget/
```

Widget tests use mocked data and don't require a running backend.

### 3. Golden Tests (No Backend Required)

```bash
# Run golden tests
flutter test test/golden/

# Update golden files after intentional UI changes
flutter test test/golden/ --update-goldens
```

Golden tests compare screenshots against baseline images to detect visual regressions.

### 4. Integration Tests (Backend Required)

```bash
# Start the local backend first, then:
flutter test integration_test/ --dart-define=BLIPS_BACKEND_URL=http://localhost:8001/api/v1
```

## Configuration Details

### Backend URL Override

The app reads the backend URL from a compile-time constant:

```dart
// lib/core/config/app_config.dart
static const backendBaseUrl = String.fromEnvironment(
  'BLIPS_BACKEND_URL',
  defaultValue: 'https://blips-api-dev.onrender.com/api/v1',
);
```

Override it with `--dart-define=BLIPS_BACKEND_URL=<your-url>`.

### Network Access

For Android, ensure your app has internet permission in `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

For iOS, local network access should work by default in debug mode.

## Troubleshooting

### Connection Refused

- **iOS Simulator**: Use `http://localhost:8001`
- **Android Emulator**: Use `http://10.0.2.2:8001` (maps to host localhost)
- **Physical Device**: Use your machine's local IP (check with `ifconfig` or `ipconfig`)

### Backend Not Starting

Check the backend logs:
```bash
cd ../blips-ai-news-backend/src/backend
docker-compose -f docker-compose.test.yml logs
```

### Content Not Loading

1. Verify backend is healthy: `curl http://localhost:8001/api/v1/health`
2. Check for seeded content: `curl http://localhost:8001/api/v1/feed`
3. Verify the `--dart-define` is correct

### FakeLLM Not Working

Ensure the backend is started with `LLM_PROVIDER=fake`:
```bash
export LLM_PROVIDER=fake
uvicorn app.main:app --reload --port 8001
```

## Test Data

The local E2E script seeds the following test content:

| ID | Type    | Title                   |
|----|---------|-------------------------|
| 1  | Article | "Test AI Breakthrough"  |
| 2  | Video   | "Tech Trends 2024"      |

Use these IDs when testing specific features.

## CI Integration

See `.github/workflows/flutter_ci.yml` for automated testing in CI:

- **flutter analyze**: Static analysis
- **flutter test**: Unit + widget tests
- **Golden tests**: Visual regression (with failure artifacts)

Integration tests requiring a real backend run separately in nightly jobs.
