#!/usr/bin/env bash
# Fails CI if a test the very_good optimizer MERGES into the shared isolate
# assigns HttpOverrides.global. That removes flutter_test's HTTP 400-mock for
# every later merged test, letting a real network call leak a connect-timer that
# surfaces as an order-dependent "Pending timers" failure cross-attributed to an
# unrelated widget test (PR #5163, #3137).
#
# A file is in the merge UNLESS it is tagged @Tags(['skip_very_good_optimization']).
# Being under test/manual/ does NOT exclude it — only the tag does (the very_good
# --optimization globber does not honor dart_test.yaml's exclude: test/manual/**).
#
# Policy: STRICT. No merged (untagged) test may assign HttpOverrides.global at
# all. A test that legitimately needs real network must be tagged
# skip_very_good_optimization (+ integration) so it stays out of the merge. A
# within-file restore is NOT accepted: grep cannot prove a restore is reachable,
# and even a correct tearDownAll restore still leaves the global nulled while the
# file runs inside the shared isolate.
#
# Reads (HttpOverrides.current) do not match — only assignment to `.global` is
# flagged. The app test tree and every package test tree are covered; lib/ is
# out of scope.
#
# Usage:
#   bash mobile/scripts/check_http_overrides_isolation.sh
#   (run from the repository root or from mobile/)
set -euo pipefail
export LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Test roots are separate merged-isolate bundles. A mutation cannot cross a
# package boundary, but it can still poison later files within that package.
scan_roots=("$MOBILE_DIR/test")
for package_test_root in "$MOBILE_DIR"/packages/*/test; do
  [[ -d "$package_test_root" ]] && scan_roots+=("$package_test_root")
done

# Files under test/ that ASSIGN HttpOverrides.global (the `= ` token stays on the
# LHS line under dart format, so a file-level match also covers multi-line RHS
# forms; the `io.`-prefixed form matches too). `.current` reads and comment
# mentions do not match.
assigning=$(grep -rlE \
  "HttpOverrides\.global[[:space:]]*=" "${scan_roots[@]}" || true)

# A file counts as "tagged out of the merge" only if it has a real
# @Tags([... 'skip_very_good_optimization' ...]) LIBRARY annotation — anchored
# at line start so a commented-out (`// @Tags(...)`) or doc-mention of the
# string does NOT satisfy the gate. This mirrors how the Dart test runner reads
# the annotation, so the gate can't be fooled by a disabled tag.
violations=""
for f in $assigning; do
  if ! grep -qE "^[[:space:]]*@Tags\([^)]*skip_very_good_optimization" "$f"; then
    violations="$violations$f"$'\n'
  fi
done

if [[ -n "$violations" ]]; then
  echo "FAIL [http_overrides_isolation]: untagged test assigns HttpOverrides.global:"
  echo "$violations" | sed '/^$/d; s/^/  /'
  echo ""
  echo "Assigning HttpOverrides.global in a MERGED (untagged) test removes"
  echo "flutter_test's HTTP 400-mock for every later test in the shared"
  echo "very_good --optimization isolate, causing order-dependent network /"
  echo "pending-timer flakes (PR #5163)."
  echo ""
  echo "Remediation — pick one:"
  echo "  (a) Real-network / integration test: tag it so it stays out of the"
  echo "      merge (place the annotation BEFORE the first import):"
  echo "        @Tags(['skip_very_good_optimization', 'integration'])"
  echo "      then bump mobile/test/vgv_tag_baseline.txt if the tag count rises."
  echo "  (b) Otherwise drop the HttpOverrides.global assignment — a true unit"
  echo "      test should rely on the default 400-mock, not real network."
  exit 1
fi

echo "OK: no untagged test assigns HttpOverrides.global."
