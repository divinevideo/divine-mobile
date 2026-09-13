# Divine Mobile

Divine is a decentralized short-form video app that revives Vine's 6-second looping format — human-made content only, no AI slop. This repository holds the Flutter app for iOS, Android, macOS, and web, the shared workspace packages that power it, and the launch and engineering documentation needed to ship to the App Store, Play Console, and Zapstore. The app is built on Nostr, so people keep ownership of their content, followers, and username.

## Features

- Record, edit, and share 6-second looping videos with an in-app camera and video editor (multi-clip timeline, draw layers, beat markers, subtitles, voice-over).
- An infinite home feed with swipe-based tuning ("more/less like this"), plus explore, hashtag, category, and curated-list discovery.
- Social graph and engagement over Nostr: follows, likes, reposts, NIP-22 comments, direct messages, and notifications.
- Content ownership and portability — your keys, your posts, your follower graph — with hardware-backed key storage and NIP-46 remote signing (`bunker://` / Keycast) for people who want to keep keys off the device.
- Media hosting on Blossom, with HLS playback for Divine-hosted blobs.
- Content provenance via C2PA / ProofMode and identity verification through `verifier.divine.video`.
- Creator analytics, monetization surfaces, people lists, and feature flags.
- Safety and compliance flows: content filters, blocklists and mutes, geo-blocking, and minor-account review.
- Localized into 18 languages.

## Architecture

Most application code lives under `mobile/`. The Flutter entry points are `mobile/lib/main.dart` and `mobile/lib/router/app_router.dart` (routing uses `go_router`). App screens and feature wiring sit in `mobile/lib/`; the repo is a Melos workspace whose shared logic lives in packages under `mobile/packages/`.

New feature work follows the layered flow `UI -> BLoC/Cubit -> Repository -> Client`. State management is mid-migration: `flutter_bloc` (BLoC/Cubit) is the target for new UI state, while `flutter_riverpod` remains as legacy compatibility glue. See `docs/STATE_MANAGEMENT.md` and `docs/BLOC_UI_MIGRATION_PRD.md`. Divine ships dark and light appearances (dark by default, user-selectable in Settings); shared components and theme primitives come from `mobile/packages/divine_ui`.

The workspace is organized into around 75 packages, grouped roughly as:

- `mobile/packages/*_repository/` — data-access and feature repositories (feed, videos, comments, follow, profile, notifications, and more).
- `mobile/packages/*_client/` and `mobile/packages/*_api_client/` — API and platform client boundaries (for example `verifier_client` and `funnelcake_api_client`).
- `mobile/packages/models/` — shared model types and generated serialization.
- `mobile/packages/nostr_*` — Nostr SDK, client, key management, and app-bridge behavior (`nostr_sdk`, `nostr_client`, `nostr_key_manager`, `nostr_app_bridge_repository`).
- `mobile/packages/divine_camera/`, `mobile/packages/divine_video_player/`, `mobile/packages/media_cache/` — capture, playback, and caching.
- `mobile/packages/blossom_upload_service/`, `mobile/packages/background_uploader/` — media upload, including OS-backed uploads that survive app suspension.
- `mobile/packages/keycast_flutter/` — NIP-46 remote signing integration.

How it fits the Divine platform: the app speaks to Nostr relays for the social graph and events, stores and serves media through Blossom, supports Keycast-style remote signers over NIP-46, and verifies identity against `verifier.divine.video`. Persistence is local via Drift (SQLite, at-rest encrypted) and Hive. Firebase provides Crashlytics, push messaging, performance monitoring, and analytics. Code-push updates use Shorebird.

Generated code (Riverpod, JSON serialization, Drift, Hive, mocks) is produced by `build_runner` and committed; regenerate after touching any generator input.

## Getting started

Requirements: Flutter `^3.47.0` and the Dart SDK `^3.13.0`. The pinned toolchain version is in `mobile/mise.toml` (Flutter 3.47.2). All Flutter commands run from `mobile/`.

```bash
cd mobile
flutter pub get
flutter run -d <device>
```

Common alternatives from `mobile/`:

- `./run_dev.sh ios debug`
- `./run_dev.sh android debug`
- `./run_dev.sh macos debug`
- `mise run local_android` - Android emulator against the default local stack

If a build fails from generated code or CocoaPods state, use the targeted scripts first (from `mobile/`):

- `./build_ios.sh debug --codegen && ./run_dev.sh ios debug`
- `./build_ios.sh debug --pod-reset && ./run_dev.sh ios debug`
- `./build_macos.sh debug --codegen && ./run_dev.sh macos debug`

