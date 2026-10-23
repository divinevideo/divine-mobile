# Account State Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement the independently owned tasks below; the coordinator owns integration, publication and final review.

**Goal:** Account choices and read actions converge across devices and survive network failure and restart.
**Architecture:** Reusable encrypted per-field account state plus thin app settings and badge adapters. Existing DM and notification protocols retain their owning repositories and gain durable retry.
**Tech Stack:** Dart/Flutter 3.47.2, Nostr NIP-44/NIP-78, SharedPreferences, existing Drift stores, BLoC and compatibility providers.
**Spec:** docs/superpowers/specs/2026-10-23-account-state-sync-design.md

## Global Constraints

- Work in the existing isolated task worktree on fix/badges-sync-rejections; preserve incorporated remote commits.
- Keep namespaces/protocol compatibility, account isolation, protected-minor enforcement, and the livestream hold.
- No new UI copy, dependency on Flutter UI types in repositories, secret logs, guard bypasses or baseline growth.
- Setters persist before success; do not await network. Sync/reset/Undo cannot resurrect stale choices.
- Workers own their listed files, do not revert others, do not push or post. Coordinate shared interfaces before changing them.

## Review Focus

- Restart after a local write but before publication: the pending choice retries and reaches the second device.
- Switching accounts during an asynchronous sync: no state leaks or wrong-account publication.
- Concurrent edits on separate devices: different fields survive; read cursors never regress.
- Incomplete/unreadable/old relay state: retain durable union; never overwrite newer schemas.
- New arrival after a read/dismissal: remains unread/visible as appropriate.

### Task 1: Shared state and badge consumer

**Files:** new mobile/packages/account_state_repository/**; mobile/packages/badge_repository/**.
**Interfaces:** implement the shared repository contract in the spec. BadgeDismissalSync becomes a compatible facade over it.
- [x] Write two-store offline/restart/concurrent-edit regressions and observe failure.
- [x] Implement durable per-field state, transport, lifecycle listeners and badge adapter.
- [x] Run package tests and analysis; preserve existing badge regression coverage.
- [x] Commit only owned files and report exact tests and any interface adjustments.

### Task 2: App settings and lifecycle

**Files:** mobile/lib/services/*preference*, selected filter services and Cubits, app providers/lifecycle; matching mobile/test/**; mobile/pubspec.yaml and lockfile.
**Interfaces:** consume Task 1 APIs; wire owning read repositories' public flushPendingReadState() where available. Register the workspace package and dependency.
- [x] Inventory account vs device settings in the design doc, with each account setting wired and device exceptions explicit.
- [x] Write integration tests for two stores, explicit reset, remote UI update, account switch and lifecycle disposal.
- [x] Integrate shared state into settings without publishing untouched defaults or bypassing age restrictions.
- [x] Start/flush sync at account startup, resume and reconnect; retain existing read transport protocols.
- [x] Run affected tests/analysis, commit owned files and report evidence.

### Task 3: Durable reads and dismissal

**Files:** mobile/packages/dm_repository/**; mobile/packages/notification_repository/**; owned package tests.
**Interfaces:** public Future<void> flushPendingReadState() on each repository; optional injected AccountStateRepository for DM dismissal if needed, coordinated with app owner.
- [x] Reproduce loss of failed/offline read publication without a second user read.
- [x] Persist retry intent using existing owning stores; retry on repository startup and explicit flush, keeping idempotence, ownership and newer-arrival boundaries.
- [x] Sync DM dismissal with a through-message boundary; preserve new-message restore behavior and existing read-marker protocol.
- [x] Run relevant read/mutation tests and analysis, commit owned files and report evidence.

### Task 4: Review, verify and publish

- [ ] Review each owned deliverable against spec, fix verified defects and integrate.
- [x] Run affected packages/app tests and app CI analysis scope, guards and generated-code checks.
- [ ] Rebase on fresh main, publish the expanded PR with a rewritten semantic title/body, preserve reviewer routing, inspect all required/relevant CI.
- [ ] Obtain and publish fresh independent review where available; accurately record unavailable review providers. No merge/release.
