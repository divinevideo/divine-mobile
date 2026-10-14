# Smart User Ranking Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rank every user list (share sheet, DM picker, search, follow lists,
pickers) by closeness, using only data already stored on the device. Caches
show old data immediately and refresh it in the background instead of
deleting it.

**Architecture:** Three layers.

- **Part A** fixes the caches: expired data is served and then refreshed,
  never deleted on read.
- **Part B** keeps the social graph on the device: a Drift `my_followers`
  table, kept current by incremental relay queries. "Follows you" and "mutual"
  are computed on the device every time they are read.
- **Part C** adds the ranking itself:
  - a pure-Dart `user_ranking` scoring package;
  - one app-layer signal loader that each BLoC uses;
  - shared row indicators.

**Tech Stack:** Flutter 3.47.2 (mise-pinned), Dart, Drift (`db_client`),
`cache_sync`, flutter_bloc, Riverpod (DI only), mocktail, bloc_test.

**Spec:** `docs/superpowers/specs/2026-10-13-smart-user-ranking-design.md`.
Read its sections 0–5 before any task.

**Delivery:**

| PR | Branch | Contents |
|---|---|---|
| PR 1 | `fix/cache-serve-stale` from fresh `origin/main` | Part A. It is independent, so it ships alone. |
| PR 2 | `feat/smart-user-ranking` (this worktree) | Parts B and C. They depend on each other, so they go in one PR with separate commits. Rebase onto `origin/main` before publishing. |

Never stack PR 2 on PR 1. PR 2 does not need Part A to work.

## Global Constraints

- **Toolchain:** run Flutter and Dart through `mise exec --` from `mobile/`.
  Run `flutter pub get` after any pubspec change.
- **Generated code:** after any change to a Drift table, `@riverpod` provider
  or Mockito mock, run
  `dart run build_runner build --delete-conflicting-outputs` in that package
  or app and commit the generated files.
- **Imports:** `package:material_ui/material_ui.dart`, never
  `package:flutter/material.dart`. Strings come from `context.l10n`. In tests,
  `MaterialApp` uses `appLocalizationsDelegates`.
- **Logging:** pubkeys reaching a log go through `pubkeyForLogs`. Never
  truncate an id.
- **BLoC rules:**
  - Every `emit` or `add` after an `await` uses `emitIfOpen` / `addIfOpen`.
  - No error strings in BLoC state.
  - No mutable fields on a BLoC.
- **Tests:**
  - Every test sits inside a `group`.
  - No `skip:`.
  - No `Future.delayed` in tests or app code.
  - No placeholder assertions.
  - Mocks are private (`_MockX`).
- **Scoring constants**, copied from the spec into `UserRankingWeights`:

  | Constant | Value |
  |---|---|
  | `interactionMax` | 100.0 |
  | `interactionHalfLife` | 14 days |
  | `mutual` | 40.0 |
  | `youFollow` | 20.0 |
  | `followsYou` | 10.0 |
  | `postingMax` | 10.0 |
  | `postingHalfLife` | 7 days |
  | `videoCountMax` | 5.0, with curve `5 × min(1, log10(1 + n) / 3)` |
  | `verifiedNip05` | 3.0 |

  The relationship values do not stack: mutual replaces you-follow.
- **Sync intervals:**

  | Constant | Value |
  |---|---|
  | Incremental follower sync | 15 minutes |
  | Full reconcile | 7 days |
  | `since` skew margin | 10 minutes |
  | Video-count refresh | top 100 candidates whose stats are more than 7 days old |
  | "Posted" label | shown only when the newest cached video is less than 7 days old |
  | `profile_stats` retention | 30 days |

- **New ARB keys (exactly two):**
  - `userRowPosted`: "Posted {time}"
  - `followSortSmart`: "Smart"

  Mirror both into every `app_*.arb` file, and render both in the same change.
- **Visible rows never move** after a list's first `ready` emit. Later data may
  update a row in place or add rows at the end.

## Review Focus

1. **A follower sync where one source fails must not wipe the table.** Replace
   the table only when every source succeeded; otherwise merge. Test: Task B2
   "partial source failure merges instead of replacing".
2. **A future-dated contact list must not push the incremental high-water mark
   past now.** Otherwise every later `since` query would miss real follows.
   Test: Task B2 "high-water mark is clamped to now".
3. **The viewer's own account and blocked accounts never appear in a ranked
   list**, even when they have DM history. Test: Task C3 "excludes self and
   blocked".
4. **After an account switch, the new account never sees the old account's
   followers or ranking.** Tests: Task B1 owner scoping, and Task B3 cleanup.
5. **A brand-new account with no follows, no DMs and no cache:** every list
   still loads, ranks by name, and makes no network call before first paint.
   Test: Task C3 "empty device".

---

## Part A — Serve stale data, refresh in the background (PR 1)

Create the worktree first:

```bash
git fetch origin
git worktree add .worktrees/cache-serve-stale -b fix/cache-serve-stale origin/main
```

### Task 1 (A1): `cache_sync` stops deleting expired entries

**Files:**
- Modify: `mobile/packages/cache_sync/lib/src/cache_dao.dart`
- Modify: `mobile/packages/cache_sync/lib/src/cache_dao_impl.dart:45-59`
- Modify: `mobile/packages/cache_sync/lib/src/cache_sync.dart` (`watchOne`,
  `watchStream`, `read`, `_driveWatchOne`, `_driveWatchStream`)
