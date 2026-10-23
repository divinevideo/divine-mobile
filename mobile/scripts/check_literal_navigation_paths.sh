#!/usr/bin/env bash
# Navigation calls in app code take their location from RoutePaths or a
# screen's path builder. A literal path does not follow its route when the
# route changes, and sampled literals broke navigation with every test green
# (#3572, #3335).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$MOBILE_DIR"
# The whole value of this guard is its zero claim, so "the detector ran and
# found nothing" must never look like "the detector could not run". The
# detector exits 1 for findings and 2 for a bad invocation; `dart run` itself
# exits non-zero on an unresolved package or a compile error.
rc=0
dart run scripts/lib/literal_navigation_path_detector.dart \
  lib --path-prefix "$MOBILE_DIR" --detail || rc=$?

if [ "$rc" -eq 0 ]; then
  echo "Literal navigation path guard passed (zero literal sites)."
elif [ "$rc" -eq 1 ]; then
  echo >&2
  echo "Navigating with a literal path string is forbidden in app code." >&2
  echo "Pass a RoutePaths constant or builder, or the screen's path builder," >&2
  echo "so the location follows its route when the route changes." >&2
  exit 1
else
  echo >&2
  echo "Literal navigation path guard could NOT run (exit $rc)." >&2
  echo "This is a tooling failure, not a finding: nothing was verified." >&2
  echo "Check the detector invocation and that 'dart' resolves to the" >&2
  echo "pinned SDK (try: mise exec -- bash scripts/$(basename "$0"))." >&2
  exit "$rc"
fi
