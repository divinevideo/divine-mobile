#!/bin/bash
# ABOUTME: Build script for diVine Android app (debug and release builds)
# ABOUTME: Builds debug APKs for testing and release AABs for Play Store distribution

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
BUILD_TYPE="debug"
VERBOSE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    debug|release)
      BUILD_TYPE="$1"
      shift
      ;;
    -v|--verbose)
      VERBOSE=true
      shift
      ;;
    -h|--help)
      echo "Usage: ./build_android.sh [debug|release] [-v|--verbose]"
      echo ""
      echo "Build types:"
      echo "  debug    - Build debug APK (default, no signing required)"
      echo "  release  - Build signed release AAB for Google Play (requires keystore)"
      echo ""
      echo "Options:"
      echo "  -v, --verbose  Show detailed build output"
      echo "  -h, --help     Show this help message"
      exit 0
      ;;
    *)
      echo -e "${RED}Error: Unknown argument '$1'${NC}"
      echo "Run './build_android.sh --help' for usage information"
      exit 1
      ;;
  esac
done

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}diVine Android Build${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "Build type: ${YELLOW}$BUILD_TYPE${NC}"
echo ""

# Change to mobile directory
cd "$(dirname "$0")"

# For release builds, ALWAYS increment build number (required by Play Store)
if [ "$BUILD_TYPE" = "release" ]; then
  echo -e "${YELLOW}🔢 Auto-incrementing build number (required for Play Store)...${NC}"
  ./increment_build_number.sh --auto
  echo ""
fi

# Clean previous builds
echo -e "${YELLOW}Cleaning previous builds...${NC}"
flutter clean
flutter pub get

# Generate code (Riverpod providers, Freezed models, etc.)
echo -e "${YELLOW}Generating code with build_runner...${NC}"
dart run build_runner build --delete-conflicting-outputs

# Verify keystore exists for release builds
if [ "$BUILD_TYPE" = "release" ]; then
  KEYSTORE_PATH="/Users/rabble/android-keys/openvine/upload-keystore.jks"
  if [ ! -f "$KEYSTORE_PATH" ]; then
    echo -e "${RED}Error: Keystore not found at $KEYSTORE_PATH${NC}"
    echo "Release builds require a valid keystore file."
    exit 1
  fi

  if [ ! -f "android/key.properties" ]; then
    echo -e "${RED}Error: android/key.properties not found${NC}"
    echo "Release builds require key.properties file with keystore credentials."
    exit 1
  fi

  echo -e "${GREEN}✓ Keystore verified${NC}"
  echo ""
fi

# Build APK or AAB depending on build type
if [ "$BUILD_TYPE" = "release" ]; then
  echo -e "${YELLOW}Building Android App Bundle (AAB) for Play Store...${NC}"
  echo ""

  if [ "$VERBOSE" = true ]; then
    flutter build appbundle --release -v
  else
    flutter build appbundle --release
  fi
else
  echo -e "${YELLOW}Building Android APK ($BUILD_TYPE)...${NC}"
  echo ""

  if [ "$VERBOSE" = true ]; then
    flutter build apk --$BUILD_TYPE -v
  else
    flutter build apk --$BUILD_TYPE
  fi
fi

# Check build result
if [ $? -eq 0 ]; then
  echo ""
  echo -e "${GREEN}================================${NC}"
  echo -e "${GREEN}Build Successful!${NC}"
  echo -e "${GREEN}================================${NC}"
  echo ""

  if [ "$BUILD_TYPE" = "release" ]; then
    OUTPUT_PATH="build/app/outputs/bundle/release/app-release.aab"
    OUTPUT_TYPE="AAB"
  else
    OUTPUT_PATH="build/app/outputs/flutter-apk/app-debug.apk"
    OUTPUT_TYPE="APK"
  fi

  if [ -f "$OUTPUT_PATH" ]; then
    OUTPUT_SIZE=$(du -h "$OUTPUT_PATH" | cut -f1)
    echo -e "$OUTPUT_TYPE location: ${YELLOW}$OUTPUT_PATH${NC}"
    echo -e "$OUTPUT_TYPE size: ${YELLOW}$OUTPUT_SIZE${NC}"
    echo ""

    if [ "$BUILD_TYPE" = "release" ]; then
      echo -e "${GREEN}To upload to Google Play Console:${NC}"
      echo -e "  1. Go to Google Play Console > Your app > Testing > Internal testing"
      echo -e "  2. Create or manage a release"
      echo -e "  3. Upload the AAB file: $OUTPUT_PATH"
      echo ""
      echo -e "${YELLOW}Note: AAB files cannot be installed directly via adb.${NC}"
      echo -e "${YELLOW}For local testing, use './build_android.sh debug' to build an APK.${NC}"
      echo ""
    else
      # Show installation instructions for debug APK
      echo -e "${GREEN}To install on a connected device or emulator:${NC}"
      echo -e "  flutter install"
      echo ""
      echo -e "${GREEN}To install APK directly with adb:${NC}"
      echo -e "  adb install $OUTPUT_PATH"
      echo ""
    fi
  else
    echo -e "${RED}Warning: $OUTPUT_TYPE file not found at expected location${NC}"
  fi
else
  echo ""
  echo -e "${RED}================================${NC}"
  echo -e "${RED}Build Failed!${NC}"
  echo -e "${RED}================================${NC}"
  echo ""
  echo "Run with -v flag for verbose output to diagnose issues."
  exit 1
fi
