#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# Manual Android local-stack runner
#
# Usage:
#   local_stack/run_android_local.sh [device_id] [debug|profile|release]
#
# Defaults to the first connected Android emulator and debug mode.
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="$(cd "${SCRIPT_DIR}/../mobile" && pwd)"
COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.yml"

# shellcheck source=android_sdk.sh
source "${SCRIPT_DIR}/android_sdk.sh"

DEVICE_ARG="${1:-}"
BUILD_MODE="${2:-debug}"

case "$BUILD_MODE" in
    debug|profile|release) ;;
    *)
        echo "ERROR: Unknown build mode: ${BUILD_MODE}" >&2
        echo "Usage: $0 [device_id] [debug|profile|release]" >&2
        exit 2
        ;;
esac

if [[ "$BUILD_MODE" == "debug" ]]; then
    ANDROID_PACKAGE_ID="co.openvine.app.staging"
else
    ANDROID_PACKAGE_ID="co.openvine.app"
fi

if ! local_stack_has_running_container "$COMPOSE_FILE"; then
    echo "ERROR: Docker stack is not running. Start with: mise run local_up" >&2
    exit 1
fi

if ! command -v adb >/dev/null 2>&1; then
    echo "ERROR: 'adb' not on PATH and Android SDK not found." >&2
    echo "Set ANDROID_HOME or install the SDK at \$HOME/Android/Sdk (Linux) / \$HOME/Library/Android/sdk (macOS)." >&2
    exit 1
fi

if [[ -n "$DEVICE_ARG" ]]; then
    if [[ "$DEVICE_ARG" != emulator-* ]]; then
        echo "ERROR: ${DEVICE_ARG} is not an Android emulator." >&2
        echo "This local-stack command uses Android emulator host URLs. Start one with: mise run emulator" >&2
        exit 1
    fi

    DEVICE="$DEVICE_ARG"
else
    DEVICE="$(adb devices | awk 'NR > 1 && $1 ~ /^emulator-/ && $2 == "device" { print $1; exit }')"
fi

if [[ -z "$DEVICE" ]]; then
    echo "ERROR: No Android emulator connected. Start one with: mise run emulator" >&2
    exit 1
fi

clear_app_data() {
    local clear_output
    local path_output

    if clear_output="$(adb -s "$DEVICE" shell pm clear "$ANDROID_PACKAGE_ID" 2>&1)"; then
        return 0
    fi

    if path_output="$(adb -s "$DEVICE" shell pm path "$ANDROID_PACKAGE_ID" 2>&1)"; then
        echo "ERROR: Failed to clear persisted app data for ${ANDROID_PACKAGE_ID}" >&2
        printf '%s\n' "$clear_output" >&2
        exit 1
    fi

    if [[ -z "$path_output" ]]; then
        echo "No existing app install found for ${ANDROID_PACKAGE_ID}; continuing with a clean first run" >&2
        return 0
    fi

    echo "ERROR: Failed to inspect installed package ${ANDROID_PACKAGE_ID}" >&2
    printf '%s\n' "$path_output" >&2
    exit 1
}

echo "Running Divine against the local stack on Android emulator: ${DEVICE}" >&2
echo "Clearing persisted app data for ${ANDROID_PACKAGE_ID} so LOCAL is deterministic" >&2
clear_app_data

cd "$MOBILE_DIR"
exec flutter run \
    -d "$DEVICE" \
    --"$BUILD_MODE" \
    --dart-define=DEFAULT_ENV=LOCAL
