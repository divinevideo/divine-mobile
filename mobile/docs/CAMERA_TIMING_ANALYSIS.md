Status: Historical

> Historical note
> Analyses the `Future.delayed` calls in `vine_recording_controller.dart`, which the recorder rewrite in #859 removed. The start/stop race it describes is now handled by `VideoRecorderBloc`, which queues recording start and stop with `sequential()` and holds a stop that arrives mid-start in `pendingStopAfterStart`; see [CAMERA_ARCHITECTURE.md](CAMERA_ARCHITECTURE.md). Start with docs/README.md and docs/archive/README.md for current guidance.

# Camera Timing Analysis - Future.delayed Context

## Context from Journal Entries

### The Race Condition (Nov 12, 2025)
You recently fixed a **critical iOS camera race condition** that was causing:
- 22-second videos instead of stopping at 6.3s
- Single-frame captures failing
- Rapid taps causing continuous recording

**Root Cause:**
`CameraController.value.isRecordingVideo` updates **asynchronously via stream**, NOT synchronously when `stopVideoRecording()` Future completes. There's a window where:
1. `await stopVideoRecording()` completes
2. But `controller.value.isRecordingVideo` is still `true`
3. Next `startVideoRecording()` checks the stale value
4. Thinks camera is still recording and returns early
5. Original recording continues → 22-second video

**Your Fix:**
Added `_operationInProgress` mutex to serialize start/stop operations:
```dart
while (_operationInProgress) {
  await Future.delayed(const Duration(milliseconds: 10));
  waitCount++;
}
```

**This fixed the bug!** 🎉

---

## Current Future.delayed Usage in vine_recording_controller.dart

### 1. Lines 190, 240, 297: Mutex Polling (3 occurrences)

**Current Pattern:**
```dart
// Wait for any in-progress operation to complete
while (_operationInProgress) {
  if (waitCount >= maxWaitMs / 10) {
    throw Exception('Camera operation timeout');
  }
  await Future.delayed(const Duration(milliseconds: 10));
  waitCount++;
}

_operationInProgress = true;
try {
  await _controller!.startVideoRecording();
  isRecording = true;
} finally {
  _operationInProgress = false;
}
```

**Analysis:**
- **Purpose:** Serialize camera operations (prevent race condition)
- **Why it works:** Yields control to event loop, allows other operations to complete
- **Problem:** Polling a flag instead of waiting for completion event

**Alternative Approaches:**

#### Option A: Use AsyncScope.waitForCondition()
```dart
// The scope is a field on the owner, disposed with it. That ownership is the
// point — a wait nobody owns keeps polling after the camera controller is gone.
final _async = AsyncScope(debugName: 'CameraService');

await _async.waitForCondition(
  condition: () => !_operationInProgress,
  timeout: Duration(milliseconds: 5000),
  checkInterval: Duration(milliseconds: 10),
  debugName: 'Camera operation lock',
);

@override
void dispose() {
  _async.dispose(); // pending polls abort with AsyncCancelledException
  ...
}
```

