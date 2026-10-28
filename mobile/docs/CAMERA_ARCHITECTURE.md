# Camera Architecture

Status: Current
Validated against: recorder code on `main` on 2026-10-28.

How the video recorder is put together, from the route to the native camera. What each recorder mode offers the creator is in [`VIDEO_EDITOR_FEATURES.md`](VIDEO_EDITOR_FEATURES.md#getting-into-the-editor); the native microphone lifecycle and diagnostics are in the [`divine_camera` README](../packages/divine_camera/README.md).

## Layers

One code path serves every platform that can record. Platform differences live in the native code of the `divine_camera` plugin, not in the app.

| Layer | Code | Role |
|---|---|---|
| Route | [`VideoRecorderRoute`](../lib/screens/video_recorder_screen.dart), registered in [`video_routes.dart`](../lib/router/routes/video_routes.dart) | Reads the query parameters, wraps the recorder in `CameraPermissionGate` |
| UI | `VideoRecorderView` and the per-mode stacks under [`lib/widgets/video_recorder/modes/`](../lib/widgets/video_recorder/modes) | Renders state, dispatches events, owns navigation |
| State | [`VideoRecorderBloc`](../lib/blocs/video_recorder/video_recorder_bloc.dart) | Recorder state, recording start/stop, modes, zoom, focus, countdown, stop motion, chroma key |
| Camera API | [`CameraService`](../lib/services/video_recorder/camera/camera_base_service.dart) | The app's camera interface; `CameraService.create()` picks the implementation |
| Plugin | [`divine_camera`](../packages/divine_camera) (`DivineCamera.instance`) | Method channel to the native camera, preview texture |
| Native | CameraX on Android; `AVCaptureSession` with `AVAssetWriter` on iOS and macOS | Capture, encoding, audio session |

Recorded clips leave the bloc for `ClipManagerNotifier` in [`clip_manager_provider.dart`](../lib/providers/clip_manager_provider.dart), a Riverpod notifier. The bloc reaches it, the video editor notifier and `SharedPreferences` through injected accessors, so it imports no Riverpod itself. `_VideoRecorderBlocScope` builds the bloc and keys its `BlocProvider` on those dependencies, so a dependency rebuilt at runtime gives a fresh bloc (see `state_management.md`).

## Platforms

| Platform | `CameraService` | Native side |
|---|---|---|
| Android | `CameraMobileService` | `divine_camera`, CameraX `VideoCapture<Recorder>` |
| iOS | `CameraMobileService` | `divine_camera`, Swift under `darwin/` |
| macOS | `CameraMobileService` | The same Swift as iOS. The Mac has no lens array, zoom, stabilization or flash |
| Linux | `CameraLinuxService` | None. A stub that reports `CameraInitializationError.unsupportedPlatform`; see [`LINUX_SUPPORT.md`](LINUX_SUPPORT.md) |
| Web | `CameraMobileService` | No web plugin backend, so recording is not supported. On the standalone route, `CameraPermissionGate` shows the "not supported on web" screen instead of the recorder; the editor's embedded recorder has no permission gate |

## Opening the recorder

The recorder lives at `/video-recorder` (`RoutePaths.videoRecorder`). Its query parameters are `entry_point` (analytics), `auto_record=true` (the bottom-nav hold shortcut: capture mode, recording starts once the camera is ready) and `challenge_recording`; a preselected sound rides in `extra`. Details are in [`DEEP_LINK_URL_REFERENCE.md`](DEEP_LINK_URL_REFERENCE.md).

There are two ways in:

- **Standalone.** In-app camera buttons (camera FAB, bottom nav, empty library) call `pushToCameraWithPermission` from [`camera_permission_check.dart`](../lib/utils/camera_permission_check.dart), which asks for permission on the current page and only navigates once the answer is final. Direct navigation (quick actions, deep links) reaches the route unasked, and `CameraPermissionGate` fires the dialog itself.
- **From the video editor.** The editor pushes `VideoRecorderScreen(fromEditor: true)` to add a clip. There is no permission gate and no bottom bar, the persisted mode is not restored, and `cropGuideAspectRatio` draws a split-screen cell's shape over the viewfinder.

On its first frame the view marks a page as open through `OverlayVisibility` (pausing the feed's players), dispatches `VideoRecorderInitializeRequested`, shows the one-time "why six seconds?" sheet and offers an autosaved session back.

## Permissions

`CameraPermissionBloc` is created once in `app_composition_root.dart` and asks [`PermissionsService`](../packages/permissions_service) for camera and microphone access.

| Platform | Backed by |
|---|---|
| iOS, Android | `permission_handler` |
| macOS | The `openvine/native_camera` channel to [`macos/NativeCameraPlugin.swift`](../macos/NativeCameraPlugin.swift), which calls `AVCaptureDevice.authorizationStatus` / `requestAccess` and opens System Settings. The plugin does nothing else; recording runs through `divine_camera` |
| Linux | No check. The bloc reports `authorized` |

There is no in-app priming screen: the OS dialog always follows the user's camera tap. A permission the OS will no longer ask for (`requiresSettings`) shows the gate's settings prompt. `CameraPermissionRequest` uses `restartable()` because the Android dialog dismissed with the back button can leave `permission_handler`'s request hanging forever; the next tap supersedes it.

The usage descriptions are `NSCameraUsageDescription` and `NSMicrophoneUsageDescription` in `ios/Runner/Info.plist` and `macos/Runner/Info.plist`, and `CAMERA` plus `RECORD_AUDIO` in `android/app/src/main/AndroidManifest.xml`.

## Camera startup

`VideoRecorderInitializeRequested` restores the last-used mode, lens (default: back) and stabilization (default: `standard`, since `auto` resolves on iOS to a look-ahead mode that delays every stop by about 1.6 s). They are stored in `SharedPreferences` under `camera_last_used_recorder_mode`, `camera_last_used_lens` and `camera_last_used_stabilization`.

`CameraService.initialize` then receives everything that is fixed for the life of the capture session:

- quality `VideoEditorConstants.quality` (1080p) and automatic lens switching on zoom
- `preferUnprocessedAudio` from `MusicModePreferenceService`, which records the microphone without speech noise suppression
- `mirrorFrontCameraOutput` from `FrontCameraMirrorPreferenceService`
- the stabilization mode, applied with the first bind so Android does not rebind the camera twice

A change to the music mode or mirror setting therefore applies the next time the recorder opens.

Startup is measured by the `camera_startup` performance trace, tagged with lens, quality and outcome. A failed start sets `initializationError` to a `CameraInitializationError` code rather than a message; `VideoRecorderCameraPreview` localizes it and shows it in `VideoRecorderCameraPlaceholder`. Once the camera runs, the bloc enables remote record control so the volume buttons and Bluetooth clickers start and stop recording.

## Recording a take

### Shutter gestures

Shutter surfaces that combine tap-to-toggle and long-press-to-record must route through [`ShutterGestureDetector`](../lib/widgets/video_recorder/shutter_gesture_detector.dart) instead of wiring `GestureDetector` callbacks by hand. It keeps the guard added for issue #4409:

- A tap-started recording is never stopped by an incidental long-press release on the same target.
- In press-down mode, a press on a recording started by anything else (volume key, Bluetooth remote, a dropped release) still stops it, so the button is never a dead control.

`RecordButton` (`video_recorder_record_button.dart`) and the Classic preview (`VideoRecorderClassicStack`) use it today.

### Start

A shutter tap dispatches `VideoRecorderRecordingToggleRequested`, which becomes `VideoRecorderRecordingStartRequested` or `VideoRecorderRecordingStopRequested`. Both run with `sequential()`, so each is a FIFO queue. In stop motion the toggle captures a still instead (see [Modes](#modes)).

A toggle is ignored while the camera is switching. A start is ignored while navigation has locked recording, while another take is starting or stopping, and in Classic once less than 30 ms of the recording limit is left.

When the mode supports it and a timer is set, a countdown runs first. The microphone is closed for the beeps (`suspendAudioCapture`) and the volume buttons are released, because on iOS a mic left open while the speaker plays takes seconds to recover its input level, and the clip would start quiet and grow louder (#4539).

Then the bloc starts the selected sound, calls `CameraService.startRecording` and keeps the screen awake with `WakelockPlus`. Only Classic passes a `maxDuration`: what is left of `VideoEditorConstants.maxDuration` (6.3 s across all clips). The native side stops at that limit on its own and reports it through `onAutoStopped`. A stop that arrives while the native start is still running is held in `pendingStopAfterStart` and sent once the recording has begun, so a short hold still produces a clip.

### Stop

The clip timer freezes at the tap, not when the native stop returns. `stopRecording()` hands back the file, and `ClipManagerNotifier.addClip` turns it into a `DivineVideoClip`. In Classic a take longer than the remaining time is trimmed in the background. The clip is saved to the clip library right away. Then, detached from the stop handler so a slow pass never delays the next stop:

1. The real duration (`commonTrackEnd`, see [`VIDEO_TRACK_END_MISMATCH.md`](VIDEO_TRACK_END_MISMATCH.md)), the thumbnail and the ghost frame are read from a copy of the file, and the clip is saved again.
2. A chroma-key take is keyed into the composite the viewfinder showed.

In parallel the clip manager signs the take with ProofMode / C2PA (`NativeProofModeService.proofFile`). Once signing settles, `RecordingGalleryBackupService` copies it to the device gallery when the user has turned that on in Settings (off by default).

A second stop result for a file that was already stopped is dropped, so one take never becomes two clips (#10194).

## Modes

`VideoRecorderMode` lists the modes in mode-wheel order: Capture, Stop Motion, Lip Sync, Chroma Key, Classic, Upload. Its getters (`hasRecordingLimit`, `hasVideoEditor`, `capturesStills`, `needsLiveChromaKey`, `supportsCountdownTimer`, `supportsVideoStabilization`, `supportsGhostFrame`, `supportGridLines`, `defaultAspectRatio`) decide what the recorder offers; the per-mode UI is in `lib/widgets/video_recorder/modes/`.

- **Stop Motion** captures stills with `CameraService.capturePhoto`. [`StopMotionSessionStore`](../lib/services/video_recorder/stop_motion_session_store.dart) mirrors each still into the clip library as it is shot and hands the session to the clip manager on assemble.
- **Lip Sync** shows the sound picker until a sound is picked, with remote record control paused meanwhile. Its clips are muted before the editor opens.
- **Chroma Key** is offered only where `ChromaKeyShader.isBackendSupported`, because the keyed viewfinder is the mode.
- **Classic** has the recording limit and no editor (see [Leaving the recorder](#leaving-the-recorder)).
- **Upload** records nothing: the view pauses the camera while it shows and resumes it on leaving.

Switching between two recording modes discards the session's clips, which stay in the clip library; a visit to Upload and back keeps them.

## Leaving the recorder

`openVideoEditorFromRecorder` in [`video_recorder_navigation.dart`](../lib/widgets/video_recorder/video_recorder_navigation.dart):

1. Locks recording (`VideoRecorderRecordingLockedForNavigation`) so a volume or Bluetooth trigger racing the transition cannot leave a recording nobody can stop.
2. Pushes the video editor, or in Classic the metadata screen while the video renders in the background.
3. Disposes the camera once the push transition has covered the preview (`VideoRecorderCameraPausedForNavigation`).
4. Re-initializes the camera when the pushed route pops.

`openRecorderLibrary` follows the same pattern. Closing the recorder (`closeVideoRecorder`, or a pop) calls `discardRecorderSession`: the clips stay in the clip library, and only the session and its autosave draft go.

## App lifecycle

`VideoRecorderView` forwards `didChangeAppLifecycleState` to the bloc, which passes it to `DivineCamera.handleAppLifecycleState`:

| State | Camera |
|---|---|
| `inactive` (Control Center, notification shade, app switcher) | Preview paused, microphone kept |
| `paused`, `hidden`, `detached` | Preview paused, microphone released (on iOS, so a locked phone shows no recording indicator) |
| `resumed` | Preview resumed |

A resume while Upload is showing is ignored. A camera that fails to resume shows the initialization error instead of a black preview.

## Testing

- Unit and widget tests: `test/blocs/video_recorder/`, `test/services/video_recorder/camera/`, `test/blocs/camera_permission/`, `test/widgets/camera_permission_gate_test.dart`, `test/widgets/video_recorder/`, and `mobile/packages/divine_camera/test/`.
- End to end: the Maestro recorder flows in [`e2e/maestro/README.md`](../e2e/maestro/README.md). They need a real camera: the iOS Simulator has none, an Android emulator's virtual camera is enough.
- Permissions by hand: install fresh, grant both permissions, relaunch (no second prompt), revoke in system settings (the gate's settings prompt appears), grant again.
- macOS debug builds sign ad hoc so the permission prompts appear; see [`MACOS_DEBUG_SIGNING.md`](MACOS_DEBUG_SIGNING.md). To ask again from scratch: `tccutil reset Camera co.openvine.app`.
