# Camera Screen Migration Plan
## Migrating Features from UniversalCameraScreenPure to TestCameraScreen

**Goal**: Add all functionality from the old camera screen to the working TestCameraScreen WITHOUT breaking the camera orientation fix.

**Critical Constraint**: The camera preview structure MUST remain exactly as it is:
```dart
Stack(fit: StackFit.expand)
  └─ SizedBox.expand
       └─ FittedBox(fit: BoxFit.cover)
            └─ SizedBox(width: previewSize.height, height: previewSize.width)
                 └─ CameraPreview(_controller!)
```

---

## Phase 1: Safe Additions (No Risk to Orientation)

These features can be added to the Stack WITHOUT touching the camera preview structure.

### 1.1 Back Button (PRIORITY: HIGH)
**Current**: Test screen has back button at top-left
**Status**: ✅ Already implemented
**Location**: Lines 126-132 in test_camera_screen.dart
**Action**: Keep as-is

### 1.2 Recording Indicator (PRIORITY: HIGH)
**Current**: Shows "RECORDING" badge when recording
**Status**: ✅ Already implemented
**Location**: Lines 174-210 in test_camera_screen.dart
**Action**: Keep as-is

### 1.3 Recording Button (PRIORITY: HIGH)
**Current**: Simple tap toggle
**Status**: ✅ Already implemented
**Location**: Lines 135-172 in test_camera_screen.dart
**Action**: Keep as-is, but will need to enhance for mobile vs web behavior

### 1.4 Bottom Control Bar (PRIORITY: HIGH)
**Status**: ❌ Not implemented (Cancel button present, but no gradient overlay, Publish button, or segment counter)
**Add**: Gradient overlay with Cancel/Publish buttons and segment counter
**Risk**: LOW - just Positioned widgets in Stack
**Implementation**:
```dart
// Add after recording button in Stack
Positioned(
  bottom: 0,
  left: 0,
  right: 0,
  child: Container(
    height: 120,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
      ),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Cancel button (X)
        // Record button (center, already exists)
        // Publish button (✓) - only when hasSegments
      ],
    ),
  ),
)
```

### 1.5 Camera Controls (Flash, Timer, Aspect Ratio) (PRIORITY: MEDIUM)
**Status**: ✅ Partial - Flash and Switch Camera implemented, Timer and Aspect Ratio missing
**Add**: Vertical button stack at top-right
**Risk**: LOW - just Positioned widgets in Stack
**Implementation**:
```dart
Positioned(
  top: 60,
  right: 16,
  child: Column(
    children: [
      // Flash button
      // Timer button
      // Aspect ratio button
    ],
  ),
)
```

### 1.6 Switch Camera Button (PRIORITY: MEDIUM)
**Status**: ✅ Implemented at top-right
**Add**: In bottom control bar, right side
**Risk**: LOW - just a button
**Implementation**: Add to Row in bottom control bar

### 1.7 Countdown Overlay (PRIORITY: MEDIUM)
**Add**: Full-screen semi-transparent overlay with countdown number
**Risk**: LOW - just Positioned widget in Stack
**Implementation**:
```dart
if (_countdownValue != null)
  Positioned.fill(
    child: Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Text(
          '$_countdownValue',
          style: TextStyle(fontSize: 72, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    ),
  )
```

### 1.8 Processing Overlay (PRIORITY: MEDIUM)
**Add**: Full-screen overlay with spinner and "Processing video..." text
**Risk**: LOW - just Positioned widget in Stack
**Implementation**:
```dart
if (_isProcessing)
  Positioned.fill(
    child: Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: VineTheme.vineGreen),
            SizedBox(height: 16),
            Text('Processing video...', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    ),
  )
```

### 1.9 Square Crop Mask (PRIORITY: LOW)
**Add**: Darkened top/bottom areas with green border
**Risk**: MEDIUM - uses LayoutBuilder but doesn't touch camera preview
**Implementation**:
```dart
if (_aspectRatio == AspectRatio.square)
  Positioned.fill(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final squareSize = constraints.maxWidth;
        final topBottomHeight = (constraints.maxHeight - squareSize) / 2;
        return Column(
          children: [
            Container(height: topBottomHeight, color: Colors.black.withOpacity(0.6)),
            Container(
              height: squareSize,
              decoration: BoxDecoration(
                border: Border.all(color: VineTheme.vineGreen, width: 3),
              ),
            ),
            Container(height: topBottomHeight, color: Colors.black.withOpacity(0.6)),
          ],
        );
      },
    ),
  )
```

