#!/usr/bin/env bash
# ABOUTME: Runs every Mobile CI guard from scripts/ci/guards.tsv in parallel.
# ABOUTME: One job, N workers, per-guard logs replayed in manifest order.

# Mobile CI's guard steps used to be ~60 sequential workflow steps in one job.
# Each Dart-AST detector pays ~8s of VM start plus package:analyzer JIT on the
# runner before it parses a single file, so the job grew from 3 to 9 minutes
# between July and September 2026 and became the workflow's critical path
# (see docs/PERF_BASELINE.md). The guards are independent of each other, so
# this driver runs them `--jobs` wide on the runner's 4 vCPUs and replays each
# guard's captured output afterwards, in manifest order, so the log reads as
# if they had run one after another.
#
# Manifest format (scripts/ci/guards.tsv): one guard per line,
#   <name>TAB<flags>TAB<command>
# `#` lines and blank lines are ignored. `flags` is `-` or a comma-separated
# set of:
#   native    only run when --native true (the guard's inputs are native
#             platform config; see detect_mobile_ci_scope.sh)
#   advisory  never fails the job; a non-zero exit or a `WARN ` line becomes
#             a GitHub warning annotation instead
# The command runs through `bash -c` with mobile/ as the working directory.
#
# Exit codes: 0 every non-advisory guard passed, 1 at least one failed,
# 2 the driver itself could not run (bad manifest, bad flag).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
TAB="$(printf '\t')"

MANIFEST="${GUARDS_MANIFEST:-$SCRIPT_DIR/guards.tsv}"
JOBS="${GUARDS_JOBS:-}"
NATIVE="${GUARDS_NATIVE:-true}"
LIST_ONLY=0

usage() {
  cat <<'USAGE'
Usage: scripts/ci/run_guards.sh [--manifest FILE] [--jobs N] [--native true|false] [--list]

Runs every guard listed in the manifest (default scripts/ci/guards.tsv) in
parallel and replays their output in manifest order.

  --manifest FILE   Guard manifest to run (default: scripts/ci/guards.tsv).
  --jobs N          Parallel workers (default: number of online CPUs on
                    Linux; 1 on macOS, where concurrent `dart run` codesign
                    steps clobber each other).
  --native BOOL     Whether guards flagged `native` run (default: true).
  --list            Print the guards and whether each would run; run nothing.
USAGE
}

worker_mode=0
WORK_DIR=""
WORKER_INDEX=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --manifest) MANIFEST="${2:-}"; shift 2 ;;
    --jobs) JOBS="${2:-}"; shift 2 ;;
    --native) NATIVE="${2:-}"; shift 2 ;;
    --list) LIST_ONLY=1; shift ;;
    --worker) worker_mode=1; WORK_DIR="${2:-}"; WORKER_INDEX="${3:-}"; shift 3 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

case "$NATIVE" in
  true|false) ;;
  *) echo "--native must be true or false, got: ${NATIVE}" >&2; exit 2 ;;
esac

# --- worker: run one guard by its index, capture output + status ------------
# Invoked by the parent through xargs as `--worker DIR INDEX`; never called
# directly. Reads guard INDEX (1-based line) from the normalized manifest the
# parent wrote to DIR.
if [ "$worker_mode" -eq 1 ]; then
  index="$WORKER_INDEX"
  line="$(sed -n "${index}p" "$WORK_DIR/guards.tsv")"
  command="${line##*"$TAB"}"
  start="$(date +%s)"
  rc=0
  (cd "$MOBILE_DIR" && bash -c "$command") > "$WORK_DIR/$index.log" 2>&1 || rc=$?
  end="$(date +%s)"
  printf '%s\t%s\n' "$rc" "$((end - start))" > "$WORK_DIR/$index.status"
  exit 0
fi

# --- parent: parse the manifest ---------------------------------------------
if [ ! -f "$MANIFEST" ]; then
  echo "Guard manifest not found: ${MANIFEST}" >&2
  exit 2
fi

names=()
flags=()
commands=()
line_no=0
while IFS= read -r raw || [ -n "$raw" ]; do
  line_no=$((line_no + 1))
  case "$raw" in
    ''|'#'*) continue ;;
  esac
  name="${raw%%"$TAB"*}"
  rest="${raw#*"$TAB"}"
  flag="${rest%%"$TAB"*}"
  command="${rest#*"$TAB"}"
  if [ "$name" = "$raw" ] || [ "$flag" = "$rest" ] || [ -z "$name" ] || [ -z "$flag" ] || [ -z "$command" ]; then
    echo "${MANIFEST}:${line_no}: expected <name>TAB<flags>TAB<command>, got: ${raw}" >&2
    exit 2
  fi
  case "$command" in
    *"$TAB"*)
      echo "${MANIFEST}:${line_no}: a command must not contain a tab: ${raw}" >&2
      exit 2 ;;
  esac
  for f in $(printf '%s' "$flag" | tr ',' ' '); do
    case "$f" in
      -|native|advisory) ;;
      *) echo "${MANIFEST}:${line_no}: unknown flag '${f}' (expected -, native, advisory)" >&2; exit 2 ;;
    esac
  done
  names+=("$name")
  flags+=("$flag")
  commands+=("$command")
done < "$MANIFEST"

total="${#names[@]}"
if [ "$total" -eq 0 ]; then
  echo "${MANIFEST}: no guards listed" >&2
  exit 2
fi

has_flag() { # $1 = flags field, $2 = flag
  case ",$1," in *",$2,"*) return 0 ;; *) return 1 ;; esac
}

