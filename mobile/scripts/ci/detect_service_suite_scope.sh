#!/usr/bin/env bash
# ABOUTME: Classifies changed files for the headless service integration suites.
# ABOUTME: Separates focused service dependencies from app-connected dependencies.

set -euo pipefail

changed_files="$(mktemp)"
trap 'rm -f "$changed_files"' EXIT

emit_scope() {
  echo "focused=$1" >> "$GITHUB_OUTPUT"
  echo "app=$2" >> "$GITHUB_OUTPUT"
}

fall_open() {
  emit_scope true true
  echo "$1"
  exit 0
}

if [ "${GITHUB_EVENT_NAME}" != "pull_request" ]; then
  fall_open "Non-PR event; running every headless service integration suite."
fi

# The files endpoint caps at 3000 entries. A PR that large is not a scoped
# change, so run every suite rather than trusting a truncated response.
changed_total=$(gh api "/repos/${GITHUB_REPOSITORY}/pulls/${PR_NUMBER}" --jq '.changed_files')
if [ "$changed_total" -gt 3000 ]; then
  fall_open "PR touches $changed_total files (> 3000 API cap); running every suite."
fi

gh api --method GET --paginate -F per_page=100 \
  "/repos/${GITHUB_REPOSITORY}/pulls/${PR_NUMBER}/files" \
  --jq '.[].filename' > "$changed_files"

file_count=$(( $(wc -l < "$changed_files") ))
if [ "$file_count" -eq 0 ] || [ "$file_count" -ne "$changed_total" ]; then
  fall_open "PR returned $file_count files but reported $changed_total changed files; running every suite."
fi

echo "Changed files:"
cat "$changed_files"

focused=false
app=false
while IFS= read -r path; do
  # These inputs affect the runner or the suites as a population, so changes
  # run both dependency groups.
  case "$path" in
    .github/workflows/mobile_service_integration_tests.yaml|\
    mobile/scripts/ci/detect_service_suite_scope.sh|\
    mobile/scripts/check_service_suite_coverage.sh|\
    mobile/integration_test/e2e/service_suite_exclusions.txt|\
    mobile/integration_test/e2e/*|\
    mobile/integration_test/helpers/*|\
    mobile/pubspec.yaml|\
    mobile/pubspec.lock|\
    mobile/dart_test.yaml|\
    mobile/linux/*)
      focused=true
      app=true
      ;;
  esac

  # Eleven suites have this maintainable production dependency closure.
  case "$path" in
    mobile/packages/cache_sync/*|\
    mobile/packages/db_client/*|\
    mobile/packages/dm_repository/*|\
    mobile/packages/follow_repository/*|\
    mobile/packages/funnelcake_api_client/*|\
    mobile/packages/models/*|\
    mobile/packages/nostr_client/*|\
    mobile/packages/nostr_sdk/*|\
    mobile/packages/text_sanitizer/*|\
    mobile/packages/unified_logger/*|\
    mobile/lib/observability/crash_reporter.dart|\
    mobile/lib/services/outgoing_dm_retry_service.dart|\
    mobile/lib/services/outgoing_dm_retry_service_reportable_sites.dart|\
    mobile/lib/services/relay_discovery_service.dart|\
    mobile/lib/utils/relay_url_utils.dart)
      focused=true
      ;;
  esac

  # Two widget-level suites import the app's provider/router graph. That graph
  # reaches nearly all app and workspace-package production code, so a narrower
  # rule would silently miss real dependencies.
  case "$path" in
    mobile/lib/*|mobile/packages/*)
      app=true
      ;;
  esac
done < "$changed_files"

emit_scope "$focused" "$app"
echo "Focused service suites required: $focused"
echo "App-connected service suites required: $app"
