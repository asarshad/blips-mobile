#!/bin/zsh
set -euo pipefail

# Review-only screenshot capture across multiple devices and content variants.
# Unlike capture_marketing_screenshots.sh, this script does NOT copy any output
# to blips-site/assets — it's purely for in-house layout review.
#
# Usage:
#   tool/capture_review_screenshots.sh                # all devices, both variants
#   tool/capture_review_screenshots.sh DEVICE         # one device, both variants
#   tool/capture_review_screenshots.sh DEVICE VARIANT # one device, one variant
#
# Output:
#   build/marketing_screenshots/review/<device-slug>-<variant>/screenshot-*.png

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_BUNDLE_ID="${BLIPS_IOS_BUNDLE_ID:-com.blips.blipsMobile}"
REVIEW_ROOT="${ROOT_DIR}/build/marketing_screenshots/review"

DEFAULT_DEVICES=(
  "iPhone SE (3rd generation)"
  "iPhone 17 Pro"
  "iPhone 17 Pro Max"
)
DEFAULT_VARIANTS=(standard maxlength)

SELECTED_DEVICE="${1:-}"
SELECTED_VARIANT="${2:-}"

if [[ -n "${SELECTED_DEVICE}" ]]; then
  DEVICES=("${SELECTED_DEVICE}")
else
  DEVICES=("${DEFAULT_DEVICES[@]}")
fi

if [[ -n "${SELECTED_VARIANT}" ]]; then
  VARIANTS=("${SELECTED_VARIANT}")
else
  VARIANTS=("${DEFAULT_VARIANTS[@]}")
fi

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

resolve_device_id() {
  local name="$1"
  xcrun simctl list devices available -j | python3 -c '
import json, sys
target = sys.argv[1].strip()
data = json.load(sys.stdin)
for runtime_devices in data.get("devices", {}).values():
    for device in runtime_devices:
        if not device.get("isAvailable"):
            continue
        if device.get("name") == target:
            print(device["udid"])
            sys.exit(0)
sys.exit(f"Simulator not found: {target}")
' "${name}"
}

device_slug() {
  local name="$1"
  echo "${name}" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/-+/-/g; s/^-|-$//g'
}

apply_status_bar_override() {
  local device_id="$1"
  xcrun simctl status_bar "${device_id}" override \
    --time 9:41 \
    --dataNetwork wifi \
    --wifiBars 3 \
    --batteryState charged \
    --batteryLevel 100 >/dev/null 2>&1 || true
}

clear_status_bar_override() {
  local device_id="$1"
  xcrun simctl status_bar "${device_id}" clear >/dev/null 2>&1 || true
}

FLUTTER_BIN="$(resolve_flutter_bin)"
echo "Using Flutter: ${FLUTTER_BIN}"
cd "${ROOT_DIR}"
"${FLUTTER_BIN}" pub get

mkdir -p "${REVIEW_ROOT}"

for DEVICE_NAME in "${DEVICES[@]}"; do
  DEVICE_ID="$(resolve_device_id "${DEVICE_NAME}")"
  SLUG="$(device_slug "${DEVICE_NAME}")"
  echo ""
  echo "============================================================"
  echo "Device: ${DEVICE_NAME} (${DEVICE_ID})"
  echo "============================================================"

  xcrun simctl boot "${DEVICE_ID}" >/dev/null 2>&1 || true
  open -a Simulator --args -CurrentDeviceUDID "${DEVICE_ID}"
  xcrun simctl bootstatus "${DEVICE_ID}" -b
  apply_status_bar_override "${DEVICE_ID}"

  for VARIANT in "${VARIANTS[@]}"; do
    OUTPUT_DIR="${REVIEW_ROOT}/${SLUG}-${VARIANT}"
    mkdir -p "${OUTPUT_DIR}"
    rm -f "${OUTPUT_DIR}"/*.png(N)

    case "${VARIANT}" in
      maxlength) DART_DEFINE="--dart-define=BLIPS_MAX_LENGTH=true" ;;
      standard)  DART_DEFINE="--dart-define=BLIPS_MAX_LENGTH=false" ;;
      *) echo "Unknown variant: ${VARIANT}" >&2; exit 1 ;;
    esac

    echo ""
    echo "  >>> Variant: ${VARIANT}  ->  ${OUTPUT_DIR}"
    xcrun simctl uninstall "${DEVICE_ID}" "${APP_BUNDLE_ID}" >/dev/null 2>&1 || true

    BLIPS_SCREENSHOT_OUTPUT_DIR="${OUTPUT_DIR}" \
      "${FLUTTER_BIN}" drive \
        --flavor blips \
        ${DART_DEFINE} \
        --driver=test_driver/marketing_screenshots_driver.dart \
        --target=integration_test/marketing_screenshots_test.dart \
        -d "${DEVICE_ID}"
  done

  clear_status_bar_override "${DEVICE_ID}"
done

echo ""
echo "Review screenshots written under: ${REVIEW_ROOT}"
ls -1 "${REVIEW_ROOT}"
