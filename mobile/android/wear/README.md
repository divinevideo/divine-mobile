# Divine Wear OS remote

A watch app that starts and stops a take on the phone and shows how much of
the clip budget is used. It is the Wear OS counterpart of the Apple Watch app
in `mobile/ios/DivineWatch` and is drawn the same way: one shutter in the
proportions of the phone's record button, the recorded time in `00:04`
format, and a strip along the bottom that fills with green against the
budget and marks time recorded past it. The recorder mode sits before the
time along the top edge.

## How it talks to the phone

Through the Wearable Data Layer, which needs Google Play services on both
devices. The phone side lives in the camera plugin
(`mobile/packages/divine_camera/android/.../WearRemoteLink.kt`).

| Direction | Path | What |
|---|---|---|
| Phone → watch | data item `/divine/remote/recorder` | The recorder state Dart publishes as `RemoteRecorderState`, or `available = false` while no recorder is on screen, with its `revision`. |
| Watch → phone | message `/divine/remote/hello` | A `helloId`. Sent when the remote comes on screen, on each connection change, and when a state arrives while the phone counts as unreachable. |
| Phone → watch | message `/divine/remote/state` | The answer to hello: the same state, and the `helloId` it answers. It tells the watch that the phone app is running and can act on a press. |
| Watch → phone | message `/divine/remote/shutter` | The `action` the shutter showed, `watchStart` or `watchStop`, and the `revision` of the state it showed it on. The phone hands the action to Dart as an `onRemoteRecordTrigger`, the path volume keys and Bluetooth remotes take. |

The data item outlives the phone app, so a state alone never enables the
shutter: only the answer to the hello in flight, from a phone it went to,
does. The stored item, its changes and the answers reach the watch in any
order, so the watch shows a state only when its revision is newer than the
one it shows. Revisions start from the phone's clock, so a restarted phone
app publishes above its earlier run.

The phone drops a press whose revision is not the state it last published,
so a Stop meant for one take cannot stop the next, and a Start made before
the recorder closed or changed modes does nothing. The recorder can move on
before the phone's native side hears of it, so a press goes on to Dart with
Dart's own number for the state it matched (`stateId`, which never reaches
the watch), and Dart drops it too once it has sent a newer state.

Each app declares a Data Layer capability (`divine_remote_shutter` on the
watch, `divine_recorder` on the phone) so each finds the other.

A press waits for the phone's answer, which is the state it publishes next:
a video press flips the shutter, and a Stop Motion still counts up the
finished stills. After 4 s without one, as for a press the phone dropped,
the shutter is released.

While the phone's camera is open, the watch shows an ongoing activity on the
watch face and in the launcher's recents; a tap opens the remote. A phone app
cannot open a watch app on its own, so this is how the remote turns up, the
way the Apple Watch app turns up in the Smart Stack. It needs the
notification permission, which the remote asks for the first time it opens.

### Media buttons

The recorder holds a playing media session so headphone buttons can work
the shutter. Wear OS shows a phone's playing media session as media controls
over the watch app, and their play and pause would start takes. So while a
reachable watch has the remote, the phone leaves the media session
unclaimed, as iOS does for the Apple Watch: headphone buttons do not work the
shutter then, volume keys still do.

### Phones without Google Play services

`WearRemoteLink.create` returns `null` on a phone without Google Play
services, and the recorder works as before. Such a phone cannot be paired
with a Wear OS watch in the first place.

## Building

The watch app is a Gradle build of its own, not part of the phone app's
Android project: Flutter runs unqualified tasks such as `assembleDebug` and
`bundleRelease`, which Gradle would otherwise run here on every phone build.
It uses the phone build's wrapper and toolchain (Android Gradle plugin,
Kotlin, compile SDK) so the two upgrade together.

```bash
cd mobile/android/wear
../gradlew testDebugUnitTest lintDebug assembleDebug
```

Gradle needs the Android SDK: set `ANDROID_HOME`, or put `sdk.dir` in
`mobile/android/wear/local.properties` (ignored by git).

The Data Layer only connects apps with the same package name and signing
key. The debug build is `co.openvine.app.staging`, matching the phone app's
debug build, both signed with the local debug key. The release build is
`co.openvine.app`, signed with the phone app's release key from
`mobile/android/key.properties` or the Codemagic keystore variables.

### Trying it on a watch

1. Install a debug build of the phone app on a phone paired with the watch.
2. Enable ADB debugging on the watch (Settings → Developer options) and
   connect to it, for example with wireless debugging.
3. `adb -s <watch> install -r build/outputs/apk/debug/divine-wear-debug.apk`
4. Open the camera on the phone. The ongoing activity appears on the watch
   face; tap it, or open Divine Staging from the watch's app list.

### Trying it on the Wear OS emulator with a real phone

Without a watch, a Wear OS emulator can be paired with a phone over USB. The
phone needs the Google Pixel Watch app; its own setup searches over Bluetooth
and never finds an emulator, so start its emulator mode the way Android
Studio's pairing assistant does:

```bash
adb -s <phone> forward tcp:5601 tcp:5601
# The emulator's node id: localNode in this output.
adb -s <emulator> shell dumpsys activity service WearableService | grep localNode
adb -s <phone> shell am start \
  -n com.google.android.apps.wear.companion/.EmulatorActivity \
  --es emulator-name "<avd name>" --es emulator-id "<node id>"
```

Then tap "Add smartwatch" in the Pixel Watch app and accept the Wear OS
terms; the Google sign-in for the emulator can be skipped. The phone's
logcat reports `[EMULATOR_PAIRING:SUCCESS]`, and
`adb -s <emulator> shell am broadcast -a com.google.android.gms.wearable.EMULATOR --es operation get-pairing-status`
then lists the phone as a connected peer. Start the phone app after pairing.

## Versions

The version name is the phone app's. The version code is the phone's build
number plus 1,000,000,000: Play needs a version code no other form factor of
the app uses. Both come from `mobile/pubspec.yaml` unless the build passes
`-PdivineBuildName=<name> -PdivineBuildNumber=<number>`, as a release build
should with the build number it allocated for the phone.

## Releasing

- **Codemagic.** The `android-build` workflow builds the signed watch bundle
  right after the phone bundle, with the phone's name and allocated build
  number, and keeps it in the build's artifacts
  (`android/wear/build/outputs/bundle/release/`, with its R8 mapping). The
  step is allowed to fail: a broken watch build does not hold up the phone
  release. The guarded Play upload only takes the phone bundle, so the watch
  bundle is not uploaded automatically.
- **Google Play.** The app ships in the phone app's Play listing. Before the
  first upload, someone with Play Console access adds the Wear OS form factor
  (Advanced settings → Form factors), and the Wear OS store listing needs
  watch screenshots. Wear OS bundles go to their own release tracks: upload
  the bundle from the Codemagic artifacts there. To build one by hand:
  `../gradlew bundleRelease -PdivineBuildName=<name> -PdivineBuildNumber=<number>`.
- **Zapstore** publishes only the phone's arm64 APK. The watch app is not
  published there: Zapstore installs on phones, and a phone without Google
  Play services cannot pair a Wear OS watch.
