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

`db_client`'s v1 is a special case for whoever writes its first real
migration. Because the repair block lives in `beforeOpen`, two installs can
both report `user_version = 1` with different tables, columns, and indexes on
disk — and Drift runs `onUpgrade` *before* `beforeOpen`, so the repair has not
run yet when the upgrade step executes. Make the first `1 -> 2` step
idempotent (probe `sqlite_master` / `PRAGMA table_info` before altering), and
treat the generated v1 snapshot as the declared schema rather than as what
every install actually has.

See #6921 for the tracked `db_client` repair-to-migration cleanup.

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
