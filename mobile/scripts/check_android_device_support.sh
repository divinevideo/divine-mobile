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
#      raising it drops older-OS users with no Google requirement to do so. Only
#      `minSdk = <number>` is read: any other line naming minSdk fails, because
#      a symbolic value such as flutter.minSdkVersion cannot be checked here.
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
# Resolves its input from its own location, so it runs from any directory;
# ANDROID_APP_GRADLE overrides the file for tests. Not flagged `native`: a
# change to this script alone has to re-run it, and `mobile/scripts/*` turns on
# the app scope the Guards job needs without a detector entry.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
gradle="${ANDROID_APP_GRADLE:-$SCRIPT_DIR/../android/app/build.gradle.kts}"
fail=0

if [ ! -f "$gradle" ]; then
  echo "❌ Cannot find the app Gradle file at $gradle." >&2
  exit 1
fi

# Kotlin shares Dart's comment and string syntax, so the shared stripper keeps
# a commented-out minSdk, or a number in a trailing comment, from being read.
code="$(awk -f "$SCRIPT_DIR/lib/dart_code_only.awk" "$gradle")"

# ---------------------------------------------------------------------------
# 1. minSdk floor (<= 28)
# ---------------------------------------------------------------------------
max_min_sdk=28
min_hits="$(printf '%s\n' "$code" | grep -nE '(^|[^[:alnum:]_.])minSdk' || true)"
if [ -z "$min_hits" ]; then
  echo "❌ No minSdk assignment in $gradle."
  fail=1
fi
while IFS= read -r hit; do
  [ -z "$hit" ] && continue
  lineno="${hit%%:*}"
  value="$(printf '%s\n' "${hit#*:}" |
    sed -nE 's/^[[:space:]]*minSdk[[:space:]]*=[[:space:]]*([0-9]+)[[:space:]]*$/\1/p')"
  if [ -z "$value" ]; then
    echo "❌ $gradle:$lineno sets minSdk in a form this guard cannot read:"
    echo "     $(sed -n "${lineno}p" "$gradle")"
    echo "   Write it as \`minSdk = <number>\`."
    fail=1
  elif [ "$value" -gt "$max_min_sdk" ]; then
    echo "❌ minSdk is $value at $gradle:$lineno; it must stay <= $max_min_sdk (Android 9.0)."
    echo "   28 is pinned by c2pa_flutter. Raising it drops older-OS users."
    echo "   See mobile/docs/ANDROID_DEVICE_SUPPORT.md."
    fail=1
  fi
done <<< "$min_hits"

# ---------------------------------------------------------------------------
# 2. abiFilters must keep 32-bit, if present at all
# ---------------------------------------------------------------------------
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

if [ "$fail" -ne 0 ]; then
  echo
  echo "Android device-support policy regressed. If a change here is genuinely"
  echo "intended, update this guard and mobile/docs/ANDROID_DEVICE_SUPPORT.md"
  echo "together so the decision is reviewed."
  exit 1
fi

echo "✅ Android device support intact: minSdk <= 28, 32-bit ABI preserved."
