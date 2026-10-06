# Divine Live Server Implementation Plan

> **For agentic workers:** REQUIRED: use `superpowers:subagent-driven-development` or `superpowers:executing-plans` when continuing implementation. This document is now a progress tracker synced to the real backend repo, not the original greenfield checklist.

Status: In Progress
Last synced against: `../divine-live-server` `main` at `64a497c` on 2026-04-08.

**Goal:** Finish the dedicated Rust/Axum service in `../divine-live-server` on `live.api.divine.video` that verifies NIP-98 auth, persists live room/session state, mints LiveKit Cloud tokens, and handles replay webhooks for the mobile live feature.

**Architecture:** Standalone live control-plane service with an Axum router, Postgres persistence through `sqlx`, a NIP-98 verifier for caller identity, a LiveKit Cloud integration layer for token minting and webhook verification, and route handlers that keep Nostr as the public source of truth while enforcing server-authoritative media permissions.

**Tech Stack:** Rust, Axum, Tokio, SQLx + Postgres, Serde, Chrono, JsonWebToken, HMAC/SHA256, Tracing, Tower HTTP, Docker, and GKE manifests.

---

## Current Status

- Hosted LiveKit Cloud is authenticated locally for the `divine` project
- the backend repo already exists at `/Users/rabble/code/divine/divine-live-server`
- runtime startup in `src/main.rs` loads config, connects to Postgres, applies migrations, and serves the Axum app
- the router in `src/app.rs` exposes:
  - `GET /health`
  - `POST /v1/live/rooms`
  - `POST /v1/live/rooms/:roomId/sessions`
  - `POST /v1/live/rooms/:roomId/sessions/:sessionId/end`
  - `POST /v1/live/rooms/:roomId/join`
  - `PUT /v1/live/rooms/:roomId/participants/:pubkey/role`
  - `GET /v1/live/rooms/:roomId/recording`
  - `POST /v1/live/webhooks/livekit`
- deployment packaging exists in `Dockerfile` and `k8s/`
- the repo is on `main` and recent progress has already landed there

## Progress By Task

### Task 1: Scaffold The New Repo

- [x] Repo scaffolded in `d9dda0f chore(live): scaffold divine live server`
- [x] Health route and smoke tests exist in `src/routes/health.rs` and `tests/health_routes.rs`

### Task 2: Add Typed Config, Shared State, And Error Responses

- [x] Config, error, and shared state foundation landed in `6038f42 feat(live): add config and app state foundation`
- [x] Health output includes safe service metadata

### Task 3: Implement NIP-98 Verification

- [x] NIP-98 verification landed in `bc461ce feat(live): add NIP-98 request verification`
- [x] Coverage exists for valid auth, stale events, wrong URL, wrong method, wrong payload, and malformed base64 in `tests/nip98_auth.rs`

### Task 4: Add Postgres Schema And Repository Layer

- [x] Initial schema exists in `migrations/0001_init.sql`
- [x] Postgres models and repositories exist under `src/db/` and `src/repos/`
- [x] Production runtime uses `AppState::from_pg_pool(...)`
- [ ] Add sqlx-backed integration tests that exercise the Postgres path directly instead of relying mostly on the in-memory test backend
- [ ] Decide whether the in-memory backend should remain test-only or be moved behind a narrower test helper boundary

### Task 5: Implement Room Draft, Session Start, And Session End Routes

- [x] Lifecycle routes landed in `2025fe0 feat(live): add control plane routes and gke packaging`
- [x] Coverage exists in `tests/live_rooms_routes.rs`

### Task 6: Add LiveKit Token Minting And Join Authorization

- [x] Join token minting exists in `src/livekit/tokens.rs`
- [x] Join authorization exists in `src/routes/live_rooms.rs`
- [x] Coverage exists in `tests/live_join_routes.rs`

### Task 7: Add Speaker Role Grant Route

- [x] `PUT /v1/live/rooms/:roomId/participants/:pubkey/role` is implemented
- [x] Host-only authority and speaker/audience role semantics are covered in `tests/live_join_routes.rs`

### Task 8: Add Replay Lookup And LiveKit Webhook Handling

- [x] Replay lookup route and webhook route are implemented
- [x] Recording-ready handling exists
- [x] Webhook authorization was tightened in `9fb99dd fix(live): verify livekit webhook authorization`
- [ ] Reconcile the configured `LIVEKIT_WEBHOOK_SECRET` with the actual verification code, or remove the unused setting if it is not needed
- [ ] Decide whether additional LiveKit webhook event types should update room/session state in v1

### Task 9: Add Final Service Hardening And Developer Docs

- [x] `README.md` and `.env.example` exist
- [x] Container packaging exists and was hardened in:
  - `2025fe0 feat(live): add control plane routes and gke packaging`
  - `84391ce build(live): include lockfile in container build`
  - `64a497c build(live): use rust 1.93 in docker image`
- [ ] Expand local development docs with example NIP-98 request flows and Postgres bootstrap steps
- [ ] Add structured request ids, metrics, and audit-friendly logs
- [ ] Add CI or release automation if we want reproducible deploys beyond local `docker build`

## Remaining Execution Slices

### Slice 1: Persistence And Verification Hardening

- [ ] Add Postgres-backed integration tests for migrations, repositories, and route handlers
- [ ] Verify create/start/join/end/recording flows against the real database path
- [ ] Tighten conflict/error mapping so Postgres constraint failures return stable API errors

### Slice 2: Webhook And Replay Cleanup

- [ ] Settle the canonical LiveKit webhook verification approach
- [ ] Either wire `LIVEKIT_WEBHOOK_SECRET` into code or remove it from config, docs, and manifests
- [ ] Decide whether replay URLs should be rewritten behind a Divine domain or stored exactly as provided by LiveKit

### Slice 3: Observability And Ops

- [ ] Add structured request ids to request logs
- [ ] Add counters for auth failures, token issuance, session starts, session ends, and webhook failures
- [ ] Document GKE deploy expectations more concretely, including secret names and rollout checks

### Slice 4: Mobile Integration Follow-Up

- [ ] Add a dedicated `LIVE_API_URL` to the mobile client instead of routing live traffic through the generic backend base URL
- [ ] Call the participant role endpoint when hosts promote or demote speakers
- [ ] Verify end-to-end mobile start/join/replay against the deployed live server

## Suggested Verification Commands

Run from `/Users/rabble/code/divine/divine-live-server`:

```bash
cargo fmt --all --check
cargo clippy --all-targets --all-features -- -D warnings
cargo test --all-targets
```

If Postgres-backed tests are added, include the DB boot or test harness command in this section when that slice lands.

## Out Of Scope For This Plan

- mobile discovery and room UI work
- `divine-funnelcake` changes
- custom SFU or self-hosted LiveKit work
- paywalls, private rooms, or non-Nostr guest access
