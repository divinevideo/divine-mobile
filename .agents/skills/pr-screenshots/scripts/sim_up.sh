#!/usr/bin/env bash
# ABOUTME: Starts the local Docker stack, boots an iOS simulator, and installs a LOCAL debug build of the app.
# ABOUTME: Usage: bash sim_up.sh <worktree-root> [simulator name]; prints UDID=, BUNDLE_ID= and STACK_STARTED= on success.
set -euo pipefail

ROOT="${1:?usage: sim_up.sh <worktree-root> [simulator name]}"
SIM_NAME="${2:-iPhone 16 Pro}"
LOG_DIR="${TMPDIR:-/tmp}/pr-screenshots"
mkdir -p "$LOG_DIR"

# The seeder bakes this into the media URLs it mints; the iOS simulator reaches
# the stack on localhost.
export BLOSSOM_PUBLIC_URL=http://localhost:43003
COMPOSE_FILE="$ROOT/local_stack/docker-compose.yml"

# Every worktree's local_stack is the same compose project, so a stack another
# session started is shared: reuse it rather than recreate its containers. A
# failing `ps` (Docker not running) falls through to up.sh, which reports it.
RUNNING_SERVICES=$(docker compose -f "$COMPOSE_FILE" ps --status running --services 2>/dev/null || true)
if grep -qx funnelcake-proxy <<<"$RUNNING_SERVICES"; then
  STACK_STARTED=no
  echo "Reusing the local stack that is already running; leave it up at cleanup."
else
  STACK_STARTED=yes
  # Keycast mounts the gitignored local_stack/master.key, which only setup.sh
  # writes, and setup.sh also insists on adb. Without the file Docker mounts a
  # directory, Keycast dies and up.sh exits before its tuning and seed steps.
  # Prefer the main checkout's key: every worktree shares one Keycast database.
  KEY="$ROOT/local_stack/master.key"
  if [ ! -f "$KEY" ]; then
    [ ! -d "$KEY" ] || rmdir "$KEY"
    MAIN_KEY="$(git -C "$ROOT" worktree list --porcelain | sed -n '1s/^worktree //p')/local_stack/master.key"
    if [ -f "$MAIN_KEY" ]; then cp "$MAIN_KEY" "$KEY"; else openssl rand 32 | base64 > "$KEY"; fi
  fi

  echo "Starting local stack (log: $LOG_DIR/stack.log)..."
  if ! bash "$ROOT/local_stack/up.sh" > "$LOG_DIR/stack.log" 2>&1; then
    echo "warning: local_stack/up.sh failed; the end of $LOG_DIR/stack.log:" >&2
    tail -n 15 "$LOG_DIR/stack.log" >&2
  fi
  # Untuned, a video published now stays out of the REST feeds for up to
  # 15 minutes, so a failed up.sh must not skip this step.
  if ! grep -q 'refresh-interval tuning: applied=' "$LOG_DIR/stack.log"; then
    docker compose -f "$COMPOSE_FILE" run --rm funnelcake-local-tuning >> "$LOG_DIR/stack.log" 2>&1 \
      || { echo "error: refresh-interval tuning failed; see $LOG_DIR/stack.log" >&2; exit 1; }
  fi
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
echo "STACK_STARTED=$STACK_STARTED"