### 1.10 Tap-Anywhere-to-Record (PRIORITY: HIGH)
**Status**: ✅ Implemented with onTapDown/onTapUp/onTapCancel
**Add**: Full-screen GestureDetector for mobile recording
**Risk**: LOW - wraps Stack but doesn't touch camera preview
**Implementation**:
```dart
// Wrap the entire Stack
return Scaffold(
  backgroundColor: Colors.black,
  body: GestureDetector(
    onTapDown: !kIsWeb && _canRecord ? (_) => _startRecording() : null,
    onTapUp: !kIsWeb && _isRecording ? (_) => _stopRecording() : null,
    onTapCancel: !kIsWeb && _isRecording ? () => _stopRecording() : null,
    behavior: HitTestBehavior.translucent,
    child: Stack(
      fit: StackFit.expand,
      children: [
        // Camera preview (unchanged)
        // Other UI elements
      ],
    ),
  ),
)
```

---

## Phase 2: State Management Integration (MODERATE RISK)

These require integrating with Riverpod providers but shouldn't affect camera preview.

### 2.1 Convert to ConsumerStatefulWidget (PRIORITY: HIGH)
**Current**: StatefulWidget
**Change to**: ConsumerStatefulWidget
**Risk**: LOW - just adds `ref` parameter
**Implementation**:
```dart
class TestCameraScreen extends ConsumerStatefulWidget {
  const TestCameraScreen({super.key});

  @override
  ConsumerState<TestCameraScreen> createState() => _TestCameraScreenState();
}

class _TestCameraScreenState extends ConsumerState<TestCameraScreen> {
  // State variables
}
```

### 2.2 Replace Direct Controller with Provider (PRIORITY: HIGH)
**Current**: Local `CameraController? _controller`
**Change to**: `ref.read(vineRecordingProvider.notifier).cameraInterface`
**Risk**: MEDIUM - changes camera initialization flow
**Strategy**:
1. Keep test screen's direct controller approach for now (PROVEN TO WORK)
2. In parallel, create new provider-based screen
3. Only switch when proven working

### 2.3 Add Riverpod Listeners (PRIORITY: MEDIUM)
**Add**: Auto-stop listener, recording state listener
**Risk**: LOW - just adds listeners, doesn't change structure
**Implementation**:
```dart
@override
void initState() {
  super.initState();

  // Add Riverpod listeners in build() or with useEffect
  ref.listen<VineRecordingUIState>(vineRecordingProvider, (previous, next) {
    // Handle auto-stop
    // Handle recording failure
  });
}
```

---

## Phase 3: Enhanced Recording Features (MODERATE RISK)

These change recording behavior but don't touch camera preview.

### 3.1 Multi-Segment Recording (Mobile) (PRIORITY: HIGH)
**Current**: Single recording
**Add**: Press-hold multiple times, concatenate segments
**Risk**: MEDIUM - changes recording flow
**Implementation**:
- Modify `_startRecording()` to create new segment
- Store segments in List<RecordingSegment>
- Show segment counter in UI
- Concatenate on finish via FFmpeg

### 3.2 Web vs Mobile Recording Split (PRIORITY: HIGH)
**Status**: ✅ Implemented (mobile: press-hold, web: tap toggle)
**Current**: Simple tap toggle
**Add**: Platform-specific behavior
**Risk**: LOW - just conditional logic
**Implementation**:
```dart
// Mobile: onTapDown/onTapUp (press-hold)
// Web: onTap toggle (_toggleRecordingWeb)
```

### 3.3 Timer/Countdown Feature (PRIORITY: MEDIUM)
**Add**: 3s/10s countdown before recording starts
**Risk**: LOW - just delays startRecording()
**Implementation**:
```dart
Future<void> _startCountdownTimer() async {
  if (_timerDuration == TimerDuration.off) return;

  final duration = _timerDuration == TimerDuration.three ? 3 : 10;
  for (int i = duration; i > 0; i--) {
    setState(() => _countdownValue = i);
    await Future.delayed(Duration(seconds: 1));
  }
  setState(() => _countdownValue = null);
}
```

### 3.4 Max Duration Auto-Stop (PRIORITY: HIGH)
**Add**: Stop recording at 6.3s, show message
**Risk**: LOW - just checks duration
**Implementation**: Via Riverpod listener watching `remainingDuration`

### 3.5 Flash Control (PRIORITY: LOW)
**Status**: ✅ Implemented (toggles between off → torch → off)
**Add**: Toggle flash modes (off → torch → off)
**Risk**: LOW - just calls controller.setFlashMode()
**Implementation**:
```dart
Future<void> _toggleFlash() async {
  final newMode = _flashMode == FlashMode.off ? FlashMode.torch : FlashMode.off;
  await _controller!.setFlashMode(newMode);
  setState(() => _flashMode = newMode);
}
```

