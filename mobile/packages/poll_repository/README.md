# poll_repository

Status: Current
Validated against: `pubspec.yaml` on 2026-10-31.

Purpose: NIP-88 polls on Divine videos. Builds the `kind:1068` poll event a
creator publishes with a video (a poll, a quiz with its answer, or an emoji
slider), reads it back with the `kind:1018` votes cast on it, tallies one vote
per pubkey, and publishes a viewer's vote.

Used by: the video publish flow, which signs the poll before the video that
points to it, and the poll, quiz and slider stickers in the player.

Funnelcake counts the votes (`GET /api/polls/{id}/results`), and only the
viewer's own vote is read from the relays. When Funnelcake is not configured
or does not answer, the votes are counted on the device from the relays'
`kind:1018` events instead, read in one capped request.

Test locally (`nostr_sdk` pulls in `dart:ui`, so `dart test` cannot run it):

```bash
cd mobile/packages/poll_repository
flutter test
```