- Create: `mobile/packages/cache_sync/lib/src/cache_entry.dart`, and export it
  from the barrel
- Modify the tests:
  - `test/cache_dao_test.dart`: the `TTL eviction` group becomes
    `TTL staleness`
  - `test/cache_sync_watch_one_test.dart`
  - `test/cache_sync_watch_stream_test.dart`
  - `test/cache_sync_read_write_test.dart`
  - `test/fake_cache_dao.dart`

**Interfaces:**

- **Produces:**
  - `class CacheEntry { final String payload; final bool isStale; }`
  - `CacheDao.readEntry(String key) -> Future<CacheEntry?>`. It never deletes.
  - `CacheDao.read(String key)` is removed. Its callers move to `readEntry`.
  - `CacheSync.readEntry<T>({required String key, required T Function(String) fromJson}) -> Future<({T data, bool isStale})?>`
  - `CacheSync.read<T>` keeps its contract: it returns `null` when the entry is
    stale. It no longer deletes the row.
- **Watch semantics after this task:**

  | Policy | Behavior |
  |---|---|
  | `cacheAndNetwork` | Emit any cached value, fresh or stale, then fetch and emit live. |
  | `cacheFirst` | A fresh value ends the stream. A stale value is emitted and then a fetch runs. A missing value means fetch. |
  | `cacheOnly` | Emit any cached value, including a stale one. |
  | `networkOnly` | Unchanged. |

- Corrupt payloads are still deleted. Size-based LRU eviction is unchanged.

- [ ] **Step 1: Write failing tests:**
  - `CacheDaoImpl`: `readEntry returns an expired row as stale and keeps it`. Write with `ttl: Duration(seconds: 1)`, inject a clock or wait past expiry with a fake `now`, then `expect(entry!.isStale, isTrue)` and that a second `readEntry` is non-null.
  - `watchOne`:
    - `cacheFirst emits a stale value then the live value`. The emitted values are `[CacheResult.cached(old), CacheResult.live(new)]`, and the fetch is called once.
    - `cacheAndNetwork serves an expired value before fetching`.
    - `cacheOnly emits an expired value`.
  - `watchStream`: the same three cases.
  - `CacheSync.read`: `returns null for a stale entry without deleting it`, followed by `readEntry` returning `isStale: true`.
- [ ] **Step 2: Run** `cd mobile/packages/cache_sync && mise exec -- flutter test`. Expect the new tests to fail.
- [ ] **Step 3: Implement.**
  - `CacheDaoImpl` needs a clock seam for the tests: `CacheDaoImpl(db, {int? maxSizeBytes, DateTime Function()? now})`.
  - In `_driveWatchOne` and `_driveWatchStream`, track `servedFresh` separately from `servedCachedValue`. Stop early only when the policy is `cacheOnly`, or when the policy is `cacheFirst` and `servedFresh`.
  - Update the dartdoc for `watchOne`, `watchStream`, `read` and the `CacheFetchPolicy` values to the new semantics.
- [ ] **Step 4: Run** the package tests with `--coverage`. Expect them to pass with 100% coverage; the package is strict-coverage.
- [ ] **Step 5: Run every app-side consumer suite that uses `watchOne` or `watchStream`**, and fix any test that asserted "no cached emission after expiry". List the consumers with:

  ```bash
  grep -rln "CacheSync.watch" mobile/lib mobile/packages/*/lib
  ```

  Then run each one's mirrored test file. In particular, run the follow_repository suite: `follow_repository_cached_test.dart`.
- [ ] **Step 6: Commit:** `fix(cache_sync): serve stale entries and refresh instead of deleting them`.

### Task 2 (A2): `CacheSync.read` callers that already revalidate show stale data

**Files:** each `CacheSync.read` caller, listed with:

```bash
grep -rn "CacheSync.read" mobile/lib
```

- `lib/blocs/video_feed/home_feed_cache.dart`
- `lib/repositories/profile_pins_repository.dart`
- `lib/blocs/profile_feed/profile_video_snapshot_cache.dart`
- the `profile_liked_videos` bloc
- the `profile_saved_videos` bloc
- the `profile_reposted_videos` bloc
- the `profile_collab_videos` bloc
- `lib/services/c2pa_trust_anchor_service.dart`

Change each one's mirrored test.

**Decision rule:**

- If the caller already fetches fresh data after reading the cache, switch it
  to `CacheSync.readEntry`. Render the data whether or not it is stale, and
  keep the existing refetch.
- `c2pa_trust_anchor_service.dart` keeps `read`, because a stale trust root is
  never acceptable. Add a one-line comment that says so.
- Record each caller's decision in the commit body.

- [ ] **Step 1:** For each migrated caller, write a test: `shows a stale snapshot while revalidating`. Seed the `FakeCacheDao` with an expired entry, then assert that the first emitted state carries the cached items and that the fetch still runs.
- [ ] **Step 2: Run** each test and expect it to fail.
- [ ] **Step 3: Migrate** the callers.
- [ ] **Step 4: Run** each mirrored test file and expect it to pass.
- [ ] **Step 5: Commit:** `fix(cache): show stale snapshots while revalidating`.

### Task 3 (A3): `profile_stats` keeps rows for 30 days

**Files:**
- Modify: `mobile/packages/db_client/lib/src/database/daos/profile_stats_dao.dart`
  (`getStats` around :97, `deleteExpired`, and constants :10-24)
