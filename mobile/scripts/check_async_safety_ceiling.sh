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

emit_current() {
  local output_file="${ASYNC_SAFETY_DIAGNOSTICS_FILE:-}"
  local saved_options=""

  if [[ -z "$output_file" ]]; then
    output_file="$(mktemp)"
    saved_options="$(mktemp)"
    cp "$MOBILE_DIR/analysis_options.yaml" "$saved_options"

    cleanup_async_analysis() {
      cp "$saved_options" "$MOBILE_DIR/analysis_options.yaml"
      rm -f "$saved_options" "$output_file"
    }
    trap cleanup_async_analysis EXIT HUP INT TERM

    awk '
      !/^[[:space:]]+(discarded_futures|unawaited_futures):[[:space:]]+ignore[[:space:]]*$/
    ' "$saved_options" > "$MOBILE_DIR/analysis_options.yaml"

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
    still_suppressed="$(grep -nE "$suppression_re" \
      "$MOBILE_DIR/analysis_options.yaml" || true)"
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

    cp "$saved_options" "$MOBILE_DIR/analysis_options.yaml"
    rm -f "$saved_options"
    saved_options=""
    trap - EXIT HUP INT TERM

    # Dart analyze uses 2 for warnings and 3 for errors. Exit 1 is an analyzer
    # invocation/infrastructure failure, not a clean result.
    if [[ "$analyzer_status" -ne 0 &&
      "$analyzer_status" -ne 2 &&
      "$analyzer_status" -ne 3 ]]; then
      cat "$output_file" >&2
      rm -f "$output_file"
      echo "Analyzer failed with exit code $analyzer_status." >&2
      return "$analyzer_status"
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
