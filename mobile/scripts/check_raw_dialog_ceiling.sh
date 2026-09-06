#!/usr/bin/env bash
# Raw-dialog ceiling ratchet (#6145, epic #4339): every Dart file under mobile/lib
# that calls a raw dialog/sheet helper (`showDialog(`, `showModalBottomSheet(`, …)
# or constructs the modal Route behind one (`DialogRoute<T>(`, …) is frozen at its
# current count in scripts/baseline/raw_dialogs.txt, a per-file CEILING that may
# only ever DECREASE. New surfaces should prefer a full-screen flow, or the
# VineBottomSheet family from divine_ui, rather than a raw dialog/sheet (rule:
# ui_theming.md / AGENTS.md → "Prefer full-screen flows over new dialogs/sheets").
#
# Detector (occurrences, in code only — see lib/dart_code_only.awk):
#   \b(showDialog|showModalBottomSheet|showGeneralDialog|showBottomSheet
#     |showCupertinoDialog|showCupertinoModalPopup|showAdaptiveDialog
#     |DialogRoute|RawDialogRoute|ModalBottomSheetRoute)[[:space:]]*[(<]
# The imperative `show*` helpers and the modal Route classes they build on are both
# counted: pushing a `DialogRoute<void>(...)` onto the navigator is the same drift
# as calling showDialog, and was previously invisible to this guard.
#
# The trailing `[(<]` (rather than a bare `\(`) is deliberate: these are generic and
# are usually called with an explicit type argument — showDialog<bool>(,
# showModalBottomSheet<void>(, DialogRoute<void>(, nested/multi-line generics — that
# a `...\(` regex would miss (and a dev could add a type arg to bypass). Requiring a
# call/generic opener also keeps a bare mention in a log message or an identifier
# from counting. Word boundaries exclude wrapper NAMES (showForgotPasswordDialog,
# _showDialog, showVideoPausingVineBottomSheet); a wrapper's body still calls the raw
# token once, counted once (correct). Dartdoc refs like `/// [showModalBottomSheet]`
# are dropped by the comment filter. VineBottomSheet (the sanctioned sheet) lives in
# divine_ui, a separate package, so VineBottomSheet.show(...) callers are out of
# scope by construction. showLicensePage is deliberately NOT counted: it pushes a
# full-screen MaterialPageRoute, which is the outcome this ratchet steers toward.
#
# Per-key NUMERIC ceiling: a file may drop calls while above zero, but the lower
# ceiling must be committed in the same change (#8323); growth / new file /
# raised ceiling / unlocked shrink / drop-to-zero (STALE) fails. Generated code
# excluded by path (l10n/generated) and suffix.
#
# Regenerate after MIGRATING to a full-screen flow / VineBottomSheet (never to raise):
#   UPDATE_BASELINE=1 bash mobile/scripts/check_raw_dialog_ceiling.sh
# Run (from repo root or mobile/): bash mobile/scripts/check_raw_dialog_ceiling.sh

set -euo pipefail
export LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TAB="$(printf '\t')"

RATCHET_LABEL="raw_dialog_ceiling"
SCAN_DIR="${RAW_DIALOG_SCAN_DIR:-$MOBILE_DIR/lib}"
PATH_PREFIX="${RAW_DIALOG_PATH_PREFIX:-$MOBILE_DIR}"
BASELINE_FILE="${RAW_DIALOG_BASELINE_FILE:-$SCRIPT_DIR/baseline/raw_dialogs.txt}"
BASELINE_REPO_PATH="${RAW_DIALOG_BASELINE_REPO_PATH:-mobile/scripts/baseline/raw_dialogs.txt}"
BASE_REF="${RAW_DIALOG_BASELINE_BASE_REF:-origin/main}"
ALLOW_NO_BASE="${RAW_DIALOG_CEILING_ALLOW_NO_BASE:-0}"
ALLOW_NO_BASE_VAR="RAW_DIALOG_CEILING_ALLOW_NO_BASE"

# A migration that removes calls must commit the lower ceiling in the same
# change (#8323). Without it a shrink is invisible to CI, so the win is left
# unlocked and the file can silently regrow to its stale ceiling.
REQUIRE_BASELINE_UPDATE_ON_DECREASE=1

DETECT_RE='\b(showDialog|showModalBottomSheet|showGeneralDialog|showBottomSheet|showCupertinoDialog|showCupertinoModalPopup|showAdaptiveDialog|DialogRoute|RawDialogRoute|ModalBottomSheetRoute)[[:space:]]*[(<]'

NEW_HINT="Don't add raw dialogs/sheets (showDialog, showModalBottomSheet, showGeneralDialog, DialogRoute, …) — prefer a full-screen flow or the VineBottomSheet family from divine_ui. ui_theming.md / AGENTS.md; #6145. Note: only real code counts — comments and string literals are stripped, so this is a genuine new call site."
STALE_HINT="A file dropped its raw dialog/sheet call (migrated to a full-screen flow / VineBottomSheet or removed)."
FOOTER="Raw dialog/sheet counts under mobile/lib are frozen and may only decrease.
Prefer full-screen flows or VineBottomSheet rather than adding more.
See ui_theming.md / AGENTS.md and epics #6145 / #4339."

# Print "relpath<TAB>count" for every non-generated Dart file under SCAN_DIR that
# references a raw dialog/sheet function (in code only), by path.
emit_current() {
  find "$SCAN_DIR" \
    -type f -name '*.dart' \
    -not -path '*/l10n/generated/*' \
    -not -path '*/.dart_tool/*' \
    -not -path '*/build/*' \
    ! -name '*.g.dart' ! -name '*.freezed.dart' ! -name '*.gr.dart' \
    ! -name '*.config.dart' ! -name '*.mocks.dart' \
    -print0 2>/dev/null \
  | while IFS= read -r -d '' f; do
      count="$(awk -f "$SCRIPT_DIR/lib/dart_code_only.awk" "$f" 2>/dev/null \
        | grep -oE "$DETECT_RE" \
        | grep -c . || true)"
      count="${count//[[:space:]]/}"
      if [[ "${count:-0}" -gt 0 ]]; then
        printf '%s\t%s\n' "${f#"$PATH_PREFIX"/}" "$count"
      fi
    done \
  | LC_ALL=C sort -t "$TAB" -k1,1
}

print_baseline_header() {
  cat <<EOF
# Frozen baseline: Dart files under mobile/lib calling a raw showDialog( /
# showModalBottomSheet( / showGeneralDialog( / showBottomSheet( / the Cupertino and
# adaptive variants, or constructing a DialogRoute/RawDialogRoute/
# ModalBottomSheetRoute, each with its current count as a CEILING (format:
# relpath<TAB>count). Generated by scripts/check_raw_dialog_ceiling.sh. A ceiling
# may only SHRINK and a shrink must be committed here; more raw calls, a new file,
# a raised ceiling, or an unlocked shrink fails CI vs ${BASE_REF}. Prefer
# full-screen flows or VineBottomSheet. Comments and string literals are not
# counted. Issue: #6145. Regenerate after migrating:
#   UPDATE_BASELINE=1 bash scripts/check_raw_dialog_ceiling.sh
EOF
}

# shellcheck source=lib/numeric_ratchet.sh
source "$SCRIPT_DIR/lib/numeric_ratchet.sh"
run_numeric_ratchet
