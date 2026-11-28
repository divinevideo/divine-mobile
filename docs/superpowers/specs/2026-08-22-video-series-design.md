# Video Series — Design

Date: 2026-08-22
Status: Revised design, pending review
Revised 2026-11-27: the series chip opens the series at the part it is on,
and reads `Series name · Ep 3 of 10`, since the app calls each part an
episode.

## Problem

A creator has a story that does not fit in one 6-second loop. Today they post
part 1, part 2, and part 3 as unrelated videos. A viewer who meets part 3 in a
feed cannot tell that earlier parts exist or watch the story in order.

The first release needs one complete loop: a creator publishes a new video into
a named series, and a viewer can identify the part and open the series there.

## Scope

Version 1 includes:

- Creating or selecting one of the creator's series while publishing a video.
- Appending each successfully published video to that series.
- Showing `Series name · Ep 3 of 10` on a series video.
- Opening the existing curated-list feed at that part from that label.
- Showing part numbers in the existing curated-list grid.
- Swiping through the ordered parts with the existing fullscreen list player.

Version 1 does not include:

- Assigning already-published videos to a series.
- Removing or reordering parts.
- Splitting a long recording into several posts or batch publishing.
- Encoding series order as a NIP-22 reply chain.
- A dedicated series discovery surface, profile section, or series card.
- Collaborative series or series containing another creator's videos.
- A new Nostr event kind.

These are separate product problems. They should be reconsidered after the
publish-and-watch loop has real usage rather than built speculatively.

## Protocol and data model

### Series list

A series is a public kind-30005 curated video list with manual play order. It
uses the existing list fields and adds one marker:

```text
["series", "true"]
```

Each part is an existing ordered `a` tag containing the part's kind-34236
coordinate. The list order is the only source of truth for part number and
total count.

Series created by Divine are non-collaborative and public. When reading a
series, the app only accepts kind-34236 coordinates whose embedded author
matches the list author. Malformed or foreign-author entries are ignored.

### Video reference

Each newly published series video carries a marked reference to the list:

```text
["a", "30005:<creator_pubkey>:<series_d_tag>", "", "series"]
```

The `series` marker distinguishes this reference from inspired-by, reply, and
other `a` tags already used on video events. The creator pubkey in the
coordinate must match the video author.

There is deliberately no `part` tag. Rendering `Part 3 of 10` already requires
the list for its name and total, so a second copy of the index only creates
stale state. There are also no reply tags: a reply chain would duplicate order,
change comment semantics, and require filtering work unrelated to the core
feature.

If the referenced list is missing, is not marked as a series, does not contain
the video's addressable coordinate, or has a different owner, the video is
treated as an ordinary video and no series UI is shown.

## Architecture

### Models and conversion

- Add `isSeries` to `CuratedList` and persist it through JSON serialization,
  `copyWith`, equality, and `CuratedListConverter` event conversion.
- Add a nullable `seriesCoordinate` to `VideoEvent`. Parse only an `a` tag with
  the `series` marker and persist the value through JSON serialization and
  `copyWith` so cached REST and relay videos behave the same.
- Preserve the full coordinate everywhere. Nostr identifiers are never
  truncated.

### Existing list mutation path

Keep kind-30005 writes in `CuratedListService`, where list creation, local
persistence, serialized mutation, relay publication, and retry state already
live. Version 1 adds only:

- `createSeries(name)`, which creates a public, non-collaborative manual list
  with the series marker.
- Appending a published video's addressable coordinate through the existing
  list-mutation path.

Do not move all list CRUD into `curated_list_repository` as part of this
feature. That package is currently a read-oriented bridge, and completing the
larger Riverpod-to-repository migration is unrelated scope.

### Series lookup

Add one exact-coordinate fetch to `CuratedListRepository`, backed by its
existing `NostrClient`: query kind 30005 by author and `d` tag, apply
replaceable-event ordering, validate `isSeries`, and cache the result by full
coordinate. This supports videos encountered anywhere without a broad `#a`
scan.

#### Cache freshness contract

