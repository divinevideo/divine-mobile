# Chat Mentions Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans inline. The user requested autonomous completion.

**Goal:** Pick accounts in chat and receive useful, spam-resistant in-app mention notifications.
**Architecture:** Authenticated p tags and nostr references survive the encrypted rumor path. An account-scoped repository observes previously opened rooms, filters trusted senders, and supplies grouped local notifications to NotificationRepository.
**Tech Stack:** Dart, Flutter, BLoC, existing Concord and notification repositories.
**Spec:** docs/superpowers/specs/2026-10-28-chat-mentions-design.md

## Global Constraints

- Chat feature flag, authenticated account and protected-minor gates apply.
- No background OS push or livestream changes.
- No real account IDs in fixtures; preserve full synthetic keys.
- Local storage contains encrypted wraps and read metadata, not plaintext chat copies.

## Review Focus

- Deleted composer mentions must not publish stale recipient tags.
- Blocking/unfollowing must remove existing notification rows.
- Replay and reconnect must not resurrect read state.
- Account changes must dispose subscriptions and isolate storage.
- Future-dated messages and old history must not create fresh alerts.

### Task 1: Mention identity across chat
- [x] Write and run protocol/repository tests for explicit recipient tags through send, receive, restore and edit folding.
- [x] Implement immutable mentionedPubkeys on ChatMessage and authenticated p-tag handling.
- [x] Add composer suggestions via existing mention cubit/overlay, publish nostr references, and render tappable mentions.
- [x] Run chat composer and repository tests.

### Task 2: Trusted local notification source
- [x] Test explicit/self/stranger/block/history/future filtering, grouping and persisted read state.
- [x] Implement injected room observer repository and account-owned metadata store.
- [x] Merge local notifications into feed and badge snapshots, route local reads separately from server IDs.
- [x] Wire feature/auth gates, follow/block updates and room enrollment.
- [x] Run affected notification tests and Flutter analyze.

### Task 3: Delivery
- [x] Review full diff in a fresh review context, fix verified findings, run affected checks.
- [x] Commit and push, open PR against main, request mapped team once.
- [ ] Inspect CI through completion and hand back the PR with precise delivery limitations.

Published PR: https://github.com/divinevideo/divine-mobile/pull/10536. Current CI status is authoritative on that PR.
