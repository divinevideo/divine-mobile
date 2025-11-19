#!/bin/bash
# Strip bitcode from Zendesk frameworks in the built app archive
# Run this script after building but BEFORE uploading to App Store

set -e

# Check if archive path is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <path-to-xcarchive>"
    echo "Example: $0 ~/Library/Developer/Xcode/Archives/2025-11-18/Runner.xcarchive"
    exit 1
fi

ARCHIVE_PATH="$1"
FRAMEWORKS_PATH="${ARCHIVE_PATH}/Products/Applications/Runner.app/Frameworks"

if [ ! -d "$FRAMEWORKS_PATH" ]; then
    echo "Error: Frameworks directory not found at $FRAMEWORKS_PATH"
    exit 1
fi

echo "Stripping bitcode from Zendesk frameworks in archive..."

# List of Zendesk frameworks that contain bitcode
ZENDESK_FRAMEWORKS=(
    "CommonUISDK"
    "MessagingAPI"
    "MessagingSDK"
    "SDKConfigurations"
    "SupportProvidersSDK"
    "SupportSDK"
    "ZendeskCoreSDK"
)

for framework in "${ZENDESK_FRAMEWORKS[@]}"; do
    FRAMEWORK_BINARY="${FRAMEWORKS_PATH}/${framework}.framework/${framework}"

    if [ -f "$FRAMEWORK_BINARY" ]; then
        echo "Processing $framework..."

        # Strip bitcode in-place (no backup)
        # Use a temp file to avoid overwriting while reading
        TEMP_FILE="${FRAMEWORK_BINARY}.tmp"
        xcrun bitcode_strip -r "$FRAMEWORK_BINARY" -o "$TEMP_FILE"
        mv "$TEMP_FILE" "$FRAMEWORK_BINARY"
        echo "  ✅ Bitcode stripped from $framework"

        # Clean up any .backup files that may exist from previous runs
        if [ -f "${FRAMEWORK_BINARY}.backup" ]; then
            rm -f "${FRAMEWORK_BINARY}.backup"
            echo "  🧹 Removed backup file"
        fi
    else
        echo "  ⚠️  Framework binary not found: $FRAMEWORK_BINARY"
    fi
done

# Clean up any remaining .backup files in frameworks directory
echo ""
echo "🧹 Cleaning up any .backup files..."
find "$FRAMEWORKS_PATH" -name "*.backup" -type f -delete

echo ""
echo "✅ Bitcode stripping complete!"
echo ""
echo "You can now upload this archive to App Store Connect:"
echo "  xcodebuild -exportArchive -archivePath \"$ARCHIVE_PATH\" ..."