A series list is remote-derived cacheable data, so the exact-coordinate lookup
uses the existing `cache_sync` package rather than introducing a feature-local
cache. A session-long entry would freeze a replaceable event.
A viewer who cached parts 1-3 would keep reading `of 3` for the rest of the
session, and a newly published part 4 would fail membership validation and show
no series UI at all — the feature silently disappearing on exactly the video
that motivated it. The cache is therefore bounded:

- **`cache_sync` entries use a 60-second TTL.** The stable cache key contains
  the full list owner pubkey and d-tag. A read older than the TTL refetches
  before answering. 60 seconds is chosen so a creator publishing consecutive
  parts sees the count move without a restart, while a viewer scrolling a feed
  of one series' parts still gets one fetch, not one per video.
- **A negative membership result is never served from cache.** If the cached
  list does not contain the video's coordinate, the repository awaits
  `CacheSync.invalidate(key)` and performs one exact-coordinate relay fetch
  before concluding that the video is not a member. Only that fresh miss
  suppresses the series UI. This is the rule that keeps a just-published part
  from rendering as an ordinary video; everything else here is an optimization,
  this one is correctness.
- **Local mutation invalidation is awaited.** After `createSeries` or the append
  path commits a local mutation, it awaits `CacheSync.invalidate(key)` before
  its future completes. Callers therefore cannot observe the old entry after an
  awaited mutation. `CacheSync.invalidate` is Drift-backed and asynchronous;
  read-your-write ordering, not a literally synchronous eviction API, is the
  required guarantee.

Version 1 deliberately adds no second live kind-30005 subscription. The
existing subscription is owned by `CuratedListService` and covers the signed-in
user's lists; coupling it into the read-oriented repository, or adding another
subscription there, would create ownership and lifecycle work that the TTL,
awaited local invalidation, and fresh-on-negative rule do not require.

Remote total-count staleness is bounded to 60 seconds and membership staleness
to one forced relay fetch. `Part 3 of 9` briefly reading `of 8` is acceptable;
`no series UI` for a valid part after a successful fresh fetch is not.

`VideoSeriesCubit` is the only new state-management unit. Given a `VideoEvent`,
it:

1. Returns no series state when `seriesCoordinate` is absent or malformed.
2. Loads the exact list through `CuratedListRepository`.
3. Validates matching ownership and membership.
4. Exposes the list and the video's zero-based authoritative list position.

There is no separate `SeriesBloc`; the existing curated-list providers and
fullscreen player already own list loading and playback.

### Publish flow

The metadata screen adds an optional series picker containing the creator's
series and `New series…`. Creating a series asks only for a name. The selected
full series coordinate is stored in the publish draft/background-upload state
so retries do not lose it.

At publish time:

1. If a new series was requested, create its empty kind-30005 event first, and
   do not begin the video publish until a relay has accepted it. A creation
   failure keeps the user on the metadata screen with retry and cancel actions.

   Generic `CuratedListService.createList()` does **not** provide this proof and
   its offline behavior must remain unchanged. It deliberately keeps a local
   list when no relay is reachable: `_createList` awaits
   `_publishListToNostr(current, confirmed: true)` but discards the returned
   boolean, then returns the retained list. Private lists publish too, with
   sealed items; `isPublic` is a series visibility requirement, not a condition
   that makes publication happen.

   `createSeries` therefore has a series-specific confirmed-creation contract.
   It creates a public, non-collaborative manual list with a fresh coordinate.
   It saves the list locally only after `acceptedByAny` is true and returns
   `SeriesCreated` once the local save succeeds. An absent account returns
   `SeriesCreationUnauthenticated`. A signing failure or unconfirmed send returns
   `SeriesCreationRejected` without saving a local series. A local failure or
   account change returns `SeriesCreationFailed`. A relay-confirmed list that
   could not be saved can be recovered by syncing with relays. The publish flow
   continues to step 2 only for `SeriesCreated`. A failed result keeps the
   metadata state. The publish flow must reconcile an indeterminate or confirmed
   send before offering another attempt for the same request. If it resends
   an indeterminate event, it reuses the original signed event and coordinate.
