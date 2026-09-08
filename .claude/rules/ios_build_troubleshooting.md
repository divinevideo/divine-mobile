# iOS Build Troubleshooting

When iOS build fails with "Could not resolve package dependencies" and Firebase plugins require different FlutterFire versions (`'X' depends on 'flutterfire' A-firebase-core-swift and 'Y' depends on 'flutterfire' B-firebase-core-swift`), there are two distinct causes. Diagnose which one you have before fixing. A third, unrelated failure shape — every plugin "requires minimum platform version 15.0/16.0 ... but this target supports 13" — is covered last.

## Cause 1: misaligned Firebase plugin versions (check this first)

Each FlutterFire plugin's `Package.swift` pins the shared `flutterfire` Swift package at exactly the `firebase_core` minimum declared in that plugin's own pubspec. If any Firebase plugin in `mobile/pubspec.lock` declares a different `firebase_core` minimum than its siblings, SPM resolution fails deterministically on every fresh machine, including CI — no cache clearing helps. (Codemagic iOS Build broke this way when `firebase_remote_config` 6.1.2 declared `^4.2.1` while every sibling declared `^4.4.0`; fixed by #7016.)

Check the constraints for the locked plugin versions:

```bash
grep -h "firebase_core:" ~/.pub-cache/hosted/pub.dev/firebase_*/pubspec.yaml
```

All `firebase_core` minimums must be identical and match the locked `firebase_core` version. If one differs, bump that plugin to the release aligned with the locked `firebase_core` — pub.dev's API lists every version's dependencies (`https://pub.dev/api/packages/<pkg>`) — and commit the pubspec + lockfile change. GitHub CI does not run an SPM iOS build, so this misalignment goes green on PRs and only surfaces on Codemagic after merge.

To confirm a suspected conflict without building the app: a scratch `Package.swift` with `.package(path:)` dependencies into `~/.pub-cache/hosted/pub.dev/<pkg>-<version>/ios/<pkg>` for `firebase_core` plus the suspect plugins reproduces the exact error with `swift package resolve` in seconds.

## Cause 2: stale local Xcode SPM cache

If the plugin constraints are aligned and the failure is on a local machine, it's a stale Xcode SPM cache, not a code issue.

Fix:

```bash
rm -rf ~/Library/Developer/Xcode/DerivedData
cd mobile/ios && rm -rf Pods Podfile.lock .symlinks
flutter clean && flutter pub get && cd ios && pod install
```

Do not create PRs to change `pubspec.lock` or `Package.resolved` for the stale-cache case.

## Cause 3: the generated Swift package floor is below iOS 16

Xcode reports, for `FlutterGeneratedPluginSwiftPackage`, that `c2pa-flutter` / `divine-video-player` require iOS 16.0 but the generated package supports an older target. The project is not misconfigured: every `IPHONEOS_DEPLOYMENT_TARGET` in `mobile/ios/Runner.xcodeproj/project.pbxproj` and the Podfile `platform` are 16.0. The floor that fails is the `platforms:` line of the generated, gitignored `mobile/ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift`.

Flutter writes that manifest at its own default every time it injects plugins — 3.44 used `.iOS("13.0")`, while 3.47 uses `.iOS("15.0")`. Commands such as `flutter pub get`, `flutter analyze`, `flutter test`, and the implicit pub step of most other commands can therefore lower it. `flutter build ios` and `flutter run` normally raise it to the project's deployment target afterwards, but that step can silently do nothing when `xcodebuild -showBuildSettings` exceeds Flutter's 60-second timeout (a cold machine or a fresh worktree).

The shared Runner scheme's pre-action uses `scripts/ensure_ios_swift_package_floor.rb` to repair any generated target below iOS 16 in place, without invoking Flutter. Codemagic uses the same helper. **That repair cannot rescue the Xcode build it runs in.** Xcode emits `Resolve Package Graph` at the very start of a build, before it runs scheme pre-actions, so a build that starts below 16 still fails; the repair then lands, and the *next* build succeeds. Measured 2026-09-06 on a device Profile build: sabotaged floor → `** BUILD FAILED **` with the repair line present in the same log → unchanged rebuild → `** BUILD SUCCEEDED **`.

So the failure is self-limiting rather than prevented: if Xcode fails this way, just build again. To skip the wasted first build after any `flutter pub get`, `flutter analyze` or `flutter test`, run this from `mobile/` before returning to Xcode:

```bash
flutter build ios --config-only
grep -A1 "platforms:" ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift
```

The grep must show `16.0` or newer. If it still shows an older version, run the build command again — Flutter can skip its own bump when `xcodebuild -showBuildSettings` exceeds its 60-second timeout on a cold machine.

Do not add a Flutter command to `mobile/pre_build_ios.sh`: it runs as a pre-action of the shared Runner scheme on every Xcode build, so a `flutter pub get` there re-lowered the floor mid-build and made every Xcode build and Profile run fail this way. The script now repairs the manifest directly and syncs CocoaPods. CI performs the same repair separately in `codemagic.yaml` before archiving.
