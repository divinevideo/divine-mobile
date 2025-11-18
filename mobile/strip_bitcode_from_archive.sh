#!/bin/bash
# ABOUTME: Strips bitcode from all frameworks in an existing xcarchive
# ABOUTME: Run this after flutter build ipa creates the archive

set -e

# Accept archive path as parameter, or use default
ARCHIVE_PATH="${1:-build/ios/archive/Runner.xcarchive}"

if [ ! -d "$ARCHIVE_PATH" ]; then
  echo "❌ Archive not found at $ARCHIVE_PATH"
  echo "   Usage: $0 [path/to/archive.xcarchive]"
  echo "   Default: build/ios/archive/Runner.xcarchive"
  exit 1
fi

echo "🔧 Stripping bitcode from frameworks in archive..."
echo "   Archive: $ARCHIVE_PATH"
echo ""

FRAMEWORKS_DIR="$ARCHIVE_PATH/Products/Applications/Runner.app/Frameworks"

if [ ! -d "$FRAMEWORKS_DIR" ]; then
  echo "❌ Frameworks directory not found: $FRAMEWORKS_DIR"
  exit 1
fi

# Find all framework executables and strip bitcode
STRIPPED_COUNT=0
find "$FRAMEWORKS_DIR" -type d -name "*.framework" | while read -r framework; do
  framework_name=$(basename "$framework" .framework)
  framework_executable="$framework/$framework_name"

  if [ -f "$framework_executable" ]; then
    # Check if it contains bitcode
    if otool -l "$framework_executable" | grep -q __LLVM; then
      echo "   Stripping bitcode from: $framework_name"
      xcrun bitcode_strip -r "$framework_executable" -o "$framework_executable"
      STRIPPED_COUNT=$((STRIPPED_COUNT + 1))
    else
      echo "   ✓ $framework_name (no bitcode found)"
    fi
  fi
done

echo ""
echo "✅ Bitcode stripping complete!"
echo ""
echo "Next steps:"
echo "  1. Open the archive in Xcode:"
echo "     open $ARCHIVE_PATH"
echo ""
echo "  2. Click 'Distribute App' → 'App Store Connect' → 'Upload'"
echo "  3. Validate and upload to TestFlight"
