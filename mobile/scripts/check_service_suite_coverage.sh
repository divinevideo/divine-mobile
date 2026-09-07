#!/usr/bin/env bash
# ABOUTME: Accounts for every E2E suite in the headless service workflow.
# ABOUTME: Rejects missing, duplicate, stale, reasonless, or newly excluded suites.

set -euo pipefail

# sort/comm/uniq must agree regardless of the runner's locale.
export LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_DIR="$(cd "$MOBILE_DIR/.." && pwd)"
WORKFLOW_FILE="${SERVICE_SUITE_WORKFLOW_FILE:-$REPO_DIR/.github/workflows/mobile_service_integration_tests.yaml}"
E2E_DIR="${SERVICE_SUITE_E2E_DIR:-$MOBILE_DIR/integration_test/e2e}"
SUITE_PATH_ROOT="${SERVICE_SUITE_PATH_ROOT:-$MOBILE_DIR}"
MANIFEST_FILE="${SERVICE_SUITE_MANIFEST_FILE:-$E2E_DIR/service_suite_exclusions.txt}"
MANIFEST_REPO_PATH="${MANIFEST_FILE#"$REPO_DIR"/}"
BASE_REF="${SERVICE_SUITE_BASE_REF:-origin/main}"
WORKFLOW_PARSER="${SERVICE_SUITE_WORKFLOW_PARSER:-$SCRIPT_DIR/lib/service_suite_workflow_parser.dart}"

scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT

parse_manifest() {
  awk '
    /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
    {
      separator = index($0, "|")
      if (separator == 0) {
        printf "Invalid exclusion on line %d: expected suite path | reason\n", FNR > "/dev/stderr"
        invalid = 1
        next
      }
      path = substr($0, 1, separator - 1)
      reason = substr($0, separator + 1)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", path)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", reason)
      if (path == "" || reason == "") {
        printf "Invalid exclusion on line %d: suite path and reason are required\n", FNR > "/dev/stderr"
        invalid = 1
        next
      }
      print path
    }
    END { exit invalid }
  ' "$1"
}

find "$E2E_DIR" -type f -name '*_test.dart' -print \
  | sed "s|^$SUITE_PATH_ROOT/||" \
  | sort > "$scratch/all"

parser_error="$scratch/workflow_parser_error"
if ! dart run "$WORKFLOW_PARSER" --workflow "$WORKFLOW_FILE" --all \
  2> "$parser_error" | sort > "$scratch/included"; then
  cat "$parser_error" >&2
  echo "FAIL [service_suite_coverage]: could not parse the workflow suite lists."
  exit 1
fi

parse_manifest "$MANIFEST_FILE" | sort > "$scratch/excluded"

failed=false
for population in included excluded; do
  duplicates="$(uniq -d "$scratch/$population")"
  if [ -n "$duplicates" ]; then
    echo "FAIL [service_suite_coverage]: duplicate $population suites:"
    echo "$duplicates"
    failed=true
  fi
done

sort -u "$scratch/included" > "$scratch/included_unique"
sort -u "$scratch/excluded" > "$scratch/excluded_unique"
cat "$scratch/included_unique" "$scratch/excluded_unique" | sort -u > "$scratch/accounted"

overlap="$(comm -12 "$scratch/included_unique" "$scratch/excluded_unique")"
if [ -n "$overlap" ]; then
  echo "FAIL [service_suite_coverage]: suites cannot be both included and excluded:"
  echo "$overlap"
  failed=true
fi

unaccounted="$(comm -23 "$scratch/all" "$scratch/accounted")"
if [ -n "$unaccounted" ]; then
  echo "FAIL [service_suite_coverage]: E2E suites missing from the workflow and exclusion manifest:"
  echo "$unaccounted"
  failed=true
fi

unknown="$(comm -13 "$scratch/all" "$scratch/accounted")"
if [ -n "$unknown" ]; then
  echo "FAIL [service_suite_coverage]: accounted suites that do not exist:"
  echo "$unknown"
  failed=true
fi

base_manifest="${SERVICE_SUITE_BASE_MANIFEST:-}"
skipped_growth=false
if [ -z "$base_manifest" ]; then
  if ! git -C "$REPO_DIR" rev-parse --verify --quiet "$BASE_REF^{commit}" >/dev/null 2>&1; then
    git -C "$REPO_DIR" fetch --quiet --depth=1 origin main 2>/dev/null || true
  fi
  if ! git -C "$REPO_DIR" rev-parse --verify --quiet "$BASE_REF^{commit}" >/dev/null 2>&1; then
    if [ "${SERVICE_SUITE_ALLOW_NO_BASE:-0}" = "1" ]; then
      echo "NOTE [service_suite_coverage]: $BASE_REF unavailable; skipping the no-growth comparison (SERVICE_SUITE_ALLOW_NO_BASE=1, local opt-out)."
      skipped_growth=true
    else
      echo "FAIL [service_suite_coverage]: cannot resolve base ref $BASE_REF, so the"
      echo "  no-growth ratchet cannot be verified - failing closed. Ensure $BASE_REF is"
      echo "  fetched (CI fetches it before this guard); for a local run without a base"
      echo "  ref, set SERVICE_SUITE_ALLOW_NO_BASE=1."
      exit 1
    fi
  elif git -C "$REPO_DIR" cat-file -e "$BASE_REF:$MANIFEST_REPO_PATH" 2>/dev/null; then
    base_manifest="$scratch/base_manifest"
    if ! git -C "$REPO_DIR" show "$BASE_REF:$MANIFEST_REPO_PATH" > "$base_manifest" 2>/dev/null; then
      echo "FAIL [service_suite_coverage]: $MANIFEST_REPO_PATH exists on $BASE_REF but could"
      echo "  not be read, so the no-growth ratchet cannot be verified - failing closed."
      exit 1
    fi
  fi
fi

if [ -n "$base_manifest" ]; then
  parse_manifest "$base_manifest" | sort -u > "$scratch/base_excluded"
  growth="$(comm -13 "$scratch/base_excluded" "$scratch/excluded_unique")"
  if [ -n "$growth" ]; then
    echo "FAIL [service_suite_coverage]: exclusion debt grew relative to $BASE_REF:"
    echo "$growth"
    failed=true
  fi
elif [ "$skipped_growth" != "true" ]; then
  echo "NOTE [service_suite_coverage]: no exclusion manifest on $BASE_REF yet (introducing the guard); skipping the no-growth comparison."
fi

if [ "$failed" = "true" ]; then
  exit 1
fi

included_count="$(wc -l < "$scratch/included_unique" | tr -d '[:space:]')"
excluded_count="$(wc -l < "$scratch/excluded_unique" | tr -d '[:space:]')"
if [ -n "$base_manifest" ]; then
  echo "OK: all E2E suites accounted for ($included_count included, $excluded_count excluded); exclusion debt did not grow."
else
  echo "OK: all E2E suites accounted for ($included_count included, $excluded_count excluded); no-growth comparison skipped."
fi
