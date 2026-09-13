#!/usr/bin/env bash
# ABOUTME: Measures representative Flutter test buckets without writing repo files.
# ABOUTME: Emits JSONL timing records to /tmp by default for before/after comparisons.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DEFAULT_OUTPUT="/tmp/divine-test-timing-$(date +%Y%m%d-%H%M%S).jsonl"
OUTPUT="${DIVINE_TEST_TIMING_OUTPUT:-$DEFAULT_OUTPUT}"
MODE="quick"
FAILED=0
VERY_GOOD_BIN=""

usage() {
  cat <<'USAGE'
Usage: scripts/test_timing_baseline.sh [--quick|--full|--selftest] [--output path]

Runs representative test buckets and writes JSONL records with duration,
exit status, and log path. The default output path is /tmp so normal timing
runs do not dirty the repository.

Modes:
  --quick  app unit, router, golden, and VGV opt-out count buckets
  --full   quick buckets plus services, widgets, selected packages, and
           the CI-equivalent VGV optimized command
  --selftest  verify the Very Good CLI resolver without running test buckets
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --quick)
      MODE="quick"
      shift
      ;;
    --full)
      MODE="full"
      shift
      ;;
    --selftest)
      MODE="selftest"
      shift
      ;;
    --output)
      if [ "$#" -lt 2 ]; then
        echo "Missing value for --output" >&2
        exit 2
      fi
      OUTPUT="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

mkdir -p "$(dirname "$OUTPUT")"
LOG_DIR="$(mktemp -d "${TMPDIR:-/tmp}/divine-test-timing.XXXXXX")"

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

run_bucket() {
  local name="$1"
  shift
  local log_file="$LOG_DIR/${name}.log"
  local command="$*"
  local start_epoch
  local end_epoch
  local duration
  local status

  echo "==> $name"
  echo "    $command"
  start_epoch="$(date +%s)"
  "$@" >"$log_file" 2>&1
  status=$?
  end_epoch="$(date +%s)"
  duration=$((end_epoch - start_epoch))

  printf '{"bucket":"%s","status":%s,"duration_seconds":%s,"command":"%s","log":"%s"}\n' \
    "$(json_escape "$name")" \
    "$status" \
    "$duration" \
    "$(json_escape "$command")" \
    "$(json_escape "$log_file")" >>"$OUTPUT"

  if [ "$status" -eq 0 ]; then
    echo "    PASS in ${duration}s"
  else
    FAILED=1
    echo "    FAIL in ${duration}s (log: $log_file)"
  fi
}

run_shell_bucket() {
  local name="$1"
  local command="$2"
  run_bucket "$name" bash -lc "$command"
}

# Resolve the vgv-optimized bucket's executable and check it against the same
# pin `mise run test` and CI use so a stale local install doesn't produce a
# timing record for the wrong CLI mechanics.
check_very_good_cli_version() {
  local pinned
  pinned="$(grep -m1 '^VERY_GOOD_CLI_VERSION=' "$PROJECT_ROOT/mise.toml" | cut -d= -f2)"
  if [ -z "$pinned" ]; then
    echo "Could not read the pinned Very Good CLI version from mise.toml." >&2
    return 1
  fi

  local pub_cache_bin="${PUB_CACHE:-$HOME/.pub-cache}/bin"
  VERY_GOOD_BIN=""
  if command -v very_good >/dev/null 2>&1; then
    VERY_GOOD_BIN="$(command -v very_good)"
  elif [ -x "$pub_cache_bin/very_good" ]; then
    VERY_GOOD_BIN="$pub_cache_bin/very_good"
  fi

  if [ -z "$VERY_GOOD_BIN" ]; then
    echo "very_good CLI not found on PATH or in $pub_cache_bin." >&2
    echo "Install the pinned version with: dart pub global activate very_good_cli $pinned" >&2
    return 1
  fi

  local current
  current="$("$VERY_GOOD_BIN" --version | awk 'NR == 1 { print $1 }')"
  if [ "$current" != "$pinned" ]; then
    echo "very_good CLI at $VERY_GOOD_BIN is $current, but $pinned is pinned." >&2
    echo "Install the pinned version with: dart pub global activate very_good_cli $pinned" >&2
    return 1
  fi
}

run_selftest() {
  local fixture_root
  fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/divine-vgv-resolver.XXXXXX")"
  trap "rm -rf '$fixture_root'" EXIT
  mkdir -p "$fixture_root/bin"

  local pinned
  pinned="$(grep -m1 '^VERY_GOOD_CLI_VERSION=' "$PROJECT_ROOT/mise.toml" | cut -d= -f2)"
  printf '#!/usr/bin/env bash\nprintf "%%s\\n" "%s"\n' "$pinned" \
    >"$fixture_root/bin/very_good"
  chmod +x "$fixture_root/bin/very_good"

  if ! PUB_CACHE="$fixture_root" PATH="/usr/bin:/bin" check_very_good_cli_version; then
    echo "SELFTEST FAIL: pub-cache-only executable was not accepted." >&2
    return 1
  fi
  if [ "${VERY_GOOD_BIN:-}" != "$fixture_root/bin/very_good" ]; then
    echo "SELFTEST FAIL: resolved executable was not preserved for the bucket." >&2
    return 1
  fi

  echo "SELFTEST PASS: pub-cache-only executable is preserved for execution."
}

if [ "$MODE" = "selftest" ]; then
  run_selftest
  exit $?
fi

cd "$PROJECT_ROOT"
: >"$OUTPUT"

echo "Writing timing records to $OUTPUT"
echo "Command logs are in $LOG_DIR"

run_bucket app-unit flutter test test/unit --no-pub --reporter=compact
run_bucket app-router flutter test test/router --no-pub --reporter=compact
# Off Linux this bucket always fails: golden references are rendered on
# the Ubuntu runner and Skia antialiases differently per OS. The timing
# is still the measurement of interest, so record it without the verdict.
run_bucket app-goldens scripts/golden.sh verify
run_shell_bucket vgv-opt-out-count \
  "grep -rln \"skip_very_good_optimization\" test | wc -l | tr -d '[:space:]'"

if [ "$MODE" = "full" ]; then
  run_bucket app-services flutter test test/services --no-pub --reporter=compact
  run_bucket app-widgets flutter test test/widgets --no-pub --reporter=compact
  run_bucket package-models flutter test packages/models/test --no-pub --reporter=compact
  run_bucket package-db-client flutter test packages/db_client/test --no-pub --reporter=compact
  if check_very_good_cli_version; then
    run_bucket vgv-optimized "$VERY_GOOD_BIN" test --optimization --concurrency=4 \
      --exclude-tags integration --test-randomize-ordering-seed random
  else
    echo "==> vgv-optimized"
    echo "    SKIP (see prerequisite error above)"
    FAILED=1
  fi
fi

echo "Done. Timing JSONL: $OUTPUT"
exit "$FAILED"
