#!/usr/bin/env bash
# Real HTTP integration test, isolated from the normal stack. Owns only its
# generated Compose project and volume; port 43005 must be free.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_PROJECT="name-server-test-$$"
COMPOSE=(docker compose -p "$TEST_PROJECT" -f "$SCRIPT_DIR/docker-compose.yml")
cleanup() { "${COMPOSE[@]}" down -v --remove-orphans; }
trap cleanup EXIT

"${COMPOSE[@]}" up -d --wait --wait-timeout 120 name-server
"${COMPOSE[@]}" run --rm --no-deps name-server-smoke
"${COMPOSE[@]}" run --rm --no-deps name-server-smoke --seed
"${COMPOSE[@]}" restart name-server
"${COMPOSE[@]}" up -d --no-build --wait --wait-timeout 120 name-server
"${COMPOSE[@]}" run --rm --no-deps name-server-smoke --verify-seed
echo "Name-server fresh migrations, signed requests and persistence passed."
