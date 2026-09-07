#!/usr/bin/env bash
# Service-suite coverage guard (#8755): every integration_test/e2e suite must
# either run in the Linux service workflow or appear in the shrink-only
# exclusion manifest with a reason.

set -euo pipefail

# Byte-wise, locale-independent ordering. lib/list_ratchet.sh exports this too,
# but it is sourced at the bottom of this file, so every sort/comm above would
# otherwise run in the caller's collation and disagree with emit_current's.
export LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="${SERVICE_SUITE_MOBILE_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
REPO_ROOT="$(cd "$MOBILE_DIR/.." && pwd)"
WORKFLOW="${SERVICE_SUITE_WORKFLOW:-$REPO_ROOT/.github/workflows/mobile_service_integration_tests.yaml}"
E2E_DIR="${SERVICE_SUITE_E2E_DIR:-$MOBILE_DIR/integration_test/e2e}"

RATCHET_LABEL="service_suite_coverage"
BASELINE_FILE="${SERVICE_SUITE_BASELINE_FILE:-$SCRIPT_DIR/baseline/service_suite_exclusions.txt}"
BASELINE_REPO_PATH="mobile/scripts/baseline/service_suite_exclusions.txt"
BASE_REF="${SERVICE_SUITE_BASE_REF:-origin/main}"
ALLOW_NO_BASE="${SERVICE_SUITE_ALLOW_NO_BASE:-0}"
ALLOW_NO_BASE_VAR="SERVICE_SUITE_ALLOW_NO_BASE"
NEW_HINT="Run each new suite in the Linux service workflow, or explain why it cannot run there. Exclusions may not grow versus origin/main."
STALE_HINT="An excluded suite is now executed by the workflow or no longer exists."
FOOTER="Every integration_test/e2e suite must be run by the Linux service
workflow or remain in the reason-bearing, shrink-only exclusion manifest.
See issue #8755."

fail() {
  echo "FAIL [service_suite_coverage]: $*" >&2
  exit 1
}

[ -f "$WORKFLOW" ] || fail "workflow not found: $WORKFLOW"
[ -d "$E2E_DIR" ] || fail "suite directory not found: $E2E_DIR"
[ -f "$BASELINE_FILE" ] || fail "exclusion manifest not found: $BASELINE_FILE"

anchor='- name: 🚀 Run service integration tests'
anchor_count="$(grep -cF -- "$anchor" "$WORKFLOW" || true)"
[ "$anchor_count" -eq 1 ] || fail "expected exactly one '$anchor' step, found $anchor_count"

# The anchored step only, not the rest of the file: a later step whose body
# happens to contain a shell loop is none of this guard's business. awk matches
# the anchor as a literal substring, the way the count above does -- feeding it
# to sed as a regex address would diverge the moment the step is renamed to
# something containing '.', '[' or '*'.
step_body="$(awk -v anchor="$anchor" '
  !inside && index($0, anchor) {
    inside = 1
    match($0, /^[ ]*/)
    indent = RLENGTH
    next
  }
  inside && match($0, /^[ ]*-[ ]/) && index($0, "-") - 1 == indent { inside = 0 }
  inside
' "$WORKFLOW")"
loop_start_count="$(printf '%s\n' "$step_body" | grep -cE '^[[:space:]]*for suite in \\$' || true)"
loop_end_count="$(printf '%s\n' "$step_body" | grep -cE '; do[[:space:]]*$' || true)"
[ "$loop_start_count" -eq 1 ] || fail "expected exactly one service-suite loop start, found $loop_start_count"
[ "$loop_end_count" -eq 1 ] || fail "expected exactly one service-suite loop end, found $loop_end_count"

# Accounting for a suite is only worth anything if the step actually runs. A
# condition on it, or a workflow that no longer fires on pull requests, leaves
# every suite listed and none of them executed -- green guard, no coverage.
step_condition="$(printf '%s\n' "$step_body" | grep -E '^[[:space:]]*if:' || true)"
[ -z "$step_condition" ] || fail "the service-suite step is conditional, so the guard cannot promise the suites run:
$(printf '%s\n' "$step_condition" | sed 's/^/  /')"

