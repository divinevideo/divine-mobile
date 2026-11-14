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

`mobile/scripts/check_android_device_support.sh` (Mobile CI `Guards` job) freezes
the three config-level regressions:

1. `minSdk` rising above 28.
2. An `abiFilters` list in `android/app/build.gradle.kts` that omits
   `armeabi-v7a`.
3. `--target-platform` on the Shorebird AAB build in `codemagic.yaml`, which
   restricts which ABIs the Play AAB contains.

The guard is static and **cannot inspect the built AAB** — it protects the
repo, not the upload. The upload is covered by the runbook below.

## Play upload runbook (the part the guard can't check)

The repo builds **two different Android artifacts**, and mixing them up is how
the Nov 2026 1.0.29 release lost ~16,000 devices:

- **Per-ABI split APKs** (`flutter build apk --split-per-abi`, e.g.
  `app-arm64-v8a-release.apk`) → for **Zapstore / direct download only**.
- **The universal Shorebird AAB** (`shorebird release android`, the
  "Build Android AAB" Codemagic step) → for **Google Play**.

Uploading a split APK — or a hand-built `--target-platform android-arm64` AAB —
to Play gives Play a 64-bit-only artifact, which drops every 32-bit device.

When Play Console shows **"This release no longer supports N devices"**:

1. **Do not click through.** Proceeding drops those devices and cuts off updates
   for existing installs on them.
2. Open the warning's **"Check changes to your supported devices"** link and read
   the per-device **reason** (ABI / API level / required feature / OpenGL).
3. If the reason is ABI, confirm the artifact:
   ```sh
   unzip -l app-<version>.aab | grep base/lib/
   ```
   Expect `armeabi-v7a/`, `arm64-v8a/`, `x86_64/`. A missing `armeabi-v7a/` is
   the regression.
4. Replace the draft's artifact with the **universal Shorebird AAB** from
   Codemagic. The companion error **"You cannot remove all production APKs and
   App Bundles"** just means the draft is empty — it clears once the correct AAB
   is attached. Confirm `versionCode` is higher than the live release.
5. The device-support warning should then disappear. If it persists, the AAB is
   still 64-bit-only — re-run the `unzip` check before shipping.
