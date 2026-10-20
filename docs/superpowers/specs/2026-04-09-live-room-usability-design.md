# Live Room Usability Design

**Date:** 2026-04-09
**Branch:** `codex/live-spaces-v1`

## Problem

The current live room is technically reachable, but it still fails the basic product test:

- the room screen is a dead end because it lacks an explicit back affordance
- the stage is fake UI that lists speaker pubkeys instead of rendering actual live media
- chat can show the wrong session history and renders raw hex pubkeys instead of Divine-style identity

That makes the feature feel unfinished even when the control plane and room join flow are working.

## Decision

Fix the live room as a product surface in three focused slices that can be built independently and integrated together:

1. add explicit exit affordances for the live entry and room flows
2. make chat correctly scope to the active live session and render participant identity with cached profiles
3. replace the fake stage roster with a real media surface that can show local and remote stage participants

## UX

### Navigation

- `Go live`, room detail, and live room screens must all show an explicit back affordance.
- Back should return to the previous in-app live surface when possible.
- If there is no poppable route, back should fall through to the live discovery screen instead of leaving the user trapped.

### Chat

- Live chat must always subscribe to the active session address for the room the user is currently in.
- Entering a new session in the same room must not show stale messages from an older session.
- Each chat row should render:
  - participant avatar
  - participant display name
  - message content
- Fallback order for identity should be:
  - cached profile display name and picture
  - generated Divine display name
  - never raw pubkey as the primary label unless there is no better fallback available

### Stage

- The stage must render actual live media, not just speaker metadata.
- When the current user can publish and turns on camera, they should see a local preview on stage.
- When remote stage participants publish video, the room should render their media on stage.
- If nobody is publishing video yet, the stage can fall back to a waiting state, but that state must clearly be an empty media state rather than pretending to be a finished stage.

## Implementation Notes

- Keep navigation fixes local to the live screen widgets. Do not rework global router behavior just to restore a back button.
- Fix chat startup at the room page boundary so the chat bloc cannot miss the initial session address.
- Reuse existing cached-profile infrastructure (`profileRepositoryProvider`, `userProfileReactiveProvider`, `UserAvatar`, `UserName`) instead of inventing a live-specific identity stack.
- Extend `LiveKitRoomService` only as far as needed to expose the media state the stage needs. Do not bundle unrelated moderation or discovery refactors into this slice.

## Success Criteria

- Hosts and audience can always leave `Go live`, room detail, and live room screens without force-quitting or deep-link hacks.
- A newly created live session shows only that session's chat, not a previous session's messages.
- Live chat uses Divine-style identity presentation instead of raw hex-first UI.
- The stage can show actual live media for local and remote stage participants.
