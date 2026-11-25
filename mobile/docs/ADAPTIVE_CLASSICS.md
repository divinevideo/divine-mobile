# Adaptive Classics

Classics browsing and swipe playback can use Funnelcake's private recommendation
read instead of a random archive slice. Home owns its queue. A classic opened
from Explore owns a separate route session; its changes do not reorder the grid.
Reached history, the playing video and the prepared next video remain stable
while recommendations replace the unseen tail.

## API and compatibility

`POST /api/v2/videos/classics/recommendations` accepts a session seed, opaque
cursor, optional anchor, up to twenty distinct recent outcomes and the last ten
reached video IDs. Outcomes are `completed`, `replay`, `positive`, `skip` and
`less`. It returns the existing video/pagination envelope and recommendation
source. Viewer identity uses the existing `X-Pubkey` hint and normal moderation
query parameters remain present. Account identity is not included in the body.

Recent feedback is request-only. Existing playback and explicit Nostr feedback
publishing are unchanged; the new local stream emits no additional public event.
Both consent and account changes invalidate in-flight results and clear context.
Private POST bodies are not automatically retried by transport after their owner
might have changed. Filtered-page top-ups check ownership before continuing.

Any failure of the first page falls back to the existing archive reader: a
missing or disabled endpoint, a server error or a timeout. Its cursor then stays on the archive path and per-swipe adaptation is
disabled for that session. An adaptive continuation failure preserves playback
and its cursor for retry. Manual refresh starts a new session. Confirmed-invalid
archive claims are excluded in both paths; an explicitly popular backend response
may retain the existing unknown-provenance compatibility during archive outages.

## Rollout controls

The Flutter build define `ADAPTIVE_CLASSICS_ENABLED` defaults to `false`, so
Home, Explore browsing and selected-classic playback use the existing archive
path. The Funnelcake `CLASSIC_RECOMMENDATIONS_ENABLED` flag also defaults to
`false`.

Keep both flags off for release until the client requires usage-data consent
and a confirmed non-protected account status before collecting recommendation
feedback or sending personalized requests. Protected accounts and accounts
whose status is pending or unavailable stay on the archive path.

Old clients keep their existing endpoints. This work leaves archive inference
and production item-to-item indexing disabled.

Backend ranking combines Gorse, archive popularity, current Divine engagement
and trusted discovery facets. The starting 60/20/20 mix and immediate signal
weights are experimental. Online changes in satisfaction, discovery, skip rate,
latency and resources require a controlled rollout; local tests are not evidence
of that product effect.

## Fresh-install guest playback

For an iOS or Android QA build, set `GUEST_CLASSICS_MANIFEST_BASE_URL` to the
HTTPS directory containing the reviewed starter manifests. An empty value
keeps the normal welcome screen. On a fresh ordinary launch, a usable
manifest adds **Classics** below the existing age and terms notice. Selecting
it plays the first eligible classic muted. Closing the player returns to
the account and Greenlight choices. Deep links, account recovery, pending
terms, account switching and returning accounts retain their existing entry.

The client requests `v1/<language>/muted.json` in viewing preference order,
then `v1/und/muted.json`. A valid empty list or HTTP 404 advances to the
next language. The player checks a fresh `audible.json` before enabling
sound. The first rendered frame triggers preparation of the next clip.
Transport errors, expired manifests and withdrawals preserve the existing
welcome flow. Backgrounding releases the player, and resuming requires a
fresh manifest. The welcome screen keeps its recently seen set in memory
only while it stays on top; opening another screen from it, such as age
authorization, starts a fresh set on return.

When the approved manifest includes discovery tags, swipes update the unseen
order from early skips, completions and time spent in a second loop. Two
distinct completed clips with the same tag are required before boosting that
tag. The reached and prepared clips keep their positions. Buffering and
unpresented frames do not count. Outcomes stay in memory for the current
manifest and are discarded on close, replacement or backgrounding. Omitted
tags retain the original catalog ordering.

For local QA, override `guestClassicsObserverProvider` to observe a native
first rendered frame and a page change. This build has no guest behavioral
upload or experiment enrollment. Validate first-frame latency, audio behavior
and physical-device playback with reviewed media before enrollment.