- Modify: `mobile/packages/db_client/lib/src/database/app_database.dart:1836`
  (startup cleanup)
- Test: `mobile/packages/db_client/test/src/database/daos/profile_stats_dao_test.dart`

**Interfaces:**

- **Produces:**
  - `const profileStatsRetention = Duration(days: 30)`
  - `getStats(...)` returns `null` for a stale row but **never deletes** it.
  - `deleteExpired({Duration retention = profileStatsRetention})` deletes only
    rows whose `cachedAt` and `followerCountsUpdatedAt` are both older than the
    retention window.
- `profileStatsCacheDuration` (5 minutes) stays, as the freshness signal.

- [ ] **Step 1:** Write the failing tests:
  - `getStats leaves a stale row in place`
  - `deleteExpired keeps a 6-day-old row with only a video count`
  - `deleteExpired removes a 31-day-old row`
- [ ] **Step 2: Run** `cd mobile/packages/db_client && mise exec -- flutter test test/src/database/daos/profile_stats_dao_test.dart`. Expect it to fail.
- [ ] **Step 3: Implement.** Update the doc comments, which state the retention policy (see `data_foundation.md`).
- [ ] **Step 4: Run** the db_client tests and expect them to pass. Also run `app_database` startup-cleanup tests if they exist (`grep -rn runStartupCleanup mobile/packages/db_client/test`).
- [ ] **Step 5: Commit:** `fix(db_client): keep profile stats for 30 days instead of 5 minutes`.

### Task 4 (A4): Ship PR 1

- [ ] **Step 1:** From `mobile/`, run:
  - `mise exec -- dart format` on the changed files
  - `mise exec -- flutter analyze lib test integration_test`
  - `bash scripts/ci/run_guards.sh`
- [ ] **Step 2:** `git fetch origin && git rebase origin/main && git push -u origin fix/cache-serve-stale`.
- [ ] **Step 3:** Open the PR with `gh pr create --base main --title "fix(cache): serve stale data and refresh in the background"`. The body follows the PR template, lists the per-caller decisions from Task A2, and flags the behavior change: screens now show old data instead of a spinner.
- [ ] **Step 4:** Run `gh pr checks <n> --watch`. Fix anything red.

---

## Part B — Local social graph (PR 2, commits 1–3)

Work in `.worktrees/smart-user-ranking`. Run `git fetch origin && git rebase origin/main` before starting.

### Task 5 (B1): The `my_followers` Drift table and DAO (schema v22)

**Files:**
- Modify: `mobile/packages/db_client/lib/src/database/tables.dart`. Add `MyFollowers` after `RemovedMessageIds`, and give it a doc comment stating the retention policy from spec §5.
- Create: `mobile/packages/db_client/lib/src/database/daos/my_followers_dao.dart`. Export it from `daos/daos.dart`.
- Modify: `app_database.dart`:
  - register the table and DAO in `@DriftDatabase`;
  - `schemaVersion => 22`;
  - add the `onUpgrade` step `if (from < 22 && to >= 22) await m.createTable(myFollowers);`.
- Generate:
  - run `dart run build_runner build --delete-conflicting-outputs`, then `dart run drift_dev make-migrations`;
  - commit `drift_schemas/app_database/drift_schema_v22.json`, the regenerated `app_database.steps.dart` and `test/drift/app_database/generated/*`.
- Modify: `packages/db_client/MIGRATIONS.md`. Bump "Current Schema Version" to 22 and add a v22 paragraph.
- Test:
  - `test/src/database/daos/my_followers_dao_test.dart`
  - `test/drift/app_database/migration_test.dart`. Bump the two "current version" tests to 22, retarget the `vN migrates to v22` tests, and add `a v21 database gains my_followers`.

**Interfaces:**

- **Table** `my_followers`:

  | Column | Type |
  |---|---|
  | `owner_pubkey` | text |
  | `follower_pubkey` | text |
  | `followed_at` | int, nullable, unix seconds |
  | `last_seen_at` | int, unix seconds |

  The primary key is `{ownerPubkey, followerPubkey}`. There is no
  `@TableIndex`, because the primary-key prefix covers owner lookups.
- **`MyFollowersDao`:**
  - `Future<List<({String pubkey, int? followedAt})>> followersOf(String ownerPubkey)`: ordered by `followed_at DESC NULLS LAST`, then by `follower_pubkey`.
  - `Future<Set<String>> followerSubset({required String ownerPubkey, required Iterable<String> candidates})`: one `IN` query, chunked at 500 items.
  - `Future<void> upsertAll({required String ownerPubkey, required Iterable<({String pubkey, int? followedAt})> followers, required int seenAt})`: keeps the larger `followed_at`.
  - `Future<void> replaceAll({required String ownerPubkey, required Iterable<({String pubkey, int? followedAt})> followers, required int seenAt})`: deletes the owner's rows and inserts, inside one transaction.
  - `Future<int?> newestFollowedAt(String ownerPubkey)`
  - `Future<int> clearAllForUser(String ownerPubkey)`

- [ ] **Step 1:** Write the failing DAO tests:
  - owner scoping: owner B never reads owner A's rows;
  - `upsertAll` keeps the newer `followedAt`;
  - `replaceAll` drops followers missing from the input;
  - `followerSubset` with 1,200 candidates returns the correct intersection;
  - `clearAllForUser` leaves other owners alone.
