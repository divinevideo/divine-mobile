#!/usr/bin/env bash
# Raw indeterminate Material progress indicators repeat forever without honoring
# MediaQuery.disableAnimations. Keep production code on the Divine wrappers so
# reduced-motion users and XCUITest can both reach quiescence (#8681).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$MOBILE_DIR"
# The whole value of this guard is its zero claim, so "the detector ran and
# found nothing" must never look like "the detector could not run". The
# detector exits 1 for findings and 2 for a bad invocation; `dart run` itself
# exits non-zero on an unresolved package or a compile error.
rc=0
dart run scripts/lib/indeterminate_progress_indicator_detector.dart \
  lib packages --path-prefix "$MOBILE_DIR" --detail || rc=$?

if [ "$rc" -eq 0 ]; then
  echo "Indeterminate progress indicator guard passed (zero raw sites)."
elif [ "$rc" -eq 1 ]; then
  echo >&2
  echo "Raw indeterminate Material progress indicators are forbidden." >&2
  echo "Use DivineCircularProgressIndicator or DivineLinearProgressIndicator" >&2
  echo "so MediaQuery.disableAnimations produces a static indicator." >&2
  exit 1
else
  echo >&2
  echo "Indeterminate progress indicator guard could NOT run (exit $rc)." >&2
  echo "This is a tooling failure, not a finding: nothing was verified." >&2
  echo "Check the detector invocation and that 'dart' resolves to the" >&2
  echo "pinned SDK (try: mise exec -- bash scripts/$(basename "$0"))." >&2
  exit "$rc"
fi
