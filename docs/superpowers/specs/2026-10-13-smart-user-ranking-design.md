# Smart user ranking for sharing and lists — design

**Problem.** Every user list in the app renders in whatever order the DB or
server returned it: the share sheet shows follows in contact-list order, the
new-DM picker in profile-cache order, the follow screens in newest/oldest
order. To share a video with someone you talk to every day, the user scrolls
or types. The lists also carry no signal about who a person is: no mutual
marker, no nip05, no "has posted videos", no "was active recently".

We want picking a person — to share a video or start a DM — to be instant and
to put the people you actually interact with first, everywhere a user list
appears.

## Approved design

### 1. One shared ranking source: `UserRankingService`

New service under `mobile/lib/services/` (layered `UI → BLoC → Repository`).
It owns a single local snapshot, built only from data already on device, and
streams ranked results to every list. No network call on open.

Snapshot inputs, all from existing local sources:

- **Follow state** — following set and mutual set from `FollowRepository`
  (`followingPubkeys`, follower caches, `relationshipTo`).
- **Interaction history** — who you have messaged and shared with, with
  timestamps, from `DmRepository` (`watchAcceptedConversations`) and
  `VideoSharingService.recentlySharedWith`.
- **Activity** — derived per pubkey from the newest event already cached:
  newest profile event time, newest video, newest DM. Best-effort; absent when
  unknown. No new network calls.
- **Profile signals** — `nip05` and video count from `ProfileStats` /
  `UserProfile` (`restVideoCount`).

The service exposes a `Stream<List<RankedUser>>` (and a context-scoped watch for
the share/DM preload). Recompute is incremental on cache change.

`RankedUser` carries: `pubkey`, `score`, `displayName`, `avatarUrl`, `nip05`,
`videoCount`, `lastActiveAt`, and the derived relationship flags.

### 2. Score — closeness-first, single weighted value

One blended score. Lean: closeness dominates; activity and content lift within
that.

- **Message/share recency** — dominant, decays with time; most recent first.
- **Mutual follow** — large.
- **You follow** — moderate.
- **Activity recency** — moderate tiebreak.
- **Video count** — mild.
- **nip05 present** — small.

Consequence: someone you talk to outranks a stranger who just posted.

### 3. Per-list application

- **Share sheet** (`ShareSheetBloc`, `mobile/lib/blocs/share_sheet/`) and
  **new-DM picker** (`NewMessageSearchBloc`): the preloaded list is ordered by
  **who you messaged/shared with most recently**; the blended score breaks ties.
- **Search results** (`UserSearchBloc`): empty query uses ranked order; with a
  query, text relevance first, then score.
- **Following / Followers screens**: add `FollowSortOrder.smart`, make it the
  default in `showFollowSortMenu`; `newestFirst` / `oldestFirst` remain.
- **Collaborator picker** and **people-list pickers**
  (`UserPickerFilterMode`, `AddPeopleToListCubit`): consume the same ranked
  order instead of their local name/mutual sort.

### 4. Row indicators

Each recipient row shows, only when the signal exists: a nip05 marker,
"posted N videos", and a relative last-active label. Rows with no signal stay
clean. Built from `divine_ui` / `VineTheme` components; new strings added to
`app_en.arb` and every `app_*.arb` locale.

### 5. Performance

Local snapshot, zero network on open, `O(n log n)` sort, streamed. Target: the
list paints from cache immediately, then updates as the snapshot hydrates.

## Tests

- Score ordering and tiebreaks (unit).
- Service snapshot built from seeded Drift / follow / DM fixtures.
- `FollowSortOrder.smart` ordering, including the undated-tail boundary.
- Widget tests: indicators render when present and are absent when not;
  share/DM preload order follows message recency.
- l10n: new keys present in all locales (`arb_consistency_test`).

## Out of scope

- Any real server-side "last active" field or new backend support.
- Ordering the feed, notifications, or any non-user list.
