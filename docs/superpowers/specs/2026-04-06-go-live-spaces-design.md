# Go Live / Spaces Design

Status: Proposed
Date: 2026-04-06
Validated against: current `main` architecture, `docs/STATE_MANAGEMENT.md`, `mobile/docs/NOSTR_VIDEO_EVENTS.md`, and the existing Nostr app bridge/live-stream references on 2026-04-06.

## Goal

Add a native Divine `Go Live` / `Spaces` feature for public multi-user rooms with:

- native Divine discovery and room UI
- Nostr-backed room metadata, presence, chat, and zaps
- LiveKit-backed real-time video/audio room media
- mobile-first hosting and speaker controls

## Product Decisions

These decisions were explicitly approved during brainstorming:

- Full product direction, but optimized for speed to ship
- Public rooms only for v1
- Native Divine room UI is required
- Video + audio rooms, not audio-only
- LiveKit/WebRTC is acceptable for room media
- Recommended hybrid architecture accepted
- Rollout compressed to 2 larger slices rather than 5 smaller slices

## Non-Goals For V1

- Private or invite-only rooms
- Paywalled room access
- Fully Divine-owned ingest/transcoding infrastructure
- Large egalitarian many-video rooms with unlimited active publishers
- Full replay/archive product beyond recording handoff
- Splitting livestream behind multiple separate rollout flags

## Recommended Architecture

### High-Level Split

Divine should own the product and the user experience. Nostr should remain the open social/state layer. LiveKit should provide the actual room media transport.

- Divine app:
  - discovery UX
  - `Go Live` host flow
  - room detail screen
  - native room screen
  - host/moderator controls
  - feature flags, routing, analytics, error states
- Nostr:
  - room metadata
  - active-session metadata
  - public discovery interoperability
  - live chat
  - presence and role state
  - zaps and identity continuity
- LiveKit:
  - speaker camera/mic publishing
  - audience subscriptions
  - speaker grid/stage transport
  - reconnection and network adaptation
- Divine backend:
  - token issuance for room join/publish permissions
  - mapping Nostr identity to room roles
  - optional room/session registry for discovery acceleration
  - recording webhook integration for replay handoff

### Why This Split

Nostr is strong for open coordination and cross-client discoverability, but it is not the real-time media plane. LiveKit solves the mobile real-time video/audio problem directly. This split preserves interoperability without forcing Nostr to do a job it is not suited to do.

## Nostr Object Model

### Room

Use NIP-53 `kind:30312` as the stable room object.

Purpose:
- public identity for the space
- title, summary, host pubkey, image, relay hints
- logical container for one or more sessions

Think of `30312` as "this is the place."

### Session

Use NIP-53 `kind:30313` as the scheduled or active live session.

Purpose:
- references the parent room
- carries `planned`, `live`, or `ended` state
- start/end timestamps
- active session metadata for discovery

Think of `30313` as "this room is live right now."

### Presence

Use NIP-53 `kind:10312` for lightweight per-user presence.

Purpose:
- in-room presence
- hand raise state
- coarse role state

Presence should be intentionally coarse. The app should not spam relays with high-frequency transport-derived churn.

### Live Chat

Use NIP-53 `kind:1311` for room chat.

Purpose:
- live messages attached to the active session via `a` tags
- room conversation separate from video comments

This should not reuse the existing comments stack directly. The UX may look related, but the domain model and operational constraints are different.

### Optional Interop Layer

The primary model should be `30312` + `30313` + `10312` + `1311`.

If needed later, Divine can emit or derive a companion `30311` live-event representation for simpler interop with clients that lean on the `30311` shape. That is optional and should not drive the first architecture.

## Media And Backend Model

### Media

Use LiveKit room media for v1.

Capabilities:
- host and invited speakers publish camera/mic
- audience joins receive-only by default
- active video publisher count is capped for quality and mobile sanity
- speakers can degrade to audio-only when needed

### Divine Backend

The backend should remain thin in v1, but it still needs to exist.

Responsibilities:
- issue short-lived LiveKit tokens
- authorize publish vs subscribe roles
- authorize host/moderator actions
- expose recording completion hooks
- optionally cache public room/session metadata for faster discovery queries

The backend should not become the social source of truth. It should support the media control plane, not replace Nostr.

## Product Surfaces

### Discovery

Add a `Live` discovery entry inside Explore first.

Recommended initial surfaces:
- active rooms
- upcoming rooms
- featured hosts

