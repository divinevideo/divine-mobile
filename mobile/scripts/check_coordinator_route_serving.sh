#!/usr/bin/env bash
# Fails unless the account-deletion coordinator routes return their expected
# credential-free response. Missing, unreachable, unavailable, and unexpected
# responses mean the client would ship without its required backend contract.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$MOBILE_ROOT"

# This pure Dart HTTP/config probe needs no app native assets. Execute the
# script directly: `dart run` builds the workspace's unrelated native hooks
# (including sqlite3mc downloads) before it reaches the probe.
if [ -n "${DEFAULT_ENV:-}" ]; then
  dart scripts/lib/coordinator_route_probe.dart "--environment=$DEFAULT_ENV"
else
  dart scripts/lib/coordinator_route_probe.dart
fi
