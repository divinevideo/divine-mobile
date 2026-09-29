#!/usr/bin/env bash
# Fails CI if an integration_test suite handles ErrorWidget.builder or
# FlutterError.onError in a way that can leak an override into a later test
# (#5839) or hang the run when a check fails (#9659).
#
# app.main() replaces both hooks, and its FlutterError.onError does not chain
# to the one flutter_test installed. flutter_test reports a failed `expect`
# through whichever handler is current, so unless the original is put back
# first the failure never reaches the test binding and the run hangs. A suite
# that launches the app therefore runs its scenario inside the shared helper:
#
#   await runWithAppErrorHandlers(() async {
#     launchAppGuarded(app.main);
#     ...
#   });
#
# runWithAppErrorHandlers (helpers/test_setup.dart) suppresses known noise,
# restores FlutterError.onError before a failure propagates, restores
# ErrorWidget.builder when the scenario ends (flutter_test checks it at the
# end of the body, before any teardown), and registers teardown restores for
# both. The old per-suite save/restore helpers are gone, so the compiler
# already rejects that shape. See
# test/integration_test_helpers/test_setup_test.dart for the pinned contract.
#
# Policy (presence-based, scoped to mobile/integration_test):
#   Rule 1 — no raw `ErrorWidget.builder =` / `FlutterError.onError =`
#            assignments outside helpers/ (use runWithAppErrorHandlers).
#   Rule 2 — a file that imports package:openvine/main*.dart, to launch the
#            app, must call runWithAppErrorHandlers(.
#
# Allowlist: integration_test/helpers/** (defines the raw ops the helper wraps).
#
# Usage:
#   bash mobile/scripts/check_integration_test_error_restore_safety.sh
#   (run from the repository root or from mobile/)
set -euo pipefail
export LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
IT_DIR="$MOBILE_DIR/integration_test"

if [[ ! -d "$IT_DIR" ]]; then
  echo "check_integration_test_error_restore_safety: no integration_test dir; skipping."
  exit 0
fi

fail=0

# All .dart under integration_test except the helpers/ allowlist. Word-splitting
# is safe: integration_test paths contain no spaces (matches the convention in
# the sibling check_*.sh guards, and keeps this portable to macOS bash 3.2).
files=$(find "$IT_DIR" -name '*.dart' -not -path "$IT_DIR/helpers/*" | sort)

for f in $files; do
  rel="${f#"$MOBILE_DIR"/}"

  # Rule 1: raw assignments (single '=', not '==') are banned outside helpers/.
  if grep -nE '(ErrorWidget\.builder|FlutterError\.onError)[[:space:]]*=([^=]|$)' "$f" \
    >/dev/null 2>&1; then
    echo "✗ $rel: raw ErrorWidget.builder / FlutterError.onError assignment."
    grep -nE '(ErrorWidget\.builder|FlutterError\.onError)[[:space:]]*=([^=]|$)' "$f" \
      | sed 's/^/    /'
    echo "    → run the scenario inside runWithAppErrorHandlers() from"
    echo "      helpers/test_setup.dart instead."
    fail=1
  fi

  # Rule 2: launching the app requires the shared helper.
  if grep -Eq "package:openvine/main[A-Za-z0-9_]*\.dart" "$f" \
    && ! grep -q 'runWithAppErrorHandlers(' "$f"; then
    echo "✗ $rel: launches the app without runWithAppErrorHandlers()."
    echo "    A failed check would be reported through the app's own"
    echo "    FlutterError.onError and hang the run instead of failing it (#9659)."
    fail=1
  fi
done

if [[ "$fail" -ne 0 ]]; then
  echo ""
  echo "Unsafe error-hook handling in integration_test (#5839, #9659)."
  echo "Run app-launching scenarios inside runWithAppErrorHandlers(); see"
  echo "test/integration_test_helpers/test_setup_test.dart for the contract."
  exit 1
fi

echo "✓ integration_test error hooks are restored safely."
