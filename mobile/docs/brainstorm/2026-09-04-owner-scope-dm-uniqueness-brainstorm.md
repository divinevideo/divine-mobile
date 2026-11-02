# Brainstorm: owner-scope direct message uniqueness (#6645)

Date: 2026-09-04

## Problem Statement

`direct_messages` and `conversations` key rows **globally** — by the NIP-17
rumor id and by the derived conversation id respectively — while every read is
owner-scoped by `owner_pubkey`. A peer's group send produces one rumor id
inside N distinct gift wraps, so when two local accounts' rows coexist the
second account's copy cannot be represented: `INSERT OR IGNORE` drops it, the
wrap is recorded as terminally processed, and no later drain recovers it.

## Constraints

- **Layering.** The defect is in `mobile/packages/db_client` (schema + DAOs);
  the consumers are `mobile/packages/dm_repository` and the app layer. A fix
  must not push protocol knowledge down into `db_client` or storage knowledge
  up into the blocs.
- **`data_foundation.md`.** Drift schema evolution goes through real
  migrations with `schemaVersion` bumped, a generated snapshot under
  `drift_schemas/app_database/`, and a `migration_test.dart` case. The
  `beforeOpen` repair block is a compatibility bridge, not the place for new
  schema work.
- **Migration history.** v1 → v11 is additive (`_addColumnIfMissing`,
  `createTable`, `createIndex`) with one exception: the `from < 3` step uses
  `m.alterTable(TableMigration(identityEvents, newColumns: [...]))`, which is a
  real drift table rebuild. So precedent exists, but no migration has ever
  changed a primary key.
- **SQLite NULL semantics (measured, 3.51.0).** NULLs compare distinct in a
  unique constraint, so a composite key over a *nullable* `owner_pubkey` would
  stop deduplicating legacy NULL-owner rows — silently breaking the issue's own
  acceptance criterion 2.
- **Protocol.** NIP-59 gives every gift wrap a fresh ephemeral key and exactly
  one `p` tag, so the two recipients' wrap ids differ. The rumor id is shared
  because NIP-17 seals one rumor per group message. Neither is negotiable
  client-side.
- **Recovery reality.** `_alreadyProcessed` consults the processed-wrap ledger
  **before** decryption, so anything already ledgered is invisible to every
  future drain unless the ledger is touched.

## Prior Art

- `DmMessageReactions` — PK `{id, ownerPubkey}` with a **NOT NULL** owner. The
  dartdoc states the reason plainly: "on a multi-device account both wraps can
  arrive locally and must collapse to one row." This is the same problem,
  already solved once, in the same file.
- `RemovedConversations` — PK `{conversationId, ownerPubkey}`, owner NOT NULL.
- `PendingGiftWraps` — non-nullable owner that is part of the primary key;
  #8119 called this out as the reason it "needs no legacy handling."
- `#8119` claimed legacy NULL-owner rows at session setup and scoped the
  account-switch deletes, deliberately preserving other accounts' rows.