- [ ] **Step 2:** Write the failing migration test. `a v21 database gains my_followers` uses `verifier.schemaAt(21)`, then `migrateAndValidate(db, 22)`, then `upsertAll` and `followersOf` round-trip.
- [ ] **Step 3: Run** `cd mobile/packages/db_client && mise exec -- flutter test`. Expect it to fail.
- [ ] **Step 4: Implement** and generate, as listed under Files.
- [ ] **Step 5: Run** the db_client tests and expect them to pass.
- [ ] **Step 6: Commit:** `feat(db_client): add owner-scoped my_followers table (schema v22)`.

### Task 6 (B2): `FollowRepository` persists and syncs the follower set

**Files:**
- Modify: `mobile/packages/follow_repository/lib/src/follow_repository.dart`:
  - constructor (:57-87): add `MyFollowersDao? myFollowersDao` and `int Function()? nowSeconds`;
  - `initialize()` (:2031): load the persisted followers before `_loadFromLocalStorage`;
  - `_fetchMyFollowers` (:536): persist the result;
  - `_streamFollowers` (:1789): persist when the pubkey is your own;
  - add `syncMyFollowers()`.
- Create: `mobile/packages/follow_repository/lib/src/my_followers_sync_state.dart`. It holds the prefs-backed timestamps under the keys `my_followers_full_sync_$owner` and `my_followers_incremental_sync_$owner`. Embedding the pubkey makes them pubkey-scoped, so the prefs-classification guard does not report them.
- Test: `mobile/packages/follow_repository/test/src/my_followers_sync_test.dart`. It is a new file; reuse the mock setup from `follow_repository_test.dart:21-212`.
- Modify: `mobile/lib/providers/repository_providers.dart:131-161`. Pass `myFollowersDao: ref.watch(databaseProvider).myFollowersDao`.

**Interfaces:**

- **Consumes:** `MyFollowersDao` (Task B1).
- **Produces:**
  - `Future<void> FollowRepository.syncMyFollowers()`. It is single-flight: concurrent calls share one future. It does nothing when offline (`isOnline` is false) or when no keys are loaded.
    - **Seed:** no rows for the owner → `_fetchOrderedFollowers(me)` → `replaceAll` if no source errored, otherwise `upsertAll`. Stamp the full sync.
    - **Reconcile:** the last full sync is more than 7 days old → same as seed.
    - **Incremental:** the last incremental sync is more than 15 minutes old →
      `queryEvents([Filter(kinds: [EventKind.contactList], p: [me], since: hw - 600)]).timeout(_fetchFollowersTimeout)`.
      Here `hw = min(newestFollowedAt ?? 0, nowSeconds())`. Run the results through `_datableFollowedAt`, then `upsertAll`, then stamp the incremental sync.
    - After any write, refresh `_cachedMyFollowersPubkeys`, `_cachedMyFollowersDatedCount` and `_hasMyFollowersCache` from the DAO.
  - Constants `myFollowersIncrementalInterval`, `myFollowersReconcileInterval` and `myFollowersSinceSkew`, all `static const`, using the values from Global Constraints.
  - `relationshipTo` does not change, but it is now correct from a cold start.

- [ ] **Step 1: Write the failing tests:**
  - `initialize loads persisted followers so relationshipTo is mutual with no fetch`. Verify `queryEvents` was never called with a `p` filter.
  - `seed replaces the table on full success`
  - `partial source failure merges instead of replacing`. The relay throws, the API returns two followers, and the existing third row survives.
  - `incremental query uses since = high-water mark minus 600`. Capture the filter.
  - `high-water mark is clamped to now`. Seed a `followedAt` of now + 1 day, and assert that `since` is ≤ now − 600.
  - `reconcile after 7 days removes an unfollower`
  - `no sync inside the 15-minute window`
  - `offline does nothing`
  - `concurrent syncMyFollowers calls share one fetch`
  - `getMyFollowers persists to the table`
- [ ] **Step 2: Run** `cd mobile/packages/follow_repository && mise exec -- flutter test test/src/my_followers_sync_test.dart`. Expect it to fail.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the full follow_repository suite with `--coverage`. Expect it to pass at 100%; the package is strict-coverage.
- [ ] **Step 5: Run** the app tests for the provider: `cd mobile && mise exec -- flutter test test/providers/repository_providers_test.dart`, if it exists. Otherwise run whichever tests construct `followRepositoryProvider` (find them with `grep -rln followRepositoryProvider test/providers`).
- [ ] **Step 6: Commit:** `feat(follow_repository): keep the follower set on device and sync it incrementally`.

### Task 7 (B3): Account cleanup clears `my_followers`

**Files:**
- Modify: `mobile/lib/providers/social_providers.dart`. In the `!preserveActiveSession` block (:849-883), add `await requiredCleanup(() => db.myFollowersDao.clearAllForUser(userPubkey))` when `userPubkey != null`.
- Test: `mobile/test/providers/social_providers_cleanup_test.dart`

- [ ] **Step 1:** Write the failing test `account switch clears the departing owner's my_followers rows and keeps the other owner's`.
- [ ] **Step 2: Run** it and expect it to fail.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** it and expect it to pass.
- [ ] **Step 5: Commit:** `feat(cleanup): clear my_followers on account switch`.

---

## Part C — Ranking (PR 2, commits 4 onward)

### Task 8 (C1): The pure-Dart `user_ranking` package

