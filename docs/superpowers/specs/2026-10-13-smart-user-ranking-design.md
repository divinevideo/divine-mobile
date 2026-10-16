# Smart user ranking for sharing and lists — design

**Problem.** Every user list in the app renders in whatever order the DB or
server returned it. The share sheet shows this session's recent shares, then
follows in contact-list order. The new-DM picker and the collaborator picker
sort by rendered name. The follow screens sort newest or oldest first. To share
a video with someone you talk to every day, the user has to scroll or type.
Most of these lists also say nothing about who a person is. Search results are
the exception: `SearchUserTile` already shows a NIP-05 handle, social proof
and a video count.

Picking a person, whether to share a video or start a DM, should be instant.
The people you actually interact with should come first in every user list.

**Revised 2026-10-14** after checking the spec against the code. What changed
and why is listed in [Review notes](#review-notes-2026-10-14) at the end.

## Approved design

### 0. Caching rule: never drop data because it is old

Old data is still the best answer available until fresher data arrives. Show
it straight away, fetch an update in the background, and update the screen
when the update lands. A TTL decides *when to refresh*, never *when to delete*.
Data is deleted for only three reasons:

- a size or row cap (for example `cache_sync`'s 100 MB eviction of the oldest
  entries);
- a retention window measured in weeks, not minutes;
- account cleanup.

Today two stores break this rule, and fixing them is part of this work:

- `cache_sync` deletes an expired entry the moment it is read
  (`cache_dao_impl.dart:52`). After its TTL expires, a screen shows nothing and
  waits for the network.
- `ProfileStatsDao` drops rows older than five minutes
  (`profileStatsCacheDuration`), both on read and in the startup cleanup, unless
  they hold follower counts. That means video counts never survive long enough
  to be ranked on.

The C2PA trust-anchor bundle keeps refusing expired data on purpose. A stale
trust root is a security decision, not a display one.

### 1. Shape: a pure scorer plus one signal loader

The ranking has two parts, and neither is a long-lived singleton.

- **`user_ranking` package** (pure Dart, new, under `mobile/packages/`). It
  holds `UserRankingSignals` (the per-pubkey inputs), `RankedUser`, and
  `rankUsers(...)`, which sorts candidates by score. There is no I/O and no
  Flutter in it. It gets its own CI workflow at the default 100% coverage
  floor, as `check_package_ci_floor.sh` requires.
- **`UserRankingSignalsLoader`** (`mobile/lib/services/user_ranking/`). It is
  constructor-injected with the repositories and DAOs it reads, and gathers
  the signals for a candidate set in one batched pass. It holds no state and
  keeps no cached snapshot between opens. It reaches BLoCs through a
  non-keepAlive Riverpod provider that `ref.watch`es those repositories, so a
  repository swap after an auth change yields a new loader. Bridged screens
  include the loader in their `BlocProvider` `ValueKey`, as
  `state_management.md` requires. It ships with a
  same-named test, as the untested-services floor requires.

Signals are loaded **once, when the list opens**, from data already on the
device. Opening a list makes no network call. Repositories keep their own
caches, so the loader does not add a second one.

The loader reads these signals:

| Signal | Source | Notes |
|---|---|---|
| Last interaction | `DmRepository.watchAcceptedConversations()`, taking its first emission: `lastMessageTimestamp` of each 1:1 conversation where `currentUserHasSent` | This covers shares as well, since a share is sent as a DM. Group conversations are ignored. `VideoSharingService.recentlySharedWith` is in-memory, capped at 10, and reset on restart, so it is *not* a ranking source. It only keeps its existing job of showing the current session's shares at the front of the share sheet. |
| You follow | `FollowRepository.followingPubkeys` | Already in memory. |
| Follows you / mutual | The local social graph (§5) | Computed on the device each time it is read: "follows you" is membership in the local follower set, and "mutual" is "you follow them" plus "they follow you". Nothing ever stores a mutual flag, so following someone new who already follows you makes them a mutual straight away. Before the first sync, "follows you" is unknown and scores as absent. It never counts against the person. |
| Verified NIP-05 | `Nip05VerificationsDao.getValidVerifications(pubkeys)`, batched | Only a *verified* handle scores. A claimed handle is just text that anyone can write into their profile. Ranking never triggers a new verification. |
| Video count | `ProfileStatsDao` `videoCount`, falling back to `UserProfile.restVideoCount` | Absent when neither is cached. Kept fresh by the background refresh in §5. |
| Last posted | A new batched `NostrEventsDao` query: newest cached video event per author, using the kinds in `NIP71VideoKinds.getAllVideoKinds()` | Best-effort, because the event cache is pruned. |

The loader drops the viewer's own pubkey and every account the content policy
hides: accounts the viewer blocked or muted, and accounts that block or mute
the viewer. The viewer's own Following and Followers lists use a loader that
drops only the accounts the viewer blocked, as those lists did before, so an
account that hides the viewer can still be reached there to unfollow or
report. The loader also keeps each list's existing rule for deleted accounts
and accounts with no visible identity, such as
`ShareableUser.hasVisibleIdentity`.

### 2. Score: closeness first, one weighted value

`rankUsers` computes one score per candidate. The weights below are the
starting values. They live in one `UserRankingWeights` constants class so the
tests can pin them and product can tune them later.

| Component | Value |
|---|---|
| Interaction recency | `100 × 0.5^(age / 14 days)` since the last message you sent to them or received from them |
| Relationship | mutual `40`, you follow `20`, follows you `10` (these do not stack) |
| Posting recency | `10 × 0.5^(age / 7 days)` since their newest cached video |
| Video count | `5 × min(1, log10(1 + n) / 3)` |
| Verified NIP-05 | `3` |

Ties break on rendered display name, then on full pubkey, so the order is
deterministic.

With these values, anyone you have never messaged scores at most 58: a mutual
follow with every other signal maxed out. Someone you messaged in the last 11
days scores more than that, so they always rank above everyone you haven't
messaged. Past 11 days, their message signal has decayed enough that a strong
mutual follow can overtake them. A stranger who just posted a video scores no
more than about 18.

### 3. Per-list application

- **Share sheet** (`ShareSheetBloc`). This session's shares stay at the front,
  as they do today. The rest is two tiers: first everyone you have a 1:1
  conversation with, ordered by last interaction; then everyone else in score
  order.
- **New-DM picker** (`NewMessageSearchBloc`). It uses the same two tiers and
  replaces `_sortedByPeerName` for the preloaded contacts. Local filtering
  while typing keeps the ranked order.
- **Search** (`UserSearchBloc`). Server results arrive in pages, sorted by
  follower count. Within each page, people you already know (an interaction or
  a follow relationship) are moved to the front in score order. Everyone else
  keeps the server's order. Earlier pages are never reordered. An empty query
  still shows no list, because this design adds no new empty state.
- **My following / my followers** (`MyFollowingBloc`, `MyFollowersBloc`).
  These get a new `smart` sort, and it becomes the default. `newestFirst` and
  `oldestFirst` stay available in `showFollowSortMenu` with a new "Smart" option
  listed first. `smart` is an app-level order, because the
  `follow_repository` package cannot see DMs and its `fromNewestFirst` /
  `fromFollowOrder` helpers cannot compute it. The chosen order lives in the
  BLoC state, as it does today. Other users' follow lists are unchanged.
- **Collaborator / user picker** (`UserPickerSheet`) and **add-to-people-list**
  (`AddPeopleToListCubit`). The rendered-name sort is replaced by the ranked
  order. The picker's mutual-only *filter* stays as it is.

**Ordering is fixed once the list is on screen.** The order is computed when
the list opens. Signals that arrive afterwards may add rows to the end or
update rows in place, but they never move rows that are already visible. This
keeps the existing share-sheet rule in `ShareSheetBloc._onRecipientToggled`:
moving rows under the user's finger while they multi-select is disorienting.
The next open uses the new signals.

### 4. Row indicators

Vertical list rows show indicators only when the signal exists, and reuse
what search already ships:

- The identifier line comes from `resolveUserIdentifierLine`: a NIP-05 handle
  when it is safe to show, otherwise social proof (`socialProofMutual` /
  `socialProofFollowsYou` / `socialProofYouFollow`).
- The video count uses the existing `searchUserVideoCount` key, formatted with
  `count_formatter`.
- The follow-list sort menu needs one more new key, `followSortSmart`, for the
  "Smart" option.
- "Posted {time}" appears **only when the newest cached video is less than
  7 days old**. Because the event cache is partial, an old or missing date
  proves nothing about whether someone is active. The label only ever makes
  the positive claim, never "inactive". The time is formatted with
  `LocalizedTimeFormatter.formatRelativeVerbose`, which already produces "2h ago" through
  existing keys. The label adds a single new key, `userRowPosted`
  ("Posted {time}"). It is added to `app_en.arb`
  and every `app_*.arb` locale in the same change that renders it.

The shared indicator line is extracted from `SearchUserTile` into a reusable
widget, which the DM picker, follow lists and pickers then use. The share
sheet's horizontal avatar row stays as it is: it has no room for a text line.

### 5. Caching, latency and server cost

The goal: a ranked list appears as fast as an unranked one, keeps working
offline, and adds next to no server load.

**Opening a list makes no network call.** Every signal is read from durable
local storage. The extra local work per open is a handful of batched Drift
reads over the candidate set, plus a sort. Target: ranking adds less than
50 ms to a list load on a mid-range phone with 5,000 follows. This is measured
with a benchmark run on a seeded database, not asserted in CI. Nothing
re-sorts after first paint (see §3). The loader runs inside the BLoC's
existing load handler, after the cache-first read and before the first `ready`
emit, so the list never draws in the old order and then jumps to the new one.

**The social graph lives on the device.** Your following list is already
local: it is your own kind 3 contact list, which `FollowRepository` persists
and syncs. Your followers list becomes local too, in a new durable Drift table.
Every relationship question is answered by computing it from those two local
sets. Nothing waits on the network, and no server ever decides who is a
mutual.

- **New table `my_followers`** in `db_client`, with columns `owner_pubkey`,
  `follower_pubkey`, `followed_at` (nullable) and `last_seen_at`. The primary
  key is `(owner_pubkey, follower_pubkey)`. It is a real Drift migration with a
  schema snapshot, as `data_foundation.md` requires. Its retention policy,
  written in the table's doc comment: one row per follower, bounded by the
  account's follower count. Rows are pruned by the full reconcile below and
  deleted for an account by the account-cleanup path. An account switch
  clears the departing owner's rows through `UserDataCleanupService`, scoped
  by owner.
- **`FollowRepository` loads the set at initialization** into the in-memory
  follower list it already keeps (`_cachedMyFollowersPubkeys`), so
  `relationshipTo` answers correctly from a cold start. Today that list is only
  filled after a network fetch. This also fixes the cold-start under-claiming
  documented at `follow_repository.dart:488` for every screen that shows
  social proof, not just ranked lists.
- **"Mutual" is computed, never stored:** `isFollowing(x)` plus membership in
  the follower set. Follows and unfollows you make take effect immediately,
  because the following side is already live in memory.

**Keeping the follower set current, cheaply:**

| Step | When | What it fetches |
|---|---|---|
| Seed | Once, when the table has no rows for this owner | The existing three-source follower fetch (API, relays, indexers), written in full |
| Incremental | On app foreground or when a ranked list opens, at most once every 15 minutes, and only while online | One relay query: `kinds: [3], #p: [me], since: <high-water mark minus a skew margin>`. It returns only the contact lists that changed since the last sync and still include you, which is usually none. New authors are added; known ones get `last_seen_at` bumped. |
| Full reconcile | When the last full sync is more than 7 days old, or whenever the followers screen does a full fetch anyway | The existing fetch. The table is replaced with the result, which is the only way to see unfollows, because a contact list that drops you no longer matches `#p: [me]`. |

Everything runs in the background after first paint and never blocks a list.
One sync runs at a time. A failed sync keeps the existing rows. Results apply
on the next open, so visible rows never move (§3). Between full reconciles,
someone who unfollowed you can still read as "follows you" for up to a week.
That is the same staleness class the current union-of-sources code already
has (`follow_repository.dart:492`), and it only costs a small ranking boost.

The server cost goes down, not up. Today every followers-screen open past the
30-second TTL triggers the full three-source fetch. With the local graph, a
typical day costs a few incremental relay queries that return little or
nothing, plus one full fetch a week.

**Other signals:**

| Signal | Store | Lifetime | How it refreshes |
|---|---|---|---|
| Last interaction | Drift `conversations` (existing) | Durable | Updates as DMs arrive. Never fetched for ranking. |
| Verified NIP-05 | Drift `nip05_verifications` (existing) | That table's own expiry | Existing verification flow. Ranking never starts a verification. |
| Video count | Drift `profile_stats` (existing) | Durable: under §0, kept for 30 days rather than 5 minutes | A background refresh covers only the top 100 ranked candidates whose `cachedAt` is more than 7 days old. It goes in batches through the existing `/api/users/bulk` endpoint, which already returns a video count. If that path does not already write `profile_stats`, it is changed to. Results apply on the next open. |
| Last posted | Drift `event` cache (existing) | Best-effort, since the cache is pruned | Not refreshed for ranking. |

**Optional server help (not required to ship):**

- Add `last_video_at` to the `/api/users/bulk` stats in divine-funnelcake.
  Funnelcake knows every author's real latest post, while the phone's event
  cache is partial. The app would store it in a new nullable `profile_stats`
  column (a Drift migration) and prefer it over the event-cache query, which
  would make the "Posted" label reliable.
- Paging the funnelcake followers endpoint by `since` would let the weekly
  reconcile download only the changes, instead of the whole list. That
  matters only for accounts with very many followers.

**The 30-second `_profileListCacheTtl` stops hurting.** Under §0 it becomes
a freshness window. The followers and following screens then show the saved
list immediately and refresh it in the background, instead of waiting on the
network after 30 seconds.

## Tests

- `user_ranking` package, at 100%: each weight and decay curve, the
  non-stacking relationship rule, tiebreaks, absent signals scoring zero, and
  the two-tier comparator.
- `UserRankingSignalsLoader`: seeded conversations, follows, cached followers,
  NIP-05 rows, stats and video events produce the expected signals. It
  excludes the viewer and blocked accounts, ignores group conversations, and
  makes no network call (verified against the repository mocks).
- `my_followers` table (`db_client`): the migration test against the
  committed schema snapshot; owner-scoped reads and writes; deleting one
  owner's rows leaves other owners' rows alone.
- Local social graph in `FollowRepository` (strict-coverage package):
  - at initialization, `relationshipTo` answers from the persisted set with
    no fetch;
  - mutual follows the following set live: following someone who is in the
    follower set makes them a mutual with no sync;
  - the seed runs only when the table is empty;
  - the incremental query uses the high-water mark and adds new authors;
  - the full reconcile replaces the set and so removes unfollowers;
  - the 15-minute and 7-day intervals are honored;
  - a failed sync keeps the existing rows;
  - concurrent sync calls share one fetch.
- Account switch: `UserDataCleanupService` clears the departing owner's
  `my_followers` rows.
- Video-count refresh: only stale rows among the top 100 candidates are
  requested, in batches. Fresh rows are not requested. Results never reorder
  a list that is already on screen.
- Latency benchmark: ranking 5,000 seeded follows stays under the §5 budget.
  This is a benchmark harness, not a CI assertion.
- The new `NostrEventsDao` newest-video-per-author query: one row per author,
  and only `NIP71VideoKinds` video kinds count.
- BLoC tests for share sheet, DM picker, search, follow lists and the people-list
  cubit:
  - ranked order on load;
  - late signals append rather than reorder;
  - the session's recent shares stay at the front;
  - search only reorders within a page.
- `smart` sort: it is the default, and switching to newest or oldest and back
  works.
- Widget tests: each indicator renders when its signal exists and is absent
  otherwise. "Posted" stays hidden for a date 7 days old or older. Assertions
  use `lookupAppLocalizations`.
- l10n: `arb_consistency_test`. The orphan ratchet stays green because the new
  key is rendered.

## Out of scope

- Required backend changes. The two funnelcake additions in §5 are optional.
- Persisting the computed ranking itself. It is cheap to recompute on every
  open, and a stored ranking would just be one more thing to go stale.
- Changing the 30-second follower TTL value itself. Under §0 it only sets
  how often to refresh.
- Ordering the feed, notifications, or any other list that isn't a list of
  users.
- Other users' following and followers screens.

## Review notes (2026-10-14)

These are the changes from the first draft, checked against `main` at
`835f9ab418`:

1. **A long-lived service composing three repositories broke the layering.**
   The repo's rule is that a repository does not depend on another repository.
   The draft's always-on `UserRankingService` also had no clear owner for its
   lifecycle. Its replacement is a pure scorer package plus a per-BLoC
   loader that keeps no cache.
2. **`recentlySharedWith` cannot rank anything.** It is in-memory, capped at
   10, and empty after a restart (`video_sharing_service.dart:182`,
   `:503`). Shares are DMs, so conversation recency is the durable source.
3. **Mutual follows were not available locally.** `relationshipTo` only knows
   followers after a network fetch (`follow_repository.dart:488`). A first
   revision proposed a cache-only read of the existing followers entry. That
   entry expires after 30 seconds, and expired entries are deleted when read,
   so the read would almost always have come back empty. The fix is now a
   local social graph: a durable follower table, kept current by incremental
   relay queries, with "mutual" computed on the device whenever it is read
   (§5).
4. **The draft scored a NIP-05 handle just for being present.** A claimed
   handle is spoofable, so now only a verified handle scores. Display still
   follows `resolveUserIdentifierLine`'s existing safety rule.
5. **The draft would have reordered rows while the user was tapping them.**
   A streamed, recomputing order conflicts with the share sheet's existing
   no-reorder rule. The order is now fixed once the list is on screen.
6. **A "last active" label would have been wrong.** The cache is partial, so
   "active 3 months ago" could be false for someone who posted today. The
   label is now only shown for recent videos, and says "Posted", not "Active".
7. **`FollowSortOrder.smart` did not fit the package enum.** Its helpers
   cannot compute a DM-aware order, so `smart` is now an app-level order.
8. **Search pagination.** Re-sorting server pages by score would move earlier
   rows when page 2 arrives. Reordering now happens only within a page, and
   only to promote people you know. The draft's empty-query ranked list was a
   new empty state that no surface asked for, so it is dropped.
9. **The draft planned new strings that already exist.** Search already
   ships social proof, the video count and NIP-05 strings, and relative times
   already have keys. Only two new keys remain: `userRowPosted` and
   `followSortSmart`.
10. **"Large / moderate / mild" could not be tested.** The weights and decay
    half-lives are now concrete constants.
11. **Indicators don't fit the share sheet.** The share sheet is a horizontal
    avatar row, so indicators are limited to vertical lists.
