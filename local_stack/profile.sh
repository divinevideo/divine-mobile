#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# E2E Performance Profiler
# Captures docker + app logs during a test run, merges into sorted JSON lines.
#
# Usage:
#   local_stack/profile.sh [test_path]
#   local_stack/profile.sh integration_test/auth/session_expiry_test.dart
#   local_stack/profile.sh integration_test/auth/   (whole directory)
#
# Default: integration_test/auth/
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="$(cd "${SCRIPT_DIR}/../mobile" && pwd)"
COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.yml"
MERGE_SCRIPT="${SCRIPT_DIR}/merge_logs.py"
# Honour a relocated pub cache; $HOME/.pub-cache does not exist when
# PUB_CACHE points elsewhere. Same resolution as mobile/mise.toml.
PUB_CACHE_BIN="${PUB_CACHE:-$HOME/.pub-cache}/bin"

# shellcheck source=android_sdk.sh
source "${SCRIPT_DIR}/android_sdk.sh"
INVITE_SERVER_URL="$(android_emulator_invite_server_url)"

# --- Ensure DISPLAY is set for emulator (Hyprland/XWayland) ---
DISPLAY_TO_USE="$(detect_x11_display)"
if [[ -n "$DISPLAY_TO_USE" ]]; then
    export DISPLAY="$DISPLAY_TO_USE"
fi

TEST_PATH="${1:-integration_test/auth/}"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
REPORT_DIR="${MOBILE_DIR}/test_reports"
REPORT_FILE="${REPORT_DIR}/${TIMESTAMP}.jsonl"

TMPDIR="$(mktemp -d)"
DOCKER_LOG="${TMPDIR}/docker.log"
APP_LOG="${TMPDIR}/app.log"
LOGCAT_LOG="${TMPDIR}/logcat.log"

cleanup() {
    if [[ -n "${DOCKER_PID:-}" ]] && kill -0 "$DOCKER_PID" 2>/dev/null; then
        kill "$DOCKER_PID" 2>/dev/null || true
        wait "$DOCKER_PID" 2>/dev/null || true
    fi
    if [[ -n "${LOGCAT_PID:-}" ]] && kill -0 "$LOGCAT_PID" 2>/dev/null; then
        kill "$LOGCAT_PID" 2>/dev/null || true
        wait "$LOGCAT_PID" 2>/dev/null || true
    fi
    rm -rf "$TMPDIR"
}
trap cleanup EXIT

echo "=== E2E Performance Profiler ===" >&2
echo "Test path:  ${TEST_PATH}" >&2
echo "Report:     ${REPORT_FILE}" >&2
echo "" >&2

# --- Verify docker stack is running ---
if ! local_stack_has_running_container "$COMPOSE_FILE"; then
    echo "ERROR: Docker stack is not running. Start with: mise run local_up" >&2
    exit 1
fi

# --- Ensure the patrol CLI matches the patrol package ---
# patrol_cli enforces the pairing itself and aborts the run on a mismatch
# (patrol_cli 4.7.0+ pairs with patrol 4.9.0+). Activating the pinned CLI before
# log capture starts keeps install/compile time out of the profiler timeline.
# Keep in sync with the patrol constraint in mobile/pubspec.yaml.
PATROL_CLI_VERSION=4.7.0
PATROL_BIN=""
if [ -x "$PUB_CACHE_BIN/patrol" ]; then
    PATROL_BIN="$PUB_CACHE_BIN/patrol"
elif command -v patrol >/dev/null 2>&1; then
    PATROL_BIN="$(command -v patrol)"
fi

PATROL_CURRENT_VERSION=""
if [ -n "$PATROL_BIN" ]; then
    # `patrol --version` prints an update banner before the version line. The
    # update check can fail offline, so treat probe failure as "version unknown"
    # and let the pinned activation below repair the install.
    PATROL_CURRENT_VERSION="$("$PATROL_BIN" --version 2>/dev/null |
        sed -n 's/^patrol_cli v\([0-9][0-9.]*\).*/\1/p' | tail -1)" || true
fi

if [ "$PATROL_CURRENT_VERSION" != "$PATROL_CLI_VERSION" ]; then
    echo "Installing patrol_cli ${PATROL_CLI_VERSION} (pinned to match the patrol package)..." >&2
    dart pub global activate patrol_cli "$PATROL_CLI_VERSION" >&2
fi

# --- Start docker log capture (background, from now only) ---
echo "Starting docker log capture..." >&2
docker compose -f "$COMPOSE_FILE" logs -f -t --since "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    keycast funnelcake-relay funnelcake-api blossom blossom-proxy invite \
    > "$DOCKER_LOG" 2>&1 &
DOCKER_PID=$!

# --- Detect connected Android device ---
# ANDROID_SERIAL wins so a physical phone does not steal emulator e2e runs.
if [[ -n "${ANDROID_SERIAL:-}" ]]; then
    DEVICE="$ANDROID_SERIAL"
else
    DEVICE="$(adb devices | awk '/emulator-/{print $1; exit}')"
    if [[ -z "$DEVICE" ]]; then
        DEVICE="$(adb devices | sed -n '2p' | cut -f1)"
    fi
fi
if [[ -z "$DEVICE" ]]; then
    echo "ERROR: No Android device connected." >&2
    exit 1