**Files:**
- Create: `mobile/packages/user_ranking/`, copying the layout of `count_formatter`:
  - `pubspec.yaml`: `resolution: workspace`, `sdk: ^3.11.0`, dev dependencies `test ^1.26.3` and `very_good_analysis ^10.2.0`
  - `analysis_options.yaml`
  - `lib/user_ranking.dart`
  - `lib/src/user_ranking_signals.dart`
  - `lib/src/user_ranking_weights.dart`
  - `lib/src/rank_users.dart`
  - `test/src/rank_users_test.dart`
- Create: `.github/workflows/user_ranking.yaml`. Copy `count_formatter.yaml` and change the names and paths.
- Modify:
  - `mobile/pubspec.yaml`: add `  - packages/user_ranking` to the workspace (between `upload_repository` and `verifier_client`), and add a bare `user_ranking:` dependency with a comment line.
  - `mobile/scripts/baseline/package_coverage_floors.txt`: regenerate it with `UPDATE_BASELINE=1 bash mobile/scripts/check_package_coverage_floor.sh`, which adds the line `user_ranking 100`.
  - `.claude/rules/testing.md`: add `user_ranking` to the strict-coverage list.

**Interfaces:**

- **Produces:**
  - `class UserRankingSignals` with fields:
    - `String pubkey`
    - `DateTime? lastInteractionAt`
    - `bool youFollow`
    - `bool? followsYou` (null means unknown)
    - `bool hasVerifiedNip05`
    - `int? videoCount`
    - `DateTime? lastPostedAt`

    It is a const constructor with Equatable-style `==`. Implement it by hand; the package takes no equatable dependency.
  - `abstract final class UserRankingWeights`, holding the constants from Global Constraints.
  - `double scoreUser(UserRankingSignals s, {required DateTime now})`. A future date counts as age 0.
  - `bool isKnown(UserRankingSignals s)`: `lastInteractionAt != null || youFollow || followsYou == true`.
  - `List<String> rankUsers(Iterable<UserRankingSignals> candidates, {required DateTime now, required String Function(String pubkey) nameOf, bool interactionTierFirst = false})`:
    - Without tiers: sort by score descending, then `nameOf` (case-insensitive), then pubkey.
    - With `interactionTierFirst`: first the candidates with `lastInteractionAt`, by it descending; then the rest by score.
  - `List<String> promoteKnown(List<String> pageOrder, Map<String, UserRankingSignals> signals, {required DateTime now, required String Function(String) nameOf})`: known pubkeys first in `rankUsers` order, then everyone else in the order they arrived.

- [ ] **Step 1: Write the failing tests:**
  - `scoreUser` for each component at age 0, at the half-life (interaction 14 days scores 50.0) and at an absent value;
  - mutual scores 40, not 60;
  - the video-count curve: 0 → 0; 999 → 5.0; 9 gives `5 × log10(10) / 3`;
  - `someone messaged 10 days ago outranks a maxed-out never-messaged mutual`;
  - `one messaged 12 days ago can be overtaken`;
  - name, then pubkey, tiebreaks;
  - `interactionTierFirst` ordering;
  - `promoteKnown` keeps unknown users in arrival order;
  - a future-dated `lastPostedAt` counts as age 0.
- [ ] **Step 2: Run** `cd mobile/packages/user_ranking && mise exec -- dart test`. Expect it to fail.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `mise exec -- dart test --coverage=coverage`, and from `mobile/` run `mise exec -- flutter pub get`. Expect it to pass at 100%.
- [ ] **Step 5: Run** these guards and expect them to pass:
  - `bash mobile/scripts/check_package_ci_floor.sh`
  - `bash mobile/scripts/check_package_coverage_floor.sh`
  - `bash mobile/scripts/check_package_flutter_boundary.sh`
- [ ] **Step 6: Commit:** `feat(user_ranking): add pure-Dart closeness scoring`.

### Task 9 (C2): Batched local reads for ranking signals

**Files:**
- Modify:
  - `mobile/packages/db_client/lib/src/database/daos/profile_stats_dao.dart`: add `Future<Map<String, ProfileStatRow>> getStatsRawMany(List<String> pubkeys)`, chunked at 500.
  - `mobile/packages/db_client/lib/src/database/daos/nostr_events_dao.dart`: add `Future<Map<String, int>> newestCreatedAtByAuthor({required List<String> authors, required List<int> kinds})`. It runs `SELECT pubkey, MAX(created_at) ... WHERE pubkey IN (...) AND kind IN (...) GROUP BY pubkey`, chunked at 500.
  - `mobile/packages/profile_repository/lib/src/profile_repository.dart`: make `fetchBatchProfiles`'s `UserProfileFound` branch also write stats through `_cacheProfileStatsFromResult` (:807), and add `Future<void> refreshStatsForPubkeys(List<String> pubkeys)`. It calls `getBulkProfilesFromApi` in chunks of 100 and writes the stats.
- Test: the mirrored test files for `profile_stats_dao`, `nostr_events_dao` and `profile_repository`.

- [ ] **Step 1:** Write the failing tests:
  - `getStatsRawMany` returns only the rows that exist.
  - `newestCreatedAtByAuthor` returns one value per author, and a kind-1 note is ignored when video kinds are passed.
  - `fetchBatchProfiles persists videoCount to profile_stats`.
  - `refreshStatsForPubkeys chunks 250 pubkeys into 3 requests`.
