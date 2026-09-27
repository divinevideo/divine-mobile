# Data Foundation

Use this rule whenever new work chooses where data should live, how it is
cached, or how a local schema evolves.

## Default Decision Tree

1. **Remote-derived cacheable data** defaults to `cache_sync`.
   This includes data fetched from REST, GraphQL, relays, or other network
   sources when the app can refetch it and callers benefit from
   stale-while-revalidate behavior.
2. **Structured durable app data** belongs in Drift, usually through
   `mobile/packages/db_client`.
   Choose Drift when data needs queries, relationships, indexes, reactive
   streams, account-scoped cleanup, schema evolution, or durable offline
   behavior that is more than a small setting.
3. **Small local-only preferences** may use `SharedPreferences`.
   Keep it to scalar settings, dismissals, feature flags, last-selected UI
   options, and other values where losing the value is recoverable and no
   query/schema model is needed.
4. **Secrets and signing material** never belong in these general stores.
   Use `mobile/packages/nostr_key_manager` and its secure-storage path.
5. **Media bytes and file downloads** use the owning media cache or file
   pipeline, such as `mobile/packages/media_cache`, not ad hoc rows in app
   data stores.

If a value fits multiple buckets, prefer the more structured shared store.
Avoid inventing a feature-local persistence layer just because it is faster to
wire in the moment.

## `cache_sync` Is The Default Cache

For new remote-derived cacheable data, use `cache_sync` unless there is a
clear reason not to.

Good `cache_sync` candidates:

- profile, list, feed, count, or metadata responses that can be regenerated
  from relays or APIs
- data where showing cached content immediately is better than blocking on a
  fresh network response
- account-scoped cache entries that can be invalidated by key prefix
- simple JSON payloads that do not need relational queries

When adding a `cache_sync` cache:

