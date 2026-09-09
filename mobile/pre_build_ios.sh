#!/bin/bash
# ABOUTME: Pre-action of the shared Runner scheme: repairs the generated Swift package floor, syncs CocoaPods.
# ABOUTME: Runs no Flutter command; plugin injection can reset that floor below iOS 16.

set -e

echo "🔧 Pre-build: Ensuring iOS CocoaPods dependencies are synced..."

# Get the directory where this script is located (should be project root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Never run a Flutter command here. Plugin injection rewrites
# ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift
# at Flutter's default iOS floor, which can be lower than plugins require.
# Repair it in place, without invoking Flutter.
#
# This cannot rescue the build it runs in. Xcode emits "Resolve Package Graph"
# before it runs scheme pre-actions, so a build that starts too low still fails;
# measured 2026-09-06. What this buys is that the failure stops repeating: the
# next build reads 16.0 and succeeds. Run `flutter build ios --config-only`
# after a terminal Flutter command to skip the wasted first build.
# See .claude/rules/ios_build_troubleshooting.md, Cause 3.
SWIFT_PACKAGE_MANIFEST="ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift"
if [ -f "$SWIFT_PACKAGE_MANIFEST" ]; then
    ruby scripts/ensure_ios_swift_package_floor.rb "$SWIFT_PACKAGE_MANIFEST"
fi

# Navigate to iOS directory
cd ios

# Set environment for CocoaPods to avoid Ruby issues
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Make rbenv-managed executables discoverable before resolving CocoaPods. The
# shims work from PATH directly; shell initialization is unnecessary here and
# must not be allowed to fail every Xcode build.
if [ -d "$HOME/.rbenv" ]; then
    export PATH="$HOME/.rbenv/shims:$HOME/.rbenv/bin:$PATH"
fi

# Find CocoaPods command
POD_CMD=""
if command -v pod >/dev/null 2>&1; then
    POD_CMD="pod"
elif [ -f "/opt/homebrew/bin/pod" ]; then
    POD_CMD="/opt/homebrew/bin/pod"
elif [ -f "/usr/local/bin/pod" ]; then
    POD_CMD="/usr/local/bin/pod"
else
    echo "❌ ERROR: CocoaPods not found!"
    echo "   Please install: sudo gem install cocoapods"
    exit 1
fi

# Check if CocoaPods needs to be installed or updated
if [ ! -f "Pods/Manifest.lock" ] || [ ! -d "Pods" ]; then
    echo "⚠️  CocoaPods not found, running pod install..."
    "$POD_CMD" install --verbose
elif [ "Podfile.lock" -nt "Pods/Manifest.lock" ]; then
    echo "⚠️  Podfile.lock is newer than Manifest.lock, running pod install..."
    "$POD_CMD" install --verbose
else
    echo "✅ CocoaPods dependencies are up to date"
fi

echo "✅ Pre-build iOS setup complete!"
