# Find people

Find people recommends both active Divine accounts and classic Viners. The
full-screen page is available from Explore and empty Following feeds. Profile
setup can offer it as an optional step; Skip and Continue require no follows.
Existing search and profile pages remain the way to look up a particular person.
The permanent page uses a responsive two-column creator grid, collapsing to
one column on narrow screens or with larger text. Shared cards lead with one
eligible video thumbnail, followed by the creator identity, archive distinction,
Follow and Dismiss. Tapping a thumbnail opens the existing video detail route
with its full video id and creator public key; tapping the identity opens the
profile.

## Release switches

Both internal switches are off by default:

- `FF_FIND_PEOPLE` enables the page, entry points and optional onboarding.
- `FF_FEED_PEOPLE_SUGGESTIONS` additionally enables a people card in Home feeds.

Enable the backend endpoint and its analytics migration before enabling either
client switch. The canonical analytics adoption is tracked in
https://github.com/divinevideo/divine-context/pull/203. No switch changes the
existing analytics consent or held consumption-event release gates. Suggestion
`followed` measurements share the default-off `CONSUMPTION_ANALYTICS_ENABLED`
gate with engagement measurements and require the recorded
`engagement_linkability` and release approvals. Exposure and dismissal
measurements remain subject to ordinary product-analytics consent.

## Shared recommendations

`GET /api/users/{pubkey}/follow-suggestions` provides a cursor-paginated blend of
follow-graph, personalized, classic and cold-start candidates. Gorse contributes
creators from its video candidates; this is independent of video-feed watched
filtering and pagination. Classic labels identify restored content, not a claim
that a creator has returned to Divine. Generic explanations are used when a
specific recommendation reason cannot be shown with evidence.

The account-scoped repository filters the viewer, follows, blocked accounts and
local dismissals on every read. Dismissals stay on the device and are keyed to
the signed-in account. Server policy exclusions still apply. Account changes
retire in-flight requests and replace the visible discovery state.

The optional `video_preview` response field carries `id`, `thumbnail_url` and an
optional `blurhash` from the same eligible candidate. The mobile model ignores
malformed optional previews while preserving a usable creator. Missing preview
metadata shows a neutral profile fallback. Rendering uses the existing passive
image-auth and blurhash widgets: no per-creator video fetch, fabricated video
event, decoder or autoplay is started by a discovery card.

## Feed card

When recommendations are ready before the viewer reaches the eleventh video,
one non-video page is inserted after the first ten videos. Late results never
insert a page behind the viewer. A full feed refresh or source change starts a
new insertion opportunity; pagination preserves the current one. Returning to
the same position may show the same card again.

The native player keeps logical video indices unchanged, pauses playback on
the card and emits no video activation for it. A horizontal carousel uses the
same creator cards, follow and dismiss operations as the permanent page.
Keep watching advances to the next video; scrolling in either direction remains available. The slot stays stable
when its suggestions are exhausted, so it cannot shift the visible feed.

## Measurements and next steps

`people_suggestion_recorded` measures actual visible suggestion rows, confirmed
follows (only after the held identity/release gate is approved) and successful
dismissals with source and position only. Suggested
pubkeys and imported identities are not sent. A creator card is exposed only
when at least half of it is visible on an active, foreground surface; carousel
peeks and thumbnail prefetch do not count. Image rendering emits no video views.
Onboarding skips use the existing onboarding event; Following-feed entries are a navigation proxy for subsequent
use, not proof of playback.

The sourced comparison of contact and external-follow imports is maintained at
https://github.com/divinevideo/divine-context/blob/d58dedc82695a6873c87f225111b5b6f2e732663/docs/research/people-discovery-imports.md.
It recommends opt-in Nostr/Bluesky following imports next. Contacts require
separate verified identifier enrollment, discoverability consent and reviewed
private matching; login recovery addresses are not discovery consent.
