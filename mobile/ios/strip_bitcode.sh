#!/bin/bash
# Xcode build phase script to strip bitcode from Zendesk frameworks
# Add this as a "Run Script" build phase AFTER "Embed Frameworks"

set -e

echo "Checking for bitcode in frameworks..."

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

FRAMEWORKS_DIR="${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}"

if [ ! -d "$FRAMEWORKS_DIR" ]; then
    echo "Frameworks directory not found, skipping bitcode strip"
    exit 0
fi

for framework in "${ZENDESK_FRAMEWORKS[@]}"; do
    FRAMEWORK_BINARY="${FRAMEWORKS_DIR}/${framework}.framework/${framework}"

    if [ -f "$FRAMEWORK_BINARY" ]; then
        echo "Stripping bitcode from $framework..."
        # Use temp file to avoid overwriting while reading
        TEMP_FILE="${FRAMEWORK_BINARY}.tmp"
        xcrun bitcode_strip -r "$FRAMEWORK_BINARY" -o "$TEMP_FILE"
        mv "$TEMP_FILE" "$FRAMEWORK_BINARY"
    fi
done

# Clean up any .backup or .tmp files that may exist
find "$FRAMEWORKS_DIR" -name "*.backup" -o -name "*.tmp" | xargs rm -f 2>/dev/null || true

echo "Bitcode stripping complete"
