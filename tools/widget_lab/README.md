# Divine Widget Lab

Standalone, disposable native prototypes for a **moment of joy on the home screen**. These are experiments, not shipping Divine features. They install as a separate app and do not change the Flutter app, production widget, accounts, follows, analytics, or relays.

The question: can a highlighted video show a two-second moving preview inside a real widget, then rest on a thumbnail, with Next, Like, and Open actions?

## What to try

- Add **Divine · Moment of joy** on iOS, or the **Divine Widget Lab** widget on Android.
- Tap **Next** in the widget to select another sample and attempt a two-second preview. Both prototypes use 16 frames sampled at 8 fps. There is no GIF player or embedded video player in the widget.
- **Like** toggles local state for that sample. It does not publish a Nostr reaction.
- **Open** opens that sample in the standalone host app's native player.
- The host app has a motion/still switch, local action counts, a reset button, and a creative prompt with the existing Divine camera shortcut. Install Divine separately to use that shortcut (the stable `co.openvine.app` package on Android). iOS uses a URL; Android uses Divine's native quick-action intent.

The three samples and the selection are shared across instances of the widget on each platform. The widgets change on explicit actions; automatic background highlight selection is outside this experiment. Changing sample in the host app also requests a widget refresh, but refresh timing belongs to the OS.

## Prepare local media

Requirements: Python 3 and FFmpeg. Run from this directory:

```sh
python3 prepare_media.py
```

By default this samples the three videos already checked into the repository's seed-media directory. It only reads those content-addressed originals. All resized clips, JPEG frames, build products, debug signing keys, recordings, and test artifacts are ignored by Git. Do not add generated media or real account identifiers to the branch.

To try your own human-made clips, provide exactly three local files, each at least two seconds long:

```sh
python3 prepare_media.py /absolute/path/one.mp4 /absolute/path/two.mp4 /absolute/path/three.mp4
```

Each sample's first two seconds become the preview; up to six seconds become the host-app playback sample. Generated samples are silent. Preview frames are center-cropped to a landscape card; host-app playback samples retain their source aspect ratio. There is no media download or backend dependency.

## iOS

Requirements: macOS, Xcode with an iOS simulator runtime, and XcodeGen.

```sh
cd ios
xcodegen generate --spec project.yml
xcodebuild -project WidgetLab.xcodeproj -scheme WidgetLab \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath ../.build/ios CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- build
```

Install on an already booted simulator, then open the app once:

```sh
xcrun simctl install booted ../.build/ios/Build/Products/Debug-iphonesimulator/WidgetLab.app
xcrun simctl launch booted video.divine.widgetlab
```

Long-press the home screen, choose **Edit → Add Widget**, search for **Divine Widget Lab**, and add the medium or large widget. Then tap **Next in the widget** to test motion. The first static gallery snapshot does not test animation.

For a physical device, open the generated project in Xcode, select your signing team for both targets, and register the shared app group for your team. If changing the group identifier, change `Lab.entitlements` and `Shared/LabStore.swift` together. Simulator builds use ad-hoc signing so the shared app-group entitlement is retained. No signing team or credentials are checked in.

The iOS hypothesis uses staggered, built-in opacity transitions for overlapping video frames when the timeline entry changes. WidgetKit may flatten these into a still, coalesce transitions, or apply different timing. **A successful build or host-app playback does not establish widget video support.** Reduce Motion uses a still image. No private animation APIs, rapid timeline updates, or per-frame network requests are used.

The action definitions in `Shared/HighlightIntents.swift` compile into both the host and extension so the system can find their metadata in either process.

