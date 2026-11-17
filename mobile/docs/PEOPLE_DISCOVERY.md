# Find people

Find people recommends both active Divine accounts and classic Viners. The
full-screen page is available from Explore and empty Following feeds. Profile
setup can offer it as an optional step; Skip and Continue require no follows.
Existing search and profile pages remain the way to look up a particular person
or inspect their videos.

## Release switches

Both internal switches are off by default:

- `FF_FIND_PEOPLE` enables the page, entry points and optional onboarding.
- `FF_FEED_PEOPLE_SUGGESTIONS` additionally enables a people card in Home feeds.

Enable the backend endpoint and its analytics migration before enabling either
client switch. The canonical analytics adoption is tracked in
https://github.com/divinevideo/divine-context/pull/203. No switch changes the
existing analytics consent or held consumption-event release gates.

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

## Feed card

When recommendations are ready before the viewer reaches the eleventh video,
one non-video page is inserted after the first ten videos. Late results never
insert a page behind the viewer. A full feed refresh or source change starts a
new insertion opportunity; pagination preserves the current one. Returning to
the same position may show the same card again.

The native player keeps logical video indices unchanged, pauses playback on
the card and emits no video activation for it. The card uses the same follow and
dismiss operations as the permanent page. Keep watching advances to the next
video; scrolling in either direction remains available. The slot stays stable
when its suggestions are exhausted, so it cannot shift the visible feed.

## Measurements and next steps

`people_suggestion_recorded` measures actual visible suggestion rows, confirmed
follows and successful dismissals with source and position only. Suggested
pubkeys and imported identities are not sent. Onboarding skips use the existing
onboarding event; Following-feed entries are a navigation proxy for subsequent
use, not proof of playback.

The sourced comparison of contact and external-follow imports is maintained at
https://github.com/divinevideo/divine-context/blob/d58dedc82695a6873c87f225111b5b6f2e732663/docs/research/people-discovery-imports.md.
It recommends opt-in Nostr/Bluesky following imports next. Contacts require
separate verified identifier enrollment, discoverability consent and reviewed
private matching; login recovery addresses are not discovery consent.
