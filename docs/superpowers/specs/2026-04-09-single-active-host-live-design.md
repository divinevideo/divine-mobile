# Single Active Host Live Design

## Goal

Prevent hosts from creating multiple simultaneous livestreams across different rooms. If a host already has an active live session, `Go live` should resume that live instead of creating another room/session.

## Problem

Today the mobile client always does this:

1. create a new room draft
2. publish a new room event
3. publish a new live session event
4. start that session on the live server

The live server only enforces one active session per room, not one active session per host. That means a single host can create multiple active rooms and fragment their audience.

## Product Decision

Use a single-live-per-host rule.

- A host may only have one active live session at a time.
- If the host already has an active session, `Go live` should take them back into it.
- Do not silently end the existing live.
- Do not create a duplicate room just because the host tapped `Go live` again.

This makes livestreaming behave like a durable host channel with resumable sessions, not disposable duplicate rooms.

## Desired Behavior

### Server

The live server becomes the authority for "does this host already have a live?"

- Room creation should return the existing active room/session for that host if one exists.
- Starting a session should continue to enforce one active session per room.
- The server should expose enough response data for the client to route directly into the existing room/session.

### Mobile

The `Go live` flow should handle two success shapes:

1. a newly created room + new session
2. an existing active room + existing active session

If the server says the host already has an active live, the app should:

- skip publishing a new room/session to Nostr
- skip starting a new backend session
- navigate directly into the existing live room

## API Shape

Keep the control plane small and explicit.

### `POST /v1/live/rooms`

Current behavior:
- always creates a room

New behavior:
- if caller has no active live: create a new room draft response
- if caller already has an active live: return the existing active room/session payload instead

Response becomes:

- `status: "created"` for a new room
- `status: "existing_active"` when an active live already exists
- common room fields
- optional `active_session` object when `status == "existing_active"`

This avoids using transport-level conflict handling for the main happy path. The client gets a normal success response it can route on cleanly.

## Nostr Behavior

Nostr remains the public source of discovery metadata, but it should not receive duplicate room/session publishes from the same host when the server has already declared an existing active live.

Rules:

- new live path: publish room/session to Nostr as today
- existing active live path: publish nothing new

## Routing Behavior

If the server returns an existing active live, mobile should navigate to:

`/live/room/:roomId/session/:sessionId`

with the existing room/session payload, the same way it does after a normal successful `Go live`.

## Error Handling

- If the server returns `existing_active` but omits session payload, treat that as a server failure.
- If the app cannot load the existing room/session route payload, show a clear error rather than attempting to create another room.
- Existing explicit "end session" remains the only normal path that clears the active-live lock.

## Testing

### Server

- host with no active live gets `created`
- host with an active live gets `existing_active`
- another host can still create their own room
- ended sessions no longer block new room creation

### Mobile

- `Go live` creates/publishes/starts when no active live exists
- `Go live` resumes existing room/session and skips create/publish/start when server returns existing active
- failure path still surfaces errors normally

## Non-Goals

- auto-ending an old live when starting a new one
- merging multiple historical rooms per host
- introducing a new "replace live" UX in this slice
- changing public discovery semantics beyond avoiding duplicates
