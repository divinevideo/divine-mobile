#!/bin/bash
# ABOUTME: Universal build script for iOS and macOS that ensures CocoaPods sync
# ABOUTME: Handles proper dependency installation before Xcode builds

set -e

PLATFORM=""
BUILD_TYPE="debug"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        ios|macos)
            PLATFORM="$1"
            shift
            ;;
        debug|release)
            BUILD_TYPE="$1"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [ios|macos] [debug|release]"
            echo "Examples:"
            echo "  $0 ios debug"
            echo "  $0 macos release" 
            echo "  $0 ios (defaults to debug)"
            exit 1
            ;;
    esac
done

# If no platform specified, ask user
if [ -z "$PLATFORM" ]; then
    echo "📱 Which platform would you like to build?"
    echo "1) iOS"
    echo "2) macOS"
    echo "3) Both"
    read -p "Enter choice (1-3): " choice
    
    case $choice in
        1) PLATFORM="ios" ;;
        2) PLATFORM="macos" ;;
        3) PLATFORM="both" ;;
        *) echo "Invalid choice"; exit 1 ;;
    esac
fi

# Navigate to project root
cd "$(dirname "$0")"

# Function to build iOS
build_ios() {
    echo "🍎 Building iOS App..."

    # Ensure Flutter dependencies are up to date
    echo "📦 Getting Flutter dependencies..."
    flutter pub get

    # Generate code (Riverpod providers, Freezed models, etc.)
    echo "🔧 Generating code with build_runner..."
    dart run build_runner build --delete-conflicting-outputs

    # Navigate to iOS directory and install CocoaPods
    echo "🏗️  Installing iOS CocoaPods dependencies..."
    cd ios
    
    # Check if pod install is needed
    if [ ! -f "Pods/Manifest.lock" ] || [ ! -d "Pods" ]; then
        echo "🧹 CocoaPods not installed or out of sync, running pod install..."
        pod install
    else
        echo "📦 Checking if pod install is needed..."
        pod install --repo-update
    fi
    
    cd ..
    
    # Build the iOS app
    echo "🚀 Building iOS app ($BUILD_TYPE)..."
    flutter build ios --$BUILD_TYPE 
    
    echo "✅ iOS build complete!"
}

# Function to build macOS
build_macos() {
    echo "🖥️  Building macOS App..."

    # Reset camera permissions to fix stuck TCC state
    echo "🔐 Resetting camera permissions for fresh build..."
    tccutil reset Camera com.openvine.divine 2>/dev/null || true
    echo "✅ Camera permissions reset (will need to re-grant on first launch)"

    # Ensure Flutter dependencies are up to date
    echo "📦 Getting Flutter dependencies..."
    flutter pub get

    # Generate code (Riverpod providers, Freezed models, etc.)
    echo "🔧 Generating code with build_runner..."
    dart run build_runner build --delete-conflicting-outputs

    # Navigate to macOS directory and install CocoaPods
    echo "🏗️  Installing macOS CocoaPods dependencies..."
    cd macos
    
    # Check if pod install is needed
    if [ ! -f "Pods/Manifest.lock" ] || [ ! -d "Pods" ]; then
        echo "🧹 CocoaPods not installed or out of sync, running pod install..."
        pod install
    else
        echo "📦 Checking if pod install is needed..."
        pod install --repo-update
    fi
    
    cd ..
    
    # Build the macOS app
    echo "🚀 Building macOS app ($BUILD_TYPE)..."
    flutter build macos --$BUILD_TYPE 
    
    echo "✅ macOS build complete!"
}

# Execute builds based on platform choice
case $PLATFORM in
    ios)
        build_ios
        ;;
    macos)
        build_macos
        ;;
    both)
        build_ios
        echo ""
        build_macos
        ;;
esac

echo "🎉 All builds completed successfully!"