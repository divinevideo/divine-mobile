#!/usr/bin/env bash
# Service god-file ceiling ratchet (epic #4338): oversized Dart files under
# mobile/lib/services are frozen at their current line count in
# scripts/baseline/service_god_file_sizes.txt. A service file's ceiling may only
# ever DECREASE. CI fails if:
#   * a baselined service file grows past its recorded ceiling,
#   * a NEW service file crosses the oversized threshold,
#   * the branch baseline adds a service file or raises a ceiling vs origin/main.
#
# This deliberately does not replace check_file_size_ceiling.sh. The broad
# 800-line app-wide file-size check remains advisory per the #4339 team
# decision; this guard is the hard architecture ratchet for service-layer
# god-files that otherwise re-accumulate work while extraction lanes pause.
# For files covered by both checks, this hard service baseline is authoritative;
# the broad branch-to-main comparison remains advisory.
#
# Regenerate after shrinking/removing a service god-file (never to raise a
# ceiling):
#   UPDATE_BASELINE=1 bash mobile/scripts/check_service_god_file_ceiling.sh
# Usage:
#   bash mobile/scripts/check_service_god_file_ceiling.sh
#   (cd mobile && bash scripts/check_service_god_file_ceiling.sh)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TAB="$(printf '\t')"

RATCHET_LABEL="service_god_file_ceiling"
THRESHOLD="${SERVICE_GOD_FILE_THRESHOLD:-1500}"
SCAN_DIR="${SERVICE_GOD_FILE_SCAN_DIR:-$MOBILE_DIR/lib/services}"
PATH_PREFIX="${SERVICE_GOD_FILE_PATH_PREFIX:-$MOBILE_DIR}"
BASELINE_FILE="${SERVICE_GOD_FILE_BASELINE_FILE:-$SCRIPT_DIR/baseline/service_god_file_sizes.txt}"
BASELINE_REPO_PATH="${SERVICE_GOD_FILE_BASELINE_REPO_PATH:-mobile/scripts/baseline/service_god_file_sizes.txt}"
BASE_REF="${SERVICE_GOD_FILE_BASELINE_BASE_REF:-origin/main}"
ALLOW_NO_BASE="${SERVICE_GOD_FILE_CEILING_ALLOW_NO_BASE:-0}"
ALLOW_NO_BASE_VAR="SERVICE_GOD_FILE_CEILING_ALLOW_NO_BASE"

NEW_HINT="Do not grow service-layer god files under mobile/lib/services. Extract responsibilities behind repository/client boundaries, or keep the change out of the oversized service file. For an in-tree move, annotate the new baseline row with '# renamed-from: <old-key>' after reviewing the provenance. See epic #4338."
STALE_HINT="A service god-file was removed, renamed, or dropped below the oversized threshold. If this is paired with a NEW key for an in-tree move, UPDATE_BASELINE alone cannot approve the moved oversized service."
FOOTER="Service-layer god-file sizes are frozen and may only decrease. Keep new
work out of oversized services and continue the UI -> BLoC/Cubit -> Repository
-> Client extraction path from epic #4338."

emit_current() {
  find "$SCAN_DIR" \
    -type f -name '*.dart' \
    -not -path '*/.dart_tool/*' \
    -not -path '*/build/*' \
    ! -name '*.g.dart' ! -name '*.freezed.dart' ! -name '*.gr.dart' \
    ! -name '*.config.dart' ! -name '*.mocks.dart' \
    -print0 2>/dev/null \
  | while IFS= read -r -d '' f; do
      loc="$(wc -l < "$f" | tr -d '[:space:]')"
      if [[ "${loc:-0}" -gt "$THRESHOLD" ]]; then
        printf '%s\t%s\n' "${f#"$PATH_PREFIX"/}" "$loc"
      fi
    done \
  | LC_ALL=C sort -t "$TAB" -k1,1
}

