#!/usr/bin/env bash
# Executes the real Apple plugin with a controlled local model, then typechecks iOS.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCES="$SCRIPT_DIR/publishing_suggestions/Sources/publishing_suggestions"
ENGINE="${FLUTTER_ROOT:?Set FLUTTER_ROOT to a precached Flutter SDK}/bin/cache/artifacts/engine"
FRAMEWORK="$ENGINE/darwin-x64/FlutterMacOS.xcframework/macos-arm64_x86_64"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT
xcrun swiftc -target "$(uname -m)-apple-macos12.0" -F "$FRAMEWORK" -framework FlutterMacOS \
  "$SOURCES"/*.swift "$SCRIPT_DIR/Tests/PublishingSuggestionsTests.swift" \
  -o "$TEST_DIR/tests"
DYLD_FRAMEWORK_PATH="$FRAMEWORK" "$TEST_DIR/tests"
xcrun --sdk iphonesimulator swiftc -typecheck -target arm64-apple-ios13.0-simulator \
  -sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" \
  -F "$ENGINE/ios/Flutter.xcframework/ios-arm64_x86_64-simulator" "$SOURCES"/*.swift
