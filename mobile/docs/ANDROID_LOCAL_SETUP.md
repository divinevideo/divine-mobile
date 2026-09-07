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
