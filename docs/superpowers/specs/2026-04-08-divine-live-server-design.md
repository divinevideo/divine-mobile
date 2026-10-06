# Divine Live Server Design

Status: In Progress
Date: 2026-04-08
Last updated: 2026-04-08
Validated against: `live-spaces-v1` mobile client branch, `divine-live-server` `main` at `64a497c`, and the hosted LiveKit Cloud `divine` project authenticated locally on 2026-04-08.

## Goal

Document the dedicated Divine live control-plane service in `../divine-live-server`, deployed at `https://live.api.divine.video`, that powers livestream room creation, join-token minting, session lifecycle, speaker grants, and replay handoff for the mobile live feature.

## Implementation Snapshot

As of `divine-live-server` `main` `64a497c`:

- the repo exists and boots as a Rust/Axum service from `src/main.rs`
- production startup loads env config, connects to Postgres, runs `sqlx` migrations, and serves HTTP
- the app router exposes `/health`, room create/start/end, join, participant role, recording lookup, and LiveKit webhook routes
- NIP-98 verification is implemented in `src/auth/nip98.rs`
- role-based LiveKit join token minting is implemented in `src/livekit/tokens.rs`
- replay-ready webhook handling is implemented in `src/livekit/webhooks.rs` and `src/routes/live_webhooks.rs`
- Docker and GKE deployment assets exist in `Dockerfile` and `k8s/`
- route and auth tests exist under `tests/`
- Hosted LiveKit Cloud is authenticated locally for the `divine` project

## Product Decisions

These decisions were approved during design and are still the intended product boundary:

- use a dedicated backend repo: `../divine-live-server`
- deploy it on a dedicated host: `live.api.divine.video`
- keep it separate from `divine-funnelcake` at `api.divine.video`
- use hosted LiveKit Cloud first, not self-hosted LiveKit
- verify Nostr-signed HTTP requests rather than Divine-account session cookies or bearer tokens
- allow any valid Nostr signer to join a public room as audience
- restrict room hosting to a Divine-managed allowlist in v1
- keep Nostr as the public source of truth for room/session/chat/presence discovery
- include replay and recording webhook handling in v1

## Non-Goals For V1

- replacing Nostr as the discovery or social source of truth
- running our own SFU or self-hosting LiveKit
- folding live media control-plane logic into `divine-funnelcake`
- requiring a Divine-only account system to watch public rooms
- private rooms, paywalled rooms, or guest access without a Nostr signer
- full moderator policy tooling beyond host-controlled room lifecycle and role grants

## Why A Separate Service

`divine-live-server` has a different job than `divine-funnelcake`.

`divine-funnelcake` is the Nostr relay and analytics backend behind `api.divine.video`. `divine-live-server` is a media control plane:

- verify caller identity from Nostr-signed HTTP auth
- authorize room lifecycle actions
- mint short-lived LiveKit tokens
- track active room/session records
- receive LiveKit webhooks
- surface replay status

This boundary keeps media-plane secrets, LiveKit failure modes, and session lifecycle logic isolated from the relay and analytics stack.

## Service Responsibilities

### Owns

- room draft creation for public livestream rooms
- live session start and end lifecycle
- host allowlist enforcement
- audience versus publisher token authorization
- speaker-role grants that require server-authoritative publish permission
- LiveKit room token minting
- LiveKit webhook verification and replay state updates
- health, metrics, and audit-friendly structured logs

### Does Not Own

- public room discovery as the source of truth
- room/session/chat/presence event publication to Nostr
- video transport itself
- upload, CDN, or media transcoding outside LiveKit-managed recording output
- general Divine account identity

## Architecture

### High-Level Split

- Divine mobile app:
  - live discovery, room detail, room UI, host controls
  - publishes room/session/presence/chat to Nostr
  - calls `divine-live-server` for room draft, start, join, end, and replay lookup
- Nostr:
  - room metadata
  - active session metadata
  - chat
  - presence and hand raises
  - public discoverability across clients