### 3.6 Switch Camera (PRIORITY: MEDIUM)
**Status**: ✅ Implemented with proper state management and recording stop
**Add**: Flip between front/back cameras
**Risk**: HIGH - requires reinitializing camera
**Strategy**:
1. Keep test approach: dispose old controller, create new one
2. Test thoroughly to ensure orientation still works after switch
**Implementation**:
```dart
Future<void> _switchCamera() async {
  final cameras = await availableCameras();
  final currentIndex = cameras.indexWhere((c) => c.lensDirection == _controller!.description.lensDirection);
  final nextIndex = (currentIndex + 1) % cameras.length;

  await _controller!.dispose();
  _controller = CameraController(cameras[nextIndex], ResolutionPreset.high, enableAudio: true);
  await _controller!.initialize();
  await _controller!.lockCaptureOrientation(DeviceOrientation.portraitUp);
  setState(() {});
}
```

---

## Phase 4: Navigation & Processing (MODERATE RISK)

These handle post-recording flow.

### 4.1 Video Processing Pipeline (PRIORITY: HIGH)
**Add**: Create draft, navigate to metadata screen
**Risk**: LOW - happens after recording, doesn't touch camera
**Implementation**:
```dart
Future<void> _processRecording(XFile videoFile, NativeProofData? proofManifest) async {
  setState(() => _isProcessing = true);

  try {
    // Create VineDraft
    final draft = VineDraft.create(
      videoFile: File(videoFile.path),
      title: '',
      description: '',
      hashtags: [],
      frameCount: 0,
      selectedApproach: 'video',
      proofManifestJson: proofManifest != null ? jsonEncode(proofManifest.toJson()) : null,
      aspectRatio: _aspectRatio,
    );

    // Save draft
    final draftService = ref.read(draftStorageServiceProvider);
    await draftService.saveDraft(draft);

    // Navigate to metadata screen
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VideoMetadataScreenPure(draftId: draft.id),
      ),
    );

    // After metadata: navigate to profile
    disposeAllVideoControllers(ref);
    context.go('/profile/me/0');
  } catch (e) {
    _showErrorSnackBar('Processing failed: $e');
  } finally {
    setState(() => _isProcessing = false);
  }
}
```

### 4.2 Draft Storage Integration (PRIORITY: HIGH)
**Add**: DraftStorageService dependency
**Risk**: LOW - just uses service
**Implementation**: Use `ref.read(draftStorageServiceProvider)`

### 4.3 ProofMode Integration (PRIORITY: LOW)
**Add**: Attach ProofMode data to drafts
**Risk**: LOW - just serializes data
**Implementation**: Pass proofManifest from finishRecording() to _processRecording()

---

## Phase 5: Error Handling & Permissions (HIGH PRIORITY)

These improve reliability but don't touch camera preview.

### 5.1 Permission Handling (PRIORITY: HIGH)
**Add**: Permission request flow, permission denied screen
**Risk**: LOW - only affects initialization
**Implementation**:
```dart
Future<void> _checkPermissions() async {
  try {
    await _initializeCamera();
  } catch (e) {
    if (e.toString().contains('permission')) {
      setState(() => _permissionDenied = true);

      // Request permissions
      final statuses = await [Permission.camera, Permission.microphone].request();
      if (statuses[Permission.camera]!.isGranted) {
        setState(() => _permissionDenied = false);
        await _initializeCamera();
      }
    } else {
      setState(() => _errorMessage = 'Failed to initialize: $e');
    }
  }
}
```

### 5.2 Permission Denied Screen (PRIORITY: HIGH)
**Add**: Full-screen permission request UI
**Risk**: LOW - separate screen
**Implementation**: Use `_buildPermissionScreen()` from old camera

### 5.3 Error Screen (PRIORITY: MEDIUM)
**Add**: Full-screen error UI with retry
**Risk**: LOW - separate screen
**Implementation**: Use `_buildErrorScreen()` from old camera

### 5.4 App Lifecycle Listener (PRIORITY: MEDIUM)
**Add**: Re-check permissions when app resumes
**Risk**: LOW - just adds observer
**Implementation**:
```dart
class _TestCameraScreenState extends ConsumerState<TestCameraScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _permissionDenied) {
      _recheckPermissions();
    }
  }
}
```

### 5.5 Snackbar System (PRIORITY: MEDIUM)
**Add**: Error and success snackbars at top of screen
**Risk**: LOW - just shows snackbars
**Implementation**: Use `_showErrorSnackBar()` and `_showSuccessSnackBar()` from old camera

---

## Phase 6: Advanced Features (LOW PRIORITY)

These can be added last.

### 6.1 Aspect Ratio Toggle (PRIORITY: LOW)
**Add**: Switch between square (1:1) and vertical (9:16)
**Risk**: LOW - just stores preference, crop happens in FFmpeg
**Implementation**: Add button, store in state, pass to draft