- `DmSyncState.currentDrainVersion` (now 5) with `upgradeDrainVersionIfNeeded`
  — the sanctioned forced-recovery lever, bumped four times (#5202, #5304,
  #8209, #8362). Its own doc records that funnelcake retains kind 1059
  indefinitely.

## Approaches Explored

### Approach A — Composite primary key with a NOT NULL owner

**Description:** `owner_pubkey` becomes `NOT NULL` with a `''` default;
`primaryKey => {id, ownerPubkey}` on `direct_messages` and
`{id, ownerPubkey}` on `conversations`. A v12 migration rebuilds both tables,
backfilling `NULL → ''`. `_ownedOrLegacy` widens to treat `''` as legacy
alongside `NULL`.

**Layers affected:** Client (`db_client` schema + both DAOs), Repository
(`dm_repository` only where it reads `ownerPubkey` off a row).

**Pros:**
- Identical in shape to `DmMessageReactions` and `RemovedConversations`, so
  reviewers meet a pattern the schema already contains twice.
- `''` is already this codebase's legacy sentinel — `clearForAccountSwitch`
  and `clearUnowned` both test `owner IS NULL OR owner = ''` today.
- Legacy dedup is preserved exactly: two `('R','')` rows still collide.
- Existing DAO tests that omit `ownerPubkey` keep compiling and passing,
  because the default supplies `''`.

**Cons:**
- Needs a table rebuild for two tables and a backfill.
- `_ownedOrLegacy` must be widened in the same change or backfilled rows go
  invisible to every owner-scoped read. That coupling is the main review risk.

**Risks / Unknowns:** the read predicate and the delete predicate disagree
today (`_ownedOrLegacy` tests only `IS NULL`; the deletes test both). Widening
the read is a behaviour change for any row that already carries `''`.

**Complexity:** Medium.

### Approach B — Keep the column nullable, use a COALESCE expression index

**Description:** Leave `owner_pubkey` nullable. Drop the declared primary key
so the table falls back to an implicit rowid, and add
`CREATE UNIQUE INDEX ... ON direct_messages (id, COALESCE(owner_pubkey, ''))`.

**Layers affected:** Client only.

**Pros:**
- No backfill, no `_ownedOrLegacy` change, no NOT NULL constraint to satisfy.
- Measured correct: legacy NULL rows still dedup, two owners each get a row.
- The repo already declares raw-SQL indexes in `Table.indexes`, so it is
  expressible without new machinery.

**Cons:**
- Removing the declared primary key changes drift's row-identity semantics for
  generated update/delete-by-PK helpers, and nothing else in this schema is
  shaped that way.
- An expression index is invisible to anyone reading the Dart table
  declaration for the key; the invariant stops being self-documenting.

**Risks / Unknowns:** how much generated code depends on
`$DirectMessagesTable.$primaryKey` being non-empty.

**Complexity:** Medium — smaller migration, larger conceptual surprise.

### Approach C — Do not touch the schema; make the ingest owner-aware

**Description:** Leave the keys global. In `_persistDecryptedGiftWrap`, when
the insert is ignored, check whether the existing row belongs to a *different*
owner and, if so, synthesise a locally-unique id (e.g. `${rumorId}:${owner}`)
before retrying.

**Layers affected:** Repository only.

**Pros:** no migration, no rebuild, ships in one file.

**Cons:**
- Puts a fabricated value in the `id` column, which the codebase treats as the
  real rumor id in at least four places (reply-`e`-tag resolution, deletion
  targeting, group recovery, cross-protocol twin matching). Fixing one
  invariant by breaking another.
- Leaves `conversations` untouched, so the room steal survives.
- The rule that DM ids are real protocol ids is load-bearing for
  `_arrivedOverCounterpart`, which distinguishes NIP-04 rows by
  `id == gift_wrap_id`.

**Complexity:** Low to write, High to live with. **Rejected.**

### Approach D — Delete the coexistence instead of representing it

**Description:** Make the account-switch cleanup unconditional again so only
one account's DM rows ever exist, closing the reachability path without
touching the schema.

**Layers affected:** App layer (`social_providers`, `auth_service`).

**Pros:** small, and it targets the actual trigger.

**Cons:**
- Straight revert of #8119, which fixed a *reproduced* physical-device bug:
  unqualified deletes destroyed every account's DM history on an ordinary
  switch.
- Leaves the schema unable to express a state the product's own comments say
  it wants ("Known-owner rows for every other saved account remain intact").
- Trades a rare permanent loss for a common one. **Rejected.**

## Recommendation

**Approach A, applied to both `direct_messages` and `conversations`**, plus the
ledger recovery described below.

It is the only option that makes the schema express what the reads already
assume, and it does so with a shape this very file already uses twice. Approach
B is defensible but makes the key invisible at the declaration site and removes
a declared primary key for no gain over A once the backfill is written.
Approaches C and D each fix one invariant by breaking another.

**Recovery:** v12 preserves `processed_gift_wraps` and does not force a history
re-drain. The v11 ledger records that a wrap reached a terminal outcome, but not
which outcome: an unmatched row can be a reaction, deletion, unsupported kind,
tombstone-suppressed event, collapsed cross-protocol twin, or a message whose
insert was stranded by the old key. A migration cannot distinguish those cases
from the absence of a `direct_messages` row, so deleting unmatched entries would
guess that valid terminal decisions were failures. Historical recovery needs
positive outcome provenance; this migration fixes future persistence without
destroying evidence that prevents duplicate processing.

## Open Questions for /plan

- [x] Composite PK vs expression index — **A**, confirmed.
- [x] Include `conversations` — **yes**, same PR.
- [x] Recovery shape — preserve the outcome-ambiguous ledger; no drain bump.
- [x] The `signOut` trigger (`auth_service.dart:3199` / `:3397`) — reported,
      not fixed here.
- [x] Does `idx_dm_gift_wrap_id` stay globally unique, or become
      `(gift_wrap_id, owner_pubkey)`? Global is currently correct because a
      wrap has one recipient; leaving it alone is the smaller diff.
- [x] Does `processed_gift_wraps` need an owner-scoped key, or is its global
      key still right for the same reason?
- [x] Do `hasGiftWrap` / `giftWrapIdsPresent` stay global once the message key
      is owner-scoped?

> **Update (schema v32, #6645).** The three answers above held for an inbound
> gift wrap only. An outgoing row stores the recipient's wrap id and a kind-4
> id is shared by both ends, so with both accounts on one device one id sat on
> two accounts' rows and the second one was dropped. The index became
> `(gift_wrap_id, owner_pubkey)` and both lookups owner-scoped; the ledger kept
> its single-column key. See `DM_RETENTION.md`, "Dedup is per account".

## Prerequisites

- [x] Regenerate the drift schema snapshot (`drift_schemas/app_database/drift_schema_v12.json`)
      and the migration-test helper (`test/drift/app_database/generated/schema_v12.dart`).

## Next Step

`/plan 6645`.
