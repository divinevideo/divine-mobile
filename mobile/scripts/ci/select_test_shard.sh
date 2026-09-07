#!/usr/bin/env bash
# ABOUTME: Reduces mobile/test to one deterministic shard of *_test.dart files.
# ABOUTME: Lets `very_good test --optimization` build a per-shard merged bundle.

# Mobile CI's `Tests` job is the workflow's critical path. `very_good test
# --optimization` collapses every untagged test file into a single
# .test_optimizer.dart suite — one process — so `--concurrency=4` has nothing
# left to schedule once the skip_very_good_optimization files are done (the
# count is tracked in test/vgv_tag_baseline.txt), and the bulk of the run is
# single-core on a 4-vCPU runner.
#
# very_good has no "run this subset" flag, so the shard is selected by removing
# the other shards' *_test.dart files from the checkout before very_good scans
# it. Everything that is not a test entry point — helpers, mocks, fixtures,
# builders, flutter_test_config.dart — is left in place, because the tests that
# remain still import it.
#
# Assignment hashes each relative path into a bucket. Unlike assigning by the
# path's position in a sorted list, this keeps every existing file in the same
# shard when another test is added, removed, or renamed. File counts are only a
# rough proxy for runtime cost, so the small loss of round-robin count balance
# is preferable to unrelated pull requests reshuffling merged-isolate peers.
#
# This DELETES files. It refuses to run outside CI without --force.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

TOTAL=""
INDEX=""
DRY_RUN=0
FORCE=0

usage() {
  cat <<'USAGE'
Usage: scripts/ci/select_test_shard.sh --total N --index I [--dry-run] [--force]

Removes every mobile/test/**/*_test.dart file that does not belong to shard I
of N (0-based), leaving non-test sources untouched.

  --total N   Number of shards (>= 1).
  --index I   This shard, 0 <= I < N.
  --dry-run   Print what would be kept and removed; change nothing.
  --force     Allow running outside CI (this deletes files — be sure).
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --total) TOTAL="${2:-}"; shift 2 ;;
    --index) INDEX="${2:-}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --force) FORCE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

case "$TOTAL" in
  ''|*[!0-9]*) echo "❌ --total must be a positive integer (got '${TOTAL}')." >&2; exit 2 ;;
esac
case "$INDEX" in
  ''|*[!0-9]*) echo "❌ --index must be a non-negative integer (got '${INDEX}')." >&2; exit 2 ;;
esac
if [ "$TOTAL" -lt 1 ]; then
  echo "❌ --total must be >= 1 (got '${TOTAL}')." >&2
  exit 2
fi
if [ "$INDEX" -ge "$TOTAL" ]; then
  echo "❌ --index must satisfy 0 <= index < total (got '${INDEX}' of '${TOTAL}')." >&2
  exit 2
fi
if [ "$DRY_RUN" -eq 0 ] && [ "$FORCE" -eq 0 ] && [ "${CI:-}" != "true" ]; then
  echo "❌ Refusing to delete test files outside CI. Use --dry-run, or --force if you mean it." >&2
  exit 2
fi

cd "$PROJECT_ROOT"

all_tests_file="$(mktemp)"
golden_tests_file="$(mktemp)"
shard_assignments_file="$(mktemp)"
trap 'rm -f "$all_tests_file" "$golden_tests_file" "$shard_assignments_file"' EXIT

# test/goldens/ belongs to the dedicated `goldens` job, not to any shard.
# Image goldens cannot survive this job: `very_good test --optimization`
# merges every file into one isolate, google_fonts registers its families
# asynchronously, and whichever test runs first lays out with the fallback
# font — so the same golden renders at a different size run-to-run. The
# goldens job runs them with `flutter test` instead (one isolate per file,
# fonts loaded up front). Remove them from every shard so the merged bundle
# cannot pick them up, rather than leaving them to run four times.
: > "$golden_tests_file"
if [ -d test/goldens ]; then
  find test/goldens -type f -name '*_test.dart' | LC_ALL=C sort > "$golden_tests_file"
fi
find test -type f -name '*_test.dart' -not -path 'test/goldens/*' \
  | LC_ALL=C sort > "$all_tests_file"

total_files=$(wc -l < "$all_tests_file" | tr -d '[:space:]')
if [ "$total_files" -eq 0 ]; then
  echo "❌ Found no shardable *_test.dart files under test/ (goldens are
excluded and run by the Goldens job). Refusing to proceed." >&2
  exit 1
fi

kept=0
removed=0
LC_ALL=C awk -v total="$TOTAL" '
  BEGIN { alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_./-" }
  {
    bucket = 0
    for (i = 1; i <= length($0); i++) {
      value = index(alphabet, substr($0, i, 1))
      if (value == 0) {
        print "Unsupported character in test path: " $0 > "/dev/stderr"
        exit 2
      }
      bucket = (bucket * 33 + value) % total
    }
    print bucket, $0
  }
' "$all_tests_file" > "$shard_assignments_file"

while read -r bucket file; do
  if [ "$bucket" -eq "$INDEX" ]; then
    kept=$((kept + 1))
  else
    removed=$((removed + 1))
    if [ "$DRY_RUN" -eq 0 ]; then
      rm -f "$file"
    fi
  fi
done < "$shard_assignments_file"

if [ "$kept" -eq 0 ]; then
  echo "❌ Shard ${INDEX}/${TOTAL} selected 0 test files. Refusing to report a vacuous pass." >&2
  exit 1
fi

goldens=0
while IFS= read -r file; do
  goldens=$((goldens + 1))
  if [ "$DRY_RUN" -eq 0 ]; then
    rm -f "$file"
  fi
done < "$golden_tests_file"

verb="Kept"
[ "$DRY_RUN" -eq 1 ] && verb="Would keep"
echo "${verb} ${kept} of ${total_files} test files for shard ${INDEX} of ${TOTAL} (${removed} removed)."
# Announce the goldens rather than dropping them quietly: a silent exclusion
# reads as "the shards cover everything" when they deliberately do not.
excluded_verb="Excluded"
[ "$DRY_RUN" -eq 1 ] && excluded_verb="Would exclude"
echo "${excluded_verb} ${goldens} golden test file(s) under test/goldens/ — run by the 'goldens' job."