- [ ] **Step 2: Run** each package's tests and expect them to fail.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** them and expect them to pass. `profile_repository` is strict-coverage, so it must reach 100%.
- [ ] **Step 5: Commit:** `feat(db_client,profile_repository): batched stats and newest-post reads`.

### Task 10 (C3): `UserRankingSignalsLoader`

**Files:**
- Create: `mobile/lib/services/user_ranking/user_ranking_signals_loader.dart`. Keep it to one file; the untested-services guard requires a test for every `.dart` file under `lib/services`.
- Create: `mobile/lib/providers/user_ranking_providers.dart` with `@riverpod UserRankingSignalsLoader userRankingSignalsLoader(Ref ref)`. It `ref.watch`es `dmRepositoryProvider`, `followRepositoryProvider`, `profileRepositoryProvider` and `databaseProvider`. Run build_runner.
- Test: `mobile/test/services/user_ranking/user_ranking_signals_loader_test.dart`

**Interfaces:**

- **Consumes:**
  - `MyFollowersDao.followerSubset` (B1)
  - `FollowRepository.isFollowing` / `syncMyFollowers` (B2)
  - `rankUsers`, `promoteKnown`, `UserRankingSignals` (C1)
  - `getStatsRawMany`, `newestCreatedAtByAuthor`, `refreshStatsForPubkeys` (C2)
  - `DmRepository.watchAcceptedConversations().first`
  - `Nip05VerificationsDao.getValidVerifications`
- **Produces:**

  ```dart
  class UserRankingSignalsLoader {
    UserRankingSignalsLoader({
      required DmRepository dmRepository,
      required FollowRepository followRepository,
      required ProfileRepository? profileRepository,
      required MyFollowersDao myFollowersDao,
      required ProfileStatsDao profileStatsDao,
      required NostrEventsDao nostrEventsDao,
      required Nip05VerificationsDao nip05VerificationsDao,
      required String currentUserPubkey,
      bool Function(String pubkey)? isBlocked,
      DateTime Function()? now,
    });
    Future<Map<String, UserRankingSignals>> load(Iterable<String> pubkeys);
    void refreshInBackground(List<String> rankedPubkeys);
  }
  ```

  - `load` makes no network call. It drops the viewer and blocked accounts, and reads only 1:1 conversations (group conversations are ignored).
  - `verified` means the row's status is `'verified'`.
  - `videoCount` comes from stats, falling back to `restVideoCount`.
  - `lastPostedAt` uses the kinds in `NIP71VideoKinds.getAllVideoKinds()`.
  - `refreshInBackground` runs through `runDetached`. It calls `followRepository.syncMyFollowers()` and `refreshStatsForPubkeys` for those of the first 100 whose stats are missing or more than 7 days old.

- [ ] **Step 1: Write the failing tests:**
  - signals built from seeded fakes: one DM'd mutual; one plain follow; one stranger with a verified NIP-05 and 12 videos;
  - `excludes self and blocked`;
  - `ignores group conversations`;
  - `load makes no network call`: `verifyNever` on `fetchBatchProfiles`, `refreshStatsForPubkeys` and `syncMyFollowers`;
  - `empty device returns empty signals without throwing`;
  - `refreshInBackground requests only stale stats among the first 100`.
- [ ] **Step 2: Run** `cd mobile && mise exec -- flutter test test/services/user_ranking/` and expect it to fail.
- [ ] **Step 3: Implement**, then run build_runner.
- [ ] **Step 4: Run** it and expect it to pass. Then run `bash scripts/check_untested_services_floor.sh` and `bash scripts/check_layer_direction.sh`.
- [ ] **Step 5: Commit:** `feat(ranking): load ranking signals from local stores`.

### Task 11 (C4): The share sheet ranks its contacts

**Files:**
- Modify: `mobile/lib/blocs/share_sheet/share_sheet_bloc.dart:38-57` (constructor) and `:98-247` (`_onContactsLoadRequested`)
- Modify: `mobile/lib/widgets/video_feed_item/actions/share_action_button.dart:183-198`. Pass `ref.read(userRankingSignalsLoaderProvider)`, matching the existing `ref.read`-in-initState pattern of that widget.
- Test: `mobile/test/blocs/share_sheet/share_sheet_bloc_test.dart`

**Interfaces:**

- **Consumes:** `UserRankingSignalsLoader.load` / `refreshInBackground` and `rankUsers(interactionTierFirst: true)`.
- **Behavior:**
  - The bloc gets a new required parameter, `UserRankingSignalsLoader rankingSignalsLoader`.
  - Candidates are `followingPubkeys` plus 1:1 DM counterparts, deduplicated, excluding self.
  - `recentlySharedWith` stays first, unchanged.
  - The rest come in `rankUsers(..., interactionTierFirst: true)` order, with names taken from the cached profiles.
  - The order is fixed at the first `ready` emit. The hydration emit keeps it: rows are updated in place, and rows that lose their identity are dropped as today.
  - `refreshInBackground` is called after the first emit.

- [ ] **Step 1: Write the failing bloc tests:**
  - `contacts are ordered by last DM, then score`
  - `recent shares stay first`
  - `hydration keeps the first order`
  - `a ranking load failure falls back to the old order and adds the error`. Wrap the error with `Reportable` only if it is a `StateError` or `TypeError`, per `error_handling.md`.
