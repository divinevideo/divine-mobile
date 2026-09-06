#!/usr/bin/env bash
# Shared "shrink-only list" ratchet engine, sourced by the check_*.sh test-debt
# guards of epic #4337 (skip-ceiling, Future.delayed-ceiling,
# untested-services-floor). A ratchet freezes a committed baseline LIST of
# offending items; the set may only ever SHRINK.
#
# True ratchet (compares against the base ref, not just the in-branch baseline):
#   • NEW    — a current offender not declared in the (in-branch) baseline.
#   • STALE  — a baselined item that is no longer an offender (fixed/removed);
#              the baseline must shrink to lock the win in.
#   • GROWTH — the in-branch baseline contains entries absent from the baseline
#              on the base ref. Closes the bypass where a PR adds an offender,
#              reruns UPDATE_BASELINE, and commits the grown baseline.
#   On the commit that first introduces the baseline (absent on the base ref),
#   the GROWTH check is skipped (bootstrap).
#   If the base baseline cannot be loaded, the guard FAILS CLOSED (CI must never
#   silently skip the ratchet); a human may opt out for a local/offline run.
#
# The sourcing script MUST define, before calling run_list_ratchet:
#   RATCHET_LABEL        short id used in messages, e.g. skip_ceiling
#   MOBILE_DIR           absolute path to the mobile/ dir (REPO_ROOT is derived)
#   BASELINE_FILE        absolute path to the baseline file
#   BASELINE_REPO_PATH   repo-relative path (for `git show <ref>:<path>`)
#   BASE_REF             git ref to ratchet against (e.g. origin/main)
#   ALLOW_NO_BASE        "1" to soft-skip the growth check when base is unloadable
#   ALLOW_NO_BASE_VAR    name of the env var that sets ALLOW_NO_BASE (for hints)
#   NEW_HINT             guidance printed under a NEW failure
#   STALE_HINT           guidance printed under a STALE failure
#   FOOTER               closing guidance printed on any failure
#   emit_current()       prints the current sorted-unique list (one item/line)
#   print_baseline_header()  prints the baseline file header comment block
#
# Honours UPDATE_BASELINE=1 to regenerate (preserving any trailing "# reason").
# A baseline line may also carry `renamed-from: <old-key>` in its trailing
# comment. This is a reviewable assertion that the new item moved from the old
# item; it may be removed once the new item is present on the base ref.

set -euo pipefail

# Byte-wise, locale-independent ordering so sort/comm agree across macOS (local)
# and Linux (CI); otherwise the baseline diff can falsely flag NEW/STALE/GROWTH.
export LC_ALL=C

# Strip trailing "# reason" comments and blank lines from a baseline stream.
_lr_strip_baseline() {
  sed 's/[[:space:]]*#.*//; s/[[:space:]]*$//' | grep -v '^$' | LC_ALL=C sort || true
}

_lr_baseline_paths() {
  [[ -f "$BASELINE_FILE" ]] && _lr_strip_baseline < "$BASELINE_FILE" || true
}

