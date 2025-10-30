# Android Build Guide

## Quick Start

### For Google Play Store Distribution
```bash
./build_android.sh release
```
**Output**: `build/app/outputs/bundle/release/app-release.aab` (Android App Bundle)

### For Local Testing/Sideloading
```bash
./build_android.sh debug
```
**Output**: `build/app/outputs/flutter-apk/app-debug.apk`

## Build Types

| Command | Output Format | Use Case | Signing Required |
|---------|---------------|----------|------------------|
| `./build_android.sh release` | AAB (App Bundle) | Google Play Store | ✅ Yes |
| `./build_android.sh debug` | APK | Local testing, sideloading | ❌ No |

## Important Notes

### Why AAB for Release Builds?

**Google Play Console requires AAB files** for all new app releases and updates. APK files are rejected.

**Benefits of AAB:**
- Smaller downloads (Google generates optimized APKs per device)
- Automatic app signing by Google Play
- Dynamic feature delivery support

**Limitation:**
- AAB files **cannot be installed directly** via `adb install`
- For local testing of release builds, use TestFlight or internal testing track

### Release Build Requirements

1. **Keystore File**: Must exist at `/Users/rabble/android-keys/openvine/upload-keystore.jks`
2. **Key Properties**: `android/key.properties` must contain:
   ```properties
   storePassword=<password>
   keyPassword=<password>
   keyAlias=upload
   storeFile=/Users/rabble/android-keys/openvine/upload-keystore.jks
   ```

The build script automatically verifies these files exist before building.

## Uploading to Google Play Console

1. Run: `./build_android.sh release`
2. Go to [Google Play Console](https://play.google.com/console)
3. Navigate to: **Your App → Testing → Internal testing**
4. Click "Create new release" or "Edit release"
5. Upload: `build/app/outputs/bundle/release/app-release.aab`
6. Complete release notes and save

## Troubleshooting

### "integration_test does not exist" Error

**Cause**: Stale generated plugin files

**Fix**:
```bash
flutter clean
rm android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java
flutter pub get
./build_android.sh release
```

### Keystore Not Found

**Error**: `Error: Keystore not found at /Users/rabble/android-keys/openvine/upload-keystore.jks`

**Fix**: Ensure keystore exists at the specified path or update path in `build_android.sh`

### Build Size Too Large

**Current release AAB size**: ~135 MB

If size becomes an issue:
- Review asset compression
- Enable code shrinking (ProGuard/R8)
- Split ABIs into separate builds
