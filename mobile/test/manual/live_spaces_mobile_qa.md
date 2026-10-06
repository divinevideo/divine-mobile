# Live Spaces Mobile QA

## Host Flow

- Start a live room from a physical phone with `livestreamingBeta` enabled.
- Confirm the host lands in the room with `Turn mic on`, `Turn camera on`, `Flip camera`, and `Audio only` controls visible.
- Toggle mic off and back on.
- Toggle camera off and back on.
- Use `Flip camera` and confirm the active camera changes.
- Tap `Audio only` and confirm camera disables while microphone stays live.

## Speaker Management

- Join the room from a second account as audience.
- Raise a hand from the audience account.
- From the host account, open `Host controls` and then `Manage speakers`.
- Promote the raised-hand audience member and confirm they appear on stage.
- Repeat until the stage reaches four active video speakers and confirm the next promote attempt is blocked.
- Demote a speaker and confirm another raised-hand participant can be promoted into the freed slot.

## Audience Lifecycle

- Join a live room from an audience account.
- Have additional audience accounts join and leave repeatedly while the room stays live.
- Background the app briefly and return.
- Confirm the audience client reconnects without ending the room.
- Repeat under weak or throttled network conditions and confirm `reconnecting` appears before recovery.

## Host Lifecycle

- Start a live room as host.
- Background the app briefly and return.
- Confirm the host session remains intact and the room does not immediately tear down.
- Repeat under weak network conditions and confirm the room remains recoverable.
- Toggle camera and microphone after returning from background and confirm both recover cleanly.

## Replay Handoff

- End a live room with recording enabled on the backend.
- Open the ended room detail screen.
- Confirm a replay banner appears when the backend reports a ready recording.
- Confirm the banner shows a processing state when the backend has not finished the replay yet.
- Confirm no replay banner appears for ended sessions that have no recording yet.
