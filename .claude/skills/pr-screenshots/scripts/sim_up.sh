#!/usr/bin/env bash
# ABOUTME: Starts the local Docker stack, boots an iOS simulator, and installs a LOCAL debug build of the app.
# ABOUTME: Usage: bash sim_up.sh <worktree-root> [simulator name]; prints UDID= and BUNDLE_ID= on success.
set -euo pipefail

ROOT="${1:?usage: sim_up.sh <worktree-root> [simulator name]}"
SIM_NAME="${2:-iPhone 16 Pro}"
LOG_DIR="${TMPDIR:-/tmp}/pr-screenshots"
mkdir -p "$LOG_DIR"

# The iOS simulator reaches the stack on localhost; Blossom bakes this into media URLs.
export BLOSSOM_PUBLIC_URL=http://localhost:43003
echo "Starting local stack (log: $LOG_DIR/stack.log)..."
if ! bash "$ROOT/local_stack/up.sh" > "$LOG_DIR/stack.log" 2>&1; then
  # Keycast often fails to start locally; device-only accounts never call it.
  echo "warning: local_stack/up.sh reported a failure; checking the services screenshots need"
fi
curl -sf -o /dev/null http://localhost:43003/ || { echo "error: Blossom is not answering on :43003" >&2; exit 1; }
curl -s -o /dev/null http://localhost:47777/ || { echo "error: the relay is not answering on :47777" >&2; exit 1; }

UDID=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
name = sys.argv[1]
devices = json.load(sys.stdin)["devices"]
matches = [d for runtime in sorted(devices, reverse=True) for d in devices[runtime] if d["name"] == name]
print(matches[0]["udid"] if matches else "")
' "$SIM_NAME")
[ -n "$UDID" ] || { echo "error: no available simulator named '$SIM_NAME'" >&2; exit 1; }
xcrun simctl boot "$UDID" 2>/dev/null || true
open -a Simulator
xcrun simctl status_bar "$UDID" override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3

echo "Building a LOCAL debug app (log: $LOG_DIR/build.log)..."
cd "$ROOT/mobile"
# A fresh worktree's plugin copy step fails without these directories.
mkdir -p build/ios/SourcePackages build/macos/SourcePackages
mise exec -- flutter pub get > "$LOG_DIR/build.log" 2>&1
mise exec -- flutter build ios --simulator --debug --no-pub --dart-define=DEFAULT_ENV=LOCAL >> "$LOG_DIR/build.log" 2>&1 \
  || { echo "error: build failed; see $LOG_DIR/build.log" >&2; exit 1; }
xcrun simctl install "$UDID" build/ios/iphonesimulator/Runner.app
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" build/ios/iphonesimulator/Runner.app/Info.plist)

echo "UDID=$UDID"
echo "BUNDLE_ID=$BUNDLE_ID"
