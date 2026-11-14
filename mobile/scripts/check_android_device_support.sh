#!/usr/bin/env bash
# Fails CI if an Android build change would silently narrow device support.
#
# Divine ships one Play AAB that must reach every device the previous release
# reached. Play compares each upload against the live release and blocks a
# release that "no longer supports N devices"; in Nov 2026 a 1.0.29 upload hit
# exactly that — ~16k devices dropped — because the artifact had lost its
# 32-bit (armeabi-v7a) slice. The repo config was fine; the regression was the
# uploaded binary. This guard freezes the Gradle-level ways that regression
# could become the default, so a future narrowing is caught in a PR instead of
# at the Play upload step. It does NOT (and cannot) inspect the built AAB — see
# mobile/docs/ANDROID_DEVICE_SUPPORT.md for the upload-time runbook that covers
# the artifact itself.
#
# Two checks, both static:
#   1. minSdk must stay <= 28 (Android 9.0). It is pinned at 28 by c2pa_flutter;
#      raising it drops older-OS users with no Google requirement to do so.
#   2. If android/app/build.gradle.kts sets `abiFilters`, it must keep
#      armeabi-v7a (32-bit) — an abiFilters list that omits it narrows the ABI
#      set the AAB ships.
#
# The third way, `--target-platform` on a Shorebird Android build in
# codemagic.yaml, is asserted by
# .github/scripts/tests/test_codemagic_shorebird_config.py instead: that suite
# runs on every PR, while the Guards job this guard runs in skips a PR that only
# changes codemagic.yaml.
#
# Runs from mobile/ (the Guards job working directory). Not flagged `native`:
# a change to this script alone has to re-run it, and `mobile/scripts/*` turns
# on the app scope the Guards job needs without a detector entry.
set -euo pipefail

gradle="android/app/build.gradle.kts"
fail=0

# ---------------------------------------------------------------------------
# 1. minSdk floor (<= 28)
# ---------------------------------------------------------------------------
if [ ! -f "$gradle" ]; then
  echo "❌ Missing $gradle."
  fail=1
else
  # Kotlin DSL: `minSdk = 28` (numeric) or `minSdk = flutter.minSdkVersion`.
  min_line="$(grep -nE '^[[:space:]]*minSdk[[:space:]]*=' "$gradle" || true)"
  if [ -z "$min_line" ]; then
    echo "❌ Could not find a minSdk assignment in $gradle."
    fail=1
  elif echo "$min_line" | grep -qE 'minSdk[[:space:]]*=[[:space:]]*[0-9]+'; then
    min_value="$(echo "$min_line" | grep -oE '[0-9]+' | tail -1)"
    if [ "$min_value" -gt 28 ]; then
      echo "❌ minSdk is $min_value in $gradle; it must stay <= 28 (Android 9.0)."
      echo "   28 is pinned by c2pa_flutter. Raising it drops older-OS users."
      echo "   See mobile/docs/ANDROID_DEVICE_SUPPORT.md."
      fail=1
    fi
  elif echo "$min_line" | grep -q 'flutter.minSdkVersion'; then
    : # Flutter's default (24) is below the 28 floor — acceptable.
  else
    echo "❌ Could not read the minSdk value from: $min_line"
    fail=1
  fi
fi

# ---------------------------------------------------------------------------
# 2. abiFilters must keep 32-bit, if present at all
# ---------------------------------------------------------------------------
if [ -f "$gradle" ]; then
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    if ! echo "$line" | grep -q 'armeabi-v7a'; then
      echo "❌ abiFilters in $gradle omits armeabi-v7a (32-bit):"
      echo "     $line"
      echo "   A narrowing abiFilters drops 32-bit devices from the AAB."
      echo "   Keep armeabi-v7a, or remove abiFilters to ship every ABI."
      fail=1
    fi
  done < <(grep -nE 'abiFilters' "$gradle" || true)
fi

if [ "$fail" -ne 0 ]; then
  echo
  echo "Android device-support policy regressed. If a change here is genuinely"
  echo "intended, update this guard and mobile/docs/ANDROID_DEVICE_SUPPORT.md"
  echo "together so the decision is reviewed."
  exit 1
fi

echo "✅ Android device support intact: minSdk <= 28, 32-bit ABI preserved."
