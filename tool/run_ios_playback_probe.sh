#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEVICE_NAME="${1:-iPhone 17 Pro}"

DEVICE_ID="$(
  xcrun simctl list devices available -j | python3 -c '
import json
import sys

target = sys.argv[1]
data = json.load(sys.stdin)
for runtime_devices in data.get("devices", {}).values():
    for device in runtime_devices:
        if device.get("isAvailable") and device.get("name") == target:
            print(device["udid"])
            raise SystemExit(0)
raise SystemExit(f"Simulator not found: {target}")
' "${DEVICE_NAME}"
)"

echo "Using simulator: ${DEVICE_NAME} (${DEVICE_ID})"
xcrun simctl boot "${DEVICE_ID}" >/dev/null 2>&1 || true
open -a Simulator --args -CurrentDeviceUDID "${DEVICE_ID}"
xcrun simctl bootstatus "${DEVICE_ID}" -b

cd "${ROOT_DIR}"

flutter test integration_test/video_playback_probe_test.dart \
  -d "${DEVICE_ID}" \
  --dart-define=BLIPS_DIAGNOSTICS=true \
  --dart-define=BLIPS_DIAGNOSTICS_CONSOLE=true \
  --dart-define=BLIPS_PLAYBACK_PROBE_ACCEPT_READY=true \
  --dart-define=BLIPS_DIAGNOSTICS_MAX_ENTRIES=400
