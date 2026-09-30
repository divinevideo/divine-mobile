#!/usr/bin/env bash
# File-size advisory (epic #4339): compares every non-generated Dart file under
# mobile/lib with the same file on origin/main. It reports files over
# FILE_SIZE_THRESHOLD (default 800) lines that are either NEW or have GROWN.
#
# This is ADVISORY: it prints warnings and ALWAYS exits 0 — it never fails CI.
# Comparing directly with the base ref keeps the warning scoped to the current
# branch without a committed snapshot that can drift behind main.
#
# Excludes generated code by PATH (mobile/lib/l10n/generated/) and by suffix
# (*.g.dart/*.freezed.dart/*.gr.dart/*.config.dart/*.mocks.dart).
#
# Run (from repo root or mobile/): bash mobile/scripts/check_file_size_ceiling.sh
# For a local checkout without origin/main, set
# FILE_SIZE_CEILING_ALLOW_NO_BASE=1 to acknowledge the missing comparison.
#
# Bash 3.2 compatible (no associative arrays) for local macOS runs.

set -euo pipefail
export LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="${FILE_SIZE_REPO_ROOT:-$(cd "$MOBILE_DIR/.." && pwd)}"
TAB="$(printf '\t')"

RATCHET_LABEL="file_size_ceiling"
THRESHOLD="${FILE_SIZE_THRESHOLD:-800}"
SCAN_DIR="${FILE_SIZE_SCAN_DIR:-$MOBILE_DIR/lib}"
PATH_PREFIX="${FILE_SIZE_PATH_PREFIX:-$MOBILE_DIR}"
BASE_REF="${FILE_SIZE_BASE_REF:-origin/main}"
BASE_REPO_PATH="${FILE_SIZE_BASE_REPO_PATH:-mobile/lib}"
BASE_PATH_PREFIX="${FILE_SIZE_BASE_PATH_PREFIX-mobile/}"
ALLOW_NO_BASE="${FILE_SIZE_CEILING_ALLOW_NO_BASE:-0}"

HINT="The ${THRESHOLD}-line ceiling is advisory — this does NOT block CI. Prefer
extracting widget/class/service concerns into focused files over growing a large
file, but a small edit need not trigger a refactor. The comparison is against
${BASE_REF}, so fetch main before relying on a local result."

is_generated_path() {
  case "$1" in
    */l10n/generated/*|*/.dart_tool/*|*/build/*|*.g.dart|*.freezed.dart|*.gr.dart|*.config.dart|*.mocks.dart)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

emit_current() {
  find "$SCAN_DIR" -type f -name '*.dart' -print0 2>/dev/null \
  | while IFS= read -r -d '' file; do
      relpath="${file#"$PATH_PREFIX"/}"
      if ! is_generated_path "$relpath"; then
        loc="$(wc -l < "$file" | tr -d '[:space:]')"
        if [[ "${loc:-0}" -gt "$THRESHOLD" ]]; then
          printf '%s\t%s\n' "$relpath" "$loc"
        fi
      fi
    done \
  | LC_ALL=C sort -t "$TAB" -k1,1
}

emit_base() {
  git -C "$REPO_ROOT" ls-tree -r --name-only "$BASE_REF" -- "$BASE_REPO_PATH" \
  | while IFS= read -r repo_path; do
      [[ "$repo_path" == *.dart ]] || continue
      relpath="${repo_path#"$BASE_PATH_PREFIX"}"
      if ! is_generated_path "$relpath"; then
        loc="$(git -C "$REPO_ROOT" show "$BASE_REF:$repo_path" | wc -l | tr -d '[:space:]')"
        if [[ "${loc:-0}" -gt "$THRESHOLD" ]]; then
          printf '%s\t%s\n' "$relpath" "$loc"
        fi
      fi
    done \
  | LC_ALL=C sort -t "$TAB" -k1,1
}

if [[ "$BASE_REF" == "origin/main" ]] &&
   ! git -C "$REPO_ROOT" rev-parse --verify --quiet "$BASE_REF" >/dev/null 2>&1 &&
   [[ "$(git -C "$REPO_ROOT" rev-parse --is-shallow-repository)" == "true" ]]; then
  git -C "$REPO_ROOT" fetch --quiet --depth=1 origin main 2>/dev/null || true
fi

if ! git -C "$REPO_ROOT" rev-parse --verify --quiet "$BASE_REF" >/dev/null 2>&1; then
  if [[ "$ALLOW_NO_BASE" == "1" ]]; then
    echo "NOTE [$RATCHET_LABEL]: ${BASE_REF} unavailable; advisory comparison skipped (FILE_SIZE_CEILING_ALLOW_NO_BASE=1)."
  else
    echo "WARN [$RATCHET_LABEL]: ${BASE_REF} unavailable; cannot determine which oversized files are new or grew."
    echo "  Fetch origin/main, or set FILE_SIZE_CEILING_ALLOW_NO_BASE=1 for an acknowledged local skip."
  fi
  exit 0
fi

CUR_F="$(mktemp)"
BASE_F="$(mktemp)"
trap 'rm -f "$CUR_F" "$BASE_F"' EXIT

emit_current > "$CUR_F"
emit_base > "$BASE_F"

warn=0
new="$(join -t "$TAB" -v1 "$CUR_F" "$BASE_F" || true)"
if [[ -n "$new" ]]; then
  echo "WARN [$RATCHET_LABEL]: NEW file(s) over ${THRESHOLD} lines vs ${BASE_REF}:"
  echo "$new" | sed 's/^/  /'
  warn=1
fi

grown="$(join -t "$TAB" "$CUR_F" "$BASE_F" | awk -F "$TAB" '$2 > $3 { printf "%s\t%s -> %s\n", $1, $3, $2 }' || true)"
if [[ -n "$grown" ]]; then
  echo "WARN [$RATCHET_LABEL]: file(s) GREW past ${BASE_REF} (base -> now):"
  echo "$grown" | sed 's/^/  /'
  warn=1
fi

if [[ "$warn" -eq 0 ]]; then
  count="$(grep -c . "$CUR_F" || true)"
  echo "OK [$RATCHET_LABEL]: $count file(s) over ${THRESHOLD} lines, none new or grown vs ${BASE_REF}."
  exit 0
fi

echo ""
echo "$HINT"
exit 0