### 6.2 Video Controller Cleanup (PRIORITY: LOW)
**Add**: Dispose video controllers on entry/exit
**Risk**: LOW - cleanup utility
**Implementation**: Call `disposeAllVideoControllers(ref)` at appropriate times

### 6.3 Orientation Tracking (DEBUG ONLY) (PRIORITY: LOW)
**Add**: Log orientation changes
**Risk**: NONE - just logging
**Implementation**: Add MediaQuery listener with logging

---

## Implementation Strategy

### Step 1: Create New File (Keep Test Screen Working)
```bash
# Copy test_camera_screen.dart to vine_camera_screen.dart
cp lib/screens/test_camera_screen.dart lib/screens/vine_camera_screen.dart
```

**Rationale**: Keep working test screen as reference, build new screen incrementally

### Step 2: Implement in Order (Safety First)
1. **Phase 1** (Safe Additions) - Add UI elements to Stack ✅ LOW RISK
2. **Phase 5** (Error Handling) - Make it robust ✅ LOW RISK
3. **Phase 3** (Recording Features) - Add functionality ⚠️ MODERATE RISK
4. **Phase 4** (Navigation) - Complete the flow ✅ LOW RISK
5. **Phase 2** (Providers) - Integrate Riverpod ⚠️ MODERATE RISK
6. **Phase 6** (Advanced) - Polish ✅ LOW RISK

### Step 3: Test After Each Phase
- ✅ Camera preview orientation works (rotate device)
- ✅ Recording works
- ✅ UI elements render correctly
- ✅ Navigation works
- ✅ Error handling works

### Step 4: Switch Router When Ready
```dart
// In app_router.dart
GoRoute(
  path: '/camera',
  name: 'camera',
  builder: (_, __) => const VineCameraScreen(),  // New screen
),
```

### Step 5: Delete Old Screens
- Remove `UniversalCameraScreenPure` after new screen is stable
- Remove `TestCameraScreen` after reference no longer needed

---

## Critical Rules

### ❌ NEVER TOUCH THIS STRUCTURE:
```dart
Stack(fit: StackFit.expand, children: [
  SizedBox.expand(
    child: FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: _controller!.value.previewSize!.height,
        height: _controller!.value.previewSize!.width,
        child: CameraPreview(_controller!),
      ),
    ),
  ),
  // Other UI elements here
])
```

### ✅ SAFE TO ADD:
- Positioned widgets in Stack (buttons, overlays, indicators)
- GestureDetector wrapping Stack (for tap-anywhere)
- State variables and methods
- Riverpod listeners and providers
- Navigation logic
- Error handling

### ⚠️ TEST THOROUGHLY:
- Camera switching (must maintain orientation after switch)
- Provider integration (ensure preview structure unchanged)
- Platform differences (iOS vs Android vs web)

---

## Testing Checklist

After each phase, verify:

- [ ] Camera preview shows correctly in portrait
- [ ] Rotating device to landscape: preview content stays correct (no distortion)
- [ ] UI elements render on top of preview
- [ ] Recording starts and stops correctly
- [ ] Buttons respond to taps
- [ ] Overlays show/hide correctly
- [ ] Navigation works (metadata screen, profile)
- [ ] Permissions handled gracefully
- [ ] Errors shown to user with retry option
- [ ] Multi-segment recording works (mobile)
- [ ] Web recording works (tap toggle)
- [ ] Camera switch works and maintains orientation

---

## Estimated Timeline

| Phase | Complexity | Time Estimate | Risk Level |
|-------|------------|---------------|------------|
| Phase 1 | Low | 4-6 hours | LOW ✅ |
| Phase 5 | Medium | 3-4 hours | LOW ✅ |
| Phase 3 | High | 6-8 hours | MODERATE ⚠️ |
| Phase 4 | Medium | 3-4 hours | LOW ✅ |
| Phase 2 | High | 4-6 hours | MODERATE ⚠️ |
| Phase 6 | Low | 2-3 hours | LOW ✅ |
| **Total** | | **22-31 hours** | |

---

## Success Criteria

✅ **Camera Orientation**: Works perfectly on iOS and Android (device rotation doesn't distort preview)
✅ **Feature Parity**: All features from old camera screen work in new screen
✅ **Recording Flow**: User can record, review, add metadata, publish
✅ **Error Handling**: Permissions, errors, edge cases handled gracefully
✅ **Multi-Platform**: Works on iOS, Android, and web
✅ **Code Quality**: Clean, maintainable, well-documented

---

## Next Steps

1. **Review this plan with Rabble** ✅
2. **Create `vine_camera_screen.dart` from `test_camera_screen.dart`**
3. **Implement Phase 1 (Safe Additions)**
4. **Test orientation after Phase 1**
5. **Continue through phases sequentially**
6. **Test thoroughly after each phase**
7. **Switch router when ready**
8. **Clean up old screens**
