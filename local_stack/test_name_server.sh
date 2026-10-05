#!/usr/bin/env bash
# Real HTTP integration test, isolated from the normal stack. Owns only its
# generated Compose project and volume; port 43005 must be free.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_PROJECT="name-server-test-$$-$(date +%s)-$RANDOM"
COMPOSE=(docker compose -p "$TEST_PROJECT" -f "$SCRIPT_DIR/docker-compose.yml")
# Refuse an occupied port or a pre-existing project before installing cleanup.
port_containers="$(docker ps -q --filter publish=43005)"
project_containers="$("${COMPOSE[@]}" ps -aq)"
project_volumes="$(docker volume ls -q --filter "label=com.docker.compose.project=$TEST_PROJECT")"
project_networks="$(docker network ls -q --filter "label=com.docker.compose.project=$TEST_PROJECT")"
if [[ -n "$port_containers$project_containers$project_volumes$project_networks" ]]; then
  echo "ERROR: port 43005 or the test project is already in use." >&2
  exit 1
fi
python3 - <<'PY'
import socket
with socket.socket() as probe:
    probe.bind(('127.0.0.1', 43005))
PY
source "$SCRIPT_DIR/name-server/run-smoke.sh"
cleanup() { "${COMPOSE[@]}" down -v --remove-orphans; }
trap cleanup EXIT

"${COMPOSE[@]}" up -d --wait --wait-timeout 120 name-server
run_name_server_smoke
run_name_server_smoke --seed
"${COMPOSE[@]}" restart name-server
"${COMPOSE[@]}" up -d --no-build --wait --wait-timeout 120 name-server
run_name_server_smoke --verify-seed
echo "Name-server fresh migrations, signed requests and persistence passed."
