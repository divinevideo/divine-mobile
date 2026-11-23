#!/usr/bin/env bash
# Archives the macOS Runner workspace and exports a signed Mac App Store .pkg.
#
# Expects:
#   - `flutter build macos --release ...` already ran (populating ephemeral
#     Flutter xcconfigs and Dart defines).
#   - `scripts/setup_macos_mas_signing.sh` already ran (populating
#     `macos/Runner/Configs/LocalRelease.xcconfig` and
#     `build/macos/ExportOptions.plist`).
#
# Outputs:
#   - build/macos/archive/Runner.xcarchive
#   - build/macos/pkg/Divine.pkg
set -euo pipefail

ARCHIVE_PATH="$(pwd)/build/macos/archive/Runner.xcarchive"
EXPORT_DIR="$(pwd)/build/macos/pkg"
EXPORT_OPTIONS_PLIST="$(pwd)/build/macos/ExportOptions.plist"

if [ ! -f "$EXPORT_OPTIONS_PLIST" ]; then
  echo "ERROR: Missing $EXPORT_OPTIONS_PLIST; run scripts/setup_macos_mas_signing.sh first." >&2
  exit 1
fi

rm -rf "$ARCHIVE_PATH" "$EXPORT_DIR"
mkdir -p "$(dirname "$ARCHIVE_PATH")" "$EXPORT_DIR"

echo "Archiving macOS Runner for Mac App Store..."
(
  cd macos
  xcodebuild \
    -workspace Runner.xcworkspace \
    -scheme Runner \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -archivePath "$ARCHIVE_PATH" \
    archive
)

ARCHIVED_APP=$(find "$ARCHIVE_PATH/Products/Applications" -maxdepth 1 -name '*.app' -print -quit)
if [ -z "$ARCHIVED_APP" ] || [ ! -d "$ARCHIVED_APP" ]; then
  echo "ERROR: No .app bundle found inside $ARCHIVE_PATH/Products/Applications" >&2
  exit 1
fi

echo "Verifying archived app bundle: $ARCHIVED_APP"
codesign --verify --deep --strict --verbose=2 "$ARCHIVED_APP"

if [ ! -f "$ARCHIVED_APP/Contents/embedded.provisionprofile" ]; then
  echo "ERROR: Archived macOS app is missing Contents/embedded.provisionprofile." >&2
  exit 1
fi

if [ ! -f "$ARCHIVED_APP/Contents/Resources/PrivacyInfo.xcprivacy" ]; then
  echo "ERROR: Archived macOS app is missing Contents/Resources/PrivacyInfo.xcprivacy." >&2
  exit 1
fi

ENTITLEMENTS=$(codesign -d --entitlements :- "$ARCHIVED_APP" 2>/dev/null)
if ! grep -q '<key>com.apple.security.app-sandbox</key>' <<<"$ENTITLEMENTS"; then
  echo "ERROR: Archived macOS app is missing App Sandbox entitlement." >&2
  exit 1
fi
if ! grep -q '<key>keychain-access-groups</key>' <<<"$ENTITLEMENTS"; then
  echo "ERROR: Archived macOS app is missing keychain-access-groups entitlement (required for Data Protection Keychain)." >&2
  exit 1
fi

echo "Verifying Firebase Analytics product (no Google ads-measurement SDK)..."
bash scripts/check_ios_analytics_product.sh --app "$ARCHIVED_APP"

echo "Exporting signed Mac App Store .pkg..."
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS_PLIST" \
  -exportPath "$EXPORT_DIR"

PKG_PATH=$(find "$EXPORT_DIR" -maxdepth 1 -name '*.pkg' -print -quit)
if [ -z "$PKG_PATH" ] || [ ! -f "$PKG_PATH" ]; then
  echo "ERROR: xcodebuild -exportArchive did not produce a .pkg in $EXPORT_DIR" >&2
  ls -la "$EXPORT_DIR" >&2 || true
  exit 1
fi

echo "Verifying installer package signature: $PKG_PATH"
pkgutil --check-signature "$PKG_PATH"
echo "Mac App Store package ready: $PKG_PATH"
