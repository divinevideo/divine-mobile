# Android device support

Status: Current

Divine ships **one Google Play AAB that must reach every device the previous
release reached**. This doc records the device-support policy and the Play
upload guardrail, so the two ways we have lost device support — a config change
and a wrong upload — do not recur.

## Policy

| Lever | Value | Why |
|---|---|---|
| `minSdk` | **28 (Android 9.0)** | Pinned by `c2pa_flutter` (ProofMode/C2PA). It is **not** a Google requirement, and Google does not ask us to raise it. Our own telemetry (Nov 2026) puts only ~0.5% of active users on Android 9 and under 2% on Android 9–10, but we keep the floor as low as the C2PA dependency allows. |
| ABIs | **`armeabi-v7a` (32-bit) + `arm64-v8a` (64-bit) + `x86_64`** | 64-bit is a Google requirement; 32-bit is ours, to keep low-end/budget devices. `flutter build appbundle` ships all three by default — we do not restrict them. |
| `targetSdk` / `compileSdk` | **36 (Android 16)** via Flutter's default | Google requires app updates to target a recent API (API 36 since 31 Aug 2026). Raising `targetSdk` is a behavioral/compliance change and **drops no devices**. We track `flutter.targetSdkVersion`; do not pin a lower value. |
| Delivery | AAB, Play splits per device | Each device downloads only its ABI/density slice. |

The two axes are independent: **supporting new Android (raise `targetSdk`) never
drops old devices; keeping old devices (keep `minSdk` + all ABIs) never blocks
new ones.** There is no trade-off to make here.

## What narrows device support (and the guard that blocks it)

Two static checks freeze the three config-level regressions:

- `mobile/scripts/check_android_device_support.sh` (Mobile CI `Guards` job)
  reads `android/app/build.gradle.kts`:
  1. `minSdk` rising above 28.
  2. Any `abiFilters` setting. Flutter's Gradle plugin already sets all three
     ABIs, so the app's Gradle file has no reason to touch them.
- `test_android_shorebird_builds_target_every_abi` in
  `.github/scripts/tests/test_codemagic_shorebird_config.py` (Mobile CI
  `CI Configuration Tests` job) reads `codemagic.yaml`:
  3. `--target-platform` on a `shorebird release android` or
     `shorebird patch android` command, which drops Flutter's engine and app
     code from the omitted ABIs (see below).

The third lives in the Python suite because that job runs on every pull
request, while the `Guards` job skips a change that touches only
`codemagic.yaml`.

Neither check can **inspect the built AAB** — they protect the repo, not the
upload. The upload is covered by the runbook below.

## Play upload runbook (the part the checks can't see)

The repo builds **two different Android artifacts**, and mixing them up is how
the Nov 2026 1.0.29 release lost ~16,000 devices:

- **Per-ABI split APKs** (`flutter build apk --split-per-abi`, e.g.
  `app-arm64-v8a-release.apk`) → for **Zapstore / direct download only**.
- **The universal Shorebird AAB** (`shorebird release android`, the
  "Build Android AAB" Codemagic step) → for **Google Play**.

Uploading a split APK to Play gives Play a 64-bit-only artifact, which drops
every 32-bit device. Play warns about that one (below).

An AAB built with `--target-platform android-arm64` is worse, because Play does
not warn. Flutter's Gradle plugin keeps `abiFilters` at all three ABIs whatever
`--target-platform` says; the flag only leaves out `libflutter.so` and
`libapp.so`. Third-party native libraries, such as C2PA's, still fill
`base/lib/armeabi-v7a/`, so Play keeps serving 32-bit devices a build that
crashes on launch.

### Check an AAB's ABIs

Run this on any AAB before it reaches Play, and on the one behind a
device-support warning:

```sh
unzip -l app-release.aab | grep -E 'base/lib/[^/]+/lib(flutter|app)\.so'
```

Expect `libflutter.so` and `libapp.so` under each of `armeabi-v7a/`,
`arm64-v8a/` and `x86_64/`. A missing pair is the regression; a directory that
holds only other libraries does not count.

### When Play warns

When Play Console shows **"This release no longer supports N devices"**:

1. **Do not click through.** Proceeding drops those devices and cuts off updates
   for existing installs on them.
2. Open the warning's **"Check changes to your supported devices"** link and read
   the per-device **reason** (ABI / API level / required feature / OpenGL).
3. If the reason is ABI, run the [ABI check](#check-an-aabs-abis) on the
   draft's artifact.
4. Replace the draft's artifact with the **universal Shorebird AAB** from
   Codemagic. The companion error **"You cannot remove all production APKs and
   App Bundles"** just means the draft is empty — it clears once the correct AAB
   is attached. Confirm `versionCode` is higher than the live release.
5. The device-support warning should then disappear. If it persists, run the
   ABI check on the attached AAB before shipping.
