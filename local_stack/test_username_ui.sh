#!/usr/bin/env bash
# Owns only a fresh install of the LOCAL debug app on the selected emulator.
# Start the normal local stack first. Never run this flow with a production build.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/../mobile"
TEST_DEVICE="${1:?Usage: bash local_stack/test_username_ui.sh <emulator-id>}"
LOCAL_USERNAME="local$(date +%s)"
COMPOSE=(docker compose -f "$SCRIPT_DIR/docker-compose.yml")
source "$SCRIPT_DIR/name-server/run-smoke.sh"
run_name_server_smoke --seed
mise exec -- flutter build apk --debug --dart-define=DEFAULT_ENV=LOCAL
adb -s "$TEST_DEVICE" install -r build/app/outputs/flutter-apk/app-debug.apk
mise exec -- maestro --device "$TEST_DEVICE" test -e LOCAL_USERNAME="$LOCAL_USERNAME" e2e/maestro/tests/localUsername.yaml
# UI text alone is not proof of a persisted claim: inspect the real registry.
curl --fail --silent "http://localhost:43005/api/username/check/$LOCAL_USERNAME" |
  python3 -c 'import json,sys; r=json.load(sys.stdin); assert r["code"] == "taken" and r.get("pubkey"), r; print("UI claim persisted in the local registry.")'
