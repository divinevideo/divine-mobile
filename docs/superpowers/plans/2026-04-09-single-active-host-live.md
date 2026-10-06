# Single Active Host Live Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enforce one active live per host and make `Go live` resume an existing active live instead of creating duplicate rooms/sessions.

**Architecture:** The live server becomes the source of truth for active-live exclusivity per host pubkey. Mobile updates its `Go live` state machine to branch on a new server response: create-and-publish for new lives, or route-into-existing for resumed lives.

**Tech Stack:** Flutter, BLoC/Cubit, Rust/Axum, Postgres, LiveKit, Nostr event publishing

---

## File Map

- Modify: `mobile/lib/services/live_api_service.dart`
- Modify: `mobile/lib/models/live/live_room.dart`
- Modify: `mobile/lib/models/live/live_session.dart`
- Modify: `mobile/lib/blocs/go_live/go_live_cubit.dart`
- Modify: `mobile/lib/blocs/go_live/go_live_state.dart`
- Test: `mobile/test/services/live_api_service_test.dart`
- Test: `mobile/test/blocs/go_live/go_live_cubit_test.dart`
- Modify: `../divine-live-server/.worktrees/single-active-host-live/src/routes/live_rooms.rs`
- Modify: `../divine-live-server/.worktrees/single-active-host-live/src/state.rs`
- Test: `../divine-live-server/.worktrees/single-active-host-live/tests/postgres_live_rooms.rs`

## Chunk 1: Live Server Existing-Active Response

### Task 1: Add failing server tests for host-level active-live reuse

**Files:**
- Modify: `../divine-live-server/.worktrees/single-active-host-live/tests/postgres_live_rooms.rs`

- [ ] Write a failing integration test where:
  - host A creates a room and starts a session
  - host A calls `POST /v1/live/rooms` again
  - response is `200`
  - response payload has `status = "existing_active"`
  - payload includes existing room and active session ids
- [ ] Write a second failing integration test where:
  - host A ended their old session
  - host A calls `POST /v1/live/rooms`
  - response is `status = "created"`
- [ ] Run:
  - `cargo test --test postgres_live_rooms`
  Expected: FAIL on missing existing-active behavior

### Task 2: Implement host-level active-live lookup in server state/routes

**Files:**
- Modify: `../divine-live-server/.worktrees/single-active-host-live/src/state.rs`
- Modify: `../divine-live-server/.worktrees/single-active-host-live/src/routes/live_rooms.rs`

- [ ] Add a state/query helper that finds an active session for a given host pubkey
- [ ] Update room creation route to:
  - return normal created payload when no active live exists
  - return `existing_active` payload with room + active session when one exists
- [ ] Keep start-session enforcement unchanged for per-room active session conflicts
- [ ] Keep auth/host allowlist enforcement unchanged
- [ ] Run:
  - `cargo test --test postgres_live_rooms`
  Expected: PASS

### Task 3: Commit server slice

- [ ] Run:
  - `cargo test --test postgres_live_rooms`
  - `cargo test`
- [ ] Commit in server worktree:
  - `git add src/routes/live_rooms.rs src/state.rs tests/postgres_live_rooms.rs`
  - `git commit -m "feat(live): reuse active host live rooms"`

## Chunk 2: Mobile Existing-Active Resume Flow

### Task 4: Add failing client tests for existing-active response handling

**Files:**
- Modify: `mobile/test/services/live_api_service_test.dart`
- Modify: `mobile/test/blocs/go_live/go_live_cubit_test.dart`

- [ ] Add a failing `LiveApiService` test for parsing a `status = "existing_active"` room response with embedded active session
- [ ] Add a failing `GoLiveCubit` test asserting:
  - no Nostr room publish
  - no Nostr session publish
  - no `startSession` call
  - success state uses existing room/session from server
- [ ] Run:
  - `flutter test --no-pub test/services/live_api_service_test.dart test/blocs/go_live/go_live_cubit_test.dart`
  Expected: FAIL

### Task 5: Implement mobile resume-existing-live behavior

**Files:**
- Modify: `mobile/lib/services/live_api_service.dart`
- Modify: `mobile/lib/blocs/go_live/go_live_cubit.dart`
- Modify: `mobile/lib/blocs/go_live/go_live_state.dart`
- Modify: `mobile/lib/models/live/live_room.dart`
- Modify: `mobile/lib/models/live/live_session.dart`

- [ ] Extend live API parsing to handle both:
  - new room creation
  - existing active room/session reuse
- [ ] Update `GoLiveCubit.submit()` to branch:
  - new room path: current behavior
  - existing active path: route to existing room/session and skip create/publish/start side effects
- [ ] Preserve current validation and failure messaging
- [ ] Run:
  - `flutter test --no-pub test/services/live_api_service_test.dart test/blocs/go_live/go_live_cubit_test.dart`
  Expected: PASS

### Task 6: Commit mobile slice

- [ ] Run:
  - `flutter analyze lib/blocs/go_live lib/services/live_api_service.dart test/blocs/go_live/go_live_cubit_test.dart test/services/live_api_service_test.dart`
  - `flutter test --no-pub test/services/live_api_service_test.dart test/blocs/go_live/go_live_cubit_test.dart`
- [ ] Commit in mobile worktree:
  - `git add mobile/lib/services/live_api_service.dart mobile/lib/blocs/go_live/go_live_cubit.dart mobile/lib/blocs/go_live/go_live_state.dart mobile/lib/models/live/live_room.dart mobile/lib/models/live/live_session.dart mobile/test/services/live_api_service_test.dart mobile/test/blocs/go_live/go_live_cubit_test.dart`
  - `git commit -m "fix(live): resume existing active host sessions"`

## Chunk 3: End-to-End Verification

### Task 7: Verify server and client together

**Files:**
- No new files expected unless test fixtures need updates

- [ ] Run in server worktree:
  - `cargo test`
- [ ] Run in mobile worktree:
  - `flutter test --no-pub test/services/live_api_service_test.dart test/blocs/go_live/go_live_cubit_test.dart test/screens/live/go_live_page_test.dart`
- [ ] Manually verify:
  - first `Go live` creates a room/session
  - second `Go live` for same host re-enters the existing live instead of duplicating it
  - after ending the live, `Go live` can create a new room/session again

### Task 8: Push branches

- [ ] Push server branch:
  - `git -C /Users/rabble/code/divine/divine-live-server/.worktrees/single-active-host-live push -u origin codex/single-active-host-live`
- [ ] Push mobile branch:
  - `git -C /Users/rabble/code/divine/divine-mobile/.worktrees/live-spaces-v1 push`

Plan complete and saved to `docs/superpowers/plans/2026-04-09-single-active-host-live.md`. Ready to execute.
