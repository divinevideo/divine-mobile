#!/usr/bin/env bash
# Async-safety analyzer ratchet (#3342): unawaited_futures and
# discarded_futures remain temporarily ignored globally, but every existing
# finding is frozen as a per-rule, per-file ceiling. The issue assignee owns the
# baseline; anyone touching an affected file owns classifying its futures and
# locking in any reduction. New files and increased counts fail CI.
#
# The detector removes only these two ignores from a temporary copy of the app's
# analyzer configuration, runs the real Dart analyzer over the same app paths as
# CI, and restores the configuration before comparing results. This deliberately
# uses type resolution rather than a source-text approximation.
#
# Regenerate only after fixing findings:
#   UPDATE_BASELINE=1 bash mobile/scripts/check_async_safety_ceiling.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TAB="$(printf '\t')"

RATCHET_LABEL="async_safety_ceiling"
BASELINE_FILE="${ASYNC_SAFETY_BASELINE_FILE:-$SCRIPT_DIR/baseline/async_safety_counts.txt}"
BASELINE_REPO_PATH="mobile/scripts/baseline/async_safety_counts.txt"
BASE_REF="${ASYNC_SAFETY_BASELINE_BASE_REF:-origin/main}"
ALLOW_NO_BASE="${ASYNC_SAFETY_CEILING_ALLOW_NO_BASE:-0}"
ALLOW_NO_BASE_VAR="ASYNC_SAFETY_CEILING_ALLOW_NO_BASE"
REQUIRE_BASELINE_UPDATE_ON_DECREASE=1
NEW_HINT="Await the future, return it, or explicitly mark an intentional fire-and-forget operation with unawaited(). Do not raise this baseline. See #3342."
STALE_HINT="Async-safety findings were removed."
FOOTER="unawaited_futures and discarded_futures are frozen per rule and file.
The #3342 owner and each affected file's owner must drive these counts to zero."

OPTIONS_FILE="$MOBILE_DIR/analysis_options.yaml"
# The rewrite happens inside the `$(emit_current)` subshell but the restore has
# to work from the top-level shell, and a subshell shares neither its parent's
# traps nor its `local`s. A named path is what bridges the two; `$$` is the
# top-level PID and is unchanged in a subshell, so a second concurrent run gets
# a different name and can never restore, or delete, a backup it does not own.
OPTIONS_BACKUP_PREFIX="$MOBILE_DIR/.analysis_options.yaml.ratchet-backup"
OPTIONS_BACKUP="$OPTIONS_BACKUP_PREFIX.$$"

# At script scope, not inside emit_current: the suppression assertion's
# `return 1`, a failing analyzer, and a SIGTERM from CI cancellation or the
# local `timeout`-wrapped ratchet runner all unwind through the top-level shell.
restore_analysis_options() {
  if [[ -f "$OPTIONS_BACKUP" ]]; then
    cp "$OPTIONS_BACKUP" "$OPTIONS_FILE"
    rm -f "$OPTIONS_BACKUP"
  fi
}
trap restore_analysis_options EXIT HUP INT TERM