2. Sign and publish the video with the marked series `a` tag.
3. After the video publish succeeds, append its stable kind-34236 coordinate to
   the list through `CuratedListService`.

The operations are intentionally not described as atomic; Nostr cannot provide
that guarantee. The existing list mutation path persists a failed relay update
locally and marks it for republish. A failed video publish does not append a
part, and its background retry retains the series selection.

Generic `Add to list` UI excludes series in version 1 because adding a video to
only the list would not add the required marked tag to an already-published
video.

### UI and routing

`SeriesChip` is app-level UI built from `divine_ui` primitives because its copy
is localized. It renders only from a loaded `VideoSeriesCubit` state and reads:

```text
Series name · Ep 3 of 10
```

Tapping it opens the existing author/list route and starts
`CuratedListFeedScreen` playback at the part's position in the list. Inside
the player of that same series the chip is not shown, since it would open the
series again. That screen cannot do this today,
so version 1 extends it — see [Playback entry contract](#playback-entry-contract).
The series mode of that screen adds part numbers to grid items; playback remains
`PooledFullscreenVideoFeedScreen`. Swipe and auto-advance behavior remain
unchanged after the resolved videos have been restored to authoritative list
order.

#### Ordered resolution contract

`videoEventsByIdsProvider` does not preserve its input order today: it appends
cached event ids, then cached addressable coordinates, then relay results in
arrival order, yielding again as each event arrives. The grid and fullscreen
player render that emitted order verbatim. Reusing it without an ordering step
would make `play`, displayed part numbers, and swipe order depend on cache and
relay timing rather than the series list.

Every provider emission used for a curated list must therefore be projected
back into the order of the requested `videoIds`. Matching uses the full event id
for ordinary events and the full `34236:<pubkey>:<d-tag>` coordinate for
addressable videos. Missing or blocked videos are omitted without collapsing
the authoritative position: UI part numbers come from the matched coordinate's
zero-based position in `videoIds`, plus one, while the total remains the count
of valid same-author coordinates in the series list. The grid and player receive
the same ordered resolved list, so a late arrival inserts at its list position
rather than at the end.

#### Playback entry contract

`CuratedListFeedScreen` currently opens in grid mode and has no way to start in
playback: its constructor takes `listId`, `listName`, `videoIds` and
`authorPubkey` only, and `_activeVideoIndex` is initialized to `null`, which is
exactly what selects the grid
(`mobile/lib/screens/curated_list_feed_screen.dart:59-64`, `82`, `95`). The
acceptance criterion "tapping the chip opens the ordered series at that part"
therefore requires a screen change, not just navigation.

Version 1 adds:

- **`final int? initialListIndex;`** to `CuratedListFeedScreen`, defaulting to
  `null` so every existing call site keeps today's grid-first behavior
  unchanged.
- **The requested authoritative position stays pending while videos load.** It
  is not copied directly into `_activeVideoIndex`, because missing videos make
  an index in the resolved player list different from a position in the source
  list. Once the video at `videoIds[initialListIndex]` resolves, the screen maps
  its full id or coordinate to the corresponding index in the ordered resolved
  list and enters playback there. If that particular video cannot be loaded,
  the screen stays on the grid rather than silently starting a later part.
  Loading and error states keep the normal app bar and route-level back
  affordance. The active-player field stays mutable, so backing out of playback
  still lands on the grid rather than leaving the screen.
- **A malformed, negative, or out-of-range value stays on the grid.** The
  existing player guard is not reused: today it renders a chrome-less
  `curatedListVideoNotAvailable` dead end for a high index and does not reject a
  negative index. Version 1 validates before entering video mode instead.
- **`RoutePaths` owns the query parameter.** Its author/list path builder gains
  an optional `play` argument and emits the query parameter. The router parses
  it with `int.tryParse`, and `CuratedListByAuthorScreen` only forwards the
  nullable parsed value; screen `pathFor` methods remain thin `RoutePaths`
  delegates.
- **`SeriesChip` navigates through the typed author/list route with `play` set
  to the part's position in the list.** That position counts every list entry,
  so it can differ from the part number when the list holds entries that are
  not parts. This keeps the entry point a plain deep link, so a shared series
  URL can also open at a part.

The existing list route, deep link, sharing, loading, and missing-video behavior
are otherwise reused. Version 1 adds no previous/next overlay buttons and no new series
screen. Existing list discovery may show a series as a normal public list; no
special discovery treatment is added.

## User flows

### Publish into a new series

Metadata → `Part of a series` → `New series…` → enter a name → publish. The app
creates the empty series, publishes the tagged video, then appends the video's
coordinate as part 1.

### Publish the next part

Metadata → `Part of a series` → choose an existing series → publish. After the
video succeeds, its coordinate is appended and its position is derived from the
updated list.

### Watch

A viewer meets part 3 in any feed. Once the referenced list resolves, the chip
reads `Series name · Ep 3 of 10`. Tapping it opens the existing list player at
part 3; the viewer swipes back to earlier parts, or on through the rest.

## Failure handling

| Failure | Behavior |
|---|---|
| Series creation is unauthenticated, unconfirmed, or fails locally | Keep the metadata state. Reconcile a send that may have reached a relay before retrying the same request. A series without relay confirmation from the send is never saved by creation. |
| Video publish fails | Do not append the part. The background retry retains the selected series coordinate. |
| Video succeeds but list relay publish fails | Keep the locally appended part and the existing pending-republish state; remote viewers see no chip until the list update reaches a relay. |
| Series list is missing or deleted | Render no chip. The video remains an ordinary playable video. |
| Video tag and list membership disagree | The list wins. Render no chip until the list contains the video's coordinate. |
| A listed video cannot be loaded | Omit it from the grid/player without rewriting the list. Part numbers still come from the authoritative list order and may contain a gap. |

## Testing

- `models`: `CuratedList.isSeries` and `VideoEvent.seriesCoordinate` JSON,
  `copyWith`, equality, tag parsing, and marked-versus-unmarked `a` tags.
- `curated_list_repository`: series marker round-trip, exact-coordinate fetch,
  replaceable-event winner selection, validation, and `cache_sync` caching.
  Cache freshness specifically: a read inside the TTL does not refetch, a read
  past it does, a cached negative membership invalidates and refetches before
  suppressing the UI, and an awaited local mutation does not complete until
  invalidation completes.
- `CuratedListService`: `createSeries` invariants and append behavior using a
  full kind-34236 coordinate, including its explicit success,
  unauthenticated, relay-rejected, and local-failure outcomes, including restart
  during an unconfirmed send, recovery of an accepted series, and ordinary
  `createList` keeping a list when no relay accepts it.
- Publish: selected series is retained in the draft, the marked tag is signed,
  append happens only after successful video publication, and failed list
  publication retains retry state.
- `VideoSeriesCubit`: absent/malformed coordinate, missing list, wrong owner,
  missing membership, and valid index.
- Widget: chip copy, no chip for ordinary or invalid videos, numbered series
  grid, and chip navigation starts playback at that part. Cover mixed cache/relay
  arrival, late insertion, and missing-video gaps to prove that grid numbering,
  playback start, and swipe order follow `videoIds`; also cover that
  `initialListIndex: null` still opens the grid, malformed/negative/out-of-range
  values stay on the grid, an unavailable requested part does not substitute a
  later part, loading retains a back affordance, and backing out of seeded
  playback lands on the grid.
- Localization: mirror new keys into every `app_*.arb` locale or record known
  untranslated debt, then run the ARB consistency test.
- Visual verification: run the existing golden verification workflow and
  update only goldens affected by the chip or numbered grid.

## Acceptance criteria

- A creator can create or select a series while publishing a new video.
- A successfully published part appears once at the end of the series list.
- A series video encountered outside the series resolves to the correct name,
  position, and total without scanning all lists.
- Tapping the chip opens the ordered series at that part.
- Ordinary videos and inconsistent or unavailable series data show no series
  UI and continue to play normally.
- No reply/comment behavior, existing-video republish flow, editor duration
  rules, or batch uploader is changed by version 1.
