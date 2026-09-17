# divine_camera

Status: Current
Validated against: `pubspec.yaml` on 2026-03-19.

Purpose: Flutter camera plugin used by Divine for recording video on supported platforms.

Used by: recording and capture flows in the mobile app.

Test locally:

```bash
cd mobile/packages/divine_camera
flutter test
```

Android native unit tests (run in CI, see `.github/workflows/divine_camera.yaml`):

```bash
cd mobile/android
gradle :divine_camera:testDebugUnitTest
```

## Native diagnostics sink ownership

Curated native diagnostics are forwarded to Dart's `UnifiedLogger` through a
process-wide sink (`DivineCameraLog.sink`). Because the app also runs a
background Flutter engine (Firebase Messaging) that can register this plugin,
that singleton must always be owned by the **UI engine**, or native-only events
(e.g. a volume-key callback, an audio-session interruption) could be routed to
the wrong isolate or dropped.

Ownership is bound to the UI lifecycle as closely as each platform allows:

- **Android** — ownership is tied to the `ActivityAware` lifecycle. The sink is
  claimed in `onAttachedToActivity` / `onReattachedToActivityForConfigChanges`
  and released (ownership-guarded) in `onDetachedFromActivity`. A background
  engine attaches to the engine but never to an Activity, so it can never own
  the sink — not even transiently. `onMethodCall` re-claims as defense-in-depth.
- **iOS** — `FlutterPlugin` has no Activity-attachment lifecycle, so the sink is
  re-asserted at every UI-bound entry point: each method call, plus the
  native-only callbacks that fire without one — the volume/Bluetooth and
  suppression-timer callbacks (`VolumeKeyHandler`) and, in `CameraController`,
  the audio-session interruption observer, the sample-buffer delegate's
  first-frame / writer-start breadcrumbs, the frame watchdog and init-timeout
  timers, and the max-duration auto-stop's recording-finalization breadcrumbs
  (including the #4779 "WITHOUT audio track" warning). Those native sources only
  ever exist on the UI engine.
- **macOS** — no native-only reclaim is needed, but not because every diagnostic
  is method-driven (the init-timeout and max-duration auto-stop timers do emit
  outside a method call). The reason is that desktop has no background
  `FlutterEngine` (no FCM isolate) that could register the plugin and steal the
  sink, so a single engine owns it from `register()` and re-asserting on each
  method call is enough.

Teardown is always ownership-guarded: a plugin instance only clears the sink
when it still points at that instance, so one engine cannot silence another's
diagnostics.

## Microphone lifecycle on iOS

iOS runs a dedicated audio `AVCaptureSession` next to the video one and keeps
it open between recordings so the record tap is instant; Android opens the mic
per recording through CameraX. Three rules govern when the iOS mic is open:

- **Pre-warm** — built and started about 1s after the first preview frame
  (`completeInitializationIfNeeded`), so the attach cost (`setCategory`,
  AudioToolbox load, `startRunning`) is paid off the record tap.
- **Released on pause** — `pausePreview(releaseAudio: true)` stops it and
  deactivates the shared `AVAudioSession`, so a locked phone shows no recording
  indicator (#5869). `resumePreview()` reattaches.
- **Closed for the countdown** — `suspendAudioCapture()` stops it before the
  countdown beeps play out of the speaker and `resumeAudioCapture()` reopens
  it after the last beep (#4539). With the mic open through the beeps, the
  input level iOS settles on takes seconds to recover and a countdown clip
  starts quiet and grows louder. Only the capture session stops; the audio
  session stays active so the beeps keep playing and the reopen takes the
  cheap restart path. A record tap reopens the mic on its own, so a cancelled
  countdown never records without audio.

`attachAudioToSessionIfNeeded()` is the single reopen path for all three, and
`ios_countdown_mic_release_contract_test.dart` pins the countdown rules.