emit_current() {
  local output_file="${ASYNC_SAFETY_DIAGNOSTICS_FILE:-}"

  if [[ -z "$output_file" ]]; then
    output_file="$(mktemp)"

    local stray
    stray="$(ls "$OPTIONS_BACKUP_PREFIX."* 2>/dev/null || true)"
    if [[ -n "$stray" ]]; then
      echo "FAIL [$RATCHET_LABEL]: a rewrite of analysis_options.yaml is already" >&2
      echo "  in flight, or a previous run was killed before restoring it:" >&2
      echo "$stray" | sed 's/^/    /' >&2
      echo "  Refusing to continue: taking the already-rewritten file as this" >&2
      echo "  run's \"original\" is how both suppressions get deleted for good." >&2
      echo "  -> Wait for the other run, or if none is in progress restore from" >&2
      echo "     the backup above and delete it:" >&2
      echo "       cp <backup> '$OPTIONS_FILE' && rm <backup>" >&2
      return 1
    fi
    cp "$OPTIONS_FILE" "$OPTIONS_BACKUP"

    awk '
      !/^[[:space:]]+(discarded_futures|unawaited_futures):[[:space:]]+ignore[[:space:]]*$/
    ' "$OPTIONS_BACKUP" > "$OPTIONS_FILE"

    # The awk above matches one exact spelling. Reformat either line -- add a
    # trailing comment, requote it, reindent it, or switch it to `false` under
    # `linter: rules:` -- and the rewrite silently keeps the suppression, the
    # analyzer reports neither rule, and every baselined key reads as STALE.
    # The engine then prints UPDATE_BASELINE as the remedy, and running it
    # writes an EMPTY baseline: the guard deletes itself and stays green. So
    # assert the suppression is actually gone before trusting the analysis.
    local suppression_re still_suppressed
    suppression_re="^[[:space:]]*-?[[:space:]]*[\"']?"
    suppression_re+="(discarded_futures|unawaited_futures)[\"']?[[:space:]]*:"
    suppression_re+="[[:space:]]*[\"']?(ignore|false)[\"']?[[:space:]]*(#.*)?$"
    still_suppressed="$(grep -nE "$suppression_re" "$OPTIONS_FILE" || true)"
    if [[ -n "$still_suppressed" ]]; then
      echo "FAIL [$RATCHET_LABEL]: analysis_options.yaml still suppresses a" >&2
      echo "  tracked rule after the temporary rewrite, so the analyzer would" >&2
      echo "  report zero findings and the whole baseline would read as STALE:" >&2
      echo "$still_suppressed" | sed 's/^/    /' >&2
      echo "  -> Update the awk filter in $(basename "${BASH_SOURCE[0]}") to match the" >&2
      echo "     current spelling. Do NOT regenerate the baseline: that would" >&2
      echo "     erase all tracked async-safety debt. See #3342." >&2
      return 1
    fi

    local analyzer_status=0
    (
      cd "$MOBILE_DIR"
      dart analyze --format machine lib test integration_test tools
    ) > "$output_file" 2>&1 || analyzer_status=$?

    restore_analysis_options

    # Dart analyze uses 2 for warnings and 3 for errors; a bad invocation exits
    # 64. Accept only the three result codes.
    if [[ "$analyzer_status" -ne 0 &&
      "$analyzer_status" -ne 2 &&
      "$analyzer_status" -ne 3 ]]; then
      cat "$output_file" >&2
      rm -f "$output_file"
      echo "Analyzer failed with exit code $analyzer_status." >&2
      return "$analyzer_status"
    fi

    # Exit 3 covers "the tree does not resolve" as well as "the tree is fine but
    # has errors", and the two are not interchangeable here: both tracked rules
    # are type-driven, so an unresolved import silences them wherever the type
    # is unknown. With no mobile/.dart_tool at all the analyzer reports ZERO of
    # either rule and still exits 3 -- and a linked worktree starts every
    # session that way, because the session-end hook deletes .dart_tool. Left
    # unchecked the guard reads that as "all 489 keys removed" and prints
    # UPDATE_BASELINE as the remedy, which writes an empty baseline and quietly
    # deletes the guard. Stale codegen strips the same way, per-subtree.
    local unresolved
    unresolved="$(grep -c '|URI_DOES_NOT_EXIST|' "$output_file" || true)"
    if [[ "$unresolved" -gt 0 ]]; then
      echo "FAIL [$RATCHET_LABEL]: the analyzed tree does not resolve" >&2
      echo "  ($unresolved unresolved import(s)). Both tracked rules need type" >&2
      echo "  resolution, so these counts are undercounts, not reductions." >&2
      echo "  Do NOT regenerate the baseline from this run." >&2
      echo "  -> cd mobile && flutter pub get" >&2
      echo "  -> cd mobile && dart run build_runner build --delete-conflicting-outputs" >&2
      grep '|URI_DOES_NOT_EXIST|' "$output_file" | head -5 | sed 's/^/    /' >&2
      rm -f "$output_file"
      return 1
    fi
  fi

  awk -F '|' -v root="$MOBILE_DIR/" '
    $3 == "UNAWAITED_FUTURES" || $3 == "DISCARDED_FUTURES" {
      path = $4
      sub("^" root, "", path)
      counts[tolower($3) "|" path]++
    }
    END {
      for (key in counts) printf "%s\t%d\n", key, counts[key]
    }
  ' "$output_file" | LC_ALL=C sort -t "$TAB" -k1,1

  if [[ -z "${ASYNC_SAFETY_DIAGNOSTICS_FILE:-}" ]]; then
    rm -f "$output_file"
  fi
}

print_baseline_header() {
  cat <<'EOF'
# Frozen baseline: analyzer-reported unawaited_futures and discarded_futures,
# stored as rule|relpath<TAB>count. Generated by
# scripts/check_async_safety_ceiling.sh. Each count may only SHRINK.
# Owner: issue #3342 (NotThatKindOfDrLiz); affected-file owners must classify
# their futures and reduce the baseline when they touch these paths.
EOF
}

# shellcheck source=lib/numeric_ratchet.sh
source "$SCRIPT_DIR/lib/numeric_ratchet.sh"
run_numeric_ratchet
