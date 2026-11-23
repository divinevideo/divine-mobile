# Desktop creation and distribution

Status: approved by Rabble on 2026-11-23 with “Approve and implement.” The requested outcome includes full creation and uploads. Approval does not create new credentials, publisher accounts or permissions.

## Intended result

Ship the existing Divine Flutter app on macOS, Linux, and Windows with creation and uploads included in the first release. TV work remains in its separate projects. A viewer-only build does not meet this request.

A desktop candidate must let someone sign in, browse and play videos, use social features, record a webcam clip with microphone audio, import local footage, edit and export a video, and upload and publish it. These must be working journeys, not just controls that render or a successful compiler exit. Account switching and logout must preserve the app's existing privacy and cleanup guarantees.

## Current evidence

- Investigation base: divine-mobile origin/main at 54bda63caf7ac2a37cea49ecb34863d894f782a6. Work is isolated on feat/desktop-distribution-20261123 in the repository's established worktree directory.
- Flutter remains pinned to 3.47.9. This host is Apple Silicon with Xcode 26.2 and a Linux/arm64 Docker engine. Windows needs a Windows build runner; Linux build and package verification need Linux. Do not report a macOS build as proof of either.
- The existing Codemagic macos-build workflow disables code signing and produces a DMG. That is not Mac App Store distribution and is not a notarized direct-download release.
- Linux has a runner and a media_kit video backend, but CameraService.create explicitly selects CameraLinuxService, an unsupported-platform stub. Existing service integration CI compiles and launches Linux test applications, which provides useful build infrastructure but does not validate the complete production entrypoint or packaging.
- Windows has a runner, but divine_video_player declares no Windows backend and camera selection falls through to a plugin without a Windows implementation. A Windows build alone would therefore not establish playback or recording.
- pro_video_editor declares Windows and Linux native implementations. Its actual import, preview, export, audio and cancellation behavior must be verified at the locked version.
- Windows and Linux runner branding still contains nostrvine_app. macOS already uses Divine and co.openvine.app. Renaming a persistent application/storage identifier needs compatibility evidence; changing the displayed name does not require changing the storage namespace.
- Repository inspection and two Brain searches found no usable record of an existing Microsoft Store product or Linux distribution account. Absence from search is not proof that none exists. Retrieve actual product identity before building a Store submission; never invent a publisher ID.

## Approaches

The recommended approach is to retain the existing app, repositories, account storage and editor UI, and repair or extend the owning platform packages. Playback belongs in divine_video_player; capture belongs in divine_camera and its existing service boundary; upload fallback belongs in upload_repository. Desktop packaging and release automation sit outside the product UI.

A separate desktop Flutter shell would duplicate navigation, account wiring and editor integration, making parity and future maintenance harder. A web wrapper would not exercise the native creation and distribution requested here. Neither alternative is proposed.

Within media backends, reuse an existing implementation where its contract and supported platform match. For example, evaluate reusing the media_kit backend for Windows instead of creating a second playback stack. Camera backend selection remains an engineering decision after inspecting the native APIs and source: it must support both audio/video recording and preview, own device/lifecycle cleanup, and fit divine_camera's public contract. Do not replace working Android, iOS or macOS capture as a side effect.

## Distribution targets

- macOS: a correctly sandboxed and signed Mac App Store package, submitted through the existing organization's App Store Connect setup once its macOS app record, signing capabilities and version state are verified. A notarized direct-download DMG is an additional supported route when the existing signing setup permits it.
- Windows: a Microsoft Store MSIX using the exact reserved Partner Center package identity and publisher. A zip of the complete runnable bundle can support testing, but it is not Store publication.
- Linux: an AppImage plus a Debian package, built and installed on Linux with their runtime dependencies accounted for. Include a desktop entry, icons, application metadata, versioning, license notices and uninstall behavior. Do not require end users to install development packages. Use release assets for initial direct distribution; a signed package repository is a separate infrastructure choice if later needed.

Flathub is not the automated first-release route. Its current requirements prohibit AI-generated/assisted manifests and agent-automated submission interactions. This workflow must not author or submit a Flathub manifest or imply acceptance there. A maintainer can choose a separate compliant submission later.