**Pros:** Cleaner, more explicit, better logging, same behavior, and the poll
stops when the owner does.
**Cons:** Still polling. Cancellability is what makes it acceptable, not
tidiness — a timer-backed wait with no owner is the same defect as
`Future.delayed` wearing a different name, and is frozen at zero by
`check_uncancellable_timer_wait.sh` (#8457). Option B is still better.

#### Option B: Use Completer pattern (BEST)
```dart
Completer<void>? _currentOperation;

// In startRecordingSegment/stopRecording:
if (_currentOperation != null && !_currentOperation!.isCompleted) {
  await _currentOperation!.future.timeout(
    Duration(milliseconds: 5000),
    onTimeout: () {
      throw Exception('Camera operation timeout');
    },
  );
}

_currentOperation = Completer<void>();
try {
  await _controller!.startVideoRecording();
  isRecording = true;
} finally {
  _currentOperation!.complete();
}
```

**Pros:**
- No polling at all!
- Proper async coordination
- Waiting for actual completion, not flag
- More efficient (no 10ms periodic checks)

**Cons:**
- More complex (need to manage Completer lifecycle)
- Might need to handle multiple waiters

---

### 2. Line 1197: Stop-Motion Minimum Frame Duration (1 occurrence)

**Current Pattern:**
```dart
// Ensure minimum recording duration for stop-motion capture
if (segmentDuration < minSegmentDuration) {
  final waitTime = minSegmentDuration - segmentDuration;
  Log.info('🎬 Stop-motion mode: waiting ${waitTime.inMilliseconds}ms to capture frame');
  await Future.delayed(waitTime);
}
```

**Analysis:**
- **Purpose:** Wait for REAL TIME to pass so camera captures at least one frame
- **Why it works:** Camera needs minimum duration based on frame rate (e.g., 10fps = 100ms/frame)
- **Is this legitimate?** 🤔

**The Question:**
Is this a **hardware timing constraint** (legitimate) or **arbitrary delay** (hack)?

**Evidence for LEGITIMATE:**
- Camera frame rate determines minimum capture time (30fps = 33ms, 10fps = 100ms)
- We're not waiting for an async event - we're waiting for TIME itself
- No callback for "frame captured" - only way is to wait for duration
- Journal says: "ensures at least one frame is captured" (Oct 31)

**Evidence for HACK:**
- Assumes frame capture happens in linear time
- What if camera is laggy/slow?
- No verification that frame was actually captured

**Verdict:** **LEGITIMATE for MVP, but could be improved**

The frame capture IS a hardware timing constraint. But ideally we'd:
1. Query actual camera frame rate
2. Calculate minimum duration from frame rate
3. Or even better: Get frame count from video file metadata after recording

**For now, this Future.delayed is acceptable because:**
- It's solving a real hardware constraint (not arbitrary timing)
- Alternative would be to get frame count from video metadata (more complex)
- It's working for stop-motion feature

**Suggested comment update:**
```dart
// Wait for camera to capture at least one frame based on frame rate.
// At 10fps (100ms/frame), we need minimum 100ms recording duration.
// Future.delayed is acceptable here because we're waiting for REAL TIME
// to pass for hardware frame capture, not an async operation.
await Future.delayed(waitTime);
```

---

## Recommendations

### OPTION 1: Minimal Change (Use AsyncScope)
**Change lines 190, 240, 297 only:**
```dart
await _async.waitForCondition(
  condition: () => !_operationInProgress,
  timeout: Duration(milliseconds: 5000),
  checkInterval: Duration(milliseconds: 10),
  debugName: 'Camera operation lock',
);
```

Requires an `AsyncScope` field on the owner, disposed in its `dispose()`. Do
not reach for a static helper here: the wait must stop when the camera does.

**Keep line 1197 as-is** (legitimate hardware timing)

**Pros:**
- Minimal risk (same polling behavior, just cleaner)
- Fixes 3 of 4 violations
- Better logging and error messages

**Cons:**
- Still polling (just nicer polling)

---

### OPTION 2: Proper Async Coordination (Use Completer)
**Replace mutex pattern with Completer:**
```dart
Completer<void>? _currentOperation;

// Wait for previous operation
if (_currentOperation != null && !_currentOperation!.isCompleted) {
  try {
    await _currentOperation!.future.timeout(Duration(milliseconds: 5000));
  } catch (e) {
    Log.error('Timeout waiting for camera operation',
        name: 'VineRecordingController', category: LogCategory.system);
    throw Exception('Camera operation timeout after 5000ms');
  }
}

// Start new operation
_currentOperation = Completer<void>();
try {
  await _controller!.startVideoRecording();
  isRecording = true;
} finally {
  _currentOperation!.complete();
}
```

**Keep line 1197 as-is** (legitimate hardware timing)

**Pros:**
- No polling at all!
- Proper async coordination
- More efficient
- Architecturally superior

**Cons:**
- More complex change
- Riskier (changing recently-fixed critical code)
- Need to test thoroughly

---

### OPTION 3: Don't Touch It (Keep Working Code)
**Leave all 4 as-is, just add exception to test:**

```dart
// Add to future_delayed_detector_test.dart
const ALLOWED_DELAYS = [
  'lib/services/vine_recording_controller.dart:190', // Mutex serialization
  'lib/services/vine_recording_controller.dart:240', // Mutex serialization
  'lib/services/vine_recording_controller.dart:297', // Mutex serialization
  'lib/services/vine_recording_controller.dart:1197', // Hardware frame timing
];
```

**Pros:**
- Zero risk (don't touch working code)
- Acknowledges these are intentional, not accidents

**Cons:**
- Violates coding standards
- Sets precedent for "it's okay to use Future.delayed"
- Might accumulate more violations over time

---

## My Recommendation

**Option 1 (Minimal Change)** - Use `AsyncScope.waitForCondition()` for the mutex polling (lines 190, 240, 297), with the scope owned and disposed by the camera service.

**Why:**
1. **Low risk** - Same behavior, just cleaner implementation
2. **Better error messages** - `AsyncScope` provides better logging, and cancels its polling when the owner is disposed
3. **Respects working code** - You just fixed a critical race condition (Nov 12), don't want to break it
4. **Improves standards compliance** - Moves toward proper async patterns
5. **Easy to test** - Can verify behavior matches current implementation

**Keep line 1197 as-is** with improved comment explaining it's legitimate hardware timing.

---

## What About the Other 26 Future.delayed Violations?

Based on camera timing analysis, I'm now **more cautious** about blanket "remove all Future.delayed" approach.

**Should re-categorize the 30 violations as:**
1. **HACK - Must Fix** (polling, arbitrary timing)
2. **HARDWARE TIMING - Legitimate** (waiting for real time to pass)
3. **NEEDS INVESTIGATION** (unclear if hack or legitimate)

**Want me to:**
1. Re-analyze all 30 violations with this lens?
2. Categorize which are legitimate hardware/timing constraints vs hacks?
3. Propose fixes only for the clear hacks?

Let me know, Rabble!
