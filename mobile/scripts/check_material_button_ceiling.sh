#!/usr/bin/env bash
# Material-button ceiling ratchet (#6145, epic #4339): every Dart file under
# mobile/lib that constructs a direct Material button is frozen at its current
# count in scripts/baseline/material_buttons.txt, a per-file CEILING that may only
# ever DECREASE. New UI buttons must use DivineButton / DivineIconButton from
# divine_ui rather than a raw Material button (rule: ui_theming.md, self-review
# checklist → design system).
#
# Detector (occurrences, in code only — see lib/dart_code_only.awk):
#   \b(<Material button type>)(\.(<named ctor>))?[[:space:]]*[(<]
# covering the ButtonStyleButton family (IconButton, ElevatedButton, TextButton,
# FilledButton, OutlinedButton, BackButton, CloseButton, MaterialButton,
# RawMaterialButton), FloatingActionButton, and the menu-anchor buttons that read
# as buttons at the call site (PopupMenuButton, DropdownButton[FormField|
# HideUnderline], SegmentedButton, ToggleButtons, MenuItemButton, SubmenuButton).
# The word boundary EXCLUDES the sanctioned/custom set — DivineButton,
# DivineIconButton(, RoundedIconButton(, CircularIconButton(, VideoEditorIconButton(
# — and named params like showBackButton:/AuthBackButton/floatingActionButton:
# (grep is case-sensitive). The optional named-ctor group catches
# ElevatedButton.icon( and friends (.filled/.filledTonal/.outlined/.tonal/
# .tonalIcon) plus FloatingActionButton.small/.large/.extended, but NOT
# `.styleFrom(` — that returns a ButtonStyle (a style helper, legitimately used
# with DivineButton too), not a button widget, so it is intentionally not counted.
#
# The trailing `[(<]` (rather than a bare `\(`) is deliberate: several of these are
# generic and are called with an explicit type argument — PopupMenuButton<Action>(,
# SegmentedButton<T>(, DropdownButton<String>( — which a `...\(` regex would miss
# and a dev could add a type arg to bypass. Requiring a call/generic opener also
# keeps bare prose mentions of a type name from counting. divine_ui (where
# DivineButton lives) is a separate package, out of scope by construction.
#
# Per-key NUMERIC ceiling: a file may drop buttons while above zero, but the lower
# ceiling must be committed in the same change (#8323); growth / new file /
# raised ceiling / unlocked shrink / drop-to-zero (STALE) fails. Generated code
# excluded by path (l10n/generated) and suffix.
#
# Regenerate after MIGRATING to DivineButton/DivineIconButton (never to raise):
#   UPDATE_BASELINE=1 bash mobile/scripts/check_material_button_ceiling.sh
# Run (from repo root or mobile/): bash mobile/scripts/check_material_button_ceiling.sh

set -euo pipefail
export LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TAB="$(printf '\t')"

RATCHET_LABEL="material_button_ceiling"
SCAN_DIR="${MATERIAL_BUTTON_SCAN_DIR:-$MOBILE_DIR/lib}"
PATH_PREFIX="${MATERIAL_BUTTON_PATH_PREFIX:-$MOBILE_DIR}"
BASELINE_FILE="${MATERIAL_BUTTON_BASELINE_FILE:-$SCRIPT_DIR/baseline/material_buttons.txt}"
BASELINE_REPO_PATH="${MATERIAL_BUTTON_BASELINE_REPO_PATH:-mobile/scripts/baseline/material_buttons.txt}"
BASE_REF="${MATERIAL_BUTTON_BASELINE_BASE_REF:-origin/main}"
ALLOW_NO_BASE="${MATERIAL_BUTTON_CEILING_ALLOW_NO_BASE:-0}"
ALLOW_NO_BASE_VAR="MATERIAL_BUTTON_CEILING_ALLOW_NO_BASE"

# A migration that removes buttons must commit the lower ceiling in the same
# change (#8323). Without it a shrink is invisible to CI, so the win is left
# unlocked and the file can silently regrow to its stale ceiling.
REQUIRE_BASELINE_UPDATE_ON_DECREASE=1

DETECT_RE='\b(IconButton|ElevatedButton|TextButton|FilledButton|OutlinedButton|BackButton|CloseButton|FloatingActionButton|PopupMenuButton|MaterialButton|RawMaterialButton|DropdownButton|DropdownButtonFormField|DropdownButtonHideUnderline|SegmentedButton|ToggleButtons|MenuItemButton|SubmenuButton)(\.(icon|filled|filledTonal|outlined|tonal|tonalIcon|small|large|extended))?[[:space:]]*[(<]'

NEW_HINT="Don't add direct Material buttons — use DivineButton / DivineIconButton from divine_ui. ui_theming.md + self-review checklist; #6145. Only real code counts (comments and string literals are stripped)."
STALE_HINT="A file dropped its Material buttons (migrated to DivineButton or removed)."
FOOTER="Direct Material button counts under mobile/lib are frozen and may only
decrease. Use DivineButton / DivineIconButton rather than adding more.
See ui_theming.md and epics #6145 / #4339."

# Print "relpath<TAB>count" for every non-generated Dart file under SCAN_DIR that
# constructs a direct Material button (in code only), sorted by path.
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
# Frozen baseline: Dart files under mobile/lib constructing a direct Material
# button (IconButton/ElevatedButton/TextButton/FilledButton/OutlinedButton/
# BackButton/CloseButton/MaterialButton/RawMaterialButton/FloatingActionButton/
# PopupMenuButton/DropdownButton*/SegmentedButton/ToggleButtons/MenuItemButton/
# SubmenuButton, incl named ctors), each with its current count as a CEILING
# (format: relpath<TAB>count). Generated by scripts/check_material_button_ceiling.sh.
# A ceiling may only SHRINK and a shrink must be committed here; more buttons, a
# new file, a raised ceiling, or an unlocked shrink fails CI vs ${BASE_REF}. Use
# DivineButton / DivineIconButton. Comments and string literals are not counted.
# Issue: #6145. Regenerate after migrating:
#   UPDATE_BASELINE=1 bash scripts/check_material_button_ceiling.sh
EOF
}

# shellcheck source=lib/numeric_ratchet.sh
source "$SCRIPT_DIR/lib/numeric_ratchet.sh"
run_numeric_ratchet
