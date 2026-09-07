#!/usr/bin/env bash
# Fails CI when first-party iOS code uses an Apple "required reason API" that
# the owning bundle's PrivacyInfo.xcprivacy does not declare (#8803).
#
# Zero baseline: there is no exemption list. Declare the API in the owning
# bundle's manifest, or don't call it.
#
# Why this exists. Apple rejects App Store Connect submissions that use a
# required reason API without declaring it, and an SDK may not rely on the host
# app's manifest -- each bundle declares its own. The failure mode is drift, not
# carelessness: divine_camera's manifest was authored 2026-01-14 (#890) with an
# empty NSPrivacyAccessedAPITypes and was correct that day;
# ProcessInfo.systemUptime arrived 2026-02-25 in #1783 and nobody revisited it,
# so the shipping archive carried an undeclared required-reason API for months.
# A manifest well-formedness check would have stayed green the whole time.
#
# Scope: mobile/ios/Runner, the two iOS extension targets,
# mobile/ios/LocalPods/* and mobile/packages/*/ios. Third-party pods under
# mobile/ios/Pods are deliberately excluded -- we cannot fix upstream code, and
# each of the 58 third-party manifests in the archive is shipped by its own
# vendor.
#
# Usage:
#   bash scripts/check_privacy_manifest_coverage.sh
#   bash scripts/check_privacy_manifest_coverage.sh --detail
#   bash scripts/check_privacy_manifest_coverage.sh --archive <path/to/Runner.app>
#
# The --archive mode proves the manifests a source scan trusts actually reach
# the build product. A podspec that loses its resource_bundles line still passes
# a source-only scan while shipping nothing, which is the one gap source
# analysis cannot close.
#
# Docs: mobile/docs/IOS_PRIVACY_MANIFESTS.md
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if ! command -v python3 >/dev/null 2>&1; then
  echo "❌ python3 not found. It is preinstalled on GitHub Actions runners and macOS."
  exit 1
fi

exec python3 "$SCRIPT_DIR/lib/privacy_manifest_coverage.py" \
  --mobile "$MOBILE_DIR" "$@"
