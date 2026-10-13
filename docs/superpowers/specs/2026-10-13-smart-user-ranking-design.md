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

### 1. Shape: a pure scorer plus one signal loader

The ranking has two parts, and neither is a long-lived singleton.

- **`user_ranking` package** (pure Dart, new, under `mobile/packages/`). It
  holds `UserRankingSignals` (the per-pubkey inputs), `RankedUser`, and
  `rankUsers(...)`, which sorts candidates by score. There is no I/O and no
  Flutter in it. It gets its own CI workflow at the default 100% coverage
  floor, as `check_package_ci_floor.sh` requires.
- **`UserRankingSignalsLoader`** (`mobile/lib/services/user_ranking/`). It is
  constructor-injected with the repositories it reads and gathers the signals
  for a candidate set in one batched pass. Each BLoC that needs it gets its
  own instance (built in the BLoC's `BlocProvider.create`, keyed on its
  repositories as `state_management.md` requires). It is not a Riverpod
  singleton and keeps no cached snapshot between opens. It ships with a
  same-named test, as the untested-services floor requires.

Signals are loaded **once, when the list opens**, from data already on the
device. Opening a list makes no network call. Repositories keep their own
caches, so the loader does not add a second one.

The loader reads these signals:

| Signal | Source | Notes |
|---|---|---|
| Last interaction | `DmRepository.watchAcceptedConversations()`, taking its first emission: `lastMessageTimestamp` of each 1:1 conversation where `currentUserHasSent` | This covers shares as well, since a share is sent as a DM. Group conversations are ignored. `VideoSharingService.recentlySharedWith` is in-memory, capped at 10, and reset on restart, so it is *not* a ranking source. It only keeps its existing job of showing the current session's shares at the front of the share sheet. |
| You follow | `FollowRepository.followingPubkeys` | Already in memory. |
| Follows you / mutual | The persisted my-followers snapshot, read **cache-only** | `relationshipTo` only knows followers after a network fetch. The loader therefore needs a new `FollowRepository.readCachedMyFollowers()` that reads the `CacheSync` entry with `CacheFetchPolicy.cacheOnly`. When nothing is cached, "follows you" stays unknown and scores as absent. It never counts against the person. |
| Verified NIP-05 | `Nip05VerificationsDao.getValidVerifications(pubkeys)`, batched | Only a *verified* handle scores. A claimed handle is just text that anyone can write into their profile. Ranking never triggers a new verification. |
| Video count | `ProfileStatsDao` `videoCount`, falling back to `UserProfile.restVideoCount` | Absent when neither is cached. |
| Last posted | A new batched `NostrEventsDao` query: newest cached video event per author, using the kinds in `NIP71VideoKinds.getAllVideoKinds()` | Best-effort, because the event cache is pruned. |

The loader drops the viewer's own pubkey and blocked accounts (through
`ProfileRepository`'s block filter). It also keeps each list's existing rule
for deleted accounts and accounts with no visible identity, such as
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
- "Posted {time}" appears **only when the newest cached video is less than
  7 days old**. Because the event cache is partial, an old or missing date
  proves nothing about whether someone is active. The label only ever makes
  the positive claim, never "inactive". The time is formatted with
  `time_formatter`. This is the only new ARB key. It is added to `app_en.arb`
  and every `app_*.arb` locale in the same change that renders it.

The shared indicator line is extracted from `SearchUserTile` into a reusable
widget, which the DM picker, follow lists and pickers then use. The share
sheet's horizontal avatar row stays as it is: it has no room for a text line.

### 5. Performance

All reads are local: one batched Drift read per signal type over the candidate
set, plus an `O(n log n)` sort. The list draws from the existing cache-first
path straight away. Nothing re-sorts after first paint (see §3). The loader
runs inside the BLoC's existing load handler, after the cache-first read and
before the first `ready` emit, so the list never draws in the old order and
then jumps to the new one.

## Tests

- `user_ranking` package, at 100%: each weight and decay curve, the
  non-stacking relationship rule, tiebreaks, absent signals scoring zero, and
  the two-tier comparator.
- `UserRankingSignalsLoader`: seeded conversations, follows, cached followers,
  NIP-05 rows, stats and video events produce the expected signals. It
  excludes the viewer and blocked accounts, ignores group conversations, and
  makes no network call (verified against the repository mocks).
- `FollowRepository.readCachedMyFollowers` (strict-coverage package): it
  returns the cached snapshot, returns nothing on a cache miss, and never
  fetches.
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

- Any server-side "last active" field, or any other new backend support.
- Persisting a ranking snapshot or a per-account interaction table. The design
  only reads existing stores, so it adds no account-boundary cleanup.
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
   followers after a network fetch (`follow_repository.dart:488`). The fix is
   a cache-only read of the persisted snapshot. When nothing is cached, the
   signal is absent rather than treated as "not a follower".
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
   ships social proof, the video count and NIP-05 strings. The only new string
   is "Posted {time}".
10. **"Large / moderate / mild" could not be tested.** The weights and decay
    half-lives are now concrete constants.
11. **Indicators don't fit the share sheet.** The share sheet is a horizontal
    avatar row, so indicators are limited to vertical lists.