- choose a key shape that is stable, explicit, and scoped by pubkey when the
  data is account-specific. Account-scoped keys should follow the
  `${pubkeyHex}:${operation}` convention from `cache_sync` (RFC #4244) so
  `CacheSync.invalidatePrefix(pubkeyHex)` clears that account's entries at
  sign-out without touching other accounts.
- set a TTL that matches the product freshness expectation
- define invalidation at the repository or service boundary that owns the
  data, not in the UI
- keep serialization failures and corrupt entries recoverable by refetching

Do not create a new cache service, in-memory singleton, Hive box, or
SharedPreferences JSON blob for remote-derived cacheable data until
`cache_sync` has been ruled out in the PR notes.

## Drift Owns Durable Structured Data

Use Drift when the app is the durable owner of structured local state or when
the local copy needs database behavior.

Prefer Drift for:

- drafts, pending queues, outbox state, local-only collections, and offline
  workflow state
- denormalized tables that need indexes, joins, ordering, pruning, or reactive
  watchers
- local data that must survive app restarts and account switches with clear
  cleanup semantics
- data that requires migrations as fields or invariants change

Durable local-only user data belongs in Drift once it grows beyond a small
preference. `SharedPreferences` should not become a hidden document store.

## SharedPreferences Is Narrow

`SharedPreferences` is acceptable for small, flat, local-only values:

- booleans, enums, timestamps, and simple strings
- one-off dismissal or onboarding flags
- user preferences such as selected modes or display options
- compatibility reads while migrating legacy values into the correct store

Do not use `SharedPreferences` for remote caches, lists of domain objects,
large JSON payloads, append-only histories, queues, or anything that needs
partial updates, indexes, or schema migration.

## Hive Is Legacy By Default

New Hive boxes require explicit justification in the issue or PR. The
justification must explain:

- why `cache_sync` is not appropriate
- why Drift is not appropriate
- how corruption, migration, account cleanup, and low-storage behavior are
  handled
- how the box will be tested

Existing Hive-backed paths can stay while they are being retired
incrementally, but new work should not expand Hive usage without a deliberate
storage decision. Known legacy owners include the hashtag and personal-event
cache services, notification preferences, pending/resumable upload state, the
people-lists local cache, and cache recovery.

## Drift Schema Changes Use Real Migrations

For `db_client` and other Drift databases, schema evolution belongs in Drift
migrations.

- Bump `schemaVersion` when the schema changes for existing installs.
- Add `MigrationStrategy.onUpgrade` steps for table, column, index, and data
  migrations.
- For `db_client`, keep generated snapshots under
  `mobile/packages/db_client/drift_schemas/app_database/` and migration tests
  in `mobile/packages/db_client/test/drift/app_database/migration_test.dart`.
- Use `beforeOpen` for startup cleanup and validation only, not as the primary
  place to accumulate `CREATE TABLE IF NOT EXISTS` or `ALTER TABLE` repair SQL.

Startup repair SQL may be used only as a narrow compatibility bridge for
already-shipped damage, and should not be the pattern for new schema changes.

`db_client` now has a versioned `onUpgrade` chain and committed snapshots for
every schema version. Its `1 -> 2` normalization remains deliberately
idempotent because historical v1 installs can report the same `user_version`
while carrying different tables, columns, and indexes. The guarded
`beforeOpen` repair path is retained only for damaged or manually mutated
databases that opened without an upgrade; extend the versioned migration chain,
not that recovery path, for new schema changes. Because Drift runs `onUpgrade`
before `beforeOpen` and marks that open as upgraded, any new migration reachable
from an older damaged schema must re-run the relevant idempotent repair steps
within `onUpgrade`.

## Retention And Eviction For Existing Stores

Choosing a store (the decision tree above) is a one-time call. A table that
keeps growing after that — one row per pubkey ever seen, one row per event
ever ingested — needs its own answer to "does this ever shrink, and how."
#6987 found `db_client` had gone from 16 tables in May to 25 by August with
only four ever swept (`AppDatabase.runStartupCleanup`, all TTL-based), and
worked through what a real retention policy looks like for the rest. The
patterns below are the reusable output; a new table crossing a real growth
risk should pick one rather than shipping unbounded by default.

**Row cap on an honest recency column** (`user_profiles`). Delete
oldest-first once a table exceeds a cap, ordered by whichever column
actually advances when the row is still relevant. `user_profiles` doesn't
have a true last-*read* timestamp — only `last_fetched`, a last-*write*
stamp — but a profile that's still relevant keeps getting refetched, which
keeps its `last_fetched` current and protects it from eviction without
needing a dedicated read-tracking column. Prefer this approximation over
adding a real last-accessed column that writes on every read: for a table
touched on every feed scroll, that write amplification is worse than the
approximation's imprecision.

**Orphan sweep against the table it derives from** (`video_metrics`). When a
table is a denormalized derivative of another (metrics parsed from an
event's tags), and the two aren't kept in sync by a database-enforced
constraint, sweep it explicitly rather than relying on the constraint. Two
tables in `db_client` declare a `customConstraints` foreign key with `ON
DELETE CASCADE`, but `PRAGMA foreign_keys` is never enabled on this
connection (`DraftsDao.deleteDraft`'s comment is the canonical note on why),
so neither cascade fires on its own. Don't flip that pragma on to fix one
table: it's a schema-wide behavior change — every declared FK starts being
enforced, including insert-order assumptions elsewhere that were written
assuming it's off — for a fix that a scoped sweep (`DELETE FROM video_metrics
WHERE event_id NOT IN (SELECT id FROM event)`) gets just as well, run
alongside whatever already deletes rows from the parent table.

**Keep a dedup ledger while its history is replayable** (`processed_gift_wraps`).
The DM history drain checks this table when it revisits old relay history, not
only when a relay redelivers a wrap. Pruning terminal outcomes makes reactions,
deletions, unsupported kinds, and wraps suppressed by a removed conversation
eligible for decryption again. These rows stay unbounded while the account is
active until measured growth justifies a policy that preserves the drain's
deduplication behavior.

**Unbounded on purpose, written down as a decision** (`identity_events`,
`identity_verifications`). Not every table needs an eviction path — but
"unbounded" has to be a decision made in the table's own doc comment, not
silence. These two looked at first like they should ride on `user_profiles`'
row cap, being keyed by the same pubkey and refreshed on the same "profile
opened" trigger. That sweep was implemented, and a **shipped migration
test caught it as wrong**: `v2 identity_events rows survive the upgrade
unstamped` seeds an `identity_events` row with no corresponding
`user_profiles` row at all, because identity claims can be fetched and
cached independently of a kind-0 profile fetch, and the test expects that
row to survive. Tying eviction to `user_profiles` presence silently deleted
still-valid claims for a pubkey whose profile was never cached, with no
re-fetch trigger to recover them — the sweep was reverted, and the tables
are documented unbounded-while-signed-in instead (both already clear on
logout and account switch), bounded in practice by session length and by
how few viewed profiles publish NIP-39 claims at all. The lesson generalizes:
a plausible-sounding tie between two tables sharing a key column is a
hypothesis, not a fact, until something that writes real data — a test with
real fixtures, not just reading the code — confirms the two are actually
never independent.

When writing a table's retention policy into its doc comment, name the
mechanism and where it runs (`FooDao.method`, called from
`AppDatabase.runStartupCleanup`), not just "bounded." A future reader — or
guard script — needs to find the code, not re-derive that it exists.

## Account-Boundary Cleanup

Any store holding one account's data must be cleared when a different account
signs in. Two rules, both learned the expensive way (#8314 / #6985).

**Name the key by reference, never by copy.** `UserDataCleanupService`
references the constant each writing service declares. A copied literal has no
referent, so when a service renames or deletes its key nothing notices — that
is how eleven entries in the sweep became silent no-ops and how the moderation
leak survived four days after the list was written.

**Moving a store between layers moves its cleanup too.** `seen_videos`, the
personal-event cache and the push-notification preferences each migrated from
SharedPreferences to Drift or Hive and left a `clear` method behind with no
caller. The sweep kept faithfully clearing the pre-migration keys while the
live store accumulated the departing account's data.

Classify every new preference key as one of:

| Category | Meaning |
|---|---|
| user-scoped | referenced from `userSpecificKeys`; cleared on identity change |
| device-scoped | declared in a `deviceScopedPrefsKeys` list beside the constant |
| pubkey-scoped | the key embeds the pubkey, so it cannot leak by construction |
| prefix-swept | matched by `identityChangePrefixes` |
| device gate for user data | a migration flag; cleared **with** the data it gates, never alone |
| scoping key | other key names derive from it; **never swept on its own** |

The last two are not tidiness. Clearing `content_filter_prefs` without
`content_filter_migrated` gives the next account an empty map instead of
defaults; sweeping `blocklist_active_pubkey` unscopes every other key in
`content_blocklist_repository`.

Distinguish a **leak** (the next account inherits data) from **incomplete
deletion** (a removed account's rows linger). The `Pending*` tables carry owner
columns and are filtered at flush, so they never leaked — they are cleaned on
`deleteAccountData`, scoped by owner. An unscoped delete there would destroy a
still-signed-in account's queued work.

Enforced by `check_prefs_key_classification.sh`; see AGENTS.md.

## Review Checklist

Before approving a data/storage change, confirm:

- the selected store matches the decision tree above
- account-scoped data has account-scoped keys or cleanup
- remote caches have explicit freshness and invalidation behavior
- durable local data has migration and recovery behavior
- new Hive usage has a written justification
- Drift schema changes are represented as real migrations
