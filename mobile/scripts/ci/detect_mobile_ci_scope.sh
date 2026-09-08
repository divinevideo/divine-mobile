#!/usr/bin/env bash
# ABOUTME: Classifies changed files for Mobile CI and automated QA workflows.
# ABOUTME: Uses one fail-open contract across pull requests, merge groups, and pushes.

set -euo pipefail

changed_files="$(mktemp)"
trap 'rm -f "$changed_files"' EXIT

scope_names=(docs_only app native android ios service goldens maestro_static smoke performance ci_config)

write_all_true() {
  for scope in "${scope_names[@]}"; do
    if [ "$scope" = "docs_only" ]; then
      echo "$scope=false" >> "$GITHUB_OUTPUT"
    else
      echo "$scope=true" >> "$GITHUB_OUTPUT"
    fi
  done
}

fall_open() {
  write_all_true
  echo "$1"
  exit 0
}

fetch_compare_files() {
  local base_sha="$1"
  local head_sha="$2"
  local label="$3"
  if [ -z "$base_sha" ] || [ -z "$head_sha" ]; then
    fall_open "$label is missing a base or head SHA; running all mobile QA."
  fi

  if ! gh api --method GET --paginate -F per_page=100 \
    "/repos/${GITHUB_REPOSITORY}/compare/${base_sha}...${head_sha}" \
    --jq '.files[]?.filename' > "$changed_files"; then
    fall_open "$label compare API call failed; running all mobile QA."
  fi

  local file_count
  file_count=$(( $(wc -l < "$changed_files") ))
  if [ "$file_count" -eq 0 ] || [ "$file_count" -ge 300 ]; then
    fall_open "$label returned $file_count files (empty or at the 300-file compare API cap); running all mobile QA."
  fi
}

case "${GITHUB_EVENT_NAME}" in
  pull_request)
    if ! changed_total=$(gh api "/repos/${GITHUB_REPOSITORY}/pulls/${PR_NUMBER}" --jq '.changed_files'); then
      fall_open "PR metadata API call failed; running all mobile QA."
    fi
    if ! [[ "$changed_total" =~ ^[0-9]+$ ]]; then
      fall_open "PR reported a non-numeric changed-file count; running all mobile QA."
    fi
    if [ "$changed_total" -gt 3000 ]; then
      fall_open "PR touches $changed_total files (> 3000 API cap); running all mobile QA."
    fi
    if ! gh api --method GET --paginate -F per_page=100 \
      "/repos/${GITHUB_REPOSITORY}/pulls/${PR_NUMBER}/files" \
      --jq '.[].filename' > "$changed_files"; then
      fall_open "PR files API call failed; running all mobile QA."
    fi
    file_count=$(( $(wc -l < "$changed_files") ))
    if [ "$file_count" -eq 0 ] || [ "$file_count" -ne "$changed_total" ]; then
      fall_open "PR returned $file_count files but reported $changed_total changed files; running all mobile QA."
    fi
    ;;
  merge_group)
    fetch_compare_files "${QUEUE_BASE_SHA:-}" "${QUEUE_HEAD_SHA:-}" "Merge group"
    ;;
  push)
    if [[ "${PUSH_BEFORE_SHA:-}" =~ ^0+$ ]]; then
      fall_open "Push has no comparable before SHA; running all mobile QA."
    fi
    fetch_compare_files "${PUSH_BEFORE_SHA:-}" "${PUSH_AFTER_SHA:-}" "Push"
    ;;
  workflow_dispatch)
    fall_open "Manual dispatch requested; running all mobile QA."
    ;;
  *)
    fall_open "Unsupported event ${GITHUB_EVENT_NAME}; running all mobile QA."
    ;;
esac

echo "Changed files:"
cat "$changed_files"

docs_only=true
app=false
native=false
android=false
ios=false
service=false
goldens=false
maestro_static=false
smoke=false
performance=false
ci_config=false

