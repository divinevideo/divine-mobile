#!/usr/bin/env bash
# Rejects dependency cycles between workspace packages.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$MOBILE_DIR"
dart run scripts/lib/package_dependency_cycle_detector.dart "${1:-packages}"
