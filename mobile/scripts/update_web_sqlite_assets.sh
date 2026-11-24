#!/bin/bash
# ABOUTME: Downloads the two web assets required by drift for Flutter web support
# ABOUTME: and pins the wasm URL; run whenever drift or sqlite3 versions change.

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

# Read resolved versions from pubspec.lock
DRIFT_VERSION=$(grep -A7 "^  drift:" pubspec.lock | grep "version:" | awk '{print $2}' | tr -d '"')
SQLITE3_VERSION=$(grep -A7 "^  sqlite3:" pubspec.lock | grep "version:" | awk '{print $2}' | tr -d '"')

if [ -z "$DRIFT_VERSION" ] || [ -z "$SQLITE3_VERSION" ]; then
  echo "Error: could not parse versions from pubspec.lock." >&2
  echo "  drift=${DRIFT_VERSION:-<not found>}, sqlite3=${SQLITE3_VERSION:-<not found>}" >&2
  exit 1
fi

echo "Resolved versions — drift: ${DRIFT_VERSION}, sqlite3: ${SQLITE3_VERSION}"

DRIFT_URL="https://github.com/simolus3/drift/releases/download/drift-${DRIFT_VERSION}/drift_worker.js"
SQLITE3_URL="https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-${SQLITE3_VERSION}/sqlite3.wasm"

echo ""
echo "Downloading web/drift_worker.js from ${DRIFT_URL}"
curl -fsSL --progress-bar "${DRIFT_URL}" -o web/drift_worker.js

echo "Downloading web/sqlite3.wasm from ${SQLITE3_URL}"
curl -fsSL --progress-bar "${SQLITE3_URL}" -o web/sqlite3.wasm

# web/_headers serves *.wasm as immutable, so the connections request the wasm
# with a ?v= query and a browser holding an older copy fetches this one. The
# worker URL stays unversioned: a second worker would write the same database.
CONNECTIONS=(
  packages/db_client/lib/src/database/connection/connection_web.dart
  packages/cache_sync/lib/src/connection/connection_web.dart
)
echo "Pinning the sqlite3.wasm URL in the web database connections"
for connection in "${CONNECTIONS[@]}"; do
  perl -pi -e "s/sqlite3\.wasm\?v=[^']*/sqlite3.wasm?v=${SQLITE3_VERSION}/g" "${connection}"
done

echo ""
echo "Done. Commit the updated assets together with the pubspec change:"
echo "  git add web/drift_worker.js web/sqlite3.wasm ${CONNECTIONS[*]}"