while IFS= read -r path; do
  case "$path" in
    # A markdown file renders no pixel, builds no binary and exercises no
    # service suite, wherever it sits. Skipping the scope blocks outright
    # keeps a README inside a code directory from turning them on.
    *.md|docs/*|brand-guidelines/*|mobile/docs/*) continue ;;
    *) docs_only=false ;;
  esac

  case "$path" in
    .gitattributes|analytics-contract.lock|analytics-contract.manifest.json|.github/ci-timing-budgets.json)
      app=true ;;
    .github/workflows/mobile_ci.yaml|mobile/scripts/ci/detect_mobile_ci_scope.sh)
      app=true; native=true; android=true; ios=true; service=true; goldens=true
      maestro_static=true; smoke=true; performance=true; ci_config=true ;;
    .github/workflows/*)
      # Four `generated-files` guards read workflow files as their only input
      # (package coverage floor, package CI floor, backend host defaults,
      # service suite coverage), and `mobile/test/tools/` holds the contract
      # tests that pin these workflows. Both live behind `app`, so a workflow
      # edit has to keep running it.
      app=true; ci_config=true ;;
    codemagic.yaml)
      ci_config=true ;;
    mobile/scripts/ci/*)
      app=true; ci_config=true ;;
    mobile/lib/*|mobile/test/*|mobile/integration_test/*|mobile/scripts/*|scripts/*)
      app=true ;;
    mobile/android/*|mobile/ios/*|mobile/macos/*|mobile/web/*|mobile/assets/*|mobile/fonts/*|mobile/overrides/*|mobile/l10n/*)
      app=true ;;
    mobile/pubspec.yaml|mobile/pubspec.lock|mobile/dart_test.yaml|mobile/analysis_options.yaml|mobile/build.yaml|mobile/l10n.yaml|mobile/*)
      app=true ;;
  esac

  case "$path" in
    .gitattributes|mobile/android/*|mobile/ios/*|mobile/macos/*|mobile/scripts/check_native_transport_security.sh|mobile/scripts/check_ios_shipping_versions.sh|mobile/scripts/check_gradle_wrapper_checksum.sh|mobile/scripts/ci/detect_mobile_ci_scope.sh)
      native=true ;;
  esac

  case "$path" in
    mobile/android/*) android=true; smoke=true ;;
    mobile/ios/*) ios=true; smoke=true ;;
    mobile/lib/*|mobile/assets/*|mobile/fonts/*|mobile/integration_test/*|mobile/pubspec.yaml|mobile/pubspec.lock)
      android=true; ios=true; smoke=true ;;
  esac

  case "$path" in
    # Keep this in lockstep with detect_service_suite_scope.sh. That
    # detector decides which suites run; this one decides whether a merge
    # to main schedules them at all, so anything it treats as a service
    # dependency has to be here too — including the runner-level inputs
    # (pubspec, dart_test.yaml, the Linux embedder the suites build on).
    mobile/lib/*|\
    mobile/packages/*|\
    mobile/integration_test/e2e/*|\
    mobile/integration_test/helpers/*|\
    mobile/pubspec.yaml|\
    mobile/pubspec.lock|\
    mobile/dart_test.yaml|\
    mobile/linux/*|\
    .github/workflows/mobile_service_integration_tests.yaml|\
    mobile/scripts/ci/detect_service_suite_scope.sh|\
    mobile/scripts/check_service_suite_coverage.sh)
      service=true ;;
  esac

  # notification_rows_golden_test renders UserAvatar, which imports the
  # provider/router graph. Tracing every import from the two tests under
  # test/goldens plus test/flutter_test_config.dart reaches 2308 files across
  # nearly all of mobile/lib and mobile/packages, so a list of leaf widget
  # directories misses real dependencies: package:models,
  # notification_constants.dart (whose avatarSize the golden pins), the
  # avatar-SVG bloc/provider/repository chain, and the config that calls
  # loadAppFonts() for the suite. A miss runs the goldens in no job at all,
  # because select_test_shard.sh removes test/goldens from every Tests shard.
  # Same closure shape as the two widget-level service suites, same treatment.
  case "$path" in
    mobile/lib/*|mobile/packages/*|mobile/assets/*|mobile/fonts/*|mobile/test/goldens/*|mobile/test/flutter_test_config.dart|mobile/pubspec.yaml|mobile/pubspec.lock|mobile/scripts/golden.sh)
      goldens=true ;;
  esac

  case "$path" in
    mobile/e2e/maestro/*|mobile/scripts/check_maestro_copy_drift.sh|mobile/lib/l10n/app_*.arb|codemagic.yaml)
      maestro_static=true ;;
  esac

  case "$path" in
    mobile/lib/screens/feed/*|mobile/lib/widgets/video_feed*|mobile/lib/widgets/video_feed_item/*|mobile/lib/blocs/video_feed/*|mobile/lib/repositories/feed*|mobile/packages/feed_repository/*|mobile/packages/infinite_video_feed/*|mobile/test/screens/feed/*|mobile/test/widgets/video_feed*|mobile/test/blocs/video_feed/*|mobile/test/repositories/feed*|mobile/integration_test/*feed*|mobile/e2e/maestro/*feed*|mobile/e2e/maestro/*performance*)
      performance=true ;;
  esac
done < "$changed_files"

for scope in "${scope_names[@]}"; do
  echo "$scope=${!scope}" >> "$GITHUB_OUTPUT"
done

echo "Mobile QA scope:"
for scope in "${scope_names[@]}"; do
  echo "  $scope=${!scope}"
done