This keeps the feature inside the current information architecture and avoids prematurely creating a separate "spaces app" inside Divine.

### Room Detail

Users should land on a room detail screen before joining.

Purpose:
- explain the room
- show title, host, speakers, schedule, summary
- give a clean public URL/share target
- avoid dropping users directly into a busy room with no context

### Native Room Screen

The core room screen should include:
- speaker video stage or grid
- audience count and live state
- live chat
- zap action
- participant roster
- hand raise / request speaker
- share room action

### Host Console

Host and moderator tools should remain in-room as a sheet or panel, not as a separate route.

Core controls:
- promote/demote speaker
- mute/remove participant
- approve raised hands
- update title/status
- end session

## Mobile-First Constraints

Some hosts will stream from phones. V1 must explicitly optimize for that.

### Host Controls

Host actions should be thumb-reachable and minimal:
- mute/unmute
- camera on/off
- flip camera
- invite/promote speaker
- leave/end session

### Network Degradation

The app should degrade gracefully:
- suggest or auto-fallback to audio-only when quality drops
- keep the host in the room during reconnect attempts
- preserve room context when media reconnects

### Publisher Limits

To keep mobile hosting sane, the number of simultaneous active video publishers should be tightly capped for v1. Additional participants stay audience-only or audio-only.

### Backgrounding

Host backgrounding on mobile must be handled explicitly:
- short interruptions should attempt recovery
- accidental navigation should not immediately destroy the live session
- ending the session should be an intentional act

## Moderation And Safety

Public rooms require moderation tools from day one.

Minimum moderation set:
- report user
- block user
- mute chat participant
- remove participant from room
- approve or deny hand raises
- demote speaker
- end session

Chat moderation and media moderation may be separate internally, but they should feel unified in the host console.

## Client Architecture In This Repo

Follow the repository direction of `UI -> BLoC/Cubit -> Repository -> Client`.

Recommended new feature area:

- `mobile/lib/features/live/` or `mobile/lib/features/spaces/`

Recommended responsibilities:

- BLoCs/Cubits:
  - `LiveDiscoveryBloc`
  - `LiveRoomBloc`
  - `LiveChatBloc`
  - `GoLiveBloc` or `GoLiveCubit`
  - `RoomPresenceCubit`
- Repositories:
  - `LiveRepository` for room/session/presence Nostr operations
  - `LiveChatRepository` for `1311`
  - `LiveMediaRepository` for backend token exchange and LiveKit adapter
- Screens:
  - discovery surface
  - room detail page
  - room page/view
  - host setup page/view

This should be a dedicated feature module. Do not spread live-room logic across existing comments, feed, and settings code just because it is nearby.

## Feature Flags

Use a single live gate for this rollout:

- `livestreamingBeta`

This keeps livestream clearly on or off instead of scattering one feature across multiple rollout toggles.

## Rollout Plan

The approved rollout should be compressed into 2 large slices.

### Slice 1: Audience + Host Beta

Includes:
- public room discovery
- room detail screen
- native room join experience
- audience watch/listen
- live chat
- zaps
- host create/start/end flow
- basic moderation
- invited speakers

This is the first meaningful beta.

### Slice 2: Polish + Replay

Includes:
- reconnection hardening
- mobile host resilience improvements
- moderation refinements
- recording/replay handoff
- deeper QA and performance cleanup

This turns the beta into something operationally safer.

## Testing Strategy

### Automated

- Nostr mapping tests for `30312`, `30313`, `10312`, `1311`
- repository tests for room/session/presence/chat behaviors
- backend client tests for token exchange and role handling
- BLoC tests for room join lifecycle, reconnect states, and moderation actions
- widget tests for discovery, room detail, native room controls, and host console

### Manual

Must include:
- mobile camera/mic permissions
- host reconnect behavior on bad networks
- switching camera while live
- degrading to audio-only
- audience join/leave churn
- session end and replay handoff

## Key Risks

- overloading Nostr presence with too-fine-grained state
- trying to make Nostr the media transport layer
- allowing too many simultaneous mobile video publishers in v1
- coupling live chat to the existing comments implementation too tightly
- shipping discovery, host, and speaker publishing under one vague flag

## Recommendation

Proceed with the hybrid model:

- native Divine public-room product
- NIP-53 room/session/presence/chat state
- LiveKit room media
- thin Divine backend for authorization and recording hooks
- mobile-first host constraints
- 2-slice rollout for speed

This is the best match for the approved product direction and the current Divine codebase architecture.