Apple documents animations for data updates with a maximum two-second duration; this is not a promise of arbitrary video playback: [Animating data updates](https://developer.apple.com/documentation/widgetkit/animating-data-updates-in-widgets-and-live-activities), [Supported views](https://developer.apple.com/documentation/widgetkit/swiftui-views).

## Android

Requirements: Android SDK platform 36 and build-tools 36.0.0, plus JDK 17 or newer. The builder defaults to the standard macOS SDK path and Android Studio's JDK. Override `ANDROID_SDK_ROOT` and `JAVA_HOME` for another installation.

```sh
python3 build_android.py
adb install --no-streaming -r .build/android/widget-lab.apk
adb shell am start -n video.divine.widgetlab/.LabActivity
```

Use **Add home-screen widget** in the app, or long-press the home screen and select it from Widgets. Resize it to allow space for the image and 48 dp action buttons.

The Android hypothesis uses a launcher-owned `ViewFlipper` containing 16 local image resources. The receiver sends one update to start the sequence and another after two seconds to show the resting poster. A revision guard prevents an older preview's completion from replacing a newer card. The receiver uses `goAsync()` for the bounded completion; it does not send 16 updates per second or run a background service. System-disabled animations use the still fallback. Different launchers and physical devices need separate checks for timing and memory.

The standalone APK is debuggable, contains the test instrumentation, has no Internet permission, and is signed with a locally generated debug key. It is not a Play Store release artifact. The direct SDK build avoids adding Gradle or Flutter dependencies to the experiment.

[Android widget constraints](https://developer.android.com/develop/ui/views/appwidgets), [ViewFlipper](https://developer.android.com/reference/android/widget/ViewFlipper).

## Validation

Native state tests:

```sh
python3 test_state.py
python3 -m unittest discover -s tests -p 'test_*.py'
```

iOS home-screen test (install the lab and add the medium widget at the top of home-screen page two first):

```sh
cd ios
xcodebuild -project WidgetLab.xcodeproj -scheme WidgetLab \
  -destination 'platform=iOS Simulator,id=YOUR_SIMULATOR_UDID' \
  -derivedDataPath ../.build/ios -resultBundlePath ../.build/ui-tests.xcresult \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test
```

The XCTest exercises Next, Like, and Open on the actual medium home-screen widget and verifies the resulting local counters in the app. Screenshots are attached to the result bundle. SpringBoard does not expose the remote widget buttons consistently, so the test uses documented positions within the medium card. Use a new result-bundle path for each run.

Find your simulator's UDID with `xcrun simctl list devices available` and replace `YOUR_SIMULATOR_UDID` above.

Android rendering and widget-host test (only on a disposable test device/emulator):

```sh
adb shell appwidget grantbind --package video.divine.widgetlab
adb shell am instrument -w video.divine.widgetlab/.AndroidRenderingTests
adb shell appwidget revokebind --package video.divine.widgetlab
```

The binding grant permits the test app to host its own widget without a picker. The test restores local demo state, removes its allocated widget, and stops the host listener. It checks repeated playback uses one surface, the native camera-intent contract, RemoteViews inflation, action pending intents, frame advancement in a system widget host, and the return to the resting poster. It does not launch an installed Divine app or validate its camera screen. Check the explicit `PASS`/`FAIL` text; Android's instrumentation CLI can exit zero even when this minimal runner reports failure.

## Observed results (2026-10-23)

- iOS 26.1 simulator: the medium home-screen widget's Reset → Next → Like → Open test passes, including the expected local counters. The revised image fills the card, with overlaid branding and controls.
- Swift and Java state tests pass, including per-clip likes, counters, and a reset generation that cannot reuse an earlier preview's revision.
- The standalone Android APK builds and its signature verifies. The rendering test passes on an API 36 emulator, including Next, Like, Open, advancing frames in a system widget host, and return to the resting poster. The initial failure was a test lookup across the widget host's isolated view namespace, not missing widget content. Physical devices and launcher-specific rendering remain untested.
- Useful two-second motion has **not** been established on either platform. The Android test observes frame advancement, not visual quality or exact presentation timing. Treat the frame sequences as experiments and use the still fallback until assessed on target devices.
- The repository's Flutter CI analysis scope (`flutter analyze lib test integration_test tools`) passes; the prototypes add no Flutter app code.

## Measurement boundaries

Only intentional Next, Like/unlike, and Open actions increment local counters. Counters contain no account identifiers and never leave the device. A render is not a verified impression, video view, or active user. There is no DAU/WAU/MAU integration in this prototype.

Before turning this into a product feature, establish actual on-device animation behavior, preview timing and visibility, memory and battery cost, light/dark/tinted appearance, accessibility, content selection and filtering, offline behavior, account transitions, real signed actions, and first-party analytics definitions. No result from this lab is authorization to ship the experiment into the production app.
