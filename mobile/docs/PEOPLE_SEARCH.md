# People search: data sources, degradation, and UI contract

This document is the canonical reference for how user-profile search
works in the mobile app. It is the partial implementation answer to
the parent epic's "explicit data-source strategy" requirement
(#3801, #3627) and pins the contract that the bloc and UI rely on.

If you change behavior in `ProfileRepository.searchUsersProgressive`,
`UserSearchBloc`, or `PeopleSection`, update this file at the same
time.

## Layered flow

```
Explore / SearchResultsAppBar (UI)
  └── UserSearchQueryChanged event
        ↓
UserSearchBloc                              mobile/lib/blocs/user_search/
  • debounceRestartable transformer
  • outer .timeout(userSearchOuterTimeout)  mobile/lib/constants/search_constants.dart
  • on TimeoutException → promote pending sources to failed(timeout),
    emit `success` with `sourceOutcomes` populated
  • on Exception → Reportable wrap + `failure` state
  • per-yield: forward each newly-terminal source to
    FeedPerformanceTracker.trackSearchSource
  • with a ranking loader: until Funnelcake answers, rows already shown keep
    their places and new ones join below them; once it answers, or the
    search completes, the whole list takes the repository's order once.
    People you follow or have messaged move up, but never past an exact
    match (#8578); the username owner leads
  • the loader drops accounts hidden from feeds (blocked or muted by you,
    or blocking or muting you); the viewer stays listed on the Search page
        ↓
ProfileRepository.searchUsersProgressive    mobile/packages/profile_repository/
  Owner (offset==0, username-shaped query, Funnelcake available):
                       name server /.well-known/nostr.json?name=, run beside
                       phases 1-2; pinned only if REST search lists the owner
  Phase 1 (offset==0): UserProfilesDao.searchProfilesByIdentity
                       bounded SQLite identity query (name, display name,
                       nip05, whole pubkey; bio excluded), npub decoded to hex
  Phase 2:             funnelcake.searchProfiles REST, no explicit timeout
  Phase 3 (offset==0): nostrClient.queryUsers    NIP-50 WS, 4.5s relay budget + 5s guard
  Each phase records a SearchSourceStatus in the result envelope.
  Final yield: _enrichFromCache + _applyFilter (sortBy=relevance: the
               REST page in Funnelcake's order, then local-only matches by
               exact > prefix > word > substring; follow boost up to the
               next exact match. sortBy=followers: relevance tiers, then
               followers/videos, follow boost behind exact matches; block
               filter either way); envelope carries nextRestOffset/restHasMore
        ↓
NostrClient.queryUsers                      mobile/packages/nostr_client/
  • tempRelays = [relay.nostr.band, search.nos.today, nostr.wine]
```

## Matching and profile revisions

The app uses progressive people search with server sorting (`sortBy` is set).
That path matches visible identity: name, display name, NIP-05, and the whole
public key (including a decoded npub query). A query in a Divine username form
(`@alice`, `alice@divine.video`, `alice.divine.video`) is compared as the bare
username, and a root NIP-05 (`_@alice.divine.video`) names `alice`, as
Funnelcake reads both. Bio-only matches from REST or NIP-50 are excluded even
when they are the only server results. This keeps broader server search from
filling people results with accounts whose visible identity does not match.
Other callers of `SearchUtils.matchProfile` can still use that helper's broader
bio matching. Callers without `sortBy` retain their configured filter, or the
display-name fallback when none is set.

### Order of results

The search screen and people pickers (`UserSearchBloc`) ask Funnelcake for
`sort_by=relevance`. Funnelcake orders those results by one score: points for
how literally a profile matches plus its activity (followers, videos, loops, a
profile picture and recent posts). A better match outweighs a small difference
in activity, but a much more active near match can lead an exact match with
nothing behind it. Funnelcake also puts the owner of a Divine username searched
for first. The repository keeps that server order for the REST rows that pass
the matching above; profiles only the local cache or NIP-50 found come after
them, ordered by the app's relevance tiers (exact > prefix > word > substring),
as does everything before Funnelcake answers.

That matching is narrower than Funnelcake's in two places. Funnelcake's
letter-swap matches (a search for `alcie` finding `alice`) are dropped. And when
the app's own name-server lookup fails, an owner whose name, display name and
NIP-05 do not contain the username is dropped too, because nothing in the REST
response says which row the server pinned.

The follow boost and the bloc's promotion of people you follow or have messaged
move such an account up within the server's order, but never past an exact
match: each run of profiles between two exact matches lists its known ones
first. So three followed partial matches cannot push an exact account out of
the three-row preview (#8578), while the server still decides where that exact
match stands against unknown profiles.

With a ranking loader the bloc keeps rows already shown in place until
Funnelcake answers, then moves the whole list into the repository's order. The
profiles Funnelcake returned move once and then keep their places; a row only
the local cache found can move again when NIP-50 adds a better match ahead of
it.

A `sort_by=followers` search, which other callers still use, keeps the app's
relevance tiers first and orders each tier by the REST follower and video
counts, with the follow boost behind exact matches.

### Username owner

When the first-page query names a Divine username (`alice`, `@alice`,
`alice@divine.video`, `_@alice.divine.video` or `alice.divine.video`; not a
phrase, another domain or a complete npub), the repository asks the name
server's NIP-05 directory (`/.well-known/nostr.json?name=`) who holds it while
the local and REST phases run. That read is exact, active-only and cached for 60
seconds. The availability endpoint `/api/username/check` is not used: for a free
name it runs the username-judgment check, whose per-minute budget is shared with
claims, so search traffic would spend what sign-ups need.

The name server keeps a username active after its account is banned,
suspended, deactivated, vanished or made private, and people search hides those
accounts. So the owner is pinned only when Funnelcake's people search lists it:
either on the REST page already fetched, or in a second search for its Divine
NIP-05 (`alice.divine.video`). The profile comes from that REST result and is
reconciled with any listed copy by the same revision rule as the REST page, so
fields the server cleared stay cleared; no cache is written for it. Without
Funnelcake there is no lookup at all.

A pinned owner joins the REST yield and leads every yield from there, even when
its visible name does not match the query, and the envelope reports it as
`usernameOwnerPubkey`. The bloc keeps it first, including ahead of rows an
earlier yield already showed. Blocked owners stay dropped. A free name, a failed or
cancelled lookup, either step taking longer than 3 seconds, or an owner search
does not list leaves the results as they were. Video-only searches and later
pages skip the lookup.

A profile publishing `_@alice.divine.video` does not count as an exact match for
`alice` on that basis: anyone can publish that identifier, and only the account
the name server resolves it to is the owner. The handle counts through the pin
alone.

The search index cannot be relied on for this. Funnelcake ranks a token match
on a profile's name above a prefix match on its NIP-05, so for `alice` a
hundred profiles named `alice` fill the result window before the account whose
display name is something else but who owns `alice.divine.video`.

Two side effects to know:

- Every username-shaped query reaches the name server, whose worker logs each
  request URL, so search terms appear in those logs.
- `nameServerBaseUrl` is production for every non-local environment. On staging
  the owner is still pinned only if staging's own people search lists that
  pubkey.

Reconcile each REST profile before matching. A cached profile wins only with a
canonical event ID and an event timestamp strictly newer than the server's
known timestamp, and keeps the server's follower and video counts, which are
not part of the profile event. Equal or missing server timestamps select the
server copy; synthetic REST and bundled seed IDs cannot establish an event
revision. Preserve the selected server fields through enrichment, including
cleared names and media, then apply identity matching again. A renamed account
can therefore disappear from a query for its old name.

Pagination uses the raw REST response size, not the number of matching profiles.
An empty or short matching page may still have later results. Appended pages
skip accounts already shown, because the first page also merges cache and
NIP-50 hits. The user picker loads the next page near the end of its list and
offers Show more whenever another page exists.

## Source consultation order

The repository consults sources in a fixed, sequential order:

1. **localCache** — SQLite profile cache. Instant. Consulted only on
   the first page (`offset == 0`).
2. **funnelcakeApi** — Funnelcake REST `/api/profiles/search`. Fast.
   Consulted on every page. Skipped (`SearchSourceSkipped`) when the
   client is configured without a base URL.
3. **nip50Relay** — Federated NIP-50 search across three hardcoded
   relays. Consulted only on the first page (`offset == 0`). The SDK
   relay query has a 4.5 s budget and returns partial results when that
   budget expires; the repository keeps a 5 s guard for setup stalls
   before the SDK budget starts.

After each phase that produced new profiles, the repository yields a
`ProgressiveSearchResult` carrying:

- the accumulated deduplicated profile list
- the running `Map<SearchSource, SearchSourceStatus>`
- `isComplete: false` for intermediate yields, `true` for the final

A query with no matches still gets a final yield with
`profiles: []`, `isComplete: true`, and per-source outcomes — so the
bloc can always distinguish "true empty" from "everything failed".

## Source statuses

`SearchSourceStatus` is sealed:

| status | meaning | latency? |
|---|---|---|
| `SearchSourcePending` | Source has not yet reported. Internal/initial state, normally not visible in a terminal envelope. | — |
| `SearchSourceSkipped` | Source was intentionally not consulted (`offset > 0` for local/NIP-50, or Funnelcake unconfigured). | — |
| `SearchSourceSuccess` | Source returned successfully. Carries `resultCount` (new distinct profiles this source contributed to the accumulated result set) and `latencyMs`. | yes |
| `SearchSourceFailed` | Source threw / timed out. Carries `SearchSourceFailureReason` (`timeout` / `network` / `other`) and `latencyMs`. | yes |

The bloc never re-derives or invents source statuses — it forwards
the repository's view, except when the outer 20 s timeout fires (see
below).

## Outer-timeout contract

`UserSearchBloc` wraps the entire progressive stream in
`searchTimeout`, defaulting to `userSearchOuterTimeout` (20 s). When
it fires:

1. The bloc takes the latest snapshot of `state.sourceOutcomes`.
2. For each source still in `SearchSourcePending` (or absent from the
   snapshot defensively), it writes
   `SearchSourceFailed(reason: timeout, latencyMs: <outer timeout>)`.
3. Sources that already reported a terminal status keep that status.
4. The bloc emits `UserSearchStatus.success` with the updated map.

This means after an outer timeout, `state.isDegradedEmpty` is `true`
iff `state.results` is empty — which is the case the UI cares about.

## `isDegradedEmpty` getter

```dart
bool get isDegradedEmpty =>
    results.isEmpty &&
    sourceOutcomes.values.any((s) => s is SearchSourceFailed);
```

True iff (1) we have no profiles to show, AND (2) at least one source
reported failure. This is the single switch the UI uses to decide
between "true empty" (show empty-state with copy) and "degraded
empty" (show error-with-retry).

## UI contract (`PeopleSection`)

Branch order in `_PeopleContent.build`:

1. `status == initial || (status == loading && results.isEmpty)` →
   `_PeopleSkeletonLoader`
2. `status == failure || isDegradedEmpty` →
   `SearchSectionErrorState` (retry button)
3. `results.isEmpty && showAll` → `SearchSectionEmptyState`
4. `results.isEmpty && !showAll` → hidden section
5. otherwise → render the list

Outer `PeopleSection.build` also hides the entire section in the All-
tab preview when the result is truly empty
(`!showAll && status == success && results.isEmpty && !isDegradedEmpty`).
Degraded-empty intentionally bypasses the hide so the user can retry
even from the All tab. This is the #3791 fix.

## Instrumentation

`FeedPerformanceTracker.trackSearchSource(SearchSource, SearchSourceStatus)`
fires exactly once per source per query, when the source transitions
from pending into a terminal state. Pending statuses produce no
event.

Analytics event name: `user_search_source`. Parameters:

- `source`: `localCache` / `funnelcakeApi` / `nip50Relay`
- `status`: `success` / `failed` / `skipped`
- `result_count`, `latency_ms` (success only)
- `reason`, `latency_ms` (failed only)

Existing `feed_first_batch_received`, `feed_load_complete`, and
`feed_error` events for `feed_type=user_search` are unchanged.

## What is intentionally not in scope

- Changing the 5 s NIP-50 timeout value — latency budget is a product
  decision (parent epic Q3).
- Replacing or extending the NIP-50 relay list — parent epic Q4.
- Auto-navigate-while-typing behavior — see #3802.
- Focus / keyboard continuity across Explore → Search — see #3803,
  #3020.
- `searchUsers` (the non-progressive sibling used by
  `NewMessageSearchBloc`) — different caller, different scope.

## Related issues

- #3804 — this contract's execution ticket
- #3791 — the user-visible "cant find friends" report this closes
- #3801 — parent search-stabilization epic
- #3627 — data-source strategy doc requirement (partial payment)
- #3593 — suppressed catch blocks (the per-source-failed wrapping
  pays the relevant Phase 3 portion)
