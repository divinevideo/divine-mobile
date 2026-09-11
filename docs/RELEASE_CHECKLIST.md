# Divine Release Checklist

Status: Launch-critical
Validated against: `mobile/pubspec.yaml`, `mobile/build_ios.sh`, `mobile/build_android.sh`, `mobile/deploy_android.sh`, `.github/workflows/mobile_ci.yaml`, and current launch docs on 2026-03-19.

Use this checklist for P1 release prep and store submission. This replaces older package-release and legacy deployment checklists.

## 1. Pin The Release Candidate

"Freeze" here means pin the commit you are about to build. It is not a merge
freeze — Divine does not run release freezes, including before launch. See
[Release Policy: No Freezes](P1_LAUNCH_HUB.md#release-policy-no-freezes).

- [ ] Confirm the target commit is on `main` or the intended release branch.
- [ ] Confirm `mobile/pubspec.yaml` has the release version and build number you expect.
- [ ] Keep the current marketing version while its train is in TestFlight or awaiting approval. Changing `mobile/pubspec.yaml` is a release decision: ask a maintainer first, then follow [Cutting a release](../mobile/docs/SHOREBIRD_CODE_PUSH.md#cutting-a-release).
- [ ] Review `git status` and remove temporary files, logs, or unfinished work.
- [ ] Confirm launch-critical docs are updated:
  - [ ] [docs/P1_LAUNCH_HUB.md](P1_LAUNCH_HUB.md)
  - [ ] [docs/APP_STORE_REVIEW_DOSSIER.md](APP_STORE_REVIEW_DOSSIER.md)
  - [ ] [mobile/docs/APPLE_REVIEW_RESPONSE.md](../mobile/docs/APPLE_REVIEW_RESPONSE.md)
  - [ ] [mobile/docs/ENCRYPTION_EXPORT_COMPLIANCE.md](../mobile/docs/ENCRYPTION_EXPORT_COMPLIANCE.md)

## 2. Naming And Identifiers

- Use `Divine` for the product name in prose, UI, store metadata, release notes, docs, and commit messages.
- Keep `openvine` only where it is a legacy technical identifier:
  - Dart package name: `mobile/pubspec.yaml`
  - Store bundle IDs: `co.openvine.app` and shipped child bundle IDs such as `co.openvine.app.NotificationServiceExtension`
- Do not rename the Dart package or bundle IDs during release cleanup. They are compatibility identifiers, not brand copy drift.
- macOS direct-download builds are not App Store submissions today, so their Xcode marketing/build settings remain intentionally separate from the iOS store version path.

## 3. Run The Required Checks

From `mobile/`:

```bash
flutter pub get
flutter analyze
flutter test
bash scripts/check_ios_shipping_versions.sh
```

Run these when relevant:

- `dart run build_runner build --delete-conflicting-outputs`
- `./scripts/golden.sh verify` (off Linux this reports a pixel diff by
  design — references are Ubuntu-rendered; the `Goldens` CI job is the
  authority. See `mobile/docs/GOLDEN_TESTING_GUIDE.md`.)
- `cd packages/videos_repository && flutter test --coverage`

## 4. Verify Reviewer-Facing Behavior

- [ ] Welcome flow links open Terms, Privacy, and Safety pages.
- [ ] Settings hub routes to Support Center, Content Preferences, Moderation Controls, and Nostr Settings.
- [ ] Support Center opens the current support/legal destinations.
- [ ] Moderation Controls expose reporting, block/mute, age gate, and moderation-provider management.
- [ ] Deep links and auth callbacks still work for `https://divine.video/...`, `https://login.divine.video/...`, and `divine://`.

## 5. Build The Release Artifacts

From `mobile/`:

```bash
./build_ios.sh release
./build_android.sh release
```

Store release artifacts are built by the Codemagic `android-build` workflow (a
Shorebird release), not by these local commands. The Android AAB built here is
plain `flutter build` output — not a Shorebird release — so it cannot be
patched and never ships to Play; treat it as a verification artifact (see
section 7).

- [ ] iOS archive completed successfully in Xcode Organizer.
- [ ] Android release AAB exists at `build/app/outputs/bundle/release/app-release.aab`.
- [ ] If using the Play upload helper, verify `android/play-store-service-account.json` is present before running `./deploy_android.sh`.

## 6. iOS Submission Checklist

- [ ] Confirm app metadata matches the release candidate:
  - App name: `Divine`
  - Bundle identifier: `co.openvine.app`
  - Version name from `mobile/pubspec.yaml`; Codemagic build number from App Store Connect latest + 1.
- [ ] Confirm the built IPA's app bundle and embedded extension bundle versions agree.
- [ ] Verify `ITSAppUsesNonExemptEncryption` remains `false` in `mobile/ios/Runner/Info.plist`.
- [ ] Re-check camera, microphone, photo-library, Bluetooth, Bonjour, and location usage strings in `Info.plist`.
- [ ] Ensure App Store Connect screenshots, subtitle, description, keywords, privacy answers, and support URL are current.
- [ ] Attach reviewer notes using [docs/APP_STORE_REVIEW_DOSSIER.md](APP_STORE_REVIEW_DOSSIER.md).
- [ ] Upload the archive to TestFlight or App Store Connect and verify processing succeeds.

## 7. Android Submission Checklist

- [ ] Confirm app ID is still `co.openvine.app`.
- [ ] Confirm the manifest still removes Advertising ID and unused location/Bluetooth permissions.
- [ ] Verify the current release notes and tester notes are ready.
- [ ] Cut the release through the Codemagic `android-build` workflow: it publishes the signed, Shorebird-enabled AAB to Play's **internal testing** track. Do not rebuild for broader distribution; promote that exact Play artifact after internal testing passes.
- [ ] Verify the new release is live on the internal testing track in Play Console and available to internal testers.
- [ ] Promote the artifact deliberately in Play Console — internal testing to broader testing or production — with a staged production rollout, verifying each hop, and advance the staged rollout to 100% or record why it is being held. This promotion is the release decision; the Codemagic build alone ships nothing to production.
- [ ] `./deploy_android.sh` uploads a plain `flutter build` AAB, not a Shorebird release, so its binaries cannot be patched. Use it only for throwaway manual test lanes, never as the production release path.

## 8. Final Sign-Off

- [ ] All launch-critical docs point to current scripts and screens.
- [ ] No active doc still uses outdated project naming unless clearly historical.
- [ ] External reviewer pages are live:
  - [ ] `https://divine.video/terms`
  - [ ] `https://divine.video/privacy`
  - [ ] `https://divine.video/safety`
  - [ ] `https://divine.video/faq`
  - [ ] `https://divine.video/proofmode`
- [ ] The final release commit and store submissions are recorded in the release channel or ship notes.
