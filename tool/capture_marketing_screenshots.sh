#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SITE_DIR="${BLIPS_SITE_DIR:-$ROOT_DIR/../blips-site}"
RAW_OUTPUT_DIR="${BLIPS_SCREENSHOT_OUTPUT_DIR:-$ROOT_DIR/build/marketing_screenshots/raw}"
RESIZED_OUTPUT_DIR="${BLIPS_SCREENSHOT_RESIZED_DIR:-$ROOT_DIR/build/marketing_screenshots/resized}"
APP_BUNDLE_ID="${BLIPS_IOS_BUNDLE_ID:-com.blips.blipsMobile}"
REQUESTED_DEVICE_NAME="${1:-${BLIPS_SCREENSHOT_DEVICE_NAME:-}}"

resolve_flutter_bin() {
  if [[ -n "${FLUTTER_BIN:-}" && -x "${FLUTTER_BIN}" ]]; then
    echo "${FLUTTER_BIN}"
    return
  fi
  if command -v flutter >/dev/null 2>&1; then
    command -v flutter
    return
  fi
  if [[ -x "/opt/homebrew/bin/flutter" ]]; then
    echo "/opt/homebrew/bin/flutter"
    return
  fi

  local cask_flutter
  cask_flutter="$(find /opt/homebrew/Caskroom/flutter -path '*/flutter/bin/flutter' -type f 2>/dev/null | tail -1 || true)"
  if [[ -n "${cask_flutter}" && -x "${cask_flutter}" ]]; then
    echo "${cask_flutter}"
    return
  fi

  echo "Unable to locate flutter. Set FLUTTER_BIN to the SDK binary." >&2
  exit 1
}

resolve_simulator() {
  xcrun simctl list devices available -j | python3 -c '
import json
import sys

requested = sys.argv[1].strip()
preferred_names = [
    "iPhone 17 Pro",
    "iPhone 17 Pro Max",
    "iPhone 16 Pro",
    "iPhone 16 Pro Max",
    "iPhone 15 Pro",
    "iPhone 15 Pro Max",
]

data = json.load(sys.stdin)
devices = []
for runtime_devices in data.get("devices", {}).values():
    for device in runtime_devices:
        if not device.get("isAvailable"):
            continue
        name = device.get("name", "")
        if "iPhone" not in name:
            continue
        devices.append(device)

if requested:
    for device in devices:
        if device["name"] == requested:
            print("{}\t{}".format(device["name"], device["udid"]))
            raise SystemExit(0)
    raise SystemExit(f"Simulator not found: {requested}")

for preferred in preferred_names:
    for device in devices:
        if device["name"] == preferred:
            print("{}\t{}".format(device["name"], device["udid"]))
            raise SystemExit(0)

if devices:
    device = devices[0]
    print("{}\t{}".format(device["name"], device["udid"]))
    raise SystemExit(0)

raise SystemExit("No available iPhone simulators found.")
' "${REQUESTED_DEVICE_NAME}"
}

apply_status_bar_override() {
  xcrun simctl status_bar "${DEVICE_ID}" override \
    --time 9:41 \
    --dataNetwork wifi \
    --wifiBars 3 \
    --batteryState charged \
    --batteryLevel 100 >/dev/null 2>&1 || true
}

clear_status_bar_override() {
  xcrun simctl status_bar "${DEVICE_ID}" clear >/dev/null 2>&1 || true
}

copy_site_asset() {
  local name="$1"
  local source_file="${RAW_OUTPUT_DIR}/screenshot-${name}.png"
  local resized_file="${RESIZED_OUTPUT_DIR}/screenshot-${name}.png"
  local destination_file="${SITE_DIR}/assets/screenshot-${name}.png"

  if [[ ! -f "${source_file}" ]]; then
    echo "Expected screenshot missing: ${source_file}" >&2
    exit 1
  fi

  cp "${source_file}" "${resized_file}"
  sips -Z 2532 "${resized_file}" >/dev/null
  cp "${resized_file}" "${destination_file}"
}

FLUTTER_BIN="$(resolve_flutter_bin)"
SIMULATOR_INFO="$(resolve_simulator)"
DEVICE_NAME="${SIMULATOR_INFO%%$'\t'*}"
DEVICE_ID="${SIMULATOR_INFO##*$'\t'}"

echo "Using Flutter: ${FLUTTER_BIN}"
echo "Using simulator: ${DEVICE_NAME} (${DEVICE_ID})"

mkdir -p "${RAW_OUTPUT_DIR}" "${RESIZED_OUTPUT_DIR}"
rm -f "${RAW_OUTPUT_DIR}"/*.png(N) "${RESIZED_OUTPUT_DIR}"/*.png(N)

trap clear_status_bar_override EXIT

xcrun simctl boot "${DEVICE_ID}" >/dev/null 2>&1 || true
open -a Simulator --args -CurrentDeviceUDID "${DEVICE_ID}"
xcrun simctl bootstatus "${DEVICE_ID}" -b
apply_status_bar_override
xcrun simctl uninstall "${DEVICE_ID}" "${APP_BUNDLE_ID}" >/dev/null 2>&1 || true

cd "${ROOT_DIR}"
"${FLUTTER_BIN}" pub get
BLIPS_SCREENSHOT_OUTPUT_DIR="${RAW_OUTPUT_DIR}" \
  "${FLUTTER_BIN}" drive \
    --flavor blips \
    --driver=test_driver/marketing_screenshots_driver.dart \
    --target=integration_test/marketing_screenshots_test.dart \
    -d "${DEVICE_ID}"

copy_site_asset "feed"
copy_site_asset "videos"
copy_site_asset "reels"

echo "Updated site screenshots:"
sips -g pixelWidth -g pixelHeight \
  "${SITE_DIR}/assets/screenshot-feed.png" \
  "${SITE_DIR}/assets/screenshot-videos.png" \
  "${SITE_DIR}/assets/screenshot-reels.png"