triggers="$(awk '
  !inside && /^on:/ { inside = 1; print; next }
  inside && /^[^[:space:]#]/ { inside = 0 }
  inside
' "$WORKFLOW")"
printf '%s\n' "$triggers" | grep -q 'pull_request' \
  || fail "the service workflow no longer runs on pull_request, so the suites this guard accounts for would not run on a pull request"

loop_body="$(printf '%s\n' "$step_body" | sed -n '/^[[:space:]]*for suite in \\$/,/; do[[:space:]]*$/p')"
# Only standalone shell words in the for-list count as executed suites. A path
# in a comment, echo, or other text inside the loop slice is not an argument to
# the loop and must remain unaccounted for.
suite_word_lines="$(printf '%s\n' "$loop_body" | grep -E '^[[:space:]]*integration_test/e2e/([A-Za-z0-9_]+/)*[A-Za-z0-9_]+_test\.dart([[:space:]]+\\|; do)[[:space:]]*$' || true)"
run_list_raw="$(printf '%s\n' "$suite_word_lines" | grep -oE 'integration_test/e2e/([A-Za-z0-9_]+/)*[A-Za-z0-9_]+_test\.dart' || true)"
[ -n "$run_list_raw" ] || fail "service-suite loop contains no E2E suite paths"

duplicate_runs="$(printf '%s\n' "$run_list_raw" | sort | uniq -d)"
[ -z "$duplicate_runs" ] || fail "workflow runs duplicate suite path(s):
$(printf '%s\n' "$duplicate_runs" | sed 's/^/  /')"
RUN_LIST="$(printf '%s\n' "$run_list_raw" | sort -u)"

while IFS= read -r suite; do
  [ -f "$MOBILE_DIR/$suite" ] || fail "workflow suite does not exist: $suite"
done <<< "$RUN_LIST"

manifest_entries="$(sed -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d' "$BASELINE_FILE")"
invalid_entries="$(printf '%s\n' "$manifest_entries" | grep -vE '^integration_test/e2e/([A-Za-z0-9_]+/)*[A-Za-z0-9_]+_test\.dart[[:space:]]+#[[:space:]]*[^[:space:]].*$' || true)"
[ -z "$invalid_entries" ] || fail "every exclusion must be a canonical suite path followed by a nonempty '# reason':
$(printf '%s\n' "$invalid_entries" | sed 's/^/  /')"

manifest_paths="$(printf '%s\n' "$manifest_entries" | sed 's/[[:space:]]*#.*//; s/[[:space:]]*$//')"
duplicate_exclusions="$(printf '%s\n' "$manifest_paths" | grep -v '^$' | sort | uniq -d || true)"
[ -z "$duplicate_exclusions" ] || fail "exclusion manifest contains duplicate path(s):
$(printf '%s\n' "$duplicate_exclusions" | sed 's/^/  /')"
MANIFEST_PATHS="$(printf '%s\n' "$manifest_paths" | grep -v '^$' | sort -u || true)"

overlap="$(comm -12 <(printf '%s\n' "$RUN_LIST") <(printf '%s\n' "$MANIFEST_PATHS") | grep -v '^$' || true)"
# Regenerating is how an exclusion is retired: the suite has just been added to
# the workflow loop, so it drops out of emit_current and the rewritten manifest
# resolves the overlap by itself. Only a plain run treats it as a contradiction.
if [ "${UPDATE_BASELINE:-0}" != "1" ]; then
  [ -z "$overlap" ] || fail "suite path(s) appear in both the workflow and exclusion manifest:
$(printf '%s\n' "$overlap" | sed 's/^/  /')
  -> If the workflow now runs it, retire the exclusion by regenerating:
     UPDATE_BASELINE=1 bash mobile/scripts/check_service_suite_coverage.sh"
fi

emit_current() {
  find "$E2E_DIR" -type f -name '*_test.dart' -print \
    | sed "s#^$MOBILE_DIR/##" \
    | sort -u \
    | comm -23 - <(printf '%s\n' "$RUN_LIST")
}

print_baseline_header() {
  cat <<'EOF'
# Frozen exclusion list: integration_test/e2e suites that cannot run in the
# Linux service integration workflow. Generated by
# scripts/check_service_suite_coverage.sh. The set may only SHRINK; every entry
# must retain a trailing '# reason'. Issue: #8755.
#
# Unlike this repo's other reason-bearing baselines, this one is not a
# worklist. These suites are excluded for reasons no workflow change can fix:
# one needs a physical device, the rest need images no GitHub runner can pull.
# The runner-side half of that story -- including why local_stack cannot start
# in CI at all -- is in .github/workflows/mobile_service_integration_tests.yaml.
EOF
}

# shellcheck source=lib/list_ratchet.sh
. "$SCRIPT_DIR/lib/list_ratchet.sh"
run_list_ratchet
