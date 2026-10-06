# Camera Architecture Documentation

Status: Current
Validated against: current camera architecture notes on 2026-03-19.

## Overview

Divine uses **4 different camera interface implementations** to handle platform-specific requirements and capabilities. This multi-interface approach allows for platform-specific optimizations while maintaining a consistent API.

## Shutter Gesture Invariant

Recorder shutter surfaces that combine tap-to-toggle and long-press recording
must route those gestures through
`mobile/lib/widgets/video_recorder/shutter_gesture_detector.dart`.

This preserves a recorder-specific invariant introduced after issue `#4409`:
- A tap-started recording must not be stopped by an incidental long-press
  release on the same shutter target.
- New shutter surfaces should reuse the shared widget instead of wiring
  `GestureDetector` callbacks manually.

## Camera Interface Implementations

### 1. MobileCameraInterface (Basic)
- **Location**: `lib/services/vine_recording_controller.dart` (line 66)
- **Used on**:
  - iOS (always - primary)
  - Android (fallback only if enhanced camera fails)
- **Reason for iOS**: iOS devices experience performance issues with the enhanced camera implementation (dark/slow preview)
- **Features**: Basic video recording with camera switching
- **Permission handling**: Relies on Flutter `camera` package's native code

**Key characteristics**:
- Simple, reliable camera controller
- Minimal configuration (ResolutionPreset.high, enableAudio: true)
- Calls `prepareForVideoRecording()` for iOS compatibility
- No explicit permission requests - handled by camera package

### 2. EnhancedMobileCameraInterface
- **Location**: `lib/services/camera/enhanced_mobile_camera_interface.dart`
- **Used on**: Android (primary, with fallback to basic if initialization fails)
- **Features**:
  - Pinch-to-zoom gesture control
  - Tap-to-focus with visual indicator
  - Flash mode toggling (off → auto → torch → off)
  - Zoom level indicator overlay
- **Permission handling**: No explicit requests - relies on camera package
- **Error handling**: Provides detailed error messages for permission issues

**Android-specific benefits**:
- Better camera controls for Android devices
- Graceful fallback to basic camera if enhanced features fail
- Zoom range: device-dependent (typically 1.0x to 8.0x+)

### 3. MacOSCameraInterface
- **Location**: `lib/services/vine_recording_controller.dart` (line 336)
- **Used on**: macOS only
- **Implementation**: Native Swift plugin (`macos/NativeCameraPlugin.swift`)
- **Permission handling**: **Explicit permission requests via AVFoundation**

**Native permission flow** (NativeCameraPlugin.swift lines 85-115):
```swift
let authStatus = AVCaptureDevice.authorizationStatus(for: .video)

switch authStatus {
case .authorized:
    setupCaptureSession(result: result)
case .notDetermined:
    AVCaptureDevice.requestAccess(for: .video) { granted in
        if granted {
            setupCaptureSession(result: result)
        } else {
            result(FlutterError(code: "PERMISSION_DENIED", ...))
        }
    }
case .denied, .restricted:
    result(FlutterError(code: "PERMISSION_DENIED", ...))
}
```

**Why separate implementation**:
- macOS uses `AVCaptureSession` directly (not Flutter camera package)
- Native plugin provides better macOS integration
- Proper TCC (Transparency, Consent, and Control) permission handling

### 4. WebCameraInterface
- **Location**: `lib/services/vine_recording_controller.dart` (line 585)
- **Used on**: Web/Chrome browsers
- **Permission handling**: Browser-based permission prompts
- **Features**: Basic recording using browser MediaStream API

## Platform Selection Logic

**Decision tree** (vine_recording_controller.dart lines 845-874):

```dart
if (Platform.isMacOS) {
  // Use native macOS plugin
  _cameraInterface = MacOSCameraInterface();

} else if (Platform.isIOS || Platform.isAndroid) {

  if (Platform.isIOS) {
    // Always use basic camera for iOS (performance optimization)
    _cameraInterface = MobileCameraInterface();

  } else {
    // Android: Try enhanced camera first, fallback to basic
    try {
      _cameraInterface = EnhancedMobileCameraInterface();
      await _cameraInterface!.initialize();
      Log.info('Using enhanced mobile camera with zoom and focus features');
    } catch (enhancedError) {
      Log.warning('Enhanced camera failed, falling back to basic camera');
      _cameraInterface?.dispose();
      _cameraInterface = MobileCameraInterface();
      await _cameraInterface!.initialize();
    }
  }

} else if (kIsWeb) {
  // Use web camera interface
  _cameraInterface = WebCameraInterface();
}
```

## Permission Handling by Platform

### iOS
- **Info.plist keys** (ios/Runner/Info.plist):
  - `NSCameraUsageDescription`: "Divine needs access to your camera to record short videos."
  - `NSMicrophoneUsageDescription`: "Divine needs access to your microphone to record audio with videos."
- **Permission request timing**: When `CameraController.initialize()` is first called
- **Handled by**: Flutter `camera` package native iOS code
- **No explicit Dart code needed** - permissions requested automatically

