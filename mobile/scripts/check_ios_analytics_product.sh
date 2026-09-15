#!/usr/bin/env bash
# Fails when a built iOS app carries Google's ads-measurement code (#7303).
#
# Divine's analytics property has no Google Ads account linked, personalized
# advertising is off and there is no ATT prompt (docs/IOS_PRIVACY_MANIFESTS.md,
# decision D1). The default FlutterFire product, `FirebaseAnalytics`, still
# links `GoogleAdsOnDeviceConversion` and `GoogleAppMeasurementIdentitySupport`
# — on the 1.0.20 store population that SDK made ~4 requests and downloaded
# ~13 KB per app start to `*.app-ads-services.com`, reporting to nobody.
# `FirebaseAnalyticsCore` links neither. The plugin picks it only when
# FIREBASE_ANALYTICS_WITHOUT_ADID is present in the environment while Xcode
# evaluates `firebase_analytics`'s Package.swift, and nothing else notices
# when that variable is missing: the build succeeds either way and the
# difference shows up weeks later in the Performance export. This check reads
# the product Xcode actually linked, so the fallback fails the build instead.
#
# Two assertions, both on the Mach-O binaries in the bundle (the executable,
# any root-level dylib, and any embedded framework):
#   • no binary references `app-ads-services.com` — the only hosts
#     GoogleAdsOnDeviceConversion talks to;
#   • at least one binary references `app-analytics-services.com` — the
#     Analytics upload host. This proves analytics is still linked and that the
#     scan looked at a real binary; without it a wrong --app path or a stripped
#     stub would pass vacuously.
#
# Usage:
#   bash scripts/check_ios_analytics_product.sh --app <path/to/Runner.app>
#
# Docs: docs/NETWORK_PERFORMANCE_MONITORING.md ("Google SDK traffic")
set -euo pipefail

app=""
while [ $# -gt 0 ]; do
  case "$1" in
    --app)
      shift
      app="${1:-}"
      ;;
    *)
      echo "❌ Unknown argument: $1" >&2
      echo "Usage: bash scripts/check_ios_analytics_product.sh --app <path/to/Runner.app>" >&2
      exit 2
      ;;
  esac
  shift
done

if [ -z "$app" ] || [ ! -d "$app" ]; then
  echo "❌ --app must point at a built .app bundle (got: '${app:-<missing>}')." >&2
  exit 2
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "❌ python3 not found. It is preinstalled on Codemagic macOS images and GitHub Actions runners." >&2
  exit 2
fi

# plistlib rather than PlistBuddy so the guard, and its test, run on Linux too.
executable="$(python3 -c 'import plistlib, sys; print(plistlib.load(open(sys.argv[1], "rb")).get("CFBundleExecutable", ""))' "$app/Info.plist" 2>/dev/null || true)"
if [ -z "$executable" ] || [ ! -f "$app/$executable" ]; then
  echo "❌ $app has no CFBundleExecutable binary." >&2
  exit 2
fi

# A release build links the SDK's static frameworks into the executable; a
# debug build puts the app code in Runner.debug.dylib beside a stub executable,
# and the embedded Google*.framework bundles are 50 KB SPM stubs either way.
binaries=("$app/$executable")
for dylib in "$app"/*.dylib; do
  [ -f "$dylib" ] && binaries+=("$dylib")
done
if [ -d "$app/Frameworks" ]; then
  for fw in "$app"/Frameworks/*.framework; do
    [ -d "$fw" ] || continue
    name="$(basename "$fw" .framework)"
    [ -f "$fw/$name" ] && binaries+=("$fw/$name")
  done
fi

fail=0
analytics_seen=0
# grep -a on the file itself rather than `strings | grep -q`: under pipefail
# grep -q closes the pipe on the first hit and strings exits on SIGPIPE, which
# turns a match into a false condition.
for bin in "${binaries[@]}"; do
  if grep -a -q 'app-ads-services\.com' "$bin"; then
    echo "❌ ${bin#"$app"/} links Google ads-measurement code (references app-ads-services.com)."
    fail=1
  fi
  if grep -a -q 'app-analytics-services\.com' "$bin"; then
    analytics_seen=1
  fi
done

if [ "$analytics_seen" -eq 0 ]; then
  echo "❌ No binary in $app references app-analytics-services.com — Firebase Analytics is not linked, or the scan did not reach the real binary."
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  echo "   The iOS build must run with FIREBASE_ANALYTICS_WITHOUT_ADID set so firebase_analytics links FirebaseAnalyticsCore. Check the workflow's vars, then 'flutter clean' and rebuild — Xcode keeps the evaluated Package.swift in build/ios/SourcePackages, so setting the variable alone does not re-resolve."
  exit 1
fi

echo "OK [ios_analytics_product]: FirebaseAnalyticsCore linked — app-analytics-services.com present, app-ads-services.com absent (${#binaries[@]} binaries scanned)."
