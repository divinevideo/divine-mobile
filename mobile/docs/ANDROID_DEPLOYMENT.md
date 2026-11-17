# Android Deployment Guide

Status: Launch-critical
Validated against: `mobile/build_android.sh`, `mobile/deploy_android.sh`, `mobile/android/app/build.gradle.kts`, and `mobile/android/app/src/main/AndroidManifest.xml` on 2026-03-19.

Start store releases with `Android Store Release` in GitHub Actions on `main`.
The protected driver refreshes credentials and starts Codemagic `android-build`, which
publishes the signed, Shorebird-enabled AAB to Play's internal testing track;
after internal testing passes, promote that exact Play artifact in the Play
Console (see [docs/RELEASE_CHECKLIST.md](../../docs/RELEASE_CHECKLIST.md#7-android-submission-checklist)).
Direct Codemagic native starts are unsupported. Manual backend, release channel,
and GitHub publication choices remain available in the GitHub workflow.
This guide covers the local build and manual upload lanes. They produce a plain
`flutter build` AAB that is not a Shorebird release and cannot be patched, so
use them for local verification and throwaway test lanes — never as the
production release path.

## App Metadata

- App name: `Divine`
- Application ID: `co.openvine.app`
- Namespace: `co.openvine.app`
- Release artifact: `build/app/outputs/bundle/release/app-release.aab`

## Preferred Build Flow

From `mobile/`:

```bash
./build_android.sh release
```

What the script does:

1. Loads `.env` dart defines if present.
2. Auto-increments the build number for release builds.
3. Runs `flutter clean`, `flutter pub get`, and `build_runner`.
4. Builds a signed release AAB for Play Console upload.

`./build_android.sh` runs `flutter build appbundle`, not `shorebird release`.
The AAB it produces is for local verification and manual test lanes only; it
cannot receive Shorebird patches and must not be promoted to production.

## Upload Options

The lanes below upload a plain `flutter build` AAB for throwaway manual
testing. Production releases come from Codemagic as described above; do not
use `./deploy_android.sh production` to ship.

### Manual Play Console upload

1. Build the release AAB with `./build_android.sh release`.
2. Open Google Play Console.
3. Upload `build/app/outputs/bundle/release/app-release.aab`.
4. Add release notes and assign the correct testing or production track.

### Scripted upload helper

```bash
./deploy_android.sh internal
./deploy_android.sh closed
./deploy_android.sh production
```

The helper requires:

- `android/play-store-service-account.json`
- working Fastlane installation
- a previously built or buildable release AAB

#### Deploy Script Flags

| Flag | Description |
|------|-------------|
| `--skip-build` | Skip the build step and upload an existing AAB |
| `--skip-upload` | Build only, do not upload to Play Console |
| `--version <version>` | Override the version name (e.g. `--version 1.0.7`) |
| `--notes <text>` | Set release notes for the upload (e.g. `--notes "Bug fixes"`) |

## Google Play Service Account Setup

To use the scripted upload helper, you need a Google Play service account:

1. Open [Google Play Console](https://play.google.com/console) and navigate to **Settings > API access**.
2. Click **Create service account** and follow the link to Google Cloud Console.
3. In Google Cloud Console, create a new service account with a descriptive name (e.g. `divine-play-deploy`).
4. Back in Google Play Console, click **Grant access** on the new service account.
5. Assign the **Release manager** role so it can upload builds and manage releases.
6. On the service account row, create a new JSON key and download it.
7. Save the file as `android/play-store-service-account.json` inside the `mobile/` directory.

## Security Notes

- `android/play-store-service-account.json` is gitignored. **Never commit this file.**
- Store the JSON key securely (e.g. team password manager or encrypted CI secrets).
- Rotate the service account key periodically and revoke old keys after rotation.
- Limit service account permissions to only what is needed for deployment.

## Track Differences

| Track | Review Time | Tester Limit | Rollout Speed |
|-------|-------------|--------------|---------------|
| Internal | None (immediate) | Up to 100 internal testers | Instant |
| Closed | Typically < 24 hours | Up to 2,000 testers per group | Within hours of approval |
| Production | 1-7 days (first review may be longer) | Unlimited | Staged rollout (e.g. 5% → 20% → 100%) |

## Pre-Upload Checks

- Confirm `mobile/pubspec.yaml` version/build is correct.
- Confirm signing configuration and keystore access are available locally or in CI.
- Confirm release notes are ready.
- Confirm the manifest still removes Advertising ID and dependency-added location/Bluetooth permissions that are not used in this release.

## Manifest Notes For Store Compliance

Current Android manifest behavior:

- uses camera and microphone for recording
- uses media permissions for profile image and gallery interactions
- removes Advertising ID permission
- removes unused dependency-added Bluetooth, location, and nearby permissions
- registers deep links for `divine.video` and `login.divine.video`

## Troubleshooting

### Release build fails

- Run `flutter doctor`.
- Check keystore availability and `android/key.properties`.
- Re-run `flutter pub get` and `dart run build_runner build --delete-conflicting-outputs`.

### Upload helper fails

- Confirm `android/play-store-service-account.json` exists.
- Confirm Fastlane is installed and authenticated.
- Fall back to manual Play Console upload if needed.