For local cache resets from `mobile/`: `./clear_cache.sh` or `./clear_cache.sh --full`. See `docs/BUILD_SPEED_CHECKLIST.md` for the decision flow.

### Daily development

From `mobile/`:

```bash
flutter pub get
flutter analyze
flutter test
```

If you touch codegen-backed sources (Riverpod, JSON serialization, Drift, Hive, or mocks):

```bash
dart run build_runner build --delete-conflicting-outputs
```

### Local stack

A Docker-based local stack (relay, Keycast, Blossom, and supporting services) lives in `local_stack/` and is driven through `mise` tasks from `mobile/`: `mise run local_up`, `mise run local_status`, `mise run local_down`, and `mise run e2e_test`. The stack speaks cleartext to loopback hosts (`10.0.2.2`, `localhost`, `127.0.0.1`), and the app resolves the right one per platform — `10.0.2.2` on the Android emulator, `localhost` on the iOS Simulator and macOS. The Android emulator is the only turnkey target: non-Android runs also need `BLOSSOM_PUBLIC_URL=http://localhost:43003` exported before `local_stack/up.sh`, because the seeder bakes that host into the media URLs it mints. See `AGENTS.md` for the full workflow.

## Configuration

Runtime environment is selected at build time with `--dart-define=DEFAULT_ENV=<env>`, defaulting to `PRODUCTION`. Supported values (see `mobile/lib/models/environment_config.dart`) are `POC`, `STAGING`, `PRODUCTION`, and `LOCAL`; each maps to one relay URL and API base URL (production API is `https://api.divine.video`). For example, `mise run local_build` builds a debug APK with `DEFAULT_ENV=LOCAL`.

Additional `--dart-define` values wire up optional services, supplied by the run/build scripts and CI:

- `ZENDESK_URL`, `ZENDESK_APP_ID`, `ZENDESK_CLIENT_ID`, `ZENDESK_API_TOKEN` — in-app support.
- `PROOFMODE_SIGNING_SERVER_ENDPOINT`, `PROOFMODE_SIGNING_SERVER_TOKEN` — ProofMode attestation.

Keep credentials out of the repo. The Firebase surface is configured through generated `firebase_options.dart` and platform config files.

## Building & release

Signed store builds run on Codemagic (`codemagic.yaml`); GitHub Actions (`.github/workflows/`) runs CI. The main app CI workflow is `mobile_ci.yaml`, alongside per-package workflows and web preview/production deploy workflows.

Codemagic workflows and their publishing targets:

- iOS build — `shorebird release ios`, uploaded to App Store Connect without automatic review submission; dSYMs uploaded to Firebase Crashlytics.
- Android build — `flutter build appbundle --release` (and split-per-ABI APKs), published to Google Play.
- macOS build — packaged as a DMG and published to a GitHub Release.
- E2E smoke tests — Maestro flows on iOS Simulator and Android emulator.

Additional distribution paths:

- Zapstore — the arm64 release APK, described by `zapstore.yaml` (MPL-2.0). Publishing is done manually with `zsp`; see the Zapstore notes in `AGENTS.md`.
- Web — the Flutter web build deploys to Cloudflare (`mobile/deploy-web.sh`, `.github/workflows/mobile_web_production_deploy.yml`).
- Shorebird — over-the-air code-push patches, configured in `mobile/shorebird.yaml`.

The launch-critical release, review, and compliance docs live in `docs/P1_LAUNCH_HUB.md`, with `docs/RELEASE_CHECKLIST.md` and `docs/APP_STORE_REVIEW_DOSSIER.md` for the submission path.

## Documentation

- `CONTRIBUTING.md` — setup, workflow, verification, and PR expectations.
- `AGENTS.md` — repository guidelines, workflow, and verification rules.
- `docs/README.md` — documentation map and source-of-truth guide.
- `docs/ARCHITECTURE.md` — app architecture: layers and dependency direction.
- `docs/NOSTR_SDK_ARCHITECTURE.md` — Nostr SDK internals.
- `SERVICE-INVENTORY.md` — lightweight repo inventory.

If a doc conflicts with current code, tests, or the focused docs above, trust the implementation first. Older plans, migration notes, and postmortems are preserved in `docs/archive/`.

## License

Mozilla Public License 2.0. See `LICENSE`.

---

Part of [Divine](https://divine.video) — your playground for human creativity · [Brand guidelines](https://github.com/divinevideo/brand-guidelines)