- `divine-live-server`:
  - verifies NIP-98 auth
  - authorizes roles
  - stores room/session/replay records
  - mints LiveKit Cloud tokens
  - handles LiveKit webhook callbacks
- LiveKit Cloud:
  - realtime media transport
  - reconnect behavior
  - speaker publish and audience subscribe
  - recording and replay pipeline

### Why This Split

Nostr should carry public state and interoperability. It should not be forced to enforce media permissions or carry transport-level churn.

LiveKit should carry audio/video transport. It should not become the source of truth for public room discovery.

`divine-live-server` exists to bridge the two safely without turning Divine live into a closed identity silo.

## Identity And Auth Model

### Request Authentication

Use NIP-98 HTTP auth for all authenticated client calls.

Request format:

- `Authorization: Nostr <base64-encoded kind 27235 event>`

The server verifies:

- event kind is `27235`
- Schnorr signature is valid
- the `u` tag matches the exact request URL
- the `method` tag matches the exact HTTP method
- the `payload` tag matches the request body hash
- the event timestamp is fresh

Current implementation constants in `src/auth/nip98.rs`:

- reject requests older than 10 minutes
- reject requests more than 60 seconds in the future

The caller identity is the signing pubkey from the verified NIP-98 event.

### Why NIP-98

This keeps the service Nostr-native:

- any valid Nostr signer can prove identity
- the live backend does not require a Divine-only login session
- the system stays interoperable with the wider Nostr ecosystem

## Authorization Model

### Public Audience Access

Any valid Nostr signer may request an audience token for a public live room.

Audience tokens are:

- subscribe-only
- non-publishing
- scoped to a single active session

### Host Access

Only pubkeys in the Divine host allowlist may:

- create room drafts
- start sessions
- receive host publish tokens
- end sessions
- change speaker-role grants

### Speaker Access

Speaker publishing is server-authoritative. Nostr-only speaker state is not enough to mint secure publish tokens.

To support invited speakers, the service stores room role grants and only mints publish-capable speaker tokens for pubkeys explicitly granted speaker access by the host.

### Moderator Access

Do not add a separate moderator policy system in v1.

For v1:

- host is the only backend-authoritative moderator
- room moderation beyond token authorization can remain a follow-up slice

## LiveKit Cloud Model

Use hosted LiveKit Cloud for v1.

The service stores:

- LiveKit server URL
- LiveKit API key
- LiveKit API secret
- a configured webhook secret value for follow-up cleanup or future verification work

The service mints short-lived access tokens with role-specific grants:

- audience:
  - `roomJoin = true`
  - `canSubscribe = true`
  - `canPublish = false`
- speaker:
  - `roomJoin = true`
  - `canSubscribe = true`
  - `canPublish = true`
- host:
  - `roomJoin = true`
  - `canSubscribe = true`
  - `canPublish = true`

Participant identity should be the caller's full hex pubkey so media participation preserves Nostr identity continuity.

Current implementation details in `src/livekit/tokens.rs`:

- join token TTL is 15 minutes
- the LiveKit room name is currently the Divine room id
- `roomName`, `participantIdentity`, `serverUrl`, `canPublish`, and `expiresAt` are returned to the client

## API Contract

### `POST /v1/live/rooms`

Creates a backend room draft for an allowlisted host.

Auth:

- required NIP-98
- signer must be on the host allowlist

Request body:

```json
{
  "title": "Divine Live",
  "summary": "Public room for mobile creators",
  "imageUrl": "https://media.divine.video/example.jpg",
  "relays": ["wss://relay.divine.video"]
}
```

Response:

```json
{
  "id": "room_01JQEXAMPLE",
  "hostPubkey": "<hex-pubkey>",
  "title": "Divine Live",
  "summary": "Public room for mobile creators",
  "imageUrl": "https://media.divine.video/example.jpg",
  "relays": ["wss://relay.divine.video"],
  "visibility": "public",
  "createdAt": "2026-04-08T08:00:00Z"
}
```

