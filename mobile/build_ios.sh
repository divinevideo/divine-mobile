#!/bin/bash
# ABOUTME: iOS build script that ensures CocoaPods dependencies are properly installed
# ABOUTME: before building the iOS app to prevent pod install sync errors

set -e

echo "🍎 Building iOS App..."

# Navigate to project root
cd "$(dirname "$0")"

# For release builds, ALWAYS increment build number (required by App Store)
# For debug builds, only increment if --increment flag is passed
if [ "$1" = "release" ]; then
    echo "🔢 Auto-incrementing build number (required for App Store)..."
    ./increment_build_number.sh --auto
    echo ""
elif [[ "$1" == "--increment" || "$2" == "--increment" ]]; then
    echo "🔢 Auto-incrementing build number..."
    ./increment_build_number.sh --auto
    echo ""
fi

# Ensure Flutter dependencies are up to date
echo "📦 Getting Flutter dependencies..."
flutter pub get

# Generate code (Riverpod providers, Freezed models, etc.)
echo "🔧 Generating code with build_runner..."
dart run build_runner build --delete-conflicting-outputs

# Navigate to iOS directory and install CocoaPods
echo "🏗️  Installing CocoaPods dependencies..."
cd ios

# Clean up any potential pod cache issues
if [ -d "Pods" ]; then
    echo "🧹 Cleaning existing Pods directory..."
    rm -rf Pods
fi

if [ -f "Podfile.lock" ]; then
    echo "🧹 Removing existing Podfile.lock..."
    rm -f Podfile.lock
fi

# Install pods
echo "📦 Running pod install..."
pod install

# Navigate back to project root
cd ..

# Build the iOS app
echo "🚀 Building iOS app..."
if [ "$1" = "release" ]; then
    echo "🏗️  Building Flutter iOS release..."
    flutter build ios --release 
    
    echo "📦 Creating Xcode archive..."
    cd ios
    
    # Create archive using xcodebuild
    ARCHIVE_NAME="Runner-$(date +%Y-%m-%d-%H%M%S).xcarchive"
    ORGANIZER_PATH="$HOME/Library/Developer/Xcode/Archives/$(date +%Y-%m-%d)"
    
    # Create Organizer directory if it doesn't exist
    mkdir -p "$ORGANIZER_PATH"
    
    xcodebuild -workspace Runner.xcworkspace \
               -scheme Runner \
               -configuration Release \
               -destination generic/platform=iOS,name="Any iOS Device" \
               -archivePath "$ORGANIZER_PATH/$ARCHIVE_NAME" \
               archive
    
    if [ $? -eq 0 ]; then
        echo "✅ Archive created successfully!"
        echo "📱 Archive location: $ORGANIZER_PATH/$ARCHIVE_NAME"
        
        # Refresh Xcode Organizer if Xcode is running
        if pgrep -x "Xcode" > /dev/null; then
            echo "🔄 Refreshing Xcode Organizer..."
            osascript -e 'tell application "Xcode" to activate' 2>/dev/null || true
        fi
        
        echo "🚀 Archive is now available in Xcode Organizer for distribution!"
        echo "   • Open Xcode → Window → Organizer"
        echo "   • Select your archive and click 'Distribute App'"
        echo "   • Choose distribution method (App Store, Ad Hoc, etc.)"
        
        # Ask user if they want to export to IPA
        echo ""
        read -p "📦 Would you like to export to IPA for App Store distribution? (y/N): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "📦 Exporting archive to IPA..."
            
            # Create export options plist for App Store distribution
            cat > build/ExportOptions.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>compileBitcode</key>
    <false/>
</dict>
</plist>
EOF
            
            # Export archive to IPA
            xcodebuild -exportArchive \
                       -archivePath "$ORGANIZER_PATH/$ARCHIVE_NAME" \
                       -exportOptionsPlist build/ExportOptions.plist \
                       -exportPath build/ipa
            
            if [ $? -eq 0 ]; then
                echo "✅ IPA export successful!"
                echo "📱 IPA location: $(pwd)/build/ipa/Runner.ipa"
                echo "🚀 Ready for App Store upload via Xcode Organizer or Application Loader!"
            else
                echo "❌ IPA export failed. Archive is still available in Organizer."
            fi
        fi
    else
        echo "❌ Archive creation failed!"
        exit 1
    fi
    
    cd ..
elif [ "$1" = "debug" ]; then
    flutter build ios --debug 
else
    echo "Usage: $0 [debug|release] [--increment]"
    echo "  debug       - Build debug version"
    echo "  release     - Build release version and create Xcode archive (auto-increments build number)"
    echo "  --increment - Force auto-increment build number for debug builds"
    echo ""
    echo "Examples:"
    echo "  $0 release              # Build release (automatically increments build number)"
    echo "  $0 debug --increment    # Build debug with build number increment"
    echo ""
    echo "Building in debug mode by default..."
    flutter build ios --debug
fi

echo "✅ iOS build complete!"