#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

DEVICE_ID="${1:-00008140-000C04563640801C}"
HOST_VMSERVICE_PORT="${HOST_VMSERVICE_PORT:-58231}"

flutter drive \
  --driver=test_driver/integration_driver.dart \
  --target=integration_test/video_playback_probe_test.dart \
  -d "$DEVICE_ID" \
  --host-vmservice-port="$HOST_VMSERVICE_PORT" \
  --dart-define=BLIPS_DIAGNOSTICS=true \
  --dart-define=BLIPS_DIAGNOSTICS_CONSOLE=true \
  --dart-define=BLIPS_DIAGNOSTICS_MAX_ENTRIES=400 \
  --test-arguments=test \
  --test-arguments=--reporter=expanded