- [ ] **Step 2: Run** the test and expect it to fail.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the bloc tests and `test/widgets/video_feed_item/actions/share_action_button_test.dart`. Expect them to pass.
- [ ] **Step 5: Commit:** `feat(share): rank share-sheet contacts by closeness`.

### Task 12 (C5): The new-DM picker ranks its contacts

**Files:**
- Modify: `mobile/lib/screens/inbox/bloc/new_message_search_bloc.dart`:
  - constructor :25-46;
  - `_onStarted` :59-84;
  - replace `_sortedByPeerName` at :310-321 and its use in `_withRecomputedSearch` :326-351.
- Modify: `mobile/lib/screens/inbox/new_message_sheet.dart:83-97`. Pass the loader from `ref.read(userRankingSignalsLoaderProvider)`, and update `NewMessageSheet.show` in `inbox_view.dart:428-461`.
- Modify: the `contacts` doc comment in `new_message_search_state.dart`, which currently says "sorted alphabetically".
- Test: `mobile/test/screens/inbox/bloc/new_message_search_bloc_test.dart`

**Behavior:**

- Contacts are stored in ranked order (`interactionTierFirst: true`).
- The peer-label recompute keeps that order instead of re-sorting by name.
- Local filtering keeps the order.
- Network results still come first while searching, as today.

- [ ] **Step 1: Write the failing tests:**
  - `contacts are in ranked order`
  - `a peer label change keeps the ranked order`
  - `filtering keeps the ranked order`
- [ ] **Step 2: Run** them and expect them to fail.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the bloc tests and `test/screens/inbox/new_message_sheet_test.dart`. Expect them to pass.
- [ ] **Step 5: Commit:** `feat(dm): rank new-message contacts by closeness`.

### Task 13 (C6): Search puts people you know first within each page

**Files:**
- Modify: `mobile/lib/blocs/user_search/user_search_bloc.dart`:
  - constructor :42-61: add an optional `UserRankingSignalsLoader? rankingSignalsLoader`;
  - `_onQueryChanged` :92-280;
  - `_onLoadMore` :282-325.
- Modify the construction sites:
  - `search_results_page.dart:163-168`: watch the provider and add it to the existing record `ValueKey`;
  - `find_people_sheet.dart:90`
  - `user_picker_sheet.dart:206`
- Test: `mobile/test/blocs/user_search/user_search_bloc_test.dart`

**Behavior:**

- Each new page is reordered with `promoteKnown` before it is appended.
- Rows already shown never move.
- When the loader is null, the order is unchanged.

- [ ] **Step 1: Write the failing tests:**
  - `first page puts known users first`
  - `load more promotes only within the new page`
  - `null loader keeps server order`
- [ ] **Step 2: Run** them and expect them to fail.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the bloc tests and `test/screens/search_results/`. Expect them to pass.
- [ ] **Step 5: Commit:** `feat(search): promote people you know within each result page`.

### Task 14 (C7): A "Smart" sort for your own follow lists, made the default

**Files:**
- Create: `mobile/lib/blocs/follow_list_sort.dart`:

  ```dart
  enum FollowListSort {
    smart,
    newestFirst,
    oldestFirst;

    FollowSortOrder? get followSortOrder;
  }
  ```

  `followSortOrder` is null for `smart`.
- Modify:
  - `my_following_bloc.dart`, `my_following_state.dart`, `my_following_event.dart`
  - `my_followers_bloc.dart`, `my_followers_state.dart`, `my_followers_event.dart`

  Change: `sortOrder` becomes a `FollowListSort` that defaults to `smart`, and both blocs take a `UserRankingSignalsLoader`. In `_visiblePubkeys`, `smart` uses the order computed at load time and stored in state as `smartOrder` (a `List<String>`). The other two values use the existing `FollowSortOrder` paths.
- Modify: `lib/widgets/profile/follow_sort_menu.dart`. Offer three options: Smart first (`context.l10n.followSortSmart`, icon `.sparkle`), then Newest, then Oldest.
- Modify the screens `my_following_screen.dart` and `my_followers_screen.dart`. `ref.watch(userRankingSignalsLoaderProvider)`, and key the `MultiBlocProvider` children on `(followRepository, contentBlocklistRepository, loader)`.
- Modify: `mobile/lib/l10n/app_en.arb` and every `app_*.arb`. Add `followSortSmart`, translated in each locale's register (see `mobile/docs/LOCALIZATION_STYLE_GUIDE.md`), then run `flutter gen-l10n`.
- Test:
  - `test/blocs/my_following/my_following_bloc_test.dart`
  - `test/blocs/my_followers/my_followers_bloc_test.dart`
  - `test/screens/following/my_following_screen_test.dart`
  - `test/screens/followers/my_followers_screen_test.dart`
  - `test/widgets/profile/follow_sort_menu_test.dart` (create it if it does not exist)

- [ ] **Step 1: Write the failing tests:**
  - `default sort is smart`
  - `smart orders by score`
  - `switching to newest and back to smart restores the smart order`
  - `a follow added after load appends at the end under smart`
  - the menu shows three options with Smart selected, and its labels are asserted through `lookupAppLocalizations`.
- [ ] **Step 2: Run** them and expect them to fail.
- [ ] **Step 3: Implement**, then run `flutter gen-l10n` and build_runner if needed.
- [ ] **Step 4: Run** the tests above plus `test/l10n/arb_consistency_test.dart`. Expect them to pass.
- [ ] **Step 5: Commit:** `feat(follows): add smart sort and make it the default`.

