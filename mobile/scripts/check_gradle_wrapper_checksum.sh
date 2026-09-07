#!/usr/bin/env bash
# Fails CI if the tracked Gradle wrapper JAR is not the exact, official artifact
# we pinned or if its launchers cannot run reliably in a fresh checkout (#7201).
#
# The wrapper is tracked so a fresh clone or worktree can run gradle-based
# tooling without first running `flutter build` -- Flutter injects gradlew only
# when the flutter tool itself is about to exec Gradle, never on
# `flutter pub get`. Tracking it makes gradle-wrapper.jar the one third-party
# binary in this repo, and check_dependency_provenance.sh does not cover it:
# that guard reads pubspec.lock and pubspec.yaml, i.e. pub dependencies only.
# This script closes that gap.
#
# Guards:
#   • gradle-wrapper.jar matches the pinned sha256 exactly.
#   • The pinned sha256 is Gradle's own published wrapper checksum for the
#     version in gradle-wrapper.properties, so the two cannot drift apart.
#   • gradlew keeps its executable bit in the index (a non-executable gradlew
#     is a broken launcher in every fresh checkout).
#   • The launchers keep their platform-specific line-ending attributes.
#
# Deliberately a pinned single checksum rather than
# gradle/actions/wrapper-validation: validating against every Gradle release
# would silently accept any version swap, and we want a wrapper change to be a
# reviewed diff. On an intentional Gradle upgrade, regenerate with
#   cd mobile/android && ./gradlew wrapper --gradle-version <v> --distribution-type all
# then update EXPECTED_VERSION and EXPECTED_SHA256 below from
# https://gradle.org/release-checksums/ ("Wrapper JAR Checksum" for <v>).
set -euo pipefail

# Gradle 8.14 wrapper JAR, per https://gradle.org/release-checksums/
EXPECTED_VERSION="8.14"
EXPECTED_SHA256="7d3a4ac4de1c32b59bc6a4eb8ecb8e612ccd0cf1ae1e99f66902da64df296172"

jar="android/gradle/wrapper/gradle-wrapper.jar"
props="android/gradle/wrapper/gradle-wrapper.properties"
gradlew="android/gradlew"
gradlew_bat="android/gradlew.bat"

fail=0

for f in "$jar" "$props" "$gradlew" "$gradlew_bat"; do
  if [ ! -f "$f" ]; then
    echo "❌ Missing $f. The Gradle wrapper is tracked (#7201); it must not be deleted."
    fail=1
  fi
done
[ "$fail" -eq 0 ] || exit 1

# --- 1. The jar is the exact artifact we pinned ------------------------------
if command -v sha256sum >/dev/null 2>&1; then
  actual="$(sha256sum "$jar" | awk '{print $1}')"
else
  actual="$(shasum -a 256 "$jar" | awk '{print $1}')"
fi

if [ "$actual" != "$EXPECTED_SHA256" ]; then
  echo "❌ $jar does not match the pinned Gradle $EXPECTED_VERSION wrapper JAR."
  echo "   expected: $EXPECTED_SHA256"
  echo "   actual:   $actual"
  echo "   If this is an intentional Gradle upgrade, update EXPECTED_VERSION and"
  echo "   EXPECTED_SHA256 in $0 from https://gradle.org/release-checksums/."
  fail=1
fi

# --- 2. The pin and the distribution cannot drift apart ----------------------
if ! grep -Fq "gradle-${EXPECTED_VERSION}-all.zip" "$props"; then
  echo "❌ $props does not request gradle-${EXPECTED_VERSION}-all.zip, but the"
  echo "   pinned wrapper JAR checksum is Gradle ${EXPECTED_VERSION}'s."
  echo "   distributionUrl is:"
  grep '^distributionUrl' "$props" | sed 's/^/     /'
  fail=1
fi

# --- 3. gradlew stays executable in the index --------------------------------
mode="$(git ls-files -s "$gradlew" | awk '{print $1}')"
if [ "$mode" != "100755" ]; then
  echo "❌ $gradlew is recorded as mode ${mode:-<untracked>}, expected 100755."
  echo "   A non-executable gradlew cannot be run from a fresh checkout. Fix with:"
  echo "     git update-index --chmod=+x mobile/$gradlew"
  fail=1
fi

# --- 4. The launchers keep their platform-specific line endings --------------
gradlew_eol="$(git check-attr --cached eol -- "$gradlew" | awk -F': ' '{print $3}')"
gradlew_bat_eol="$(git check-attr --cached eol -- "$gradlew_bat" | awk -F': ' '{print $3}')"
if [ "$gradlew_eol" != "lf" ]; then
  echo "❌ $gradlew must have the eol=lf attribute, found ${gradlew_eol:-unspecified}."
  fail=1
fi
if [ "$gradlew_bat_eol" != "crlf" ]; then
  echo "❌ $gradlew_bat must have the eol=crlf attribute, found ${gradlew_bat_eol:-unspecified}."
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "✅ Gradle wrapper JAR is pinned to Gradle $EXPECTED_VERSION and its launchers are checkout-safe."
