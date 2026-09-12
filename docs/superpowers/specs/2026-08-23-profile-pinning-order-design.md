# Pinned Videos on Divine Profiles

**Date:** 2026-08-23

**Status:** Reviewed product and technical recommendation; implementation pending

## Executive Summary

Divine should let creators pin up to 12 of their videos to the beginning of
their mobile profile grid. A newly pinned video moves to the front. Within
Mobile, the grid's published-video subsequence and fullscreen player use the
same resolved launch sequence. For a given selected list event, Mobile
preserves stored managed order among visible candidates, but cross-relay and
cross-client convergence is not guaranteed.

This is not a new Divine concept. Divine Web already shipped profile video pins
in commit
[`0058e2f5`](https://github.com/divinevideo/divine-web/commit/0058e2f51091501e0cf04fe3018f05fff0460eb9).
The mobile design should reuse that established event shape: a kind-`10001`
replaceable event containing kind-`34236` video `a` coordinates.

That event shape is a Divine convention, not standard NIP-51 semantics.
NIP-51 defines kind `10001` as a list of pinned kind-1 notes using `e` tags.
The distinction matters because other Nostr clients may ignore Divine's video
references, and Divine must preserve list data it does not manage.

The recommendation remains deliberately small: one grid, a contextual
Pin/Unpin action on ordinary video tiles, and no separate pinned section or
manual drag ordering. A recovery-only management screen is required so stale
or unavailable references cannot permanently consume every pin slot.

The detailed evidence and engineering risk register are in the
[evidence appendix](2026-08-23-profile-pinning-order-evidence-audit.md).

## What Exists Today

### Divine Mobile

- The Videos tab is a three-column grid backed by `ProfileFeedCubit`.
- Published videos retain the profile feed's normal newest-first order.
- In-progress uploads appear first on the owner's profile.
- Tapping a tile opens the fullscreen profile feed.
- Long-pressing an owned tile opens the existing Edit/Delete action sheet.
- Mobile does not currently read, display, or publish profile video pins.

### Divine Web

Divine Web already:

- reads and writes kind `10001`;
- stores videos as kind-`34236` `a` coordinates;
- preserves unrelated public tags;
- displays pinned videos on profiles;
- exposes Pin and Unpin actions.

Web currently limits additions to three, appends new tags, and accepts
foreign-authored video coordinates. Mobile's recommended behavior differs:
12 creator-owned pins, with a new mobile pin inserted at the front. These
differences are documented rather than mistaken for Nostr requirements.

## Terminology

- A **managed coordinate** is a syntactically valid kind-`34236` `a` coordinate
  whose author is the profile owner. Its `d` value is preserved byte-for-byte.
- The **selected list event** is the deterministic kind-`10001` winner chosen
  from a completed network-participating read, buffered live events, cached
  candidates, and the last locally accepted revision.
- The **base feed** is the profile's normally filtered published-video sequence
  before pins are overlaid.
- An **active displayed pin** is a visible canonical video from the first 12
  de-duplicated managed coordinates. Other stored members are overflow.
- **Visible** means allowed by the current viewer's deletion, block, expiry,
  transport, playability, and content-policy filters.

## Recommended Mobile Experience

### Viewer

Render one grid in this order:

```text
owner-only in-progress uploads
+ visible pinned videos in stored managed order
+ every remaining profile video in normal feed order
```

Pinned tiles show a small pin badge. There is no heading, separate section, or
layout break. The badge is not the only signal: accessibility semantics also
announce that the video is pinned and its position.

At launch, the fullscreen sequence must exactly match the published-video
sequence shown by the grid. Tapping any tile opens that tile at the
corresponding index, and pagination continues without re-sorting or dropping
the pinned launch order.

### Creator

The existing long-press action sheet gains one action:

- `Pin to profile` for an eligible unpinned video;
- `Unpin from profile` for a pinned video.

Pin inserts the video's coordinate at the front of Divine Mobile's managed
sequence. Unpin removes every managed tag for that exact coordinate without
reordering the remaining entries; this prevents a duplicate stored tag from
making the video appear pinned again immediately.

Success and failure use localized snackbars and explicit screen-reader
announcements. A failed or unconfirmed publish leaves the local visible order
unchanged. Pin and Unpin are explicit, idempotent commands rather than a toggle:
after re-reading the selected event, Pin is a no-op if membership already
exists, and Unpin is a no-op if it is already absent. A retry or uncertainty
check always re-reads and reconciles before deciding whether another publish is
necessary.

### Creator action states

| State after current evidence is reconciled | Action and result |
|---|---|
| Initial snapshot unresolved | Show `Checking pinned videos…`; Pin is disabled. Exact cached membership may show Unpin, but executing it still reconciles first. |
| Eligible, absent, managed count below 12 | Enable `Pin to profile`. |
| Stored member, active or overflow | Enable `Unpin from profile`. |
| Absent and managed count is 12 or more | Disable `Pin to profile`, explain the 12-video cap, and enable `Manage pinned videos`. Never evict silently. |
| Mutation pending | Disable duplicate mutation actions and announce the pending state. |
| At least one relay returns `OK true` | Adopt the accepted revision locally and announce success. Record partial acceptance without claiming durability. |
| Definite rejection or no participating network relay | Keep local order unchanged; offer Retry, which starts with a fresh settled read. |
| Publish timeout or lost acknowledgement leaves the outcome unknown | Keep local order unchanged; offer `Check again`, which re-reads and reconciles without blindly republishing. |

### Recovery management

The owner-only profile More menu exposes `Manage pinned videos` whenever the
selected event has managed coordinates. The cap state also links to it. This is
a full-screen recovery flow, not an arranger:

- list every de-duplicated managed coordinate in stored order, including
  overflow and unresolved entries;
- show a video preview only when the canonical event passes the same visibility
  policy as the grid. A hidden, deleted, blocked, expired, unplayable, or
  unresolved entry uses a neutral `Unavailable video` placeholder and exposes
  no thumbnail, title, author, or other filtered metadata;
- derive status with visibility first, then slot: visible candidates in `C` are
  shown; non-visible candidates in `C` use the unavailable-pin-slot status;
  visible overflow uses the outside-first-12 status; non-visible overflow uses
  the unavailable-overflow status;
- allow removal of any exact stored coordinate, even when no video resolves;
- provide no add or reorder controls.

Deleting a pinned video does not silently rewrite the pin list. Its stored
reference remains removable through this screen. This prevents 12 stale,
deleted, or hidden references from permanently locking the creator out.

This recovery screen is preferable to the two smaller-looking alternatives.
Automatically removing a pin during video deletion couples two relay writes and
creates partial-failure data loss. Counting only currently visible pins allows
the stored list to grow whenever resolution or policy hides entries and can
surface more than the cap when they return. Explicit removal keeps the cap
bounded without silently destroying open-Nostr data.

### Eligibility

Mobile offers Pin only when all of these are true:

- the viewer owns the profile;
- the video is authored by that profile;
- the source event is kind `34236`;
- it has a nonempty addressable `d` value.

Legacy or non-addressable videos simply omit the Pin action. Mobile preserves
foreign-authored and malformed list data as unrelated data but does not display
or manage it.

### Loading

Cached pins may render immediately, but mutation actions remain governed by the
state table above. Cached membership may inform display and an initial Unpin
label; executing any action still performs the required network-participating
reconciliation and preserves the original Pin or Unpin intent.

## Ordering and Cap Rules

Let `P` be the managed coordinates in stored tag order, `C` be its first 12
de-duplicated coordinates, and `V` be the already-filtered base-feed sequence.

1. De-duplicate `P`; first occurrence wins.
2. Take the first 12 coordinates as `C`, the active display candidates.
3. Canonicalize every coordinate in `C` across raw relay, cache, fallback, and
   base-feed candidates before applying visibility exactly once.
4. Emit each visible canonical candidate in `C` order. Emit nothing for a
   canonical hidden or unresolved candidate.
5. Append every item from `V` whose exact addressable coordinate is not in `C`
   and has not already been emitted, preserving `V` order. This prevents an
   older visible base/cache version from resurfacing when the canonical pinned
   version is hidden or unresolved.
6. Leave stored overflow coordinates after position 12 eligible to appear in
   their ordinary `V` position until they are promoted into `C`.
7. Keep transient uploads outside this published-video sequence and prefix them
   only in the owner's grid.

The cap counts every unique valid owner-authored coordinate in the stored list,
including references that are currently unavailable or hidden. This prevents a
temporarily invisible pin from allowing the stored list to grow without bound
and then reappear above the cap later.

For an imported list containing more than 12 managed coordinates:

- display from the first 12 candidates in stored order;
- preserve every stored tag and the opaque `content` value;
- allow Unpin for every coordinate through the recovery screen, whether or not
  its video is available;
- reject new Pin actions until the managed count is below 12;
- never truncate the list as a side effect of an unrelated save.

These rules distinguish stored membership from an active displayed pin. A
coordinate anywhere in `P` is a stored member and therefore counts toward the
cap and offers Unpin to the owner. Only a visible video resolved from the first
12 candidates is an active displayed pin: it moves to the front and receives
the pin badge, pin-rank semantics, and pinned position. A stored overflow video
that also appears through `V` stays in its ordinary feed position without the
badge or pinned semantics, while still offering Unpin to remove the preserved
overflow entry.

Removing an active member promotes the next stored overflow coordinate into
`C`. If that promoted coordinate resolves visibly, it moves from its ordinary
base-feed position into the last active-pin position. If it is unavailable or
hidden, it consumes the candidate position without leaving an empty cell.

Stored order is authoritative because list items have no individual pin
timestamps. A mobile Pin reliably moves that video to the front, but Mobile
cannot reconstruct a globally newest-first history for a list previously
written by Web or by multiple clients using different insertion rules.

## Nostr Representation

### Existing Divine convention

Use one current kind-`10001` replaceable event for each owner and store managed
videos as:

```text
["a", "34236:<author-pubkey>:<d-tag>"]
```

The full addressable coordinate survives a metadata replacement as long as the
author and `d` value remain unchanged. Event IDs and `stableId` are not suitable
stored identities for this feature.

Use a dedicated coordinate value type. It validates kind `34236`, requires the
canonical 64-character lowercase hexadecimal pubkey and a nonempty `d`, and
preserves the complete `d` value byte-for-byte, including case and colons.
Do not reuse `stableId`, `feedDedupKey`, or `canonicalProfileFeedVideoKey`;
those helpers omit authors or normalize data too aggressively for exact pin
identity.

### Standards boundary

[NIP-51](https://github.com/nostr-protocol/nips/blob/656cecc7c0a815b6a2b218d3b5d6f078b3f4dbab/51.md)
names kind `10001` **Pinned notes** and expects kind-1 `e` references. Divine's
kind-`34236` `a` tags are an extension already used by Divine Web.

[NIP-51](https://github.com/nostr-protocol/nips/blob/656cecc7c0a815b6a2b218d3b5d6f078b3f4dbab/51.md#L9-L13)
also recommends appending new list items chronologically. Mobile deliberately
inserts a new pin at the front to implement the product behavior above. This is
a SHOULD-level interoperability deviation and must be documented as such.

[NIP-01](https://github.com/nostr-protocol/nips/blob/656cecc7c0a815b6a2b218d3b5d6f078b3f4dbab/01.md#L78-L82)
defines `a` coordinates, while
[NIP-71](https://github.com/nostr-protocol/nips/blob/656cecc7c0a815b6a2b218d3b5d6f078b3f4dbab/71.md#L23-L32)
defines kind `34236` addressable short video.

### Lossless read-modify-write

Current `NostrClient.subscribe()` is not sufficient for mutation safety: it
returns before asynchronous relay setup finishes and exposes neither readiness
nor the participant set. Before this feature ships, the client must provide an
awaited combined initial-snapshot-and-live-stream primitive for network relays.
That primitive must:

- attach local buffering before sending any subscription request;
- report the exact network relays that accepted the request;
- settle the initial kind-`10001` snapshot only after EOSE from every reported
  participant; CLOSED, error, timeout, or no participants is inconclusive;
- deliver events arriving during settlement through the same winner pipeline;
- keep the live stream attached after returning the initial snapshot.

The snapshot and live stream must share one participant set. Calling current
`subscribe()` and then `queryEventsDetailed()` separately does not meet this
contract and leaves a reconnect/relay-set lost-update window.

Before Pin or Unpin, Mobile must:

- open that combined primitive for owner kind `10001`, without `limit: 1` and
  with network-only relay participation;
- refuse mutation when its initial snapshot reports timeout or no participants;
- require participation from at least one network relay; a DAO/cache relay may
  add a candidate event but must never satisfy this gate;
- select the deterministic winner across query results, buffered subscription
  events, cached candidates, and the complete last locally accepted revision;
- restart reconciliation if a subscription event becomes the winner before
  publish; never knowingly sign against a stale selected base;
- treat a genuinely empty, fully settled network result with no other
  candidate as an empty base with `tags: []` and `content: ""`;
- re-check that the current account pubkey still equals the profile owner
  immediately before publishing;
- apply the explicit Pin or Unpin command idempotently, checking membership
  before the cap;
- manage only valid kind-`34236` coordinates authored by the event owner;
- treat every exact duplicate of a managed coordinate as managed mutation data,
  removing all copies on Unpin while first occurrence wins for display;
- preserve every unrelated public tag exactly, including order and extra
  fields;
- preserve `content` byte-for-byte because it may contain encrypted private
  list items;
- update local visible state only after at least one relay returns `OK true`.

The repository constructs and validates the replacement and orchestrates its
publication. `NostrClient` and its configured signer—including Keycast—own
signing; the repository never receives private key material.

This read settles every network relay that accepted the request, not every
configured or globally relevant relay. A disconnected, silent, unrelated, or
unqueried relay may still hold a divergent event. `OK true` means a relay
accepted the write; it does not prove durable storage everywhere.

## Technical Design

```text
Profile UI
    ↓
ProfileFeedCubit
    ↓
ProfilePinsRepository + VideosRepository
    ↓
Nostr client and local cache
```

`ProfilePinsRepository` owns list parsing, cached snapshots, relay
revalidation/subscription, exact-coordinate validation, lossless event
construction, and publication orchestration. The configured Nostr signer owns
signing. UI code never constructs Nostr tags, and no private key material enters
the repository.

`ProfileFeedCubit` combines pin coordinates with the existing profile feed and
exposes one displayed sequence, pin membership, loading state, and mutation
outcomes. Every emit path and sequence comparison must use one centralized
base-to-displayed derivation; otherwise a cache, relay, enrichment, pagination,
or filter update can silently replace the pinned sequence with the base feed.

Keep the raw base feed, normally filtered base feed, and pin-augmented displayed
sequence separate. Pagination counts use the normally filtered base feed. The
Nostr `until` cursor uses the minimum `nostrCreatedAt` in `_unfilteredVideos`,
not `createdAt` and not the pin-augmented displayed sequence.

The published sequence actually rendered by the grid is authoritative for tap
index, prefetch, and the fullscreen launch snapshot. The tap handler must not
substitute a different Cubit list after grid-level upload/relay de-duplication.
Thread the exact addressable coordinate and a sequence-generation identity
through the fullscreen route and `FullscreenFeedBloc`.

Fullscreen freezes that launch snapshot's relative order for the session.
Pagination appends unseen base-feed coordinates without re-sorting the launch
prefix, and canonical metadata replacements update an existing coordinate in
place. Pin revalidation while fullscreen is open does not reorder the session;
the new pin order applies the next time the grid or fullscreen flow opens.
Target presence in a later live page is never sufficient reason to replace the
snapshot. The current index URL remains a backward-compatible, best-effort
restoration path; an in-app grid launch carries the exact coordinate in route
state so it cannot open the wrong video.

Canonical replaceable-event selection must use `created_at` descending and
event ID ascending for ties. The current addressable-video resolver must select
the raw canonical winner before applying visibility filters; arrival order is
not a valid winner rule. Track raw-resolved coordinates separately from visible
results so a canonical-but-hidden event is not misclassified as missing and
reintroduced from Funnelcake fallback. Equivalently, canonicalize candidates
across sources before applying visibility exactly once. The same coordinate
suppression must cover stale copies already present in the base feed, not only
Funnelcake fallback.

The exact cache backend, package boundary, and same-event enrichment merge are
engineering choices, not product facts. They should follow the repository's
existing UI → BLoC → Repository → Client architecture and CI package rules.

## Failure and Concurrency

- Cached pins may render immediately and then revalidate.
- Missing payloads do not delete stored references.
- A stale asynchronous resolution result must not overwrite a newer snapshot.
- The awaited combined snapshot/live primitive prevents a replacement from
  landing in a query/subscription handoff gap; current `subscribe()` cannot.
- Filter-policy changes must re-resolve omitted pins or retain canonical raw
  winners below the visibility layer.
- A local mutation queue serializes one process but cannot prevent two devices
  from publishing competing replacements.
- Keep the complete last locally accepted event as a base candidate. A relay
  may acknowledge from a queue and still return the older revision to an
  immediate follow-up read; a timestamp floor alone would preserve ordering but
  still lose the prior mutation's tags or content.
- Same-process replacement timestamps must advance beyond both the selected
  base and the last locally issued/accepted timestamp, without exceeding relay
  future-skew policy.
- Partial relay acceptance remains partial; Mobile does not claim durability or
  automatic repair across rejecting relays.
- An unknown publish outcome is reconciled by reading, never by blind retry.

## Accessibility and Localization

Use the filled Phosphor `PushPin` geometry already used by Divine Web, exported
as a bundled Mobile SVG and mapped through a new `DivineIconName`. The badge is
a 16 dp `VineTheme.primaryText` glyph inside a 24 dp circular
`VineTheme.scrim65` background, inset 4 dp from `AlignmentDirectional.topEnd`.
It must maintain at least 3:1 non-text contrast over thumbnail imagery and move
to top-left in RTL layouts. Exclude the decorative glyph from semantics and add
an enum-to-asset test plus widget and golden coverage. These static tokens are
appropriate because the badge is fixed media chrome; the recovery screen must
use adaptive `context.vineColors` surfaces and content in both light and dark
appearances.

Long-press is not the only invocation. Every eligible owner tile exposes a
localized `CustomSemanticsAction` for Pin or Unpin, and the recovery rows expose
Remove. Use stable exact-coordinate keys so relay revalidation can preserve
focus. If revalidation changes the visible pinned order, announce `Pinned
videos updated.` once rather than announcing every BLoC transition.

An active tile extends its existing video label with one complete localized
sentence:

```text
{videoLabel}. Pinned video {pinRank} of {visiblePinCount}. Profile grid
position {gridPosition}.
```

`pinRank` is rank among visible active pins, not stored position;
`gridPosition` includes any owner-only upload placeholders that visually precede
the tile. An unresolved recovery row is labeled `Unavailable pinned video,
stored position {storedPosition}. Remove from pinned videos.`

Use these English source strings as complete localization units. Variables use
ARB placeholders; no translated fragments are assembled.

| State or control | English source string |
|---|---|
| Tile action | `Pin to profile` / `Unpin from profile` |
| Recovery entry | `Manage pinned videos` |
| Recovery status | `Shown in your pinned videos` / `Uses a pin slot but isn't currently visible` / `Stored outside your first 12 pin slots` / `Unavailable video stored outside your first 12 pin slots` |
| Recovery action | `Remove from pinned videos` |
| Initial state | `Checking pinned videos…` |
| Cap | `You can pin up to 12 videos.` |
| Pending | `Pinning video…` / `Removing pinned video…` |
| Success | `Pinned to your profile.` / `Removed from your pinned videos.` |
| Definite failure | `Couldn't pin this video. Try again.` / `Couldn't remove this pinned video. Try again.` |
| Unknown outcome | `We couldn't confirm that change. Check again.` |
| Follow-up actions | `Retry` / `Check again` |
| Revalidation | `Pinned videos updated.` |

Announce pending, success, failure, unknown outcome, and material revalidation
with `SemanticsService.sendAnnouncement` in addition to any snackbar. Use
`Directionality.of(context)` and `View.of(context)` as required by the current
accessibility rule.

## Acceptance Tests

The report recommends coverage for:

- stored pin order and first-occurrence de-duplication;
- first-12 display, imported oversize preservation, and the distinct overflow
  membership/action/badge behavior;
- overflow promotion after an active member is removed;
- 12 unresolved or hidden references remaining removable through recovery;
- hidden and blocked recovery rows exposing no filtered video metadata, with
  distinct active-slot and overflow status;
- deletion of a pinned video leaving a recoverable stored reference;
- owner-only eligibility and foreign-tag preservation;
- metadata replacement retaining a pin by coordinate;
- case-distinct and colon-containing `d` values, plus identical `d` values from
  different authors and uppercase-pubkey coordinates preserved as unrelated;
- equal-timestamp replaceable-event tie handling;
- canonical raw winner selection before filtering;
- hidden canonical coordinates suppressing stale visible base-feed copies;
- cache-first rendering followed by relay revalidation;
- participant-aware combined snapshot/live buffering of an intervening
  replacement, including delayed subscription setup and relay-set changes;
- a newer live replacement arriving after query settlement but before publish
  forcing re-reconciliation;
- stale resolution and subscription races;
- every Cubit update path retaining the centralized pin overlay;
- base-feed pagination unaffected by off-page pins and using the oldest raw
  `nostrCreatedAt` cursor;
- grid, prefetch, and fullscreen using the identical launch sequence;
- fullscreen preserving its launch prefix during pagination, metadata updates,
  revalidation, and target-already-present live pages;
- canonical-but-hidden coordinates not being reintroduced by fallback;
- a fully settled empty network result creating the first list event;
- timeout, no participating network relay, and inconclusive closure refusing
  mutation without treating the list as empty;
- account switching before publish refusing the old profile's mutation;
- explicit Pin/Unpin no-ops and unknown-outcome reconciliation without blind
  republish;
- an immediate second mutation preserving the complete last accepted revision;
- loading, cap, pending, partial-acceptance, failure, unknown-outcome, and
  legacy-video action states;
- accessible Pin/Unpin/Remove actions, focus preservation, badge contrast,
  semantics, announcements, localized copy, and RTL placement.

## Implementation and Release Gates

- Before release, use a dedicated test account to publish and read back a
  synthetic kind-`10001` video-pin event through every target Divine
  environment and normal Mobile relay path. Verify the selected event, tags,
  and opaque `content`, then publish an empty replacement as cleanup while
  assuming old signed revisions may remain on some relays. Minority-relay
  success alone does not prove the normal read path will surface pins.
- Mirror every new ARB key into all locales or record it through the repository's
  explicit untranslated-debt mechanism, regenerate localization outputs, and
  run `flutter test test/l10n/arb_consistency_test.dart` from `mobile/`. Wire
  every key through `context.l10n` in the same change and run the orphaned-ARB
  floor check.
- Run affected widget, BLoC, repository, route, accessibility, and icon tests,
  then `flutter analyze` from `mobile/`.
- Because `videos_repository` behavior changes, run its full coverage workflow
  and confirm the package requirement remains satisfied.
- Run `mobile/scripts/golden.sh verify` for the badge, recovery screen, action
  states, light and dark appearances, RTL layout, and large accessibility text.
- If implementation creates a package, add its analyzer config, package CI
  workflow, measured coverage-floor entry, and Flutter-boundary compliance.
- A new bundled SVG requires an App Store/Play Store build; do not plan to ship
  the icon solely through Shorebird.

## Cross-Client Follow-Up

Mobile can ship this design without silently changing Divine Web, but the
report records existing Web differences and defects:

- Web caps additions at three while Mobile recommends 12.
- Web appends new pins while Mobile prepends.
- Web displays foreign-authored coordinates while Mobile omits them.
- Web Pin/Unpin currently replaces opaque `content` with an empty string.
- Web kind-10001 reads use `limit: 1` without the NIP-01 event-ID tie-break.

Those are separate cross-repo corrections. They should not be hidden inside a
Mobile change, but they matter if Divine wants identical behavior on every
client.

## Out of Scope

- Manual drag ordering or an arranger screen.
- A separate pinned section or section heading.
- Pinning another account's videos from Mobile.
- Reordering unpinned profile videos.
- Multiple named pin sets.
- Changing video metadata or deletion behavior.
- Implementing the Divine Web follow-up described above.