### Task 15 (C8): The user picker and add-to-list rank by closeness

**Files:**
- Modify: `mobile/lib/widgets/user_picker_sheet.dart`. Replace the `_sortedByRenderedName` callers at :258, :300, :314 and :428 with the ranked order from the loader (`ref.read(userRankingSignalsLoaderProvider)`). Keep the mutual-only filter.
  - The re-sort on the vanished-account change (:428) must keep positions.
  - Moving this widget-state list into a cubit is out of scope, because it is an existing widget-state path. Do not add new ordering logic beyond calling the loader.
- Modify: `mobile/lib/features/people_lists/bloc/add_people_to_list_cubit.dart`. Its constructor takes the loader. `_compareCandidates` (:312-323) uses the score order computed in `started()` and stored in state, then falls back to the existing relationship rank for candidates that arrive later.
- Modify: `add_people_to_list_screen.dart:61-79`. Pass the loader.
- Test: `test/widgets/user_picker_sheet_test.dart`, `test/features/people_lists/bloc/add_people_to_list_cubit_test.dart`

- [ ] **Step 1: Write the failing tests:**
  - `picker lists DM'd mutuals before other mutuals`
  - `vanished update keeps positions`
  - `cubit candidates follow ranked order`
  - `a late candidate appends`
- [ ] **Step 2: Run** them and expect them to fail.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** them and expect them to pass.
- [ ] **Step 5: Commit:** `feat(people): rank pickers by closeness`.

### Task 16 (C9): The shared row indicator line, plus the "Posted" label

**Files:**
- Create: `mobile/lib/widgets/user_indicator_line.dart`. It is a `StatelessWidget` with the fields:
  - `String? identifier` (from `resolveUserIdentifierLine`)
  - `FollowRelationship relationship`
  - `bool isOgViner`
  - `int? videoCount`
  - `DateTime? lastPostedAt`
  - `DateTime now`

  It renders the parts joined by `' · '`. It shows `userRowPosted(LocalizedTimeFormatter.formatRelativeVerbose(l10n, seconds))` only when `now - lastPostedAt` is less than 7 days.
- Modify: `search_user_tile.dart:66-74`. Use the new widget, so the output stays the same apart from the new "Posted" part.
- Modify the vertical rows to render it under the name:
  - `_UserTile` in `new_message_sheet.dart:826`
  - `UserProfileTile` (follow lists)
  - `_UserSearchTile` in `user_picker_sheet.dart:679`
  - `PersonPickableRow`

  The rows read `lastPostedAt` and `videoCount` from their bloc's signals map, which is exposed in state as `Map<String, UserRankingSignals> rankingSignals`. Add that field to each state touched in Tasks C4–C8, except the share sheet: its horizontal row stays unchanged.
- Modify: `app_en.arb` and every `app_*.arb`. Add `userRowPosted`, with `@userRowPosted` placeholder metadata (`time`: String), then run `flutter gen-l10n`.
- Test:
  - `test/widgets/user_indicator_line_test.dart`
  - the existing tile tests for each modified row

- [ ] **Step 1: Write the failing tests:**
  - each part renders when it is present and is absent otherwise;
  - `Posted hidden at exactly 7 days`;
  - `Posted shown at 2 hours as "Posted 2h ago"`, asserted through `lookupAppLocalizations`;
  - `SearchUserTile output unchanged for a profile with no lastPostedAt`.
- [ ] **Step 2: Run** them and expect them to fail.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the tests, `test/l10n/arb_consistency_test.dart` and `bash scripts/check_orphaned_arb_key_floor.sh`. Expect them to pass.
- [ ] **Step 5: Commit:** `feat(people): show NIP-05, video count and recent posts on user rows`.

### Task 17 (C10): Ship PR 2

- [ ] **Step 1:** From `mobile/`, run:
  - `mise exec -- dart format` on the changed files
  - `mise exec -- flutter analyze lib test integration_test`
  - `bash scripts/ci/run_guards.sh`
  - the tests touched in B1–C9

  All must be green.
- [ ] **Step 2:** Measure latency in two parts.
  - **Scoring:** a benchmark script, not a test, at `mobile/packages/user_ranking/benchmark/rank_users_benchmark.dart`. Run it with `cd mobile/packages/user_ranking && mise exec -- dart run benchmark/rank_users_benchmark.dart`. It scores and sorts 5,000 synthetic candidates and prints the elapsed time.
  - **Local reads:** time the loader on a profile build on a device, with a 5,000-follow account if one is available.

  Record both numbers in the PR body; the budget is 50 ms on a mid-range phone. Do not use a tagged test for this: under `very_good test --optimization`, a tag does not exclude a bundled file, so the benchmark would run in CI.
- [ ] **Step 3:** `git fetch origin && git rebase origin/main && git push --force-with-lease -u origin feat/smart-user-ranking`.
- [ ] **Step 4:** Open the PR with `gh pr create --base main --title "feat(people): rank user lists by closeness using an on-device social graph"`. The body has one section each for the local social graph and for ranking. It flags the default-sort change and schema v22, and includes screenshots of the share sheet, the DM picker and the following list.
- [ ] **Step 5:** Run `gh pr checks <n> --watch`. Fix anything red, then request reviewers per `PR_REVIEW_TEAMS.md`.
