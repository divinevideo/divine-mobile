#!/usr/bin/env bash
# ABOUTME: Classifies changed files to decide which Mobile CI jobs must run.
# ABOUTME: Handles pull requests, merge-queue groups, and fall-open events.

set -euo pipefail

changed_files="$(mktemp)"
trap 'rm -f "$changed_files"' EXIT

fall_open() {
  echo "app=true" >> "$GITHUB_OUTPUT"
  echo "native=true" >> "$GITHUB_OUTPUT"
  echo "$1"
  exit 0
}

case "${GITHUB_EVENT_NAME}" in
  pull_request)
    # The files endpoint caps at 3000 entries. A PR that large is not a scoped
    # change, so fall open rather than under-running CI on a truncated list.
    changed_total=$(gh api "/repos/${GITHUB_REPOSITORY}/pulls/${PR_NUMBER}" --jq '.changed_files')
    if [ "$changed_total" -gt 3000 ]; then
      fall_open "PR touches $changed_total files (> 3000 API cap); running full app CI."
    fi

    gh api --method GET --paginate -F per_page=100 \
      "/repos/${GITHUB_REPOSITORY}/pulls/${PR_NUMBER}/files" \
      --jq '.[].filename' > "$changed_files"

    file_count=$(( $(wc -l < "$changed_files") ))
    if [ "$file_count" -eq 0 ] || [ "$file_count" -ne "$changed_total" ]; then
      fall_open "PR returned $file_count files but reported $changed_total changed files; running full app CI."
    fi
    ;;
  merge_group)
    # The queue head is a speculative merge of main plus every PR ahead of it
    # in the batch, so this diff is exactly what the queue is about to land.
    gh api --method GET --paginate -F per_page=100 \
      "/repos/${GITHUB_REPOSITORY}/compare/${QUEUE_BASE_SHA}...${QUEUE_HEAD_SHA}" \
      --jq '.files[]?.filename' > "$changed_files"

    # The compare endpoint includes at most 300 changed files for the whole
    # comparison. A queue entry always has a change, so empty or capped output
    # is unusable and must fall open to the full matrix.
    file_count=$(( $(wc -l < "$changed_files") ))
    if [ "$file_count" -eq 0 ] || [ "$file_count" -ge 300 ]; then
      fall_open "Merge group returned $file_count files (empty or at the 300-file compare API cap); running full app CI."
    fi
    ;;
  *)
    fall_open "Non-PR event; running full app CI."
    ;;
esac

echo "Changed files:"
cat "$changed_files"

app=false
native=false
while IFS= read -r path; do
  case "$path" in
    .gitattributes)
      app=true
      ;;
    analytics-contract.lock|analytics-contract.manifest.json)
      app=true
      ;;
    .github/ci-timing-budgets.json)
      app=true
      ;;
    .github/workflows/*)
      app=true
      native=true
      ;;
    *.md|docs/*|brand-guidelines/*|mobile/docs/*)
      # Docs-only changes do not need the full app test matrix.
      ;;
    mobile/lib/*|mobile/test/*|mobile/integration_test/*|mobile/scripts/*)
      app=true
      ;;
    mobile/android/*|mobile/ios/*|mobile/macos/*|mobile/web/*|mobile/assets/*|mobile/fonts/*|mobile/overrides/*|mobile/l10n/*)
      app=true
      ;;
    mobile/pubspec.yaml|mobile/pubspec.lock|mobile/dart_test.yaml|mobile/analysis_options.yaml|mobile/build.yaml|mobile/l10n.yaml)
      app=true
      ;;
    mobile/*)
      app=true
      ;;
  esac

  # The transport-security guard reads native configuration plus its own
  # scripts. Match at directory level so this gate cannot silently drift when
  # the guard gains another native input.
  case "$path" in
    .gitattributes|mobile/android/*|mobile/ios/*|mobile/macos/*|mobile/scripts/check_native_transport_security.sh|mobile/scripts/check_ios_shipping_versions.sh|mobile/scripts/check_gradle_wrapper_checksum.sh|mobile/scripts/ci/detect_mobile_ci_scope.sh)
      native=true
      ;;
  esac
done < "$changed_files"

echo "app=$app" >> "$GITHUB_OUTPUT"
echo "native=$native" >> "$GITHUB_OUTPUT"
if [ "$app" = "true" ]; then
  echo "App CI required."
else
  echo "Package-only/docs-only change; app CI jobs may be skipped."
fi
echo "Native transport-security inputs changed: $native"
