#!/usr/bin/env bash
# Shared "per-key numeric ceiling" ratchet engine, the numeric sibling of
# lib/list_ratchet.sh. Where list_ratchet freezes a SET membership (an item is in
# or out), this freezes a NUMBER per key: each baseline line is `key<TAB>count`
# and a key's count may only ever DECREASE.
#
# Fails (vs the in-branch baseline AND the base ref):
#   • NEW    — a key present now but absent from the baseline.
#   • GROWTH — a baselined key whose current count exceeds its frozen ceiling.
#   • STALE  — a baselined key no longer emitted (removed/renamed/dropped below a
#              detector threshold); the baseline must shrink to lock the win.
#   • BYPASS — the in-branch baseline ADDS a key or RAISES a ceiling vs the base
#              ref (closes the "grow then rerun UPDATE_BASELINE" loophole).
#   On the commit that first introduces the baseline (absent on the base ref),
#   the bypass check is skipped (bootstrap). If the base baseline cannot be
#   loaded, the guard FAILS CLOSED unless ALLOW_NO_BASE=1 (local opt-out).
#
# By default, a key may DECREASE freely without churning the baseline (low
# friction); only growth/new/removal fails. A sourcing guard can instead require
# every decrease to be locked in via UPDATE_BASELINE.
#
# The sourcing script MUST define, before calling run_numeric_ratchet:
#   RATCHET_LABEL        short id used in messages
#   MOBILE_DIR           absolute path to the mobile/ dir (REPO_ROOT derived)
#   BASELINE_FILE        absolute path to the baseline file
#   BASELINE_REPO_PATH   repo-relative path (for `git show <ref>:<path>`)
#   BASE_REF             git ref to ratchet against (e.g. origin/main)
#   ALLOW_NO_BASE        "1" to soft-skip the bypass check when base is unloadable
#   ALLOW_NO_BASE_VAR    name of the env var that sets ALLOW_NO_BASE (for hints)
#   NEW_HINT             guidance printed under a NEW/GROWTH/BYPASS failure
#   STALE_HINT           guidance printed under a STALE failure
#   FOOTER               closing guidance printed on any failure
#   REQUIRE_BASELINE_UPDATE_ON_DECREASE
#                         optional "1" when every decrease must be committed to
#                         the baseline immediately instead of remaining slack.
#   emit_current()       prints the current "key<TAB>count" lines (one per key)
#   print_baseline_header()  prints the baseline file header comment block
#
# A trailing "# reason" on a baseline line is documentation, ignored by every
# comparison and CARRIED FORWARD across UPDATE_BASELINE (matched by key, so a
# changed count keeps its reason). That mirrors lib/list_ratchet.sh, whose
# baselines have always been able to explain themselves; without it a reason
# survives only until the next regeneration, which is why no numeric baseline
# carried one before #3340.
# A baseline line may also carry `renamed-from: <old-key>` in its trailing
# comment. This is a reviewable assertion that the new key moved from the old
# key; it may be removed once the new key is present on the base ref.
#
# Honours UPDATE_BASELINE=1 to regenerate. Bash 3.2 compatible (sort/join only).

set -euo pipefail
export LC_ALL=C

_nr_tab() { printf '\t'; }

# Strip "# reason" trailing comments, comment lines, blanks; sort by key (field 1).
_nr_strip() {
  sed 's/[[:space:]]*#.*//' | grep -v '^[[:space:]]*$' | LC_ALL=C sort -t "$(_nr_tab)" -k1,1 || true
}

