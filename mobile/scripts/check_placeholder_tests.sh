#!/usr/bin/env bash
# Placeholder-test ratchet (#3340): tests that pass no matter what the product
# does, test files that declare no test, and groups that contain no test, are
# frozen at ZERO per file
# in scripts/baseline/placeholder_tests.txt. The baseline is intentionally
# EMPTY — #3340 removed all 93 sites — so any entry here is a regression.
#
# Why: .claude/rules/testing.md — "A passing test should be evidence that the
# feature works. If the test would still pass with the feature broken, it tests
# nothing." Coverage theatre is worse than an uncovered line, because the green
# line hides the gap instead of flagging it. The 93 sites removed by #3340
# included a 602-line accessibility suite whose 38 tests were all
# `expect(true, isTrue)`, and seven ProofMode suites waiting on services that
# were deliberately deleted a year earlier.
#
# Three rules, all frozen at zero:
#   1. TAUTOLOGY      — every assertion in the test is trivially satisfied
#                       (`expect(true, isTrue)`, `expect(1, 1)`).
#   2. NO DECLARATIONS — a *_test.dart that declares no test / testWidgets /
#                       blocTest / patrolTest / group. A `main()` that only
#                       forwards (`void main() => platform.main();`) is exempt:
#                       that is the conditional-import dispatcher shape, whose
#                       declarations live in the platform library it selects.
#   3. EMPTY GROUP     — a group whose callback tree declares no test. Lifecycle
#                       calls and bare assertions do not count. Unknown bare
#                       calls are conservatively treated as possible
#                       test-declaring helpers.
#
# A test with NO assertion is deliberately NOT counted. Assertions arrive
# through drift's `verifier.migrateAndValidate`, through imported helpers like
# `expectMeetsAccessibilityGuidelines`, and through matchers this parser cannot
# resolve across files. Counting them would put ~20 good tests on a debt list,
# and a guard that cries wolf gets switched off. That population is real and
# needs helper-aware triage, not a gate.
#
# There is no escape hatch. A construction smoke test can assert
# `expect(() => Foo(), returnsNormally)` or `expect(foo, isNotNull)`; a widget
# lifecycle test can assert `expect(tester.takeException(), isNull)`. If a
# genuine exception ever appears, it earns a reviewed baseline entry — not a
# self-service inline ignore.
#
# Detector: scripts/lib/placeholder_test_detector.dart (a real Dart AST).
# A grep cannot do this: `dart format` spells `expect(true, isTrue)` on one line
# or four depending on surroundings — a line scan found 14 of the 38 tautologies
# in test/widget/tdd/accessibility_ui_test.dart — and the question is whether
# the tautology is the test's ONLY assertion, which is a property of the body,
# not of a line. Pinned by test/tools/placeholder_test_detector_test.dart.
#
# Regenerate ONLY after an intentional, reviewed change:
#   UPDATE_BASELINE=1 bash mobile/scripts/check_placeholder_tests.sh
# Run (from repo root or mobile/): bash mobile/scripts/check_placeholder_tests.sh
# List the individual sites:
#   dart run scripts/lib/placeholder_test_detector.dart test integration_test packages --path-prefix . --detail

set -euo pipefail
export LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TAB="$(printf '\t')"

RATCHET_LABEL="placeholder_tests"
BASELINE_FILE="${PLACEHOLDER_TESTS_BASELINE_FILE:-$SCRIPT_DIR/baseline/placeholder_tests.txt}"
BASELINE_REPO_PATH="${PLACEHOLDER_TESTS_BASELINE_REPO_PATH:-mobile/scripts/baseline/placeholder_tests.txt}"
BASE_REF="${PLACEHOLDER_TESTS_BASELINE_BASE_REF:-origin/main}"
ALLOW_NO_BASE="${PLACEHOLDER_TESTS_ALLOW_NO_BASE:-0}"
ALLOW_NO_BASE_VAR="PLACEHOLDER_TESTS_ALLOW_NO_BASE"
DART_BIN="${PLACEHOLDER_TESTS_DART:-dart}"

# Scan roots, relative to MOBILE_DIR. `packages` is scanned whole and filtered
# to test/ and integration_test/ segments by the detector.
SCAN_DIRS="${PLACEHOLDER_TESTS_SCAN_DIRS:-test integration_test packages}"

NEW_HINT="A test must be able to fail. Assert the behaviour instead of expect(true, isTrue): expect(() => Foo(), returnsNormally) for construction, expect(tester.takeException(), isNull) for a lifecycle pump, or a real matcher on the result. If the behaviour cannot be asserted yet, delete the test rather than shipping one that always passes — .claude/rules/testing.md."
STALE_HINT="A file stopped carrying placeholder tests."
FOOTER="Tests that cannot fail are frozen at zero.
See .claude/rules/testing.md ('A Test Must Be Able to Fail') and #3340.
Inspect the sites with:
  dart run scripts/lib/placeholder_test_detector.dart test integration_test packages --path-prefix . --detail"

# Print "relpath<TAB>count" for every file with at least one site. Runs from
# MOBILE_DIR so the detector resolves package:analyzer from the app's config.
emit_current() {
  (
    cd "$MOBILE_DIR"
    # shellcheck disable=SC2086
    "$DART_BIN" run scripts/lib/placeholder_test_detector.dart \
      $SCAN_DIRS --path-prefix "$MOBILE_DIR"
  ) | LC_ALL=C sort -t "$TAB" -k1,1
}

print_baseline_header() {
  cat <<EOF
# Frozen baseline: test files under mobile/test, mobile/integration_test and
# mobile/packages/*/test containing a test that cannot fail — every assertion
# trivially satisfied — declaring no test at all, or containing an empty group
# (format: relpath<TAB>count). Generated by scripts/check_placeholder_tests.sh
# from scripts/lib/placeholder_test_detector.dart.
#
# The list is intentionally EMPTY: #3340 removed all 93 sites, so any entry here
# is a regression. Fix the test rather than regenerating this file — assert the
# behaviour, or delete the test.
#
# A test with NO assertion is not counted: assertions reach a test through
# imported helpers and third-party verifiers this parser cannot resolve, and
# flagging them would mislabel ~20 good tests as debt. See the script header.
#
# Issues: #3340, #9146.
EOF
}

# shellcheck source=lib/numeric_ratchet.sh
source "$SCRIPT_DIR/lib/numeric_ratchet.sh"
run_numeric_ratchet
