#!/usr/bin/env bash
# l10n-delegates ceiling ratchet (#3613): every Dart file under mobile/test that
# builds a MaterialApp / CupertinoApp / WidgetsApp without registering
# appLocalizationsDelegates (lib/l10n/l10n.dart), or with an AppLocalizations
# delegate beside it, is frozen at its current count in
# scripts/baseline/l10n_delegates.txt, a per-file CEILING that may only ever
# DECREASE.
#
# Why: `context.l10n` is `AppLocalizations.of(context)`, which is
# `Localizations.of<AppLocalizations>(context, AppLocalizations)!`. With no
# delegate registered that lookup returns null and the `!` throws
# `Null check operator used on a null value`. MaterialApp always supplies the
# *framework* fallbacks (DefaultMaterialLocalizations and friends), so nothing
# fails until a widget under test actually reads `context.l10n` — which makes
# this debt silent and load-bearing on whichever code paths a test happens to
# exercise today. Adding the delegates is uniform and never worse:
#     MaterialApp(
#       localizationsDelegates: appLocalizationsDelegates,
#       supportedLocales: AppLocalizations.supportedLocales,
#       home: ...,
#     )
# The generated AppLocalizations.localizationsDelegates does not count: its app
# delegate loads each locale as a deferred library, and inside a widget test
# that load leaves the next first load of any other locale hanging for the rest
# of the merged CI shard (#10517).
# Most tests should reach for `testMaterialApp(...)` from
# test/helpers/test_provider_overrides.dart instead, which already sets both.
#
# Detector: scripts/lib/l10n_delegate_detector.dart (a real Dart AST). #3613 was
# filed off `grep MaterialApp | grep -v localizationsDelegates`, which reported
# 39 offending screen tests; 31 of those were false, because the helper
# `testMaterialApp` CONTAINS the substring `MaterialApp` and the grep matched
# its name rather than a construction. A file-level grep also cannot see a file
# that builds two MaterialApps, one with delegates and one without. See that
# file's header for the full rule.
#
# Per-key NUMERIC ceiling: a file may drop sites freely while above zero without
# churning the baseline; only growth / a new file / a raised ceiling /
# drop-to-zero (STALE) fails.
#
# Regenerate after ADDING delegates (never to raise):
#   UPDATE_BASELINE=1 bash mobile/scripts/check_l10n_delegates_ceiling.sh
# Run (from repo root or mobile/): bash mobile/scripts/check_l10n_delegates_ceiling.sh
# List the individual sites in a file:
#   dart run scripts/lib/l10n_delegate_detector.dart test --detail

set -euo pipefail
export LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TAB="$(printf '\t')"

RATCHET_LABEL="l10n_delegates_ceiling"
SCAN_DIR="${L10N_DELEGATES_SCAN_DIR:-$MOBILE_DIR/test}"
PATH_PREFIX="${L10N_DELEGATES_PATH_PREFIX:-$MOBILE_DIR}"
BASELINE_FILE="${L10N_DELEGATES_BASELINE_FILE:-$SCRIPT_DIR/baseline/l10n_delegates.txt}"
BASELINE_REPO_PATH="${L10N_DELEGATES_BASELINE_REPO_PATH:-mobile/scripts/baseline/l10n_delegates.txt}"
BASE_REF="${L10N_DELEGATES_BASELINE_BASE_REF:-origin/main}"
ALLOW_NO_BASE="${L10N_DELEGATES_CEILING_ALLOW_NO_BASE:-0}"
ALLOW_NO_BASE_VAR="L10N_DELEGATES_CEILING_ALLOW_NO_BASE"
DART_BIN="${L10N_DELEGATES_DART:-dart}"

NEW_HINT="A widget test builds a MaterialApp without appLocalizationsDelegates, or with an AppLocalizations delegate beside it. With no app delegate, any \`context.l10n\` read under it throws \"Null check operator used on a null value\"; with the generated AppLocalizations.delegate or .localizationsDelegates, the deferred locale load it starts inside a widget test hangs later loads in the merged CI shard (#10517), and listing it beside the app list does not help because Localizations uses only the first delegate of each type. Prefer testMaterialApp(...) from test/helpers/test_provider_overrides.dart, or pass localizationsDelegates: appLocalizationsDelegates (package:openvine/l10n/l10n.dart) and supportedLocales: AppLocalizations.supportedLocales. See #3613 and .claude/rules/testing.md."
STALE_HINT="A file registered appLocalizationsDelegates on every MaterialApp it builds."
FOOTER="MaterialApp constructions under mobile/test that skip
appLocalizationsDelegates, or name AppLocalizations beside it, are frozen and
may only decrease. Use testMaterialApp(...) from
test/helpers/test_provider_overrides.dart where it fits; see #3613 and
.claude/rules/testing.md. Inspect a file's sites with:
  dart run scripts/lib/l10n_delegate_detector.dart test --detail"

# Print "relpath<TAB>count" for every file under SCAN_DIR with at least one
# delegate-less app-widget construction. Runs from MOBILE_DIR so the detector
# resolves package:analyzer from the app's package config.
emit_current() {
  (
    cd "$MOBILE_DIR"
    "$DART_BIN" run scripts/lib/l10n_delegate_detector.dart \
      "$SCAN_DIR" --path-prefix "$PATH_PREFIX"
  ) | LC_ALL=C sort -t "$TAB" -k1,1
}

print_baseline_header() {
  cat <<EOF
# Frozen baseline: Dart files under mobile/test that build a MaterialApp /
# CupertinoApp / WidgetsApp without appLocalizationsDelegates, or with an
# AppLocalizations delegate beside it, each with its current count as a CEILING
# (format: relpath<TAB>count).
# Generated by scripts/check_l10n_delegates_ceiling.sh from
# scripts/lib/l10n_delegate_detector.dart. A ceiling may only SHRINK; more
# sites, a new file, or a raised ceiling fails CI vs ${BASE_REF}. The fix is
# testMaterialApp(...) from test/helpers/test_provider_overrides.dart, or
# passing localizationsDelegates: appLocalizationsDelegates + supportedLocales
# explicitly (#3613; the generated list does not count, #10517).
# \`testMaterialApp\` is NOT counted — the detector matches constructions, not
# identifiers containing the substring "MaterialApp". Regenerate after adding
# delegates:
#   UPDATE_BASELINE=1 bash scripts/check_l10n_delegates_ceiling.sh
EOF
}

# shellcheck source=lib/numeric_ratchet.sh
source "$SCRIPT_DIR/lib/numeric_ratchet.sh"
run_numeric_ratchet