# Rewrite BASELINE_FILE from the emitted lines, re-attaching each key's existing
# trailing "# reason". Reasons are keyed on field 1 alone, so a count that moved
# keeps its explanation instead of silently losing it.
_nr_write_baseline() {
  local emitted="$1"
  local TAB; TAB="$(_nr_tab)"
  local reasons; reasons="$(mktemp)"

  if [[ -f "$BASELINE_FILE" ]]; then
    awk -F '\t' '
      /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
      {
        line = $0
        comment = ""
        if (match(line, /[[:space:]]+#.*/)) {
          comment = substr(line, RSTART)
          sub(/^[[:space:]]+/, "", comment)
        }
        if (comment != "") print $1 "\t" comment
      }
    ' "$BASELINE_FILE" > "$reasons"
  else
    : > "$reasons"
  fi

  # `|| true` is load-bearing: with an EMPTY offender set grep matches nothing
  # and exits 1, which under `set -o pipefail` + `set -e` would abort before the
  # baseline is written. A zero-entry baseline is the normal state of a
  # frozen-at-zero guard, not a failure.
  {
    print_baseline_header
    { printf '%s\n' "$emitted" | grep -v '^[[:space:]]*$' || true; } | while IFS= read -r line; do
      local key reason
      key="${line%%"$TAB"*}"
      reason="$(awk -F '\t' -v target="$key" '$1 == target { print $2; exit }' "$reasons")"
      if [[ -n "$reason" ]]; then
        printf '%s %s\n' "$line" "$reason"
      else
        printf '%s\n' "$line"
      fi
    done
  } > "$BASELINE_FILE"

  rm -f "$reasons"
}

run_numeric_ratchet() {
  local TAB; TAB="$(_nr_tab)"
  local REPO_ROOT; REPO_ROOT="$(cd "$MOBILE_DIR/.." && pwd)"
  local CURRENT; CURRENT="$(emit_current)"

  if [[ "${UPDATE_BASELINE:-0}" == "1" ]]; then
    mkdir -p "$(dirname "$BASELINE_FILE")"
    _nr_write_baseline "$CURRENT"
    local count; count="$(printf '%s\n' "$CURRENT" | grep -c . || true)"
    echo "OK [$RATCHET_LABEL]: wrote $count baseline entries to ${BASELINE_FILE#"$MOBILE_DIR"/}."
    return 0
  fi

  local CUR_F BASE_F MAIN_F
  CUR_F="$(mktemp)"; BASE_F="$(mktemp)"; MAIN_F="$(mktemp)"
  # shellcheck disable=SC2064
  trap "rm -f '$CUR_F' '$BASE_F' '$MAIN_F'" RETURN

  printf '%s\n' "$CURRENT" | grep -v '^[[:space:]]*$' | LC_ALL=C sort -t "$TAB" -k1,1 > "$CUR_F" || true
  if [[ -f "$BASELINE_FILE" ]]; then _nr_strip < "$BASELINE_FILE" > "$BASE_F"; else : > "$BASE_F"; fi

  local fail=0 new grown decreased stale
  new="$(join -t "$TAB" -v1 "$CUR_F" "$BASE_F" || true)"
  if [[ -n "$new" ]]; then
    echo "FAIL [$RATCHET_LABEL]: NEW key(s) not in the baseline:"
    echo "$new" | sed 's/^/  /'
    echo "  -> $NEW_HINT"
    fail=1
  fi
  grown="$(join -t "$TAB" "$CUR_F" "$BASE_F" | awk -F "$TAB" '$2 > $3 { printf "%s\t%s -> %s\n", $1, $3, $2 }' || true)"
  if [[ -n "$grown" ]]; then
    echo "FAIL [$RATCHET_LABEL]: count(s) GREW past the frozen ceiling (was -> now):"
    echo "$grown" | sed 's/^/  /'
    echo "  -> $NEW_HINT"
    fail=1
  fi
  decreased=""
  if [[ "${REQUIRE_BASELINE_UPDATE_ON_DECREASE:-0}" == "1" ]]; then
    decreased="$(join -t "$TAB" "$CUR_F" "$BASE_F" | awk -F "$TAB" '$2 < $3 { printf "%s\t%s -> %s\n", $1, $3, $2 }' || true)"
  fi
  if [[ -n "$decreased" ]]; then
    echo "FAIL [$RATCHET_LABEL]: count(s) DECREASED below the frozen ceiling (was -> now):"
    echo "$decreased" | sed 's/^/  /'
    echo "  -> $STALE_HINT Lock the win by regenerating the baseline:"
    echo "     UPDATE_BASELINE=1 bash mobile/scripts/check_${RATCHET_LABEL}.sh"
    fail=1
  fi
  stale="$(join -t "$TAB" -v2 "$CUR_F" "$BASE_F" || true)"
  if [[ -n "$stale" ]]; then
    echo "FAIL [$RATCHET_LABEL]: baselined key(s) no longer emitted:"
    echo "$stale" | sed 's/^/  /'
    echo "  -> $STALE_HINT Lock the win by regenerating the baseline:"
    echo "     UPDATE_BASELINE=1 bash mobile/scripts/check_${RATCHET_LABEL}.sh"
    fail=1
  fi

  local base_status=0
  if ! git -C "$REPO_ROOT" rev-parse --verify --quiet "$BASE_REF" >/dev/null 2>&1; then
    git -C "$REPO_ROOT" fetch --quiet --depth=1 origin main 2>/dev/null || true
  fi
  if ! git -C "$REPO_ROOT" rev-parse --verify --quiet "$BASE_REF" >/dev/null 2>&1; then
    base_status=1
  elif ! git -C "$REPO_ROOT" cat-file -e "$BASE_REF:$BASELINE_REPO_PATH" 2>/dev/null; then
    base_status=2
  elif ! git -C "$REPO_ROOT" show "$BASE_REF:$BASELINE_REPO_PATH" 2>/dev/null | _nr_strip > "$MAIN_F"; then
    base_status=3
  fi
  case "$base_status" in
    0)
      local added raised
      added="$(join -t "$TAB" -v1 "$BASE_F" "$MAIN_F" || true)"
      raised="$(join -t "$TAB" "$BASE_F" "$MAIN_F" | awk -F "$TAB" '$2 > $3 { printf "%s\t%s -> %s\n", $1, $3, $2 }' || true)"
      local rename_claims rename_line rename_new rename_old old_count new_count
      rename_claims="$(mktemp)"
      if [[ -f "$BASELINE_FILE" ]]; then
        awk -F "$TAB" '
          /renamed-from:/ {
            old=$0; sub(/^.*renamed-from:[[:space:]]*/, "", old); sub(/[;[:space:]].*$/, "", old)
            if (old == "" || old == $0) print "!MALFORMED!\t" $1
            else print $1 "\t" old
          }
        ' "$BASELINE_FILE" > "$rename_claims"
      fi
      while IFS="$TAB" read -r rename_new rename_old; do
        [[ -z "$rename_new" ]] && continue
        if [[ "$rename_new" == "!MALFORMED!" ]]; then
          echo "FAIL [$RATCHET_LABEL]: malformed renamed-from annotation on $rename_old"
          echo "  -> use '# renamed-from: <old-key>' with a non-empty key"
          fail=1
          continue
        fi
        if [[ "$(cut -f1 "$rename_claims" | grep -Fxc "$rename_new")" -gt 1 ]]; then
          echo "FAIL [$RATCHET_LABEL]: duplicate rename claim for new key $rename_new"
          fail=1
          continue
        fi
        if [[ "$(cut -f2 "$rename_claims" | grep -Fxc "$rename_old")" -gt 1 ]]; then
          echo "FAIL [$RATCHET_LABEL]: old key $rename_old is claimed more than once"
          fail=1
          continue
        fi
        if ! awk -F "$TAB" -v key="$rename_old" '$1 == key { found=1 } END { exit !found }' "$MAIN_F"; then
          echo "FAIL [$RATCHET_LABEL]: renamed-from old key is not in ${BASE_REF}: $rename_old"
          fail=1
        fi
        if awk -F "$TAB" -v key="$rename_old" '$1 == key { found=1 } END { exit found }' "$BASE_F"; then
          echo "FAIL [$RATCHET_LABEL]: renamed-from old key remains in the branch baseline: $rename_old"
          fail=1
        fi
        if awk -F "$TAB" -v key="$rename_old" '$1 == key { found=1 } END { exit found }' "$CUR_F"; then
          echo "FAIL [$RATCHET_LABEL]: renamed-from old key is still emitted: $rename_old"
          fail=1
        fi
        new_count="$(awk -F "$TAB" -v key="$rename_new" '$1 == key { print $2; exit }' "$BASE_F")"
        old_count="$(awk -F "$TAB" -v key="$rename_old" '$1 == key { print $2; exit }' "$MAIN_F")"
        if [[ -z "$old_count" || "$new_count" -gt "$old_count" ]]; then
          echo "FAIL [$RATCHET_LABEL]: renamed key $rename_new exceeds old ceiling $rename_old"
          fail=1
        fi
        added="$(printf '%s\n' "$added" | awk -F "$TAB" -v key="$rename_new" '$1 != key')"
      done < "$rename_claims"
      rm -f "$rename_claims"
      if [[ -n "$added" || -n "$raised" ]]; then
        echo "FAIL [$RATCHET_LABEL]: baseline ADDED a key or RAISED a ceiling vs ${BASE_REF} (may only shrink):"
        [[ -n "$added" ]] && echo "$added" | sed 's/^/  +added /'
        [[ -n "$raised" ]] && echo "$raised" | sed 's/^/  ^raised /'
        echo "  -> $NEW_HINT"
        fail=1
      fi
      ;;
    2)
      echo "NOTE [$RATCHET_LABEL]: no baseline on ${BASE_REF} yet (introducing the guard); skipping growth-vs-base check."
      ;;
    *)
      if [[ "$ALLOW_NO_BASE" == "1" ]]; then
        echo "NOTE [$RATCHET_LABEL]: ${BASE_REF} unavailable; skipping growth-vs-base check (${ALLOW_NO_BASE_VAR}=1, local opt-out)."
      else
        echo "FAIL [$RATCHET_LABEL]: could not load the baseline from ${BASE_REF}, so the"
        echo "  growth-vs-base ratchet cannot be verified — failing closed. Ensure ${BASE_REF}"
        echo "  is fetched (CI runs 'git fetch --depth=1 origin main' before this guard)."
        echo "  For a local run without a base ref, set ${ALLOW_NO_BASE_VAR}=1 to skip."
        fail=1
      fi
      ;;
  esac

  if [[ "$fail" -eq 0 ]]; then
    local count; count="$(grep -c . "$CUR_F" || true)"
    echo "OK [$RATCHET_LABEL]: $count key(s) tracked, none grew (frozen, ratcheted vs ${BASE_REF})."
    return 0
  fi
  echo ""
  echo "$FOOTER"
  return 1
}