Notes:

- this endpoint creates a backend control-plane record
- the mobile app still publishes the Nostr room event separately

### `POST /v1/live/rooms/:roomId/sessions`

Starts a live session for an existing room.

Auth:

- required NIP-98
- signer must be the room host

Request body:

```json
{
  "sessionId": "1744065600123456"
}
```

Response:

```json
{
  "roomId": "room_01JQEXAMPLE",
  "sessionId": "1744065600123456",
  "status": "live",
  "startedAt": "2026-04-08T08:05:00Z"
}
```

Notes:

- the service creates the active session record
- the mobile app still publishes the corresponding Nostr session event

### `POST /v1/live/rooms/:roomId/join`

Returns a LiveKit join token for the caller.

Auth:

- required NIP-98

Request body:

```json
{
  "role": "audience"
}
```

Valid request roles:

- `audience`
- `speaker`
- `host`

Role resolution rules:

- `audience`: any valid signer for a public room with an active session
- `host`: only the room host pubkey
- `speaker`: only a pubkey with an active backend speaker grant

If a signer requests `speaker` or `host` without authorization, return `403` instead of silently downgrading to audience.

Response:

```json
{
  "token": "<livekit-jwt>",
  "roomName": "room_01JQEXAMPLE",
  "participantIdentity": "<hex-pubkey>",
  "serverUrl": "wss://<project>.livekit.cloud",
  "canPublish": false,
  "expiresAt": "2026-04-08T08:20:00Z"
}
```

### `PUT /v1/live/rooms/:roomId/participants/:pubkey/role`

Adds or updates a backend-authoritative role grant for a room participant.

Auth:

- required NIP-98
- signer must be the room host

Request body:

```json
{
  "role": "speaker"
}
```

Allowed v1 values:

- `speaker`
- `audience`

Response:

```json
{
  "roomId": "room_01JQEXAMPLE",
  "pubkey": "<hex-pubkey>",
  "role": "speaker",
  "updatedAt": "2026-04-08T08:07:00Z"
}
```

Notes:

- this endpoint is the authoritative source for publish permission grants
- the host client should still publish the corresponding Nostr session update so public state stays interoperable

### `POST /v1/live/rooms/:roomId/sessions/:sessionId/end`

Ends an active session.

Auth:

- required NIP-98
- signer must be the room host

Request body:

```json
{}
```

Response:

```json
{
  "roomId": "room_01JQEXAMPLE",
  "sessionId": "1744065600123456",
  "status": "ended",
  "endedAt": "2026-04-08T09:00:00Z"
}
```

### `GET /v1/live/rooms/:roomId/recording`

Returns replay status for a room.

Auth:

- no auth required for public rooms

Response when replay exists:

```json
{
  "status": "ready",
  "playbackUrl": "https://stream.divine.video/live/room_01JQEXAMPLE/master.m3u8"
}
```

Response when replay is not available yet:

- `404 Not Found`
- `204 No Content` remains acceptable for future callers, though the current implementation returns `404`

### `POST /v1/live/webhooks/livekit`

Receives LiveKit webhook callbacks.

Auth:

- verified via LiveKit webhook authorization, not NIP-98

Current implementation responsibilities:

- verify the Bearer token authorization from LiveKit
- parse `recording_ready` webhook payloads
- update replay status when recording becomes ready

Follow-up responsibilities:

- cover more room/session lifecycle webhook types if the mobile product needs them
- reconcile the configured `LIVEKIT_WEBHOOK_SECRET` with the verification path in code

## Storage Model

Production runtime uses a durable relational database from day one.

Current implementation details:

- `src/main.rs` always connects to Postgres and runs `sqlx` migrations before serving
- `migrations/0001_init.sql` creates `host_allowlist`, `live_rooms`, `live_sessions`, and `live_room_roles`
- repository modules under `src/repos/` back the Postgres code path
- `AppState` still carries an in-memory backend for fast route and unit tests

### Tables

#### `host_allowlist`