_lr_write_baseline() {
  local reasons_file
  reasons_file="$(mktemp)"

  if [[ -f "$BASELINE_FILE" ]]; then
    awk '
      /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
      {
        item = $0
        comment = ""
        if (match(item, /[[:space:]]+#.*/)) {
          comment = substr(item, RSTART)
          sub(/^[[:space:]]+/, "", comment)
          item = substr(item, 1, RSTART - 1)
          sub(/[[:space:]]+$/, "", item)
        }
        if (comment != "") {
          print item "\t" comment
        }
      }
    ' "$BASELINE_FILE" > "$reasons_file"
  fi

  {
    print_baseline_header
    while IFS= read -r item; do
      [[ -z "$item" ]] && continue
      reason="$(awk -F '\t' -v target="$item" '$1 == target { print $2; exit }' "$reasons_file")"
      if [[ -n "$reason" ]]; then
        printf '%s %s\n' "$item" "$reason"
      else
        printf '%s\n' "$item"
      fi
    done <<< "$LR_CURRENT"
  } > "$BASELINE_FILE"

  rm -f "$reasons_file"
}

# Load the baseline from the base ref, for the GROWTH check.
# Return: 0 loaded (LR_MAIN_BASELINE set); 2 base ref ok but file absent
# (bootstrap); 1 base ref unresolvable; 3 file exists but blob unreadable.
_lr_load_base_baseline() {
  if ! git -C "$LR_REPO_ROOT" rev-parse --verify --quiet "$BASE_REF" >/dev/null 2>&1; then
    git -C "$LR_REPO_ROOT" fetch --quiet --depth=1 origin main 2>/dev/null || true
  fi
  if ! git -C "$LR_REPO_ROOT" rev-parse --verify --quiet "$BASE_REF" >/dev/null 2>&1; then
    return 1
  fi
  if ! git -C "$LR_REPO_ROOT" cat-file -e "$BASE_REF:$BASELINE_REPO_PATH" 2>/dev/null; then
    return 2
  fi
  local raw
  if ! raw="$(git -C "$LR_REPO_ROOT" show "$BASE_REF:$BASELINE_REPO_PATH" 2>/dev/null)"; then
    return 3
  fi
  LR_MAIN_BASELINE="$(printf '%s\n' "$raw" | _lr_strip_baseline)"
  return 0
}

run_list_ratchet() {
  LR_REPO_ROOT="$(cd "$MOBILE_DIR/.." && pwd)"
  LR_CURRENT="$(emit_current)"

  if [[ "${UPDATE_BASELINE:-0}" == "1" ]]; then
    mkdir -p "$(dirname "$BASELINE_FILE")"
    _lr_write_baseline
    local count
    count="$(printf '%s\n' "$LR_CURRENT" | grep -c . || true)"
    echo "OK [$RATCHET_LABEL]: wrote $count baseline entries to ${BASELINE_FILE#"$MOBILE_DIR"/}."
    return 0
  fi

  local baseline new stale fail=0
  baseline="$(_lr_baseline_paths)"

  new="$(comm -13 <(printf '%s\n' "$baseline") <(printf '%s\n' "$LR_CURRENT") | grep -v '^$' || true)"
  if [[ -n "$new" ]]; then
    echo "FAIL [$RATCHET_LABEL]: NEW entr(y/ies) not in the baseline:"
    echo "$new" | sed 's/^/  /'
    echo "  -> $NEW_HINT"
    fail=1
  fi

  stale="$(comm -23 <(printf '%s\n' "$baseline") <(printf '%s\n' "$LR_CURRENT") | grep -v '^$' || true)"
  if [[ -n "$stale" ]]; then
    echo "FAIL [$RATCHET_LABEL]: baseline entr(y/ies) no longer offending:"
    echo "$stale" | sed 's/^/  /'
    echo "  -> $STALE_HINT Lock the win by shrinking the baseline:"
    echo "     UPDATE_BASELINE=1 bash mobile/scripts/check_${RATCHET_LABEL}.sh"
    fail=1
  fi

  local base_status growth
  set +e
  _lr_load_base_baseline
  base_status=$?
  set -e
  case "$base_status" in
    0)
      growth="$(comm -23 <(printf '%s\n' "$baseline") <(printf '%s\n' "$LR_MAIN_BASELINE") | grep -v '^$' || true)"
      local rename_claims rename_line rename_new rename_old TAB
      TAB="$(printf '\t')"
      rename_claims="$(mktemp)"
      if [[ -f "$BASELINE_FILE" ]]; then
        awk '
          /renamed-from:/ {
            new=$0; sub(/[[:space:]]+#.*/, "", new); old=$0
            sub(/^.*renamed-from:[[:space:]]*/, "", old); sub(/[;[:space:]].*$/, "", old)
            if (old == "" || old == $0) print "!MALFORMED!\t" new
            else print new "\t" old
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
        if ! grep -Fqx "$rename_old" <<< "$LR_MAIN_BASELINE"; then
          echo "FAIL [$RATCHET_LABEL]: renamed-from old key is not in ${BASE_REF}: $rename_old"
          fail=1
        fi
        if grep -Fqx "$rename_old" <<< "$baseline"; then
          echo "FAIL [$RATCHET_LABEL]: renamed-from old key remains in the branch baseline: $rename_old"
          fail=1
        fi
        if grep -Fqx "$rename_old" <<< "$LR_CURRENT"; then
          echo "FAIL [$RATCHET_LABEL]: renamed-from old key is still emitted: $rename_old"
          fail=1
        fi
        growth="$(printf '%s\n' "$growth" | grep -Fvx "$rename_new" || true)"
      done < "$rename_claims"
      rm -f "$rename_claims"
      if [[ -n "$growth" ]]; then
        echo "FAIL [$RATCHET_LABEL]: baseline GREW vs ${BASE_REF} (the ratchet may only shrink):"
        echo "$growth" | sed 's/^/  /'
        echo "  -> $NEW_HINT"
        fail=1
      fi
      ;;
    2)
      echo "NOTE [$RATCHET_LABEL]: no baseline on ${BASE_REF} yet (introducing the guard); skipping growth check."
      ;;
    *)
      if [[ "$ALLOW_NO_BASE" == "1" ]]; then
        echo "NOTE [$RATCHET_LABEL]: ${BASE_REF} unavailable; skipping growth check (${ALLOW_NO_BASE_VAR}=1, local opt-out)."
      else
        echo "FAIL [$RATCHET_LABEL]: could not load the baseline from ${BASE_REF}, so the"
        echo "  growth ratchet cannot be verified — failing closed. Ensure ${BASE_REF} is"
        echo "  fetched (CI runs 'git fetch --depth=1 origin main' before this guard)."
        echo "  For a local run without a base ref, set ${ALLOW_NO_BASE_VAR}=1 to skip."
        fail=1
      fi
      ;;
  esac

  if [[ "$fail" -eq 0 ]]; then
    echo "OK [$RATCHET_LABEL]: no new entries (baseline frozen, ratcheted vs ${BASE_REF})."
    return 0
  fi
  echo ""
  echo "$FOOTER"
  return 1
}