should_run() { # $1 = index
  if has_flag "${flags[$1]}" native && [ "$NATIVE" != "true" ]; then
    return 1
  fi
  return 0
}

if [ "$LIST_ONLY" -eq 1 ]; then
  for i in $(seq 0 $((total - 1))); do
    if should_run "$i"; then state="run"; else state="skip"; fi
    printf '%s\t%s\t%s\t%s\n' "$state" "${names[$i]}" "${flags[$i]}" "${commands[$i]}"
  done
  exit 0
fi

if [ -z "$JOBS" ]; then
  # macOS defaults to serial. Most guards are `dart run` detectors, and on
  # macOS every `dart run` re-copies and re-codesigns the workspace's native
  # assets into the shared mobile/.dart_tool/lib/ before it executes. Run two
  # of them at once and they clobber each other mid-signature:
  #   Failed to codesign dylib .../.dart_tool/lib/libsqlite3mc.dylib:
  #   replacing existing signature ... No such file or directory
  # The guard then fails with an exit code that has nothing to do with its
  # ratchet, and which guard loses the race changes run to run — so a local
  # run reports 2-3 phantom failures out of 62 and hides real ones. Linux has
  # no codesigning step and no race, so CI keeps the full fan-out.
  # Override with --jobs N or GUARDS_JOBS to opt back in.
  if [ "$(uname -s)" = "Darwin" ]; then
    JOBS=1
  else
    JOBS="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)"
  fi
fi
if ! [[ "$JOBS" =~ ^[1-9][0-9]*$ ]]; then
  echo "--jobs must be a positive integer, got: ${JOBS}" >&2
  exit 2
fi

# --- parent: run --------------------------------------------------------------
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

: > "$WORK_DIR/guards.tsv"
: > "$WORK_DIR/queue"
for i in $(seq 0 $((total - 1))); do
  printf '%s\t%s\t%s\n' "${names[$i]}" "${flags[$i]}" "${commands[$i]}" >> "$WORK_DIR/guards.tsv"
  if should_run "$i"; then
    echo "$((i + 1))" >> "$WORK_DIR/queue"
  fi
done

runnable="$(wc -l < "$WORK_DIR/queue" | tr -d ' ')"
echo "Running ${runnable} of ${total} guards, ${JOBS} at a time (native guards: ${NATIVE})"
wall_start="$(date +%s)"
# `-n1` hands each worker one guard index; `-P` bounds the parallelism. The
# worker never exits non-zero for a failing guard, so xargs itself only fails
# when a worker could not run at all.
xargs -P "$JOBS" -n1 bash "$SCRIPT_DIR/run_guards.sh" --worker "$WORK_DIR" < "$WORK_DIR/queue"
wall="$(( $(date +%s) - wall_start ))"

# --- parent: replay in manifest order -----------------------------------------
on_actions=0
if [ "${GITHUB_ACTIONS:-}" = "true" ]; then on_actions=1; fi

group_start() { # $1 = title
  if [ "$on_actions" -eq 1 ]; then echo "::group::$1"; else echo; echo "=== $1 ==="; fi
}
group_end() {
  if [ "$on_actions" -eq 1 ]; then echo "::endgroup::"; fi
}
annotate() { # $1 = level (warning|error), $2 = title, $3 = message
  if [ "$on_actions" -eq 1 ]; then
    echo "::$1 title=$2::$3"
  else
    echo "$1: $2: $3"
  fi
}

passed=0
failed=0
skipped=0
cpu=0
failed_names=()
for i in $(seq 0 $((total - 1))); do
  n=$((i + 1))
  name="${names[$i]}"
  if ! should_run "$i"; then
    skipped=$((skipped + 1))
    echo "⏭️  ${name} — skipped (no native changes)"
    continue
  fi
  if [ ! -f "$WORK_DIR/$n.status" ]; then
    failed=$((failed + 1))
    failed_names+=("$name")
    annotate error "$name" "The guard never reported a status; the worker could not run it."
    continue
  fi
  IFS="$TAB" read -r rc secs < "$WORK_DIR/$n.status"
  cpu=$((cpu + secs))
  if has_flag "${flags[$i]}" advisory; then
    group_start "🟡 ${name} (${secs}s, advisory)"
    cat "$WORK_DIR/$n.log"
    group_end
    first_warn="$(grep -m1 '^WARN ' "$WORK_DIR/$n.log" || true)"
    if [ "$rc" -ne 0 ]; then
      annotate warning "${name} (advisory)" "Exited ${rc}. Advisory only — see the guard's log group above."
    elif [ -n "$first_warn" ]; then
      annotate warning "${name} (advisory)" "${first_warn} — advisory only, does not block CI; the full list is in the guard's log group."
    fi
    passed=$((passed + 1))
  elif [ "$rc" -eq 0 ]; then
    group_start "✅ ${name} (${secs}s)"
    cat "$WORK_DIR/$n.log"
    group_end
    passed=$((passed + 1))
  else
    group_start "❌ ${name} (${secs}s, exit ${rc})"
    cat "$WORK_DIR/$n.log"
    group_end
    annotate error "${name}" "Guard failed (exit ${rc}). Expand its ❌ group in the Guards job log for the diagnostic."
    failed=$((failed + 1))
    failed_names+=("$name")
  fi
done

echo
echo "Guards: ${passed} passed, ${failed} failed, ${skipped} skipped — ${wall}s wall, ${cpu}s summed"
if [ "$failed" -ne 0 ]; then
  echo "Failed:"
  for name in "${failed_names[@]}"; do echo "  - ${name}"; done
  exit 1
fi
