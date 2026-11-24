# Desktop Creation and Distribution Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this approved plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Rabble approved implementation; do not add another routine approval checkpoint.

**Goal:** Ship the existing Divine app with working creation and uploads on macOS, Windows and Linux through the approved distribution targets.

**Architecture:** Preserve application UI and repository contracts. Extend platform support in the owning media packages; add native build verification and desktop packaging outside the product flow. Deliver independent repairs through focused PRs targeting main, and combine changes that must ship together.

**Tech Stack:** Flutter 3.47.9, Dart, existing divine_camera/divine_video_player packages, native desktop runners, GitHub Actions and existing Codemagic signing integration, MSIX, AppImage, Debian packaging.

**Spec:** docs/superpowers/specs/2026-11-23-desktop-distribution-design.md

## Global Constraints

- Full creation and uploads are required on all three platforms; a viewer-only build is insufficient.
- Keep Flutter pinned to 3.47.9 and existing mobile/Apple capture behavior intact.
- Preserve account/key storage and logout/account-switch cleanup. Do not rename persistent desktop identities without migration evidence.
- Mac App Store and Microsoft Store; AppImage plus Debian packages for Linux. No agent-authored Flathub manifest or submission.
- Initial packages: macOS arm64 and Windows/Linux x64; verify each on its native OS. Docker Linux arm64 is diagnostic evidence only for x64 delivery.
- No TV, livestream/LiveKit, credential/IAM/account creation, skipped tests, suppressed failures, invented publisher identity or unverified release claims.
- No build/secret material in source or logs. Candidate metadata records exact revision, effective version, architecture, checksum and signing state.
- Before every push: affected tests, Flutter analysis, relevant package coverage and repository guards. Independent review covers the exact published head; inspect CI to completion.

## Review Focus

- Closing/reopening camera or denying microphone access must release devices and leave creation retryable; Task 2 tests lifecycle and permission failures.
- Windows must use an actual render/playback backend, not a successful build followed by MissingPluginException; Task 1 tests platform selection and absence of native-channel calls.
- Linux packages must run without development packages or accidental host libraries; Task 4 installs and launches on a clean runtime image.
- Uploads cancelled or interrupted by process exit must not be reported as published; Task 3 tests foreground fallback and explicit restart behavior.
- Store identity/version mismatches or unsigned candidates must fail before submission; Task 5 tests validation with deliberately incompatible identities and versions.

### Task 1: Restore Windows playback through the existing desktop backend

**Files:** Modify mobile/packages/divine_video_player/lib/src/divine_video_player_controller.dart, lib/src/divine_video_player_widget.dart, pubspec.yaml and README.md; add a Windows Dart plugin registrar under lib/src/windows/; extend test/src/divine_video_player_controller_test.dart and test/src/divine_video_player_widget_test.dart. Update mobile/pubspec.lock through pub get.

**Interfaces:** Preserve DivineVideoPlayerController's existing public playback API. Reuse LinuxVideoPlayerBackend's complete playback interface and media_kit implementation on Windows; compatibility names may remain until a separate rename is justified. Register a Windows Dart implementation and bundle media_kit_libs_windows_video, whose exact resolved version must be recorded.

- [ ] Add a test under TargetPlatform.windows with an injected existing desktop backend. Assert initialization, clips, play, seek, audio/volume, render widget and disposal reach that backend; assert no native divine_video_player channel call occurs. Observe failure before implementation.
- [ ] Select the desktop backend on native Windows, register its Dart plugin and include the Windows runtime library. Update platform comments without changing mobile backend selection.
- [ ] Run the full divine_video_player test suite with coverage and its package analysis. Verify mobile, Linux and web selection tests remain green; run relevant provenance/boundary guards after pub get.
- [ ] Commit the focused playback repair and publish/review through its owning branch before calling this task delivered. A Windows native build in Task 3 additionally verifies runtime linkage.

### Task 2: Implement Windows/Linux camera capture behind divine_camera

**Files:** Add a desktop implementation under mobile/packages/divine_camera/lib/src/desktop/ with package-local tests; modify divine_camera/pubspec.yaml, the public package exports only if needed, mobile/lib/services/video_recorder/camera/camera_base_service.dart and camera_mobile_service.dart at their platform seams. Update existing camera service tests and mobile/docs/LINUX_SUPPORT.md. Retire the Linux unsupported stub only after its replacement is tested; regenerate any affected shrink-only baseline.

**Interfaces:** Implement DivineCameraPlatform, including initializeCamera, buildPreviewWidget, startRecording, stopRecording, capturePhoto, pausePreview, resumePreview, disposal, state/callbacks and duration auto-stop. Constructor injection of CameraPlatform supplies a fakeable camera backend. Evaluate camera_desktop 2.0.0's public native contract/source and reuse it for Linux/Windows if it satisfies recording with microphone audio and preview. Preserve existing Android/iOS/macOS registration and capability reporting. Unsupported hardware controls must remain hidden by honest CameraState capabilities.

- [ ] Characterize the backend's native API before selecting it; verify license, platform registration, minimum SDK and recording output format. If it cannot meet the contract, record the smallest alternate native approach in the execution ledger rather than introducing an unsupported dependency.
- [ ] Write failing tests for initialize/preview, video plus audio configuration, stop result, still capture, max-duration auto-stop, repeated start/stop, failure cleanup, permission denial, close during initialization and reopen. Assert output-file metadata and device release through real adapter behavior, not mock call counts alone.
- [ ] Implement the desktop adapter and native registration, route native Windows/Linux through the working camera service, and keep mobile/Apple behavior unchanged. Do not claim a no-op unsupported method implements a required recording function.
- [ ] Run complete divine_camera tests/coverage, affected recorder tests, package/app analysis and applicable generated/guard checks. Exercise webcam and microphone on matching native devices and inspect the captured file, stating any unavailable hardware explicitly.
- [ ] Commit and independently review this camera slice with all required platform checks inspected.

