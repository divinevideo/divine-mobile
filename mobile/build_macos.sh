#!/bin/bash
# ABOUTME: macOS build script that ensures CocoaPods dependencies are properly installed
# ABOUTME: before building the macOS app to prevent pod install sync errors

set -e

echo "🖥️  Building macOS App..."

# Navigate to project root
cd "$(dirname "$0")"

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
echo "🏗️  Installing CocoaPods dependencies..."
cd macos

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

# Build the macOS app
echo "🚀 Building macOS app..."
if [ "$1" = "release" ]; then
    echo "🏗️  Building Flutter macOS release..."
    flutter build macos --release 
    
    echo "📦 Creating Xcode archive..."
    cd macos
    
    # Create archive using xcodebuild
    ARCHIVE_NAME="Runner-macOS-$(date +%Y-%m-%d-%H%M%S).xcarchive"
    ORGANIZER_PATH="$HOME/Library/Developer/Xcode/Archives/$(date +%Y-%m-%d)"
    
    # Create Organizer directory if it doesn't exist
    mkdir -p "$ORGANIZER_PATH"
    
    xcodebuild -workspace Runner.xcworkspace \
               -scheme Runner \
               -configuration Release \
               -destination generic/platform=macOS \
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
        echo "   • Choose distribution method (Mac App Store, Developer ID, etc.)"
        
        # Ask user if they want to export to PKG/DMG
        echo ""
        read -p "📦 Would you like to export to PKG for Mac App Store distribution? (y/N): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "📦 Exporting archive to PKG..."
            
            # Create export options plist for Mac App Store distribution
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
            
            # Export archive to PKG
            xcodebuild -exportArchive \
                       -archivePath "$ORGANIZER_PATH/$ARCHIVE_NAME" \
                       -exportOptionsPlist build/ExportOptions.plist \
                       -exportPath build/pkg
            
            if [ $? -eq 0 ]; then
                echo "✅ PKG export successful!"
                echo "📱 PKG location: $(pwd)/build/pkg/Runner.pkg"
                echo "🚀 Ready for Mac App Store upload via Xcode Organizer or Transporter!"
            else
                echo "❌ PKG export failed. Archive is still available in Organizer."
            fi
        fi
    else
        echo "❌ Archive creation failed!"
        exit 1
    fi
    
    cd ..
elif [ "$1" = "debug" ]; then
    flutter build macos --debug 
else
    echo "Usage: $0 [debug|release]"
    echo "  debug   - Build debug version"
    echo "  release - Build release version and create Xcode archive"
    echo "Building in debug mode by default..."
    flutter build macos --debug 
fi

echo "✅ macOS build complete!"