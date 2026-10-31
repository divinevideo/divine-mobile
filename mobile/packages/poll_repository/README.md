# poll_repository

Status: Current
Validated against: `pubspec.yaml` on 2026-10-30.

Purpose: NIP-88 polls on Divine videos. Builds the `kind:1068` poll event a
creator publishes with a video (a poll, a quiz with its answer, or an emoji
slider), reads it back with the `kind:1018` votes cast on it, tallies one vote
per pubkey, and publishes a viewer's vote.

Used by: the video publish flow, which signs the poll before the video that
points to it, and the poll, quiz and slider stickers in the player.

Votes are counted on the device from the relay's `kind:1018` events, read in
one capped request. That does not scale to very popular videos; a server-side
count can replace `PollRepository.fetchPoll` behind the same interface.

Test locally:

```bash
cd mobile/packages/poll_repository
dart test
```
