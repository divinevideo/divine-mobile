# Brainstorm: bounding and migrating `PersonalEventCacheService`

Date: 2026-08-29
Issue: #6986 · Epic: #4335 · Findings: `tasks/findings_6986.md`
Baseline: `main` @ `f99d287eb`

## Problem Statement

`PersonalEventCacheService` keeps the signed-in user's own Nostr events in two
hand-rolled Hive boxes with no TTL, no cap, and no eviction. Measured on real
`hive_ce`: **42.5 KiB per contact-list broadcast**, strictly linear, and the events box
**never compacts** (keys are unique, so `deletedEntries` stays 0 and both compaction
guards refuse). At 100 broadcasts that is 4.35 MB and **168 ms of blocked main isolate**
at sign-in; at 1,000 it is 41.5 MiB, and because `Hive.openBox` is non-lazy, file size
is also resident RAM.

The growth is invisible three separate ways: the Storage screen measures four temp
directories and not `{appSupport}/openvine`, every log line in the service is
`LogCategory.storage` which is off by default, and `getCacheStats` filters to the
current account so it cannot report the cross-account total.

## Constraints

| # | Constraint | Source |
|---|---|---|
| C1 | `video_event_publisher.dart` is a frozen god-file: ceiling **2303**, current **2298**. No sanctioned raise path. | `scripts/baseline/service_god_file_sizes.txt`, AGENTS.md |
| C2 | Three prior Hive→Drift attempts in this repo all died at "added a DAO, never cut over". | `6679ce7f3`→`c6d90090b`; `refactor/pending-upload-drift-3347` (local only); `9b3010aca` (#357) |
| C3 | `cache_sync` cannot host this — no prefix/range read, watch closes after the live event, LRU evicts never-rewritten entries first. | #4335 comment, 2026-08-10 |
| C4 | `deleteExpiredEvents` deletes `expire_at IS NULL`, and `upsertEvent` cannot express NULL (`expireAt ?? _defaultExpireAt()`). | `nostr_events_dao.dart:49,598` |
| C5 | The Drift directory is protected wholesale by cache recovery, so migrating silently flips this data disposable → durable. | `cache_recovery_service.dart:137-140` |
| C6 | Schema changes must be versioned migrations. *"Do not add new tables… to `beforeOpen`."* | `db_client/MIGRATIONS.md` |
| C7 | #5001's 100-entry pre-init queue and #5701's per-account read isolation must survive, with tests. | issue acceptance criteria |

**Decisions taken before exploring** (recorded so the reasoning is auditable):
façade stays and only the backing store changes (C1); full cutover in one PR (C2);
drop at upgrade, no backfill (the data is already classified disposable); and the
contract splits by lifetime — kind 3 disposable, retry events and raw video tags durable.

## Prior Art

- `HiveToDriftMigrator` (`6679ce7f3`, deleted by `c6d90090b`) — the only complete
  migration design this repo has produced: one-time, idempotent, SharedPreferences flag,
  Hive left in place for rollback, per-record failure isolation. Its own guide listed
  **"Personal events"** as an explicitly planned, never-executed phase.
- #357 (`9b3010aca`) added four DAOs with *no* data migration and deleted the migration
  guide in the same commit.
- #7811 (`6f34cafdd`) is the working template for **adding a table**: 13 files, ~20k
  lines, almost all generated.
- `cache_sync` — the AGENTS.md default, already evaluated and rejected for this data.

## Approaches Explored

### Approach A — One new Drift table with a retention discriminator ⭐

A `personal_events` table in `db_client` (schemaVersion 11 → 12) holding one row per
event: `id` (PK), `pubkey`, `kind`, `created_at`, `tags`, `content`, `sig`, plus a
`retention` discriminator. The DAO applies the lifetime rule on write — replaceable
kinds (0, 3, 10000–19999) delete the prior `(pubkey, kind)` row before inserting;
everything else is durable and capped. `PersonalEventCacheService` keeps its public API
exactly and becomes a thin adapter over the DAO. Both Hive boxes are deleted and removed
from `HiveBoxNames`.

**Layers:** Client (new Drift table + DAO) and the service that fronts it. **No BLoC or
UI changes. No caller changes.**

**Pros**
- Touches `video_event_publisher.dart` **zero times** — satisfies C1 outright.
- Never enters the `event` table, so C4 and the `d_tag` delete-all hazard simply do not
  apply — no sentinel, no NULL-semantics change, no exclusion logic to maintain.
- One row per event, one transaction, **no separate index** → structurally eliminates
  the non-atomic two-box window and closes **#6280** as a side effect.
- `getEventsByKind(3)` becomes an indexed `WHERE kind=? AND pubkey=? ORDER BY created_at
  DESC` returning one row — the 97 ms full materialisation and the discarded SHA-256 per
  event both disappear.
- Account isolation becomes a `WHERE pubkey = ?` predicate instead of a post-hoc filter,
  so cost stops scaling with other accounts' rows.
- Follows the #7811 template exactly.

**Cons**
- Adds a table to a database that already has 11 versions of migration history.
- Duplicates a little of `NostrEventsDao`'s query surface.
- C5 still applies: the new table sits in the protected Drift directory, so cache
  recovery must be taught to clear it or the disposable half silently becomes durable.

**Risks / Unknowns**
- The durable cap value is a judgement call (see open questions).
- `dart run drift_dev make-migrations` must produce a clean v12 snapshot; the migration
  test is the gate.

**Complexity:** Medium

---

### Approach B — Two new Drift tables, one per lifetime

`personal_replaceable_events` (collapse on `pubkey`+`kind`) and
`personal_durable_events` (capped, never swept). Each table carries exactly one lifetime
rule with no discriminator column.

**Pros** — the split by lifetime is expressed in the schema rather than in a column, so
neither table can be queried under the wrong policy.
**Cons** — two tables, two DAOs, two snapshots, two migration steps, and the service has
to route every read across both to answer `getEventById`, which the retry path calls with
no kind context. That routing is exactly the sort of implicit coupling the single-table
version avoids.
**Complexity:** Medium-High

---

### Approach C — Shared `event` table for the disposable half, new table for the durable half

Kind 3 goes into the existing `event` table via `upsertEvent` (post-#8318 it collapses
correctly and for free, and participates in the ordinary 1-day TTL, which is *correct*
for a disposable cache). Retry events and raw video tags go into a small new table.

**Pros** — no new storage at all for the single biggest consumer; reuses the indexed,
well-tested `NostrEventsDao`; the "disposable" classification becomes literal rather
than declared.
**Cons** — it makes the design depend on #8318 landing first. It subjects the user's own
kind 3 to relay-ingest upsert rules, so a relay-delivered copy and a locally-published
copy race on `created_at` at one-second resolution — two follow actions in the same
second collide, and the second is discarded (`<=` at `:132`). It also loses
`_loadFromPersonalEventCache` entirely after 24 h, changing cold-start tier behaviour.
**Risks** — the same-second collision is a genuine new failure mode that today's
id-keyed Hive store does not have.
**Complexity:** Medium

---

### Approach D — Bound Hive in place, defer the migration

Keep both boxes; collapse replaceable kinds on write, cap the durable half, delete
`SocialEventServiceBase`.

**Pros** — smallest possible risk; no schema change; satisfies every acceptance criterion
except "migrate"; and it is the only approach with no exposure to C2.
**Cons** — leaves the hand-rolled store the issue exists to remove, keeps the non-atomic
two-box write (#6280 stays open), keeps the non-lazy full-file read at sign-in, and keeps
the account filter as a post-hoc mask.
**Complexity:** Low

*Set aside by the explicit decision to do a full cutover, but recorded because it is the
honest fallback if the migration proves larger than one reviewable PR.*

## Recommendation

**Approach A.**

It is the only option that satisfies C1 (the five-line god-file headroom) without
requiring a shrink, sidesteps C4 and the `d_tag` hazard by construction rather than by
carefully-maintained exclusion logic, and eliminates an entire open bug (#6280)
structurally rather than by patching a race window. It follows the #7811 template that
already works in this repo, and — critically against C2 — it is a complete cutover in one
PR rather than a DAO added beside a still-live Hive box, which is precisely how the
previous three attempts died.

Approach C is genuinely attractive for the disposable half and would cost the least
storage, but it trades a well-understood problem (a box that grows) for a new one
(second-resolution `created_at` collisions on the user's own writes), and it couples this
work to another PR landing first. Not worth it.

## Open Questions for /plan

- [ ] What cap for the durable half — a row count, an age, or "keep while a referencing
      `PendingUpload` exists"? Note L-2: the key (`upload.nostrEventId`) is deleted by
      `cleanupCompletedUploads` on the launch after a successful publish, so rows are
      **unreachable**, not merely un-evicted. A reference-based rule would collect them
      exactly; a count cap is simpler.
- [ ] How does cache recovery clear the new table (C5)? Add it to a disposable-table list,
      or give the DAO a `clearForOwner` that `clearAllCaches` calls.
- [ ] Does `resetCurrentUser` keep hiding-not-deleting, or start deleting? Two tests pin
      the current hide semantics.
- [ ] Where does the drop-at-upgrade delete live, given C6 forbids `beforeOpen`? Probably
      `HiveStorageService` (which already owns box lifecycle) rather than the migration.
- [ ] `cached_at` is written twice per event and read nowhere — drop it, or make it the
      basis of the durable cap?
- [ ] Should `getCacheStats` / `_logCacheStatistics` be deleted outright? Decided: yes.
- [ ] Add the missing test for a failed cache write (L-1 — no such test exists today).

## Prerequisites

- [x] #8318 (`_upsertReplaceableEvent` collapse fix) — **not** a blocker for Approach A;
      it was a prerequisite only for Approach C. Already merged-ready, CI green.
- [ ] Confirm with the #4335 DRI that "personal events are a disposable cache with a
      durable minority" is the intended contract, since it makes `CacheRecoveryService`'s
      existing classification authoritative.
- [ ] Coordinate with #8266 and #7595, which touch `follow_repository` in the same region.

## Next Step

`/plan 6986` with Approach A.
