#!/usr/bin/env bash
# ABOUTME: Executes Apple diagnostic lifetime tests and typechecks plugin wiring.
# ABOUTME: Requires Xcode and a Flutter SDK precached for iOS and macOS.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCES="$SCRIPT_DIR/divine_video_player/Sources/divine_video_player"
DIAGNOSTICS_DIR="$(mktemp -d)"
trap 'rm -f "$DIAGNOSTICS_DIR/tests"; rmdir "$DIAGNOSTICS_DIR"' EXIT

xcrun swiftc "$SOURCES/PlaybackDiagnostics.swift" \
  "$SCRIPT_DIR/Tests/PlaybackDiagnosticsTests.swift" \
  -o "$DIAGNOSTICS_DIR/tests"
"$DIAGNOSTICS_DIR/tests"

ENGINE="${FLUTTER_ROOT:?Set FLUTTER_ROOT to the precached Flutter SDK}/bin/cache/artifacts/engine"
xcrun swiftc -typecheck -target arm64-apple-macos13.0 \
  -F "$ENGINE/darwin-x64/FlutterMacOS.xcframework/macos-arm64_x86_64" \
  "$SOURCES"/*.swift
xcrun --sdk iphonesimulator swiftc -typecheck \
  -target arm64-apple-ios16.0-simulator \
  -sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" \
  -F "$ENGINE/ios/Flutter.xcframework/ios-arm64_x86_64-simulator" \
  "$SOURCES"/*.swift