### Android
- **Manifest permissions** (android/app/src/main/AndroidManifest.xml):
  - `android.permission.CAMERA`
  - `android.permission.RECORD_AUDIO`
- **Permission request timing**: When `CameraController.initialize()` is first called
- **Handled by**: Flutter `camera` package native Android code
- **Runtime permissions**: Automatically requested on Android 6.0+

### macOS
- **Info.plist keys** (macos/Runner/Info.plist):
  - `NSCameraUsageDescription`: "Divine needs access to your camera to record short videos."
  - `NSMicrophoneUsageDescription`: "Divine needs access to your microphone to record audio with videos."
- **Permission request timing**: When `NativeCameraPlugin.initializeCamera()` is called
- **Handled by**: Custom Swift code using `AVCaptureDevice.requestAccess(for: .video)`
- **TCC database**: macOS tracks permissions in TCC (Transparency, Consent, and Control) database
- **Bundle ID**: `co.openvine.app` (must match for permission persistence)

### Web
- **Browser permissions**: Handled by browser's MediaStream API
- **User prompt**: Shown when accessing camera for first time
- **Persistence**: Browser-dependent (usually per-origin)

## Common Permission Issues

### macOS Debug Builds Losing Permissions
**Problem**: Debug builds get new code signatures each time, causing macOS to treat them as "different apps"

**Symptoms**:
- Permission works once, then breaks on next debug build
- `tccutil reset Camera co.openvine.app` reports "No such bundle identifier"
- Permission dialog appears inside app window instead of as system dialog

**Solutions**:
1. Use release builds for testing (consistent signature)
2. Reset entire TCC database: `sudo tccutil reset Camera`
3. Reboot Mac to clear TCC state

### iOS Permissions Not Persisting
**Problem**: App loses camera permissions after reinstall or update

**Symptoms**:
- Permission prompt appears every time
- Settings app shows no permission entry

**Solutions**:
1. Check bundle identifier matches between builds: `co.openvine.app`
2. Ensure Info.plist usage descriptions are present
3. Clean build and reinstall: `flutter clean && flutter build ios`

## Testing Camera Permissions

### Recommended Test Sequence
1. **Fresh install**: Uninstall app completely, then install fresh build
2. **Grant permission**: Launch app, grant camera permission when prompted
3. **Verify persistence**: Close and relaunch app - should not re-prompt
4. **Deny permission**: Revoke permission in Settings, verify app shows appropriate error
5. **Re-grant permission**: Grant permission in Settings, verify app resumes working

### Platform-Specific Testing

**iOS**:
- Settings → Privacy & Security → Camera → Divine (toggle off/on)
- Test both front and back cameras
- Test camera switching during recording

**Android**:
- Settings → Apps → Divine → Permissions → Camera (toggle off/on)
- Test enhanced camera features (zoom, focus, flash)
- Verify fallback to basic camera if enhanced fails

**macOS**:
- System Settings → Privacy & Security → Camera (toggle off/on)
- Test with both debug and release builds
- Verify permission persists across app launches (release builds only)

## Architecture Rationale

### Why Multiple Interfaces?

1. **Platform-specific optimizations**: iOS needs basic camera for performance, Android benefits from enhanced features
2. **Native integration**: macOS uses native AVFoundation for better system integration
3. **Progressive enhancement**: Enhanced features on Android, basic functionality on iOS
4. **Graceful fallback**: Android can fall back to basic camera if enhanced features fail

### Why Not One Universal Interface?

- **Performance**: iOS has documented issues with advanced camera features in Flutter
- **Capabilities**: Different platforms support different camera features
- **Permission models**: iOS/Android use runtime permissions, macOS uses TCC database
- **Native APIs**: macOS benefits from direct AVFoundation usage

## Future Improvements

### Potential Enhancements
1. **Unified permission API**: Abstract platform-specific permission handling
2. **Enhanced iOS camera**: Investigate performance issues and potentially enable zoom/focus
3. **Feature detection**: Runtime detection of supported camera features
4. **Permission state management**: Centralized permission state tracking

### Known Issues
1. **iOS enhanced camera performance**: Dark/slow preview on iOS devices (documented in code)
2. **macOS debug build permissions**: TCC database treats each debug build as new app
3. **Permission dialog inside app**: Indicates TCC database corruption (macOS)

## Related Files

- `lib/services/vine_recording_controller.dart` - Main recording controller with platform selection
- `lib/services/camera/enhanced_mobile_camera_interface.dart` - Enhanced Android camera
- `macos/NativeCameraPlugin.swift` - macOS native camera implementation
- `ios/Runner/Info.plist` - iOS permission descriptions
- `macos/Runner/Info.plist` - macOS permission descriptions
- `android/app/src/main/AndroidManifest.xml` - Android permission declarations

## See Also

- [Flutter Camera Plugin Documentation](https://pub.dev/packages/camera)
- [Apple TCC Documentation](https://developer.apple.com/documentation/avfoundation/cameras_and_media_capture/requesting_authorization_for_media_capture_on_ios)
- [Android Camera Permissions](https://developer.android.com/training/permissions/requesting)
