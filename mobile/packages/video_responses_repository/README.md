# video_responses_repository

The videos responding to a Divine video, for its replies and Add yours stickers:

- **Video replies**: kind 34236 videos whose NIP-22 root tags (`E`, `A`) name it.
- **Add yours answers**: kind 34236 videos that name the chain's first video as
  what inspired them (`["a", <address>, <relay>, "mention"]`) and carry the
  chain's hashtag.
- **Pins and hides**: the reply its creator pinned to the front and the ones they
  hid, in a NIP-78 `kind:30078` event of theirs whose `d` tag is
  `divine:replies:<video address>`.

Funnelcake counts the responses and returns the latest
(`GET /api/videos/{id}/responses`). While it does not answer, the repository
reads them from the relays, at most `maxResponsesRead` in one request.
