#!/usr/bin/env bash
# Raw indeterminate Material progress indicators repeat forever without honoring
# MediaQuery.disableAnimations. Keep production code on the Divine wrappers so
# reduced-motion users and XCUITest can both reach quiescence (#8681).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$MOBILE_DIR"
if dart run scripts/lib/indeterminate_progress_indicator_detector.dart \
  lib packages --path-prefix "$MOBILE_DIR" --detail; then
  echo "Indeterminate progress indicator guard passed (zero raw sites)."
else
  echo >&2
  echo "Raw indeterminate Material progress indicators are forbidden." >&2
  echo "Use DivineCircularProgressIndicator or DivineLinearProgressIndicator" >&2
  echo "so MediaQuery.disableAnimations produces a static indicator." >&2
  exit 1
fi