Native macOS arm64 and Windows/Linux x64 are the initial package targets. Broaden architecture coverage only when native dependencies and matching-runner tests support it. The existing Linux arm64 Docker host is useful for reproducing compilation failures but does not establish x64 package compatibility. State architecture limits on actual artifacts.

## Package and application boundaries

1. Add native release-build checks on the corresponding host OS and pin the existing Flutter version. First run the unmodified build to capture concrete failures. Keep logs minimized and free of secrets or user data.
2. Resolve startup/plugin-registration failures without disabling required features. Preserve supported-platform Firebase gating and other existing intentional fallbacks.
3. Extend playback and capture in their owning packages with tests at the public API and lifecycle boundaries. Report camera capabilities honestly: missing hardware is a valid device condition, but an unimplemented platform is not an acceptable first-release recording path.
4. Verify foreground upload fallback where OS-backed background upload is unavailable. A desktop upload must report progress, cancellation and failure correctly. Never claim that closing the desktop process preserves an upload unless a verified persistent worker actually owns it.
5. Make camera/microphone permissions, file selection, file export, deep links and desktop window behavior work within each packaged environment. Surface actionable failures using existing localization and design-system components.
6. Audit native bundles for required libraries and licenses, including mpv/FFmpeg/GStreamer dependencies. Do not bundle secrets or rely on libraries accidentally installed on the developer machine.
7. Build packages with one effective source revision and version identity; record checksums, architecture, signing state and validation results. Publishing uses the reviewed source and candidate artifact, not a fresh unreviewed rebuild.

## Validation and release gates

For every platform, exercise sign-in, feed playback with audio, camera preview, microphone audio in a recorded clip, stop/cancel and re-open camera, file import, editor preview, exported-file playback, upload progress/cancellation/retry, published-content visibility, logout/account switching, and app restart. Use synthetic accounts and footage, never real user credentials or private content in committed fixtures or screenshots.

Use unit/widget tests for deterministic state and cleanup behavior, package coverage gates for changed packages, and real native builds and smoke tests for platform integrations. A mocked capture test cannot establish that a webcam or exported file works. Hardware-dependent gaps must remain explicit until exercised on the corresponding platform; do not label an artifact release-ready while its required journey is unverified.

Before each push, run affected tests, Flutter analysis and relevant guards/generated-code checks. Open focused PRs targeting main: separate independent build repairs or platform packages; combine dependent changes without stacking PRs. Obtain independent fresh-context review of the exact published head, request the mapped team once and inspect required CI to completion. Platform-sensitive release and workflow edits require the verified platform-team acting identity; this session verified that authority for its current GitHub account.

Store submission additionally requires the actual publisher product identity, valid signing, complete store metadata/ratings/privacy declarations, installed-package smoke testing and the platform's submission validation. Report upload, review, approval and public availability as separate states. Do not mark delivery complete from a successful upload alone.

## Scope controls

- No TV implementation, livestream/LiveKit work, protocol changes or mobile feature redesign.
- No viewer-only release and no skipped tests or exception suppression to obtain a green build.
- Preserve existing accounts, private keys and cleanup behavior across upgrades.
- Use existing release accounts and signing facilities when authorized and available; no credential/IAM/account creation is implicit in this document.
- Do not merge or publish an unreviewed change, bypass checks, accept legal agreements, or invent successful native validation.
- Final submission must use concrete reviewed artifacts and verified destination details. If access or an external review blocks publication, finish all independent work and report the exact remaining action.

## Delivery sequence

Reproduce and repair native builds, establish full creation workflows, prepare and validate installable candidates, then submit those candidates to the selected stores/distribution channels. Deliver source repairs through reviewable PRs throughout instead of holding unrelated platform fixes in one branch until every storefront responds.

## Sources

- Current repository code and configuration paths named above.
- https://docs.flutter.dev/deployment/macos
- https://docs.flutter.dev/deployment/windows
- https://developer.apple.com/documentation/security/protecting-user-data-with-app-sandbox
- https://docs.flathub.org/docs/for-app-authors/requirements#generative-ai-policy

