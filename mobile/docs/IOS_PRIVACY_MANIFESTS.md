# iOS privacy manifests and required-reason APIs

Apple rejects App Store Connect submissions that call a **required reason API**
without declaring it in a privacy manifest. This document is the ownership and
update process for those declarations (#8803).

Source of truth for the rules is Apple's
[Describing use of required reason API][apple-rr]. The tables below were
verified against Apple's documentation payload on 2026-09-08; re-verify them
when Apple updates the list, which the page says happens periodically.

[apple-rr]: https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api

## The two rules that decide everything

1. **Each bundle declares its own use.** Apple: "Your third-party SDK can't rely
   on the privacy manifest files for apps that link the third-party SDK." A
   plugin's required-reason API goes in the plugin's manifest, never in the
   app's — even though CocoaPods links our pods statically into the `Runner`
   executable. Every one of the 58 third-party manifests in our archive follows
   this pattern under the same static linkage.
2. **Declare only what you use.** Apple permits use of these APIs "for the
   declared reasons only", so an extra reason is inaccurate, not cautious.

Scope note: the requirement covers **iOS, iPadOS, tvOS, visionOS and watchOS**.
macOS is not listed, which is why `mobile/macos` carries no obligation here.

## Where our manifests live

| Bundle | Manifest | Reaches the archive via |
|---|---|---|
| App (`Runner`) | `mobile/ios/Runner/PrivacyInfo.xcprivacy` | `Copy Bundle Resources` in `Runner.xcodeproj` |
| `divine_camera` | `mobile/packages/divine_camera/ios/Resources/PrivacyInfo.xcprivacy` | `s.resource_bundles` in its podspec |
| `divine_quick_actions` | `mobile/packages/divine_quick_actions/ios/Resources/PrivacyInfo.xcprivacy` | `s.resource_bundles` |
| `LibProofMode` (vendored) | `mobile/ios/LocalPods/LibProofMode/Resources/PrivacyInfo.xcprivacy` | `s.resource_bundles` |

`LibProofMode` is Guardian Project code vendored under `ios/LocalPods/`. Divine
owns the declaration in its archive for as long as it consumes the library as a
local path pod, even if the declaration is later accepted upstream.

### LibProofMode vendor delta

The vendored source is based on Guardian Project's upstream `0.1.11` commit
`1690d3a5237426ef6bd2d78dc5476325ad7a6e68`. Keep these Divine-local changes
when refreshing it until each change is present upstream:

- `Classes/MediaItem.swift` imports `UniformTypeIdentifiers` and qualifies the
  movie and audio types as `UTType.movie` and `UTType.audio` for current Xcode.
- `Resources/PrivacyInfo.xcprivacy` declares the required file-timestamp API,
  and `LibProofMode.podspec` bundles that manifest.

The Podfile selects LibProofMode's existing `PrivacyProtected` subspec. Divine
sets `showDeviceIds: false`, so compiling out `AdSupport` and
`ASIdentifierManager` keeps the archive aligned with the behavior and privacy
declaration described below.

## What is currently declared, and why

| Bundle | Category | Reason | Justification |
|---|---|---|---|
| `divine_camera` | `SystemBootTime` | `35F9.1` | `VolumeKeyHandler.swift` reads `ProcessInfo.systemUptime` at two sites purely to measure elapsed time for Bluetooth-trigger cooldown and debounce. Nothing derived from it leaves the device — the file has no method channel or event sink. |
| `LibProofMode` | `FileTimestamp` | `C617.1` | `MediaItem.withData` reads `URLResourceKey.contentModificationDateKey` / `.creationDateKey`. Every path Divine feeds to `MediaItem(mediaUrl:)` is a file the app wrote in its own container (editor render output or a recorded clip). |
| App (`Runner`) | *(none)* | — | The Runner target's own Release code calls no required-reason API. Its single `UserDefaults` call is inside `#if DEBUG`. |
| `divine_quick_actions` | *(none)* | — | No required-reason API detected. |

`NSPrivacyCollectedDataTypes` is empty in the app manifest and is **not** a
claim that Divine collects nothing. Filling it is a product/legal decision that
must match the App Store Connect privacy label, and was deliberately out of
scope for the required-reason API audit.

`LibProofMode`'s collected-data section is empty because Divine constructs
`ProofGenerationOptions(showDeviceIds: false, showLocation: false,
showMobileNetwork: false, notarizationProviders: [])`. Those flags gate the
corresponding blocks in `Proof.swift` (`buildProof`, lines 408 / 430 / 439), so
no device ID, location or carrier data enters the proof. **If any of those flags
is ever flipped to `true`, this manifest and the App Store privacy label must be
updated in the same change.**

## Apple's catalogue

Symbols, verified against Apple's documentation:

| Category | APIs |
|---|---|
| `FileTimestamp` | `FileAttributeKey.creationDate`, `FileAttributeKey.modificationDate`, `UIDocument.fileModificationDate`, `URLResourceKey.contentModificationDateKey`, `URLResourceKey.creationDateKey`, `getattrlist`, `getattrlistbulk`, `fgetattrlist`, `stat`, `fstat`, `fstatat`, `lstat`, `getattrlistat` |
| `SystemBootTime` | `ProcessInfo.systemUptime`, `mach_absolute_time()` |
| `DiskSpace` | `volumeAvailableCapacityKey`, `volumeAvailableCapacityForImportantUsageKey`, `volumeAvailableCapacityForOpportunisticUsageKey`, `volumeTotalCapacityKey`, `systemFreeSize`, `systemSize`, `statfs`, `statvfs`, `fstatfs`, `fstatvfs`, `getattrlist`, `fgetattrlist`, `getattrlistat` |
| `ActiveKeyboards` | `UITextInputMode.activeInputModes` |
| `UserDefaults` | `UserDefaults` |

Reason codes:

| Code | Category | Meaning |
|---|---|---|
| `DDA9.1` | FileTimestamp | display file timestamps to the user; not sent off-device |
| `C617.1` | FileTimestamp | metadata of files in the app / app-group / CloudKit container |
| `3B52.1` | FileTimestamp | files the user explicitly granted access to (document picker) |
| `0A2A.1` | FileTimestamp | third-party SDK wrapper function only |
| `35F9.1` | SystemBootTime | elapsed time between in-app events, or timers |
| `8FFB.1` | SystemBootTime | absolute timestamps for in-app events |
| `3D61.1` | SystemBootTime | user-submitted bug report |
| `85F4.1` | DiskSpace | display disk space to the user |
| `E174.1` | DiskSpace | check sufficient / low disk space, with observable behaviour |
| `7D9E.1` | DiskSpace | user-submitted bug report |
| `B728.1` | DiskSpace | health research app |
| `3EC4.1` | ActiveKeyboards | custom keyboard app |
| `54BD.1` | ActiveKeyboards | customize UI to the active keyboards |
| `CA92.1` | UserDefaults | data accessible only to the app itself |
| `1C8F.1` | UserDefaults | App Group–scoped defaults |
| `C56D.1` | UserDefaults | third-party SDK wrapper function only |
| `AC6B.1` | UserDefaults | MDM managed app configuration |

## The guard

`mobile/scripts/check_privacy_manifest_coverage.sh` runs whenever CI's
**Generated Files** job runs. The step is not gated on the narrower native-file
filter, so package-owned iOS sources are covered whenever Mobile CI is in app
scope. It scans `mobile/ios/Runner`, both iOS extension targets,
`mobile/ios/LocalPods/*` and `mobile/packages/*/ios`, and fails when a detected
required-reason API is not declared in that bundle's own manifest. There is no
baseline and no exemption list.

```bash
cd mobile
bash scripts/check_privacy_manifest_coverage.sh            # the CI check
bash scripts/check_privacy_manifest_coverage.sh --detail   # list every site
bash scripts/check_privacy_manifest_coverage.sh --archive build/ios/iphoneos/Runner.app
```

It also fails on an invalid reason code for a category, an unknown category
string, and a manifest that exists but is not bundled by the selected podspec
or subspec — a manifest nothing ships is a manifest Apple never reads.

Behaviour is pinned by
`mobile/test/tools/privacy_manifest_coverage_detector_test.dart`.

### Two things it deliberately does not do

- **Bare `.creationDate` / `.modificationDate` are reported, never fatal.**
  Apple's required-reason symbols are `FileAttributeKey.creationDate` and
  `FileAttributeKey.modificationDate`. `PHAsset.creationDate` is photo metadata
  and carries no duty. `MediaItem.swift` uses both kinds forty lines apart, so a
  detector that failed on the bare accessor would force an inaccurate
  declaration. Review those sites by hand.
- **It understands only a bare `#if DEBUG`.** Code in that branch is absent from
  Release, so it needs no declaration. Any other condition
  (`#if canImport(…)`, `#if !DEBUG`) is scanned normally, so the guard errs
  toward reporting rather than hiding a use.

## Adding or changing a declaration

1. Find the call site: `bash scripts/check_privacy_manifest_coverage.sh --detail`.
2. Pick the reason from the table above whose wording matches what the code
   actually does — including its off-device restriction. If none fits, the code
   needs to change, not the manifest.
3. Edit the owning bundle's manifest. For a pod, confirm its podspec has a
   `s.resource_bundles` entry pointing at the file.
4. Validate strictly. `plutil -lint` is lenient about XML that
   `plistlib`/`expat` rejects — notably a `--` inside an XML comment, which is
   illegal XML and which `plutil` accepts:
   ```bash
   python3 -c "import plistlib,sys; plistlib.load(open(sys.argv[1],'rb'))" path/to/PrivacyInfo.xcprivacy
   ```
5. Re-run the guard, and for a bundling change verify the product:
   ```bash
   mise exec -- flutter build ios --release --no-codesign
   bash scripts/check_privacy_manifest_coverage.sh --archive build/ios/iphoneos/Runner.app
   ```

## Known follow-ups

- `divine_device_attestation` (PR #8779, not yet merged) caches App Attest key
  handles in `UserDefaults` and ships no manifest. When that PR lands, add
  `NSPrivacyAccessedAPICategoryUserDefaults` / `CA92.1` plus a
  `s.resource_bundles` entry to its podspec. The guard will fail until then,
  which is the intended behaviour.
- `NSPrivacyCollectedDataTypes` for the app target needs a product/legal pass
  against the App Store Connect privacy label.
