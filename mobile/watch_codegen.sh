#!/bin/bash
set -euo pipefail

# Long-lived build_runner daemon. Run once in a separate terminal and leave
# it running. Subsequent edits to Riverpod / JSON / Drift inputs
# regenerate in seconds because the analyzer stays warm. Build scripts
# detect that codegen is fresh and skip the full re-run.

cd "$(dirname "$0")"

echo "👀 Starting build_runner watch (Ctrl+C to stop)..."
echo "   Leave this running while you edit codegen inputs."
echo ""

exec dart run build_runner watch --delete-conflicting-outputs
