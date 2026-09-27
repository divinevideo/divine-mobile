#!/usr/bin/env bash
# Fails CI if a new ChangeNotifier subclass — via `extends ChangeNotifier`
# or a `with ... ChangeNotifier` mixin clause — appears in mobile/lib/
# outside the sanctioned allowlist.
#
# Rule enforced:
#   * No `extends ChangeNotifier` and no `with ... ChangeNotifier` mixin
#     clause in mobile/lib/ outside the file allowlist below. Both forms
#     produce a ChangeNotifier, so a guard that matched only `extends`
#     would be trivially bypassable with the mixin syntax. Adding a new
#     sanctioned ChangeNotifier requires editing both this script's
#     ALLOWLIST and the "Sanctioned Riverpod (STAYS)" table in
#     docs/BLOC_UI_MIGRATION_PRD.md in the same PR.
#
# Scope:
#   * Only mobile/lib/ is scanned. mobile/packages/** is intentionally out
#     of scope — the standalone pub packages own their own architecture and
#     are not part of #4744's app-UI-state migration lane. This mirrors
#     check_riverpod_boundary.sh, which also scans mobile/lib/ only.
#
# Background:
#   Divine is mid-migration from Riverpod / ChangeNotifier to BLoC/Cubit for
#   UI state. The "Sanctioned Riverpod (STAYS)" section in
#   docs/BLOC_UI_MIGRATION_PRD.md enumerates the files that hold infrastructure
#   (DI / services / caches / router plumbing) and are out of scope for
#   #4744's Riverpod → BLoC lane. This guard prevents the carve-out from
#   silently regrowing — every new UI-state ChangeNotifier in mobile/lib/
#   must be migrated to a Cubit, not added here.
#
# Allowlist policy:
#   * Files in ALLOWLIST below must hold ZERO feature UI state — they own
#     infrastructure, a service, a cache, router plumbing, or preferences.
#   * Adding a file to ALLOWLIST is reviewed against that criterion and must
#     come with a matching docs table entry.
#
# Usage:
#   bash mobile/scripts/check_changenotifier_boundary.sh
#   (run from the repository root or from mobile/)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# ---------------------------------------------------------------------------
# Allowlist — paths are relative to mobile/lib/. Keep in sync with the
# "Sanctioned Riverpod (STAYS)" table in docs/BLOC_UI_MIGRATION_PRD.md.
# ---------------------------------------------------------------------------

ALLOWLIST=(
  "features/feature_flags/services/feature_flag_service.dart"
  "router/app_router.dart"
  "services/community_content_label_service.dart"
  "services/connection_status_service.dart"
  "services/content_filter_service.dart"
  "services/curated_list_service.dart"
  "services/divine_host_filter_service.dart"
  "services/video_provenance_filter_service.dart"
  "services/environment_service.dart"
  "services/feed_aspect_ratio_preference_service.dart"
  "services/stats_visibility_preferences.dart"
  "services/nip05_verification_service.dart"
  "services/og_viner_cache_service.dart"
  "services/pending_action_service.dart"
  "services/relay_statistics_service.dart"
  "services/subscribed_list_video_cache.dart"
  "services/video_event_service.dart"
)

# ---------------------------------------------------------------------------
# Find every file under mobile/lib/ that declares a ChangeNotifier subclass —
# via `extends ChangeNotifier` or a `with ... ChangeNotifier` mixin clause —
# excluding generated files and build artifacts. Then filter out allowlisted
# entries. Anything that survives is a violation.
#
# Matcher notes:
#   * The trailing `\b` keeps `ChangeNotifierProvider` / `ChangeNotifierX`
#     from matching — only the bare `ChangeNotifier` type counts.
#   * The `with [..]*ChangeNotifier` branch catches the mixin form in any
#     slot (`with ChangeNotifier`, `with Foo, ChangeNotifier`). Anchoring on
#     the `with ` keyword (vs. a bare `, ChangeNotifier`) keeps parameter /
#     field declarations of type ChangeNotifier from tripping the guard.
# ---------------------------------------------------------------------------

CHANGENOTIFIER_PATTERN='extends ChangeNotifier\b|with [A-Za-z0-9_<>, ]*ChangeNotifier\b'

GLOBAL_EXCLUDES=(
  -not -path "*/.dart_tool/*"
  -not -path "*/build/*"
  -not -name "*.g.dart"
  -not -name "*.freezed.dart"
  -not -name "*.mocks.dart"
)

FOUND=$(
  find "$MOBILE_DIR/lib" \
    "${GLOBAL_EXCLUDES[@]}" \
    -name "*.dart" -print0 \
  | xargs -0 grep -l -E "$CHANGENOTIFIER_PATTERN" 2>/dev/null \
  || true
)

VIOLATIONS=""
if [[ -n "$FOUND" ]]; then
  while IFS= read -r abs_path; do
    rel="${abs_path#$MOBILE_DIR/lib/}"
    allowed=0
    for entry in "${ALLOWLIST[@]}"; do
      if [[ "$rel" == "$entry" ]]; then
        allowed=1
        break
      fi
    done
    if [[ "$allowed" -eq 0 ]]; then
      VIOLATIONS+="  mobile/lib/$rel"$'\n'
    fi
  done <<< "$FOUND"
fi

if [[ -n "$VIOLATIONS" ]]; then
  echo "FAIL [changenotifier_boundary]: new ChangeNotifier subclass (\`extends ChangeNotifier\` or \`with ... ChangeNotifier\` mixin) found outside the sanctioned allowlist:"
  printf '%s' "$VIOLATIONS"
  echo ""
  echo "For UI state, use a BLoC/Cubit instead of a ChangeNotifier subclass."
  echo "If the new class is genuinely DI / service / cache / router plumbing"
  echo "(0 feature UI state), add it to the ALLOWLIST in this script AND to"
  echo "the 'Sanctioned Riverpod (STAYS)' table in docs/BLOC_UI_MIGRATION_PRD.md"
  echo "in the same PR."
  exit 1
fi

echo "OK: No new ChangeNotifier classes outside the sanctioned allowlist."