- `pubkey` primary key
- `created_at`
- `created_by`
- `note`
- `disabled_at`

#### `live_rooms`

- `id` primary key
- `host_pubkey`
- `title`
- `summary`
- `image_url`
- `visibility`
- `relays` JSON
- `livekit_room_name`
- `created_at`
- `updated_at`

#### `live_sessions`

- `id` primary key
- `room_id` foreign key
- `host_pubkey`
- `status` enum-ish text field currently used as `live | ended`
- `started_at`
- `ended_at`
- `recording_status`
- `recording_playback_url`
- `created_at`
- `updated_at`

#### `live_room_roles`

- `room_id`
- `pubkey`
- `role`
- `granted_by`
- `granted_at`
- `revoked_at`

This table exists so speaker publishing can be server-authoritative rather than inferred from untrusted client requests.

## Nostr Interaction Model

Nostr remains the public state layer.

The service should not require every room/session update to round-trip through its own database before it is visible publicly. The mobile app continues to publish:

- room metadata
- live session metadata
- speaker roster changes
- presence
- chat

However, the service remains authoritative for media permissions:

- host allowlist
- room ownership
- speaker publish grants
- session status for token minting

## Error Model

Use explicit HTTP status codes and stable machine-readable errors.

Examples:

- `400 Bad Request`
  - malformed JSON
  - invalid role value
- `401 Unauthorized`
  - missing or invalid NIP-98 auth
  - missing or invalid LiveKit webhook authorization
- `403 Forbidden`
  - valid signer but not allowed to host, publish, or end session
- `404 Not Found`
  - unknown room or session
  - replay not available
- `409 Conflict`
  - joining a room with no active session
  - attempting to start a second active session for the same room
- `502 Bad Gateway` or `503 Service Unavailable`
  - LiveKit dependency failure

Error body shape:

```json
{
  "error": "forbidden",
  "message": "Pubkey is not allowed to host livestreams"
}
```

## Deployment And Configuration

### Repo

- backend repo now exists at `../divine-live-server`

### Public Host

- production host: `https://live.api.divine.video`

### Required Configuration

- `LIVE_SERVER_PUBLIC_URL`
- `DATABASE_URL`
- `LIVEKIT_URL`
- `LIVEKIT_API_KEY`
- `LIVEKIT_API_SECRET`
- `LIVEKIT_WEBHOOK_SECRET`
- `REPLAY_PUBLIC_BASE_URL`
- `PORT`

### Deployment Assets

Current repo assets:

- `.env.example`
- `Dockerfile`
- `k8s/deployment.yaml`
- `k8s/service.yaml`
- `k8s/httproute.yaml`

## Observability And Testing

Current implementation provides:

- `GET /health`
- health JSON with safe `service` and `version` metadata
- unit and route tests for health, NIP-98, room lifecycle, join authorization, and replay webhooks

Still needed:

- structured request ids in logs
- counters and metrics for auth failures, token issuance, and webhook failures
- sqlx-backed integration tests that exercise migrations and repositories against a real Postgres database

## Migration Impact On Mobile

The existing mobile live branch still needs two client follow-ups:

- add a dedicated `LIVE_API_URL` client setting, defaulting to `https://live.api.divine.video`, so livestream control-plane traffic is isolated from the rest of the app backend
- call `PUT /v1/live/rooms/:roomId/participants/:pubkey/role` when the host promotes or demotes speakers

Without the second follow-up, public Nostr state may show a speaker while the backend still refuses to mint a publish-capable token.

## Known Gaps And Follow-Ups

- route tests mostly exercise the in-memory `AppState` backend, not the production Postgres path
- `LIVEKIT_WEBHOOK_SECRET` is configured but not currently used by `src/livekit/webhooks.rs`
- `REPLAY_PUBLIC_BASE_URL` is configured but replay responses currently return the playback URL from the webhook payload directly
- observability is still minimal beyond `/health`
- host moderation actions that should affect LiveKit participants directly remain a follow-up slice