service_god_file_repo_path() {
  local repo_root="$1" key="$2" prefix
  case "$PATH_PREFIX" in
    "$repo_root") prefix="" ;;
    "$repo_root"/*) prefix="${PATH_PREFIX#"$repo_root"/}/" ;;
    *) return 1 ;;
  esac
  printf '%s%s\n' "$prefix" "$key"
}

service_god_file_rename_claims() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  awk -F '\t' '
    /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
    $2 ~ /;[[:space:]]*renamed-from:/ {
      print "MALFORMED\t" $1 "\tsemicolon"
      next
    }
    $2 !~ /^[^#]*#[[:space:]]*renamed-from:/ { next }
    $2 !~ /^(0|[1-9][0-9]*)[[:space:]]*#[[:space:]]*renamed-from:[[:space:]]*[^#;[:space:]]+[[:space:]]*$/ {
      print "MALFORMED\t" $1 "\tshape"
      next
    }
    {
      count=$2
      sub(/[[:space:]]*#.*/, "", count)
      old=$2
      sub(/^[^#]*#[[:space:]]*renamed-from:[[:space:]]*/, "", old)
      sub(/[[:space:]]*$/, "", old)
      print "CLAIM\t" $1 "\t" count "\t" old
    }
  ' "$file"
}

# Claims already recorded on the base ref are settled. Their key is not an
# added row, so the claim grants nothing, and re-checking it makes the renamed
# service a tripwire: the next line-count change breaks the count equality the
# settled test used to rely on and the row reports a rename chain instead —
# including after UPDATE_BASELINE, which carries the annotation forward by key.
# A settled claim also went on reserving its old key against a later, genuine
# move. Matched on the path pair rather than the count, so a shrink stays
# settled; a claim the branch introduces on a key the base ref already has is
# still a chain or a swap and still fails below.
service_god_file_unsettled_claims() {
  local claims="$1" repo_root="$2" base_baseline base_claims=""
  base_baseline="$(mktemp)"
  if git -C "$repo_root" show "$BASE_REF:$BASELINE_REPO_PATH" > "$base_baseline" 2>/dev/null; then
    base_claims="$(service_god_file_rename_claims "$base_baseline")"
  fi
  rm -f "$base_baseline"
  awk -F "$TAB" '
    NR == FNR { if ($1 == "CLAIM") settled[$2 SUBSEP $4] = 1; next }
    NF == 0 { next }
    $1 == "CLAIM" && (($2 SUBSEP $4) in settled) { next }
    { print }
  ' <(printf '%s\n' "$base_claims") <(printf '%s\n' "$claims")
}

