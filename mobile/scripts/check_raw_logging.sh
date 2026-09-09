#!/usr/bin/env bash
# Prevents production Dart code from bypassing the shared support log.
#
# Hard invariants:
#   - No raw print() or debugPrint() outside the documented legacy package
#     exemptions and unified_logger (which owns the output sink).
#   - No direct dart:developer import in mobile/lib.
#
# Package dart:developer imports are a shrink-only list ratchet. Existing
# imports are frozen in scripts/baseline/developer_log_imports.txt; new files
# fail, fixed files make the baseline stale, and the baseline may not grow
# against origin/main. unified_logger is the one structural exemption because
# its developer.log call is the sink itself and is not migration debt.
#
# Regenerate after removing package imports (never to add one):
#   UPDATE_BASELINE=1 bash mobile/scripts/check_raw_logging.sh
#
# Test seams:
#   RAW_LOGGING_MOBILE_DIR / RAW_LOGGING_LIB_DIR /
#   RAW_LOGGING_PACKAGES_DIR / RAW_LOGGING_PATH_PREFIX /
#   RAW_LOGGING_BASELINE_FILE / RAW_LOGGING_BASELINE_REPO_PATH /
#   RAW_LOGGING_BASELINE_BASE_REF
#   RAW_LOGGING_ALLOW_NO_BASE=1
#
# Usage (from the repository root or mobile/):
#   bash mobile/scripts/check_raw_logging.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="${RAW_LOGGING_MOBILE_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
LIB_DIR="${RAW_LOGGING_LIB_DIR:-$MOBILE_DIR/lib}"
PACKAGES_DIR="${RAW_LOGGING_PACKAGES_DIR:-$MOBILE_DIR/packages}"
PATH_PREFIX="${RAW_LOGGING_PATH_PREFIX:-$MOBILE_DIR}"
BASELINE_FILE="${RAW_LOGGING_BASELINE_FILE:-$MOBILE_DIR/scripts/baseline/developer_log_imports.txt}"
BASELINE_REPO_PATH="${RAW_LOGGING_BASELINE_REPO_PATH:-mobile/scripts/baseline/developer_log_imports.txt}"
BASE_REF="${RAW_LOGGING_BASELINE_BASE_REF:-${BASELINE_BASE_REF:-origin/main}}"
ALLOW_NO_BASE="${RAW_LOGGING_ALLOW_NO_BASE:-0}"
ALLOW_NO_BASE_VAR="RAW_LOGGING_ALLOW_NO_BASE"
RATCHET_LABEL="raw_logging"

CODE_ONLY_FILTER="$SCRIPT_DIR/lib/dart_code_only.awk"
DEVELOPER_IMPORT_RE="^import[[:space:]]+['\"]dart:developer['\"]"

GENERATED_EXCLUDES=(
  -not -path "*/.dart_tool/*"
  -not -path "*/build/*"
  -not -name "*.g.dart"
  -not -name "*.freezed.dart"
  -not -name "*.mocks.dart"
)

# print/debugPrint retain their existing package exemptions. This issue
# ratchets dart:developer imports; migrating raw call sites is separate work.
PRINT_EXCLUDES=(
  "${GENERATED_EXCLUDES[@]}"
  -not -path "*/unified_logger/*"
  -not -path "*/nostr_sdk/*"
  -not -path "*/nostr_client/*"
  -not -path "*/packages/models/*"
  -not -name "migrate_logging.dart"
)

fail=0

if [[ ! -f "$CODE_ONLY_FILTER" ]]; then
  echo "FAIL [raw_logging]: Dart code-only filter is unavailable: $CODE_ONLY_FILTER" >&2
  exit 1
fi

code_call_violations() {
  local pattern="$1" matches
  find "$LIB_DIR" "$PACKAGES_DIR" \
    "${PRINT_EXCLUDES[@]}" -name "*.dart" \
    -exec grep -lE "$pattern" {} + 2>/dev/null \
  | while IFS= read -r file; do
      # grep is only a cheap batched prefilter. The code-only pass decides
      # whether the candidate is executable code rather than a comment/string.
      # Consume the complete awk stream. grep -q can close the pipe early and
      # turn a genuine match into SIGPIPE 141 under pipefail.
      matches="$(awk -f "$CODE_ONLY_FILTER" "$file" 2>/dev/null \
        | grep -E "$pattern" || true)"
      if [[ -n "$matches" ]]; then
        printf '%s\n' "${file#"$PATH_PREFIX"/}"
      fi
    done | LC_ALL=C sort -u || true
}

PRINT_VIOLATIONS="$(code_call_violations '(^|[^[:alnum:]_])print[[:space:]]*\(')"
if [[ -n "$PRINT_VIOLATIONS" ]]; then
  echo "FAIL [avoid_print]: raw print() found in:"
  printf '%s\n' "$PRINT_VIOLATIONS" | sed 's/^/  /'
  fail=1
fi

DEBUG_PRINT_VIOLATIONS="$(code_call_violations '(^|[^[:alnum:]_])debugPrint[[:space:]]*\(')"
if [[ -n "$DEBUG_PRINT_VIOLATIONS" ]]; then
  echo "FAIL [avoid_debugPrint]: debugPrint() found in:"
  printf '%s\n' "$DEBUG_PRINT_VIOLATIONS" | sed 's/^/  /'
  fail=1
fi

# App code has no migration baseline: a direct import is always forbidden.
APP_DEVELOPER_IMPORTS="$(
  find "$LIB_DIR" "${GENERATED_EXCLUDES[@]}" \
    -not -name "migrate_logging.dart" -name "*.dart" -print0 2>/dev/null \
  | while IFS= read -r -d '' file; do
      if grep -qE "$DEVELOPER_IMPORT_RE" "$file"; then
        printf '%s\n' "${file#"$PATH_PREFIX"/}"
      fi
    done | LC_ALL=C sort -u || true
)"
if [[ -n "$APP_DEVELOPER_IMPORTS" ]]; then
  echo "FAIL [avoid_developer_log]: dart:developer import found in app code:"
  printf '%s\n' "$APP_DEVELOPER_IMPORTS" | sed 's/^/  /'
  fail=1
fi

emit_current() {
  find "$PACKAGES_DIR" "${GENERATED_EXCLUDES[@]}" \
    -path "*/lib/*" -not -path "*/unified_logger/*" \
    -name "*.dart" -print0 2>/dev/null \
  | while IFS= read -r -d '' file; do
      if grep -qE "$DEVELOPER_IMPORT_RE" "$file"; then
        printf '%s\n' "${file#"$PATH_PREFIX"/}"
      fi
    done | LC_ALL=C sort -u || true
}

print_baseline_header() {
  cat <<'EOF'
# Frozen baseline: package library files that import dart:developer directly.
# Generated by scripts/check_raw_logging.sh. The baseline may only SHRINK;
# growth fails CI against origin/main. unified_logger is excluded because its
# developer.log call is the output sink rather than migration debt. A trailing
# '# reason' documents why each existing import remains.
EOF
}

NEW_HINT="Use UnifiedLogger when the package can depend on it. Otherwise inject a diagnostics or reporter port and wire it to the shared logger at the app boundary."
STALE_HINT="A package stopped importing dart:developer."
FOOTER="Package logging must reach support exports through UnifiedLogger or an
injected diagnostics/reporter port. Direct dart:developer imports are frozen
and may only decrease."

# shellcheck source=scripts/lib/list_ratchet.sh
source "$SCRIPT_DIR/lib/list_ratchet.sh"
run_list_ratchet || fail=1

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi

echo "OK: No raw logging violations found."
