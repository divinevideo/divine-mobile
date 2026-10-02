# Android local setup

What a machine needs before it can build or debug the Android app. Most Flutter
work needs none of this — `flutter test`, `flutter analyze` and the web build are
unaffected. Read this when you are about to run an Android build, drive Gradle
directly, or open `mobile/android` in Android Studio.

## What the repo provides, and what it cannot

| Thing | Provided by | Needs you |
|---|---|---|
| Gradle wrapper (`gradlew`, `gradle-wrapper.jar`) | **tracked in git** since #7201 | no |
| Gradle 8.14 itself | the wrapper downloads it on first run | no |
| `mobile/android/local.properties` | written by `flutter pub get` | no |
| JDK 17 | `mise install` (pinned in `mobile/mise.toml`) | run `mise install` |
| Android SDK + platform-tools | — | **yes** |
| `ANDROID_HOME` | — | **yes** |
| `FLUTTER_ROOT` | exported by CI's Flutter action, not by a local shell | **yes, for direct Gradle** |

## Setup

1. **JDK** — pinned in `mobile/mise.toml` as `temurin-17`:

   ```bash
   cd mobile && mise install
   ```

   17 is what the build targets (`app/build.gradle.kts` sets `jvmTarget` and
   source/target compatibility to 17; `codemagic.yaml` pins `java: 17`). A newer
   JDK usually works, but only 17 matches CI.

   > **First run downloads a JDK.** If you skip `mise install`, the next
   > `mise exec` or `mise run` in `mobile/` installs it for you — a ~200 MB
   > download that takes a minute. Run `mise install` once so that download does
   > not delay the first formatting or analysis hook. If this change was pulled
   > into an existing checkout, reinstall the hooks with `mise run setup_hooks`
   > so their diagnostics stay current.

2. **Android SDK** — install via Android Studio (*SDK Manager*), or standalone
   `cmdline-tools`. Then export, from your shell profile:

   ```bash
   export ANDROID_HOME="$HOME/Library/Android/sdk"   # macOS
   # export ANDROID_HOME="$HOME/Android/Sdk"         # Linux
   export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"
   ```

   Accept the licences once with `flutter doctor --android-licenses`.

3. **Verify:**

   ```bash
   cd mobile && flutter doctor
   ```

   The "Android toolchain" row must be green before an Android build will work.

## Debug builds render with Impeller

Debug builds use the renderer that ships. On API 29 and newer that is Impeller,
on Vulkan where the device supports it and on OpenGLES otherwise.
`main/AndroidManifest.xml` records why release builds use it. Below API 29 (the
app's minimum is 28) the engine uses Skia, which has no `ImageFilter.shader`, so
the video editor's chroma-key and effects previews stay unavailable there. Until
October 2026 the debug manifest forced Skia on every device, so a debug build on
a real phone showed "This device can't show the live preview" for those previews
unless the run passed `--enable-impeller`.

Emulators render with Impeller OpenGLES: the engine never selects Vulkan on an
Android emulator. That worked on SwiftShader (`-gpu swiftshader_indirect`), the
software GPU an emulator falls back to on a headless CI host or a machine
without native Vulkan, which is the setup the Skia opt-out was added for in
#1928. On Flutter 3.47.2 an API 30 emulator on that GPU mode starts the app and
passes the feed frame-timing and time-to-first-frame integration tests.

It is not known to work everywhere. flutter/flutter#192736 reports the host
emulator process dying about a second after Impeller selects OpenGLES on x86_64
Linux hosts that render with a software GL stack, from Flutter 3.44 on, which
includes the 3.47.2 this repo pins. If feed video renders black on an emulator,
see the OpenGLES note in `main/AndroidManifest.xml`.

If an emulator vanishes, renders black or fails to render, turn Impeller off for
that run only:

| How the app starts | Opt-out for one run |
|---|---|
| `flutter run`, `flutter test`, `flutter drive` typed directly | add `--no-enable-impeller` |
| A debug APK installed with `adb` (`mise run local_install`) | launch it with `adb shell am start -S --ez enable-impeller false -n co.openvine.app.staging/co.openvine.app.MainActivity`; `-S` stops a running copy first, because the extra is only read when the app process starts |
| `patrol test` | no flag exists; boot the emulator with `-gpu host`, which `mise run emulator` already does |

The flag and the intent extra are the same switch: `flutter run` passes
`--no-enable-impeller` to the app as that extra. The engine prints
`[Action Required]: Impeller opt-out deprecated` whenever it is used and plans
to remove it, so treat it as a diagnostic step rather than a setting, and file
an issue for an emulator that needs it.

## Running Gradle directly

The wrapper is tracked, so `./gradlew` exists in a fresh clone or worktree with
no prior `flutter build`. Two things still have to be in place:

```bash
cd mobile && flutter pub get          # writes android/local.properties
cd android
FLUTTER_ROOT=/path/to/flutter ./gradlew :app:tasks
```

- **`local.properties`** stays gitignored — it holds machine-local absolute
  paths. `settings.gradle.kts` reads it with no existence check, so Gradle fails
  during settings evaluation if you skip `flutter pub get`.
- **`FLUTTER_ROOT`** is required by
  `mobile/packages/caption_generator/android/build.gradle.kts`, which throws
  `FLUTTER_ROOT must be set to compile caption_generator` without it. CI gets it
  free from `subosito/flutter-action`; locally, export it (`FLUTTER_HOME` also
  works). `dirname $(dirname $(which flutter))` is usually the right value.

Everyday app builds need none of this — `flutter build apk` and `flutter run`
set up their own Gradle invocation.

## Why the wrapper is tracked

Flutter injects `gradlew` lazily, from `GradleUtils.getExecutable` — only when
the flutter tool itself is about to exec Gradle. `flutter pub get` does not do
it. So before #7201 a fresh worktree had the wrapper's *version pin*
(`gradle-wrapper.properties`) but not the *launcher*, and anything calling
`android/gradlew` directly — `shorebird init`, an IDE Gradle sync, a hand-run
task — failed until some Flutter build happened to inject it. All 21 worktrees
checked at the time were in that state.

The jar is pinned to Gradle's published 8.14 checksum and verified in CI by
`mobile/scripts/check_gradle_wrapper_checksum.sh`. To upgrade Gradle,
regenerate and update the expected values in that script's header:

```bash
cd mobile/android && ./gradlew wrapper --gradle-version <v> --distribution-type all
```