fi
echo "Device:     ${DEVICE}" >&2

# Expanded below with the "${a[@]+"${a[@]}"}" guard: macOS ships bash 3.2,
# where a plain "${a[@]}" on an empty array trips `set -u`.
PATROL_EXTRA_ARGS=()
if [[ "${PATROL_NO_UNINSTALL:-}" == "true" ]]; then
    PATROL_EXTRA_ARGS+=(--no-uninstall)
fi

# --- Start logcat capture (background, flutter/app logs with timestamps) ---
echo "Starting logcat capture..." >&2
adb -s "$DEVICE" logcat -c 2>/dev/null || true
adb -s "$DEVICE" logcat -v UTC -v year flutter:I BandwidthTracker:I IndividualVideoController:I C2PAManager:D OpenVineProofMode:D '*:S' > "$LOGCAT_LOG" 2>&1 &
LOGCAT_PID=$!

# --- Run E2E test ---
# Not every suite under integration_test/ is a patrol suite. `patrol test`
# can only drive a patrolTest body, so dispatch on what the target actually
# contains; either way the run keeps the docker+logcat+app timeline.
# Disable errexit so we can capture the exit code through the pipe.
cd "$MOBILE_DIR"
set +e
if grep -rq 'patrolTest' "$TEST_PATH"; then
    echo "Running: patrol test ${TEST_PATH} ..." >&2
    PATH="$PUB_CACHE_BIN:$PATH" patrol test \
        --device "$DEVICE" \
        --target "$TEST_PATH" \
        --dart-define=DEFAULT_ENV=LOCAL \
        --dart-define=INVITE_SERVER_URL="$INVITE_SERVER_URL" \
        "${PATROL_EXTRA_ARGS[@]+"${PATROL_EXTRA_ARGS[@]}"}" \
        2>&1 | tee "$APP_LOG"
    TEST_EXIT="${PIPESTATUS[0]}"
else
    # Plain integration_test suite. There is no native automator on this
    # path, so a permission dialog would block Flutter interaction with no
    # way to dismiss it. Install first so the pre-grant has a package to
    # target even after a fresh emulator wipe or Patrol's default uninstall.
    echo "Running: flutter test ${TEST_PATH} ..." >&2
    flutter install --device-id "$DEVICE" 2>&1 | tee "$APP_LOG"
    INSTALL_EXIT="${PIPESTATUS[0]}"
    if [[ $INSTALL_EXIT -eq 0 ]]; then
        adb -s "$DEVICE" shell pm grant co.openvine.app \
            android.permission.POST_NOTIFICATIONS >/dev/null 2>&1 || true
        flutter test "$TEST_PATH" \
            --device-id "$DEVICE" \
            --dart-define=DEFAULT_ENV=LOCAL \
            --dart-define=INVITE_SERVER_URL="$INVITE_SERVER_URL" \
            2>&1 | tee -a "$APP_LOG"
        TEST_EXIT="${PIPESTATUS[0]}"
    else
        TEST_EXIT="$INSTALL_EXIT"
    fi
fi
set -e

# --- Stop docker log and logcat capture ---
kill "$DOCKER_PID" 2>/dev/null || true
wait "$DOCKER_PID" 2>/dev/null || true
unset DOCKER_PID
kill "$LOGCAT_PID" 2>/dev/null || true
wait "$LOGCAT_PID" 2>/dev/null || true
unset LOGCAT_PID

# --- Merge logs ---
echo "" >&2
echo "Merging logs..." >&2
python3 "$MERGE_SCRIPT" "$DOCKER_LOG" "$LOGCAT_LOG" "$APP_LOG" "$REPORT_FILE"

ENTRY_COUNT="$(wc -l < "$REPORT_FILE" 2>/dev/null || echo 0)"

echo "" >&2
if [[ $TEST_EXIT -eq 0 ]]; then
    echo "Tests PASSED." >&2
else
    echo "Tests FAILED (exit ${TEST_EXIT})." >&2

    # Auto-surface install failures: patrol reports "Total: 0" with Gradle exit 1
    # when the APK install failed (e.g. INSTALL_FAILED_INSUFFICIENT_STORAGE), not
    # when a test is missing. The native test report has the real failure.
    if grep -qE 'Total:[[:space:]]+0([^0-9]|$)' "$APP_LOG" 2>/dev/null; then
        echo "" >&2
        echo "Patrol reported Total: 0 with non-zero exit — likely APK install failure, not a missing Dart test." >&2
        while IFS= read -r -d '' f; do
            if grep -q "<failure\|<error" "$f" 2>/dev/null; then
                echo "--- $(basename "$f") ---" >&2
                grep -A 2 "<failure\|<error" "$f" | head -12 >&2 || true
            fi
        done < <(find "${MOBILE_DIR}/build" -path '*androidTest-results*' -name 'TEST-*.xml' -print0 2>/dev/null)
    fi
fi
echo "" >&2
echo "Report: ${REPORT_FILE} (${ENTRY_COUNT} entries)" >&2
echo "Analyze: cat ${REPORT_FILE} | claude 'summarize this E2E test run: errors, slow requests, timeline issues'" >&2

exit "$TEST_EXIT"
