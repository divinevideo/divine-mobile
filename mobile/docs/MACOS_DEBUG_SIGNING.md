# macOS Debug Code Signing

Debug builds for the macOS desktop target are code signed. This note
explains why, what it means for a local developer, and how to recover
if a fresh checkout fails to sign.

## What changed

Previously `macos/Flutter/Flutter-Debug.xcconfig` disabled signing
entirely for debug builds:

```
CODE_SIGN_IDENTITY = -
CODE_SIGN_ENTITLEMENTS =
CODE_SIGNING_REQUIRED = NO
CODE_SIGNING_ALLOWED = NO
```

With signing off, the Runner entitlements were never applied, so macOS
never showed the native camera or microphone permission prompts in
debug. The recorder flow could not request access and appeared broken
on debug builds.

Debug builds now **require** signing and apply the debug entitlements,
but they use ad-hoc signing so local debug work does not require Apple
Developer team membership or provisioning:

```
CODE_SIGN_IDENTITY = -
CODE_SIGNING_REQUIRED = YES
CODE_SIGNING_ALLOWED = YES
```

The Runner target's Debug build config also sets
`OTHER_CODE_SIGN_FLAGS = --options=runtime` and resolves its signing
identity, style, and team from `DIVINE_DEBUG_*` variables defined in
`Runner/Configs/Debug.xcconfig`:

```
DIVINE_DEBUG_CODE_SIGN_IDENTITY = -
DIVINE_DEBUG_CODE_SIGN_STYLE = Manual
DIVINE_DEBUG_DEVELOPMENT_TEAM =
```

Those defaults keep the Debug app ad-hoc signed with Hardened Runtime
while still applying `Runner/DebugProfile.entitlements`. The indirection
exists so a developer who *is* on the team can opt into a stable
signature locally without changing tracked files — see
[Keychain password prompts on every rebuild](#keychain-password-prompts-on-every-rebuild).
Debug entitlements intentionally omit provisioning-backed capabilities
such as associated domains and explicit keychain access groups; those
require a team profile and remain in the team-signed configurations.
Profile and Release remain team-signed by default through
`DIVINE_RELEASE_*` variables in `Runner/Configs/Release.xcconfig`.

Two related changes make that signed debug build run:

1. **Hardened Runtime is enabled** (`ENABLE_HARDENED_RUNTIME = YES`) on
   the Runner target. The camera/microphone TCC prompts and several
   plugins behave consistently across debug, profile, and release once
   the runtime is hardened.

2. **Embedded frameworks are signed with the Runner's identity.** The
   loader rejects an embedded framework whose Team ID differs from the
   host app once Hardened Runtime is on. CocoaPods' `[CP] Embed Pods
   Frameworks` phase signs every pod framework with the Runner's
   `EXPANDED_CODE_SIGN_IDENTITY` and `OTHER_CODE_SIGN_FLAGS`, so app and
   frameworks share one identity: ad-hoc `-` for Debug, or the team
   identity for Profile/Release, each with the runtime option. A separate
   `Codesign media_kit frameworks` phase used to re-sign media_kit's
   prebuilt mpv/FFmpeg frameworks; macOS no longer bundles them (only the
   Linux video backend uses media_kit), so that phase is gone.

## Local setup expectations

Debug builds are ad-hoc signed and do not require Apple Developer team
membership. For day-to-day debug work, nothing new is required:

```bash
cd mobile
flutter run -d macos        # or ./run_dev.sh macos debug
flutter build macos --debug
```

If a fresh checkout fails a debug build with a provisioning or team
error, first verify `Runner/Configs/Debug.xcconfig` still carries the
ad-hoc `DIVINE_DEBUG_*` defaults above and that
`Runner/DebugProfile.entitlements` does not include provisioning-backed
capabilities. Do not commit a Debug `DEVELOPMENT_TEAM` override; team
signing stays opt-in through the git-ignored `LocalDebug.xcconfig`
described below, and is only the committed default for Profile and
Release.

## Keychain password prompts on every rebuild

An ad-hoc signature carries no designated requirement and a fresh
CDHash on every build (`codesign -dvvv` reports `Signature=adhoc`,
`TeamIdentifier=not set`, `Internal requirements count=0`). Two things
follow from that, and together they make macOS ask for the login
keychain password several times per debug launch:

1. The data-protection keychain rejects ad-hoc binaries with OSStatus
   `-34018`, so `appMacOsSecureStorageOptions()` in
   `lib/services/secure_storage_options.dart` falls back to the
   file-based login keychain for macOS debug builds (#5563).
2. The login keychain guards each item with an ACL bound to the calling
   app's code signature. With no stable requirement to record, "Always
   Allow" only holds until the next build, and every secret read at
   startup (database cipher key, Keycast session, saved identity)
   prompts again.

Team members can opt into a stable signature by creating
`Runner/Configs/LocalDebug.xcconfig` (git-ignored, included at the end
of `Debug.xcconfig`):

```
DIVINE_DEBUG_CODE_SIGN_IDENTITY = Apple Development
DIVINE_DEBUG_CODE_SIGN_STYLE = Manual
DIVINE_DEBUG_DEVELOPMENT_TEAM = GZCZBKH7MY
```

Manual style is deliberate: `DebugProfile.entitlements` contains no
provisioning-backed capabilities, so the build needs a development
certificate but no provisioning profile. If more than one installed
certificate matches, pin the exact one by SHA-1 instead
(`security find-identity -v -p codesigning`).

After the first team-signed build, answer each keychain prompt with
**Always Allow** once. The ACL then records a designated requirement
that survives rebuilds, and the prompts stop.

This is per-machine setup, not a repo default: leaving the tracked
defaults ad-hoc keeps debug builds working for contributors without
Apple Developer team membership.

`Runner/Configs/LocalRelease.xcconfig` works the same way for local
Release and Profile signing overrides. The tracked `DIVINE_RELEASE_*`
defaults resolve to `Apple Development`, `Automatic`, and
`GZCZBKH7MY`; local overrides can replace those values without editing
the Xcode project.

## If a stale Swift Package Manager cache blocks the build

Flutter resolves macOS plugins through Swift Package Manager. A stale
SPM cache can fail the build with `Couldn't get revision '<hash>'`
before signing even starts. This is unrelated to code signing — clear
the regenerable caches and rebuild:

```bash
rm -rf ~/Library/Developer/Xcode/DerivedData
rm -rf ~/Library/Caches/org.swift.swiftpm
cd mobile && flutter clean && flutter pub get
flutter build macos --debug
```

## Verifying the signature

After a debug build, confirm the app and its embedded frameworks carry
the runtime flag:

```bash
APP=mobile/build/macos/Build/Products/Debug/Divine.app
codesign -dvvv "$APP"                       # CodeDirectory flags include "runtime"
codesign --verify --deep --strict "$APP"    # exits 0 when the whole bundle is valid
```
