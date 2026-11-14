#!/usr/bin/env bash
# Fails CI if an Android build change would silently narrow device support.
#
# Divine ships one Play AAB that must reach every device the previous release
# reached. Play compares each upload against the live release and blocks a
# release that "no longer supports N devices"; in Nov 2026 a 1.0.29 upload hit
# exactly that — ~16k devices dropped — because the artifact had lost its
# 32-bit (armeabi-v7a) slice. The repo config was fine; the regression was the
# uploaded binary. This guard freezes the three *config-level* ways that
# regression could become the default, so a future narrowing is caught in a PR
# instead of at the Play upload step. It does NOT (and cannot) inspect the
# built AAB — see mobile/docs/ANDROID_DEVICE_SUPPORT.md for the upload-time
# runbook that covers the artifact itself.
#
# Three checks, all static:
#   1. minSdk must stay <= 28 (Android 9.0). It is pinned at 28 by c2pa_flutter;
#      raising it drops older-OS users with no Google requirement to do so.
#   2. If android/app/build.gradle.kts sets `abiFilters`, it must keep
#      armeabi-v7a (32-bit) — an abiFilters list that omits it narrows the ABI
#      set the AAB ships.
#   3. The Shorebird AAB build in codemagic.yaml must not pass
#      `--target-platform`, which restricts which ABIs `flutter build appbundle`
#      produces and is the most likely way to ship a 64-bit-only AAB.
#
# Runs from mobile/ (the Guards job working directory). Not flagged `native`:
# one of its inputs is the repo-root codemagic.yaml, not native platform config.
set -euo pipefail

gradle="android/app/build.gradle.kts"
codemagic="../codemagic.yaml"
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

# ---------------------------------------------------------------------------
# 3. No --target-platform on the Shorebird AAB build
# ---------------------------------------------------------------------------
if [ ! -f "$codemagic" ]; then
  echo "ℹ️  $codemagic not found from $(pwd); skipping --target-platform check."
else
  tp_hits="$(grep -nE '\-\-target-platform' "$codemagic" || true)"
  if [ -n "$tp_hits" ]; then
    echo "❌ codemagic.yaml passes --target-platform; this narrows the ABIs the"
    echo "   Play AAB ships and can produce a 64-bit-only release:"
    echo "$tp_hits" | sed 's/^/     /'
    echo "   The Play AAB must build every ABI. See"
    echo "   mobile/docs/ANDROID_DEVICE_SUPPORT.md."
    fail=1
  fi
fi

if [ "$fail" -ne 0 ]; then
  echo
  echo "Android device-support policy regressed. If a change here is genuinely"
  echo "intended, update this guard and mobile/docs/ANDROID_DEVICE_SUPPORT.md"
  echo "together so the decision is reviewed."
  exit 1
fi

echo "✅ Android device support intact: minSdk <= 28, 32-bit ABI preserved, no AAB platform restriction."