validate_baseline_growth_policy() {
  local main_f="$1" base_f="$2" cur_f="$3" repo_root="$4" base_status="$5"
  local claims claim_kind new_key new_count old_key old_count current_count base_new_count
  local old_path new_path rename_status merge_base fail=0
  SERVICE_GOD_FILE_VALID_RENAME_KEYS=""

  if [[ "$PATH_PREFIX" != "$repo_root" && "$PATH_PREFIX" != "$repo_root"/* ]]; then
    echo "FAIL [$RATCHET_LABEL]: service path prefix is outside the Git repository: $PATH_PREFIX"
    return 1
  fi

  claims="$(service_god_file_rename_claims "$BASELINE_FILE")"
  if [[ "$base_status" -eq 0 ]]; then
    claims="$(service_god_file_unsettled_claims "$claims" "$repo_root")"
  fi

  while IFS="$TAB" read -r claim_kind new_key new_count old_key; do
    [[ -z "$claim_kind" ]] && continue
    if [[ "$claim_kind" == "MALFORMED" ]]; then
      echo "FAIL [$RATCHET_LABEL]: malformed renamed-from annotation on $new_key"
      echo "  -> use exactly '<count> # renamed-from: <old-key>'; one claim per row"
      fail=1
      continue
    fi
    # Shape validation remains active without a base, but provenance and count
    # validation require MAIN_F, which is usable only when base_status is zero.
    [[ "$base_status" -ne 0 ]] && continue

    if [[ "$(printf '%s\n' "$claims" | awk -F "$TAB" -v key="$new_key" '$1 == "CLAIM" && $2 == key { n++ } END { print n+0 }')" -gt 1 ]]; then
      echo "FAIL [$RATCHET_LABEL]: duplicate rename claim for new key $new_key"
      fail=1
      continue
    fi
    if [[ "$(printf '%s\n' "$claims" | awk -F "$TAB" -v key="$old_key" '$1 == "CLAIM" && $4 == key { n++ } END { print n+0 }')" -gt 1 ]]; then
      echo "FAIL [$RATCHET_LABEL]: old key $old_key is claimed more than once"
      fail=1
      continue
    fi
    base_new_count="$(awk -F "$TAB" -v key="$new_key" '$1 == key { print $2; exit }' "$main_f")"
    current_count="$(awk -F "$TAB" -v key="$new_key" '$1 == key { print $2; exit }' "$cur_f")"
    if [[ -n "$base_new_count" ]]; then
      echo "FAIL [$RATCHET_LABEL]: rename chains and swaps are not supported: $new_key already exists on $BASE_REF"
      fail=1
      continue
    fi
    old_count="$(awk -F "$TAB" -v key="$old_key" '$1 == key { print $2; exit }' "$main_f")"
    if [[ -z "$old_count" ]]; then
      echo "FAIL [$RATCHET_LABEL]: renamed-from old key is not in $BASE_REF: $old_key"
      fail=1
      continue
    fi
    if awk -F "$TAB" -v key="$old_key" '$1 == key { found=1 } END { exit !found }' "$base_f" ||
       awk -F "$TAB" -v key="$old_key" '$1 == key { found=1 } END { exit !found }' "$cur_f"; then
      echo "FAIL [$RATCHET_LABEL]: renamed-from old key remains in the branch: $old_key"
      fail=1
      continue
    fi
    if [[ "$new_count" != "$current_count" ]]; then
      echo "FAIL [$RATCHET_LABEL]: renamed key $new_key ceiling must equal its current count ($current_count), got $new_count"
      fail=1
      continue
    fi
    if (( 10#$new_count > 10#$old_count )); then
      echo "FAIL [$RATCHET_LABEL]: renamed key $new_key exceeds old ceiling $old_key (was $old_count -> now $new_count)"
      fail=1
      continue
    fi
    old_path="$(service_god_file_repo_path "$repo_root" "$old_key")"
    new_path="$(service_god_file_repo_path "$repo_root" "$new_key")"
    merge_base="$(git -C "$repo_root" merge-base "$BASE_REF" HEAD 2>/dev/null || true)"
    if [[ -z "$merge_base" ]]; then
      echo "FAIL [$RATCHET_LABEL]: cannot verify rename claim without a merge base for $BASE_REF"
      fail=1
      continue
    fi
    rename_status="$(git -C "$repo_root" -c core.quotePath=false diff --find-renames=15% --name-status "$BASE_REF"...HEAD || true)"
    if ! awk -F "$TAB" -v old="$old_path" -v new="$new_path" '
      $1 ~ /^R[0-9]+$/ && $2 == old && $3 == new { found=1 }
      END { exit !found }
    ' <<< "$rename_status"; then
      echo "FAIL [$RATCHET_LABEL]: rename claim $new_key <- $old_key is not a Git rename"
      echo "  -> expected $old_path to be renamed to $new_path vs the merge base with $BASE_REF"
      fail=1
      continue
    fi
    SERVICE_GOD_FILE_VALID_RENAME_KEYS="${SERVICE_GOD_FILE_VALID_RENAME_KEYS}${new_key}"$'\n'
  done <<< "$claims"
  return "$fail"
}

filter_added_baseline_growth() {
  local added_line key
  while IFS= read -r added_line; do
    [[ -z "$added_line" ]] && continue
    key="${added_line%%"$TAB"*}"
    if ! printf '%s' "${SERVICE_GOD_FILE_VALID_RENAME_KEYS:-}" | awk -v key="$key" '$0 == key { found=1 } END { exit !found }'; then
      printf '%s\n' "$added_line"
    else
      echo "NOTE [$RATCHET_LABEL]: honoured rename claim for $key" >&2
    fi
  done
}

print_baseline_header() {
  cat <<EOF
# Frozen baseline: Dart files under mobile/lib/services over ${THRESHOLD} lines,
# each with its current line count as a CEILING (format: relpath<TAB>loc).
# Generated by scripts/check_service_god_file_ceiling.sh. A ceiling may only
# SHRINK; more lines, a new oversized service file, or a raised ceiling fails CI
# vs ${BASE_REF}. Epic: #4338.
# This hard service baseline is authoritative over the broad advisory check for
# service god-file ceilings.
# A verified in-tree move may replace its old row with:
# <new-relpath><TAB><current-count> # renamed-from: <old-relpath>
# Rename chains and swaps are deliberately unsupported.
# Regenerate after shrinking/removing: UPDATE_BASELINE=1 bash scripts/check_service_god_file_ceiling.sh
EOF
}

# shellcheck source=lib/numeric_ratchet.sh
source "$SCRIPT_DIR/lib/numeric_ratchet.sh"
run_numeric_ratchet