### Task 3: Reproduce and repair native builds and creation/upload integration

**Files:** Repair only observed failures in mobile/macos/, mobile/linux/, mobile/windows/, owning packages or startup/service boundaries. Add .github/workflows/desktop_ci.yaml and focused tests under mobile/test/desktop/ or the mirrored owning module. Use existing Linux toolchain requirements as the starting point, not proof of production support.

**Interfaces:** Native jobs build the production app entrypoint on macOS, ubuntu and windows runners with Flutter 3.47.9. Test artifacts record source SHA/platform/architecture. Existing upload_repository foreground transport remains the fallback when OS-backed background upload is unavailable.

- [ ] Run an unmodified macOS release build locally with signing disabled; capture the first real failure before changing it. Add native Linux x64 and Windows x64 build jobs, with minimum required native dependencies and artifact upload. Run them against the task branch.
- [ ] For each confirmed compiler/startup failure, add the smallest meaningful regression/characterization first, repair at the owning boundary and rerun the affected native build.
- [ ] Add integration coverage for recording/import -> edit/export -> playable output -> upload/cancel/retry. Verify unsupported background upload falls back to the foreground transport, errors are surfaced and cancellation cannot publish. Preserve account-change cleanup tests.
- [ ] Run matching-host smoke tests for accounts, playback, camera/audio, file dialogs, export and upload. A native build is not a substitute for these journeys. Record exact capabilities and any real device/access blocker.
- [ ] Commit and publish independent build fixes without stacking PRs; keep dependent platform support in one reviewed slice.

### Task 4: Produce installable desktop packages

**Files:** Add desktop packaging scripts under mobile/scripts/desktop/; add Linux desktop entry, icons and AppStream metadata under mobile/linux/packaging/; add Windows MSIX packaging inputs under mobile/windows/packaging/; add mobile/docs/DESKTOP_DISTRIBUTION.md and tests under mobile/test/tools/desktop_packaging_test.dart or Python tests for Python-owned tools. Modify runner display names and release automation only where required.

**Interfaces:** Packaging consumes an already-built native bundle plus exact version, architecture and source revision, and writes immutable artifacts and a JSON receipt. Windows identity name, publisher and publisher display name are explicit verified inputs, not invented constants. Linux packages contain the executable/data/plugins and correct runtime dependencies; preserve the existing keyring/storage namespace.

- [ ] Add failing packaging tests using a synthetic bundle: missing binaries/libs rejected; metadata uses Divine; version/architecture/source SHA carried through; unsafe output paths rejected; checksums match generated files; files with spaces preserved; no store identity means no Store package.
- [ ] Implement Debian packaging with runtime dependencies and standard desktop integration; install/uninstall in a clean Linux image. Implement AppImage with a pinned packaging tool and necessary native runtime libraries; launch in a clean runtime image and check dynamic linkage.
- [ ] Implement MSIX generation with verified Partner Center identity and Store-compliant four-part version ending in zero. Validate on Windows with the available SDK/Store validation tools.
- [ ] Prepare the signed/sandboxed Mac App Store package using the existing signing integration; validate entitlements, nested code and bundled libraries. Separately notarize direct DMG candidates when configured.
- [ ] Commit packaging and inspect its native CI/artifacts. Do not treat unsigned zips, build outputs or installer generation as store publication.

### Task 5: Verify signing/product destinations and submit reviewed candidates

**Files:** Extend existing release scripts/workflows in their owning release module; use mobile/docs/DESKTOP_DISTRIBUTION.md for the verified runbook. Keep operational credentials and store identities supplied by account-owned configuration outside source when sensitive.

**Interfaces:** Submission accepts an immutable artifact receipt and matching destination identity. It reports uploaded/submitted/in-review/approved/public states separately. No automatically recreated accounts or new access grants.

- [ ] Look up existing Apple/Microsoft publisher configuration through repository/Brain and authorized read-only provider access before asking factual account questions. Verify product IDs, accepted agreements, roles, signing availability and current version state without printing credentials.
- [ ] Add tests showing mismatched artifact receipt, version, architecture, signing state or destination identity fails before any write. Use structured provider adapters so test doubles cannot accidentally publish.
- [ ] Prepare concrete store descriptions, ratings/privacy/support metadata and synthetic screenshots for the exact candidate. Verify installed-package journeys from Task 3.
- [ ] Obtain required review/checks on the exact candidate source. Perform only authorized submission/publication actions; for a missing account/access/legal decision, complete every independent deliverable first and name the exact remaining action.
- [ ] Verify provider acceptance and eventual public listing/download bytes. Release completion requires public availability, not a successful upload. Publish Linux artifacts through the approved release route with checksums and install instructions.

### Task 6: Close delivery with reviewed evidence

- [ ] Check each approved spec requirement against actual artifacts and native test evidence. Run affected tests, package coverage, Flutter analysis, guards and native CI after final source changes.
- [ ] Obtain fresh-context adversarial whole-diff review of each exact published PR head, publish and verify the review, request mapped reviewers once and inspect CI through completion.
- [ ] Report exact PR/head/review/CI/artifact/listing links, platform architectures, verified creation journeys and any concrete external blocker. Preserve an accurate continuation ledger if external review or account access remains pending; never claim all three platforms shipped early.
