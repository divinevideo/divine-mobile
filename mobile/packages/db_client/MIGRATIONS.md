# Drift Database Migrations

This document describes how to manage database migrations for the `db_client` package using [Drift](https://drift.simonbinder.eu/).

## Current Schema Version

**Version: 27** (see `app_database.dart`).

Version 2 is the legacy-normalization baseline. Earlier releases kept Drift's
user-version at 1 while startup repair SQL added tables, columns, indexes, and
backfills in `beforeOpen`. The v1 -> v2 migration is intentionally idempotent so
any shipped v1 database shape can be brought to the current schema.

Version 3 adds `identity_events.source_created_at` and
`identity_events.source_event_id` (#7081), so a cached kind-10011 identity
event can be recognised as newer than the one a later relay read returns. The
v2 -> v3 step rebuilds the table from its current definition, which lands on
the same shape whether v1 normalization created the legacy three-column table
or the current one. `profile_statistics.follower_counts_updated_at` (#6911)
was later folded into v3 while it was still unreleased, so a database cut at
the original v3 gains that column from the idempotent v3 repair instead.

Version 4 adds the `clip_categories` table plus `clips.category_id` and
`clips.archived_at` (#7094), so library clips can be filed under a
user-created category and archived out of the default view.

Version 5 adds `pending_view_events.video_addressable_d_tag` (#7169), so a
queued view event keeps the `d` tag it needs to address its subject. The
v4 -> v5 step also copies a pre-existing `video_vine_id` into the new column
when it is not the event-id fallback, recovering the stuck backlog, and
re-runs the v3 repair so original-v3 databases converge in the same upgrade.

Version 6 adds `pending_view_events.video_event_kind` (#7399), so a queued
view event keeps the kind it needs to classify its subject.

Version 7 moves 15 index definitions out of `List<Index> get indexes` getters
and into `@TableIndex.sql()` annotations (#7040). Drift never read those
getters, so the indexes existed on no database at all; the v6 -> v7 step
creates them for every database that already exists. Note that the bump to 7
is what makes that step reachable — a database already sitting at v6 runs no
`onUpgrade` at all while `schemaVersion` stays 6, so folding index creation
into the `from < 6` block would skip every install that had already reached
v6.

Version 8 adds `pending_view_events.phase`, so a queued view event records
whether it is a `start` or `end` of a two-phase view session. Pre-existing
rows stay NULL and replay as legacy single-shot events, which the relay
continues to count as views. The `from < 8` step also re-runs the idempotent
repair chain: `hadUpgrade` suppresses the `beforeOpen` repair on an upgrading
open, so a damaged older database would otherwise keep its damage until some
later launch that happens to perform no upgrade.

Version 9 adds owner-scoped `removed_conversations` tombstones. Relay history
at or before the removal timestamp stays suppressed after local DM rows are
deleted, while a genuinely newer message can reopen the conversation.

Version 13 adds `personal_events`, replacing the hand-rolled `personal_events` /
`personal_events_metadata` Hive boxes (#6986). It deliberately has no `expire_at`
column: `deleteExpiredEvents` on the shared `event` table removes rows whose
`expire_at` IS NULL as well as past-dated ones, so a personal event stored there
would be destroyed on the next cold start. Retention is decided per row instead —
replaceable kinds collapse to one row per `(pubkey, kind)`, everything else is
trimmed to a per-owner cap. The `from < 13` step creates the indexes explicitly,
because `createTable` does not emit `@TableIndex.sql` indexes and a fresh install
would otherwise disagree with an upgraded database — the same divergence v7 had to
backfill.

Version 14 adds `pending_view_events.app_version` (#9077), the version of the
build that recorded a queued view. The healthy path flushes a row immediately,
so the published `version` tag normally matches the recording build; a failed
row can outlive an app update, and replaying it with the successor's runtime
version understated the release that dropped the view and inflated the one that
restored publishing. Pre-existing rows stay NULL and replay without a `version`
tag: nothing on such a row says which build recorded it, and the build replaying
it is by construction a later one. The step is idempotent and is part of the
guarded `beforeOpen` recovery chain, with the column in the repair probe beside
`phase`.

Version 15 adds `pending_reports` (#8053), the durable outbox for content
reports, so the kind-1984 relay publish and the Zendesk ticket can be retried
per channel instead of being fire-and-forget.

Version 16 adds `saved_caption_styles` (#7742), the custom caption looks a
user saves from the video editor's caption style picker — font, colors,
background mode, font scale and animation — so one can be applied to captions
in later videos. A custom caption style otherwise lives inside its draft's
caption track and is lost to the next video. The style fields are a JSON blob
rather than columns, so a new style field is an app-level change rather than a
migration. Rows are owner-scoped like `clip_categories`, with the same
legacy-row claim on sign-in and delete on destructive sign-out. The `from < 16`
step creates the owner index by hand for the same reason v13 does:
`createTable` does not emit `@TableIndex.sql` indexes.

Version 17 adds `saved_title_styles` (#7742), the twin of
`saved_caption_styles` for free-form text overlays: the looks a user saves
from the timeline's Styles action — font, colors, background mode, alignment,
font scale and enter/leave animation — so a title treatment can be applied to
text in later videos. A text layer has no style model of its own in the draft
(its look lives on the `pro_image_editor` layer), which is why the two kinds
get separate tables rather than a discriminator column: their payloads are
different models. Same JSON-blob shape, same owner scoping, same legacy-row
claim and destructive-sign-out delete, and the `from < 17` step creates the
owner index by hand for the same reason v13 and v16 do.

Version 18 adds `scheduled_posts` (#3538), the outbox for posts scheduled for
a future publish time. The kind-34236 event is signed on the device with
`created_at` set to the chosen time and handed to the relay's hold queue,
which broadcasts it then; the row keeps the signed blob so the app can retry
the hand-off after being offline, publish the event itself when it is open at
that time, and re-sign it for a reschedule. It is deliberately a table of its
own rather than a status on `drafts`: the future-dated event must never reach
the regular publish-retry channel, which would broadcast it as "now", and the
submission backoff, server-state mirror and failure reason are queue state,
not draft content. Rows are owner-scoped and deleted on destructive sign-out;
a plain account switch keeps them: the relay publishes the held ones
regardless, and a row not yet handed off waits on this device for its account
to sign back in. The
`from < 18` step creates the `(owner_pubkey, status)` index by hand for the
same reason v13, v16 and v17 do.

Version 19 drops `hashtag_stats` and its `idx_hashtag_video_count` index
(#9582). The table cached trending-hashtag counts, but nothing ever wrote to
it in production: `HashtagStatsDao.upsertHashtag`/`upsertBatch` — its only
writers — had zero callers, so the only rows that could ever exist were ones
a test inserted directly. This is the first migration to remove rather than
add a schema entity: `HashtagStats` and `HashtagStatsDao` are deleted from
`tables.dart`/`daos.dart` in the same change, so the `from < 19` step drops
the table by name (`Migrator.deleteTable`) instead of referencing a Dart
table object, since none remains after the deletion. `AppDbClient`'s four
matching read/delete/count methods and
`CleanupResult.expiredHashtagStatsDeleted` are removed alongside it, for the
same reason: no caller ever used them.

This removal is not backward-compatible with a v18 binary: v18 startup cleanup
still calls `HashtagStatsDao.deleteExpired()`, which fails when the v19 database
no longer has the table. Do not open a v19 database with an older build when
testing an app rollback; use a separate database for the older build.

Version 20 adds `dm_message_reactions.recipient_pubkeys` (#7880), the
gift-wrap recipient set of a queued DM reaction: a JSON list of every
participant in the conversation except the owner, normally captured when the
reaction is queued, otherwise by a later retry or the post-auth backfill. The
retry sweep and the kind-5 removal used to work that set out again from
`conversations` each time they ran, and an account switch deletes those rows
while keeping the queue, so a queued group reaction was re-sent to one member
and recorded as delivered. Pre-existing rows stay NULL: nothing on such a row
says who it was for, and `DmReactionsRepository` establishes that before it
sends the row again instead of guessing. One case it cannot tell apart: an
older build moved a queued group reaction under the 1:1 with the message's
author when its own echo arrived before the message did, and such a row looks
like a 1:1 reaction, so it goes to that author alone. The step checks `to` as
well as `from`, like the v19 removal: migration tests validate intermediate
versions, and a column added to an existing table shows up there as an extra
one. It is idempotent and part of the guarded `beforeOpen` recovery chain,
with the column in the repair probe.

Version 21 adds the `removed_message_ids` table (#8179): the rumor id of every
message and reaction deleted when its conversation was removed, owner-scoped,
with `(owner_pubkey, rumor_id)` as the primary key. Removing a conversation
deletes the rows a later NIP-09 kind 5 would apply to, so without the ids the
wrap carrying that kind 5 stayed deferred and was decrypted again on relay
redelivery until it aged out of the subscription window. The same ids stop a
replayed message from being stored again, which
the removal timestamp alone could not do: a sender chooses a rumor's
`created_at`, so a future-dated message could clear the removal instant on a
later replay. The table is new, so nothing migrates into it and conversations
removed before this version are not backfilled; a retraction naming one of
their messages stays deferred as before. Rows are kept for the account's
lifetime like `removed_conversations` and are cleared with it when the
account's data is deleted. A plain account switch keeps them. The step is a
plain `createTable`, which needs no index step because the composite primary
key is the only lookup, and it is not added to the `beforeOpen` recovery chain.

Version 22 adds the nullable `environment` column to `outgoing_dms` (#10148):
the app environment a DM was queued in. Switching environment in developer
options keeps the queue, and the retry service used to resend every row on the
new environment's relays, where a DM queued in production could be scored as
delivered while its recipient never saw it. The retry service now resends only
rows from the current environment. Rows queued before v22 keep a null
environment and retry anywhere, as before. The step adds the column through the
idempotent `_addColumnIfMissing` and checks `to` as well as `from`, like the
v20 step. The legacy normalization adds it as well, and the repair probe lists
it, because the schema-parity test requires the recovery path to rebuild every
column a fresh install has.

Version 23 adds account-scoped `concord_store_entries` for sealed room history
and the unsent outbox. Version 22 remains the main-branch DM environment schema.
Earlier chat previews also reported version 22, but had Concord storage without
`outgoing_dms.environment`. The v23 upgrade adds that column if missing before
creating the Concord table idempotently, preserving both queues for either v22
shape. Migration tests cover fresh v23 databases, the full legacy upgrade chain,
main's v22, and the chat preview's v22 with queued data.

Version 24 adds the account-scoped `sound_request_states` workflow store.
Its committed snapshot remains unchanged.

Version 25 adds `conversations.is_dismissed` and the independent, owner-scoped
`conversation_dismissals` table for a conversation or message request the user
put aside without deleting it. The conversation boolean is a cached projection;
the independent marker survives ordinary sign-out and account switching.
Dismissing also marks the thread read through the existing read cursor; the
marker itself is never published. A message newer than the stored latest one
clears it, as does a distinct message received in the same second, while relay
replay, older history and the preview refresh after a deletion keep it. The
marker stores the latest-message timestamp at dismissal and the IDs already
present at that boundary second. After cache cleanup, replaying those IDs keeps
the rebuilt conversation dismissed and read; a distinct incoming ID at the same
second (or a newer incoming message) removes the marker. As before, a new
outgoing message also restores the conversation. Explicit Restore clears it too.
Only explicit account-local
data deletion purges that owner's remaining saved markers; other accounts stay
isolated. Cross-device synchronization remains out of scope.

The step creates the independent table and adds the cached column through the
idempotent `_addColumnIfMissing` and checks `to` as well as `from`, like the v20
and v22 steps. The v12 rebuild uses the current table definition, so a
migration test that stops below v25 drops the column again. The repair probe
lists the column and table, so a damaged current database missing either is
repaired on open. Existing dismissed rows seed the independent store without losing
their conversation data. The v25 upgrade also accepts the earlier
dismissal-preview v24 shape and creates its missing sound-request store while retaining dismissed rows. Main
v24 audio rows remain intact through the upgrade. Native salvage and legacy-file
replacement checks preserve both saved dismissal markers and sound-request
workflow state.

Version 26 adds `conversations.last_message_created_at`, the `created_at` of the
message in a conversation's preview (#10276). `last_message_timestamp` is capped
at the local clock when a message is stored, so for a sender whose clock runs
ahead it sits below the message's real `created_at`. The read cursor pinned when
an account switches away covers this column too, capped at the current time, so
the re-downloaded message does not reopen an already-read chat as unread. The
step adds the column through `_addColumnIfMissing` and checks `to` as well as
`from`. The v12 rebuild lists it in `newColumns` beside `is_dismissed`, and a
migration test that stops below v26 drops it again. The repair probe lists it.
Existing rows keep NULL until their preview next changes. The v25 snapshot is
unchanged.

Version 26 also adds nullable `retained_message_ids` on the same conversation
row. Account cleanup captures known IDs at its preview boundary before deleting
local messages. Dismissing a kept row before history returns includes those IDs,
so replay stays dismissed while a genuinely new ID in the same second still
restores unread. IDs survive partial history and same-boundary preview refresh,
clear when the timestamp changes, and are deleted with their owning row.
The v26 upgrade repeats v25's idempotent dismissal repair because upgrades skip
the guarded `beforeOpen` recovery. Current-version recovery also probes and
restores both new columns without losing the other kept account state.

Version 27 adds `my_followers`, an owner-scoped durable follower cache. Its
composite primary key `(owner_pubkey, follower_pubkey)` isolates accounts and
covers owner lookups. Sync merges retain the newest known `followed_at`; full
reconciliation replaces one owner's snapshot transactionally. Account cleanup
clears that owner's follower rows.

Canonical v1–v26 snapshots stay unchanged. The
v27 step preserves queued sound jobs, conversation dismissal flags, independent
markers and their known replay IDs. It also accepts the earlier ranking-preview
v25 shape, which already has `my_followers` but lacks dismissal storage: it adds
the missing dismissal and retained-conversation columns and table without
recreating the follower table or losing follower timestamps. Upgrade tests exercise canonical v25/v26 and ranking-preview v25/v26 shapes, replay after
account cleanup, and owner isolation.

Going forward, schema changes must be versioned Drift migrations. Do not add new
tables, columns, indexes, or schema backfills to `beforeOpen`; that hook is only
for startup cleanup and guarded recovery of damaged local databases.

## Project Structure

```
db_client/
├── lib/src/database/
│   ├── app_database.dart       # Main database class with schema version
│   ├── app_database.g.dart     # Generated code (build_runner)
│   ├── app_database.steps.dart # Generated migration steps (make-migrations)
│   └── tables.dart             # Table definitions
├── drift_schemas/
│   └── app_database/
│       ├── drift_schema_v1.json
│       ├── drift_schema_v2.json
│       ├── drift_schema_v3.json
│       ├── drift_schema_v4.json
│       ├── drift_schema_v5.json
│       ├── drift_schema_v6.json
│       ├── drift_schema_v7.json
│       ├── drift_schema_v8.json
│       └── drift_schema_v9.json
├── test/drift/
│   └── app_database/
│       ├── migration_test.dart
│       └── generated/
│           ├── schema.dart
│           ├── schema_v1.dart
│           ├── schema_v2.dart
│           ├── schema_v3.dart
│           ├── schema_v4.dart
│           ├── schema_v5.dart
│           ├── schema_v6.dart
│           ├── schema_v7.dart
│           ├── schema_v8.dart
│           └── schema_v9.dart
└── build.yaml                  # Drift build configuration
```

## Migration Workflow

### Step 1: Modify the Schema

Edit `lib/src/database/tables.dart` to add/modify/remove columns or tables.

```dart
// Example: Adding a new column
class NostrEvents extends Table {
  // ... existing columns ...
  IntColumn get newColumn => integer().nullable()();  // NEW
}
```

### Step 2: Increment Schema Version

In `lib/src/database/app_database.dart`, increment `schemaVersion`:

```dart
@override
int get schemaVersion => 3;  // Was 2, now 3
```

### Step 3: Run Build Runner

Generate the updated `app_database.g.dart`:

```bash
cd mobile/packages/db_client
dart run build_runner build --delete-conflicting-outputs
```

### Step 4: Export Schema Snapshot

Save the new schema version for migration testing:

```bash
cd mobile/packages/db_client
dart run drift_dev make-migrations
```

This command:
- Reads the `databases` config from `build.yaml`
- Creates `drift_schemas/app_database/drift_schema_v3.json`
- Regenerates `app_database.steps.dart` with new migration steps
- Updates `test/drift/app_database/generated/` files

### Step 5: Write the Migration Logic

Edit `lib/src/database/app_database.dart` to add the migration step:

```dart
MigrationStrategy get migration => MigrationStrategy(
  onCreate: (m) async {
    await m.createAll();
    await _normalizeLegacyV1Schema();
  },
  onUpgrade: (m, from, to) async {
    if (from < 3) {
      await m.alterTable(
        TableMigration(
          nostrEvents,
          newColumns: [nostrEvents.newColumn],
        ),
      );
    }
  },
  beforeOpen: (details) async {
    // Keep startup cleanup and guarded recovery here.
  },
);
```

For schema changes that need custom SQL or idempotent repair, add that logic to
the versioned `onUpgrade` path for the new version. Keep it covered by migration
tests and avoid making `beforeOpen` the primary schema evolution mechanism.

### Step 6: Run Migration Tests

Verify migrations work correctly:

```bash
cd mobile/packages/db_client
dart test test/drift/app_database/migration_test.dart
```

Or using the Dart MCP tool:
```
mcp__dart__run_tests with paths: ["test/drift/"]
```

### Step 7: Update Data Integrity Tests (Optional)

For migrations that modify existing data, update `migration_test.dart`:

```dart
test('migration from v2 to v3 does not corrupt data', () async {
  final oldEventData = <v2.EventData>[
    // Add test data...
  ];
  final expectedNewEventData = <v3.EventData>[
    // Expected data after migration...
  ];

  await verifier.testWithDataIntegrity(
    oldVersion: 2,
    newVersion: 3,
    // ...
  );
});
```

## Quick Reference Commands

| Task | Command |
|------|---------|
| Generate code | `dart run build_runner build --delete-conflicting-outputs` |
| Export schema | `dart run drift_dev make-migrations` |
| Run migration tests | `dart test test/drift/app_database/migration_test.dart` |
| Run all tests | `dart test` |
| Analyze | `dart analyze` |
| Format | `dart format lib test` |

## Common Migration Operations

### Adding a Column

```dart
from2To3: (m, schema) async {
  await m.alterTable(
    TableMigration(
      schema.tableName,
      newColumns: [schema.tableName.newColumn],
    ),
  );
}
```

### Adding a Table

```dart
from2To3: (m, schema) async {
  await m.createTable(schema.newTable);
}
```

### Dropping a Column

```dart
from2To3: (m, schema) async {
  await m.alterTable(
    TableMigration(
      schema.tableName,
      columnTransformer: {
        // Map old columns to new schema (excluding dropped column)
      },
    ),
  );
}
```

### Renaming a Column

```dart
from2To3: (m, schema) async {
  await m.alterTable(
    TableMigration(
      schema.tableName,
      columnTransformer: {
        schema.tableName.newName: schema.tableName.oldName,
      },
    ),
  );
}
```

### Adding an Index

```dart
from2To3: (m, schema) async {
  await m.createIndex(schema.indexName);
}
```

## Troubleshooting

### "make-migrations" fails with "database not configured"

Ensure `build.yaml` has the correct configuration:

```yaml
targets:
  $default:
    builders:
      drift_dev:
        options:
          databases:
            app_database: lib/src/database/app_database.dart
          schema_dir: drift_schemas/
          test_dir: test/drift/
```

### Migration tests fail

1. Ensure schema version matches the latest `drift_schema_vN.json`
2. Run `dart run drift_dev make-migrations` to regenerate files
3. Check that migration logic in `MigrationStrategy.onUpgrade` handles all versions

### Generated files out of date

Always run both commands after schema changes:

```bash
dart run build_runner build --delete-conflicting-outputs
dart run drift_dev make-migrations
```

## References

- [Drift Migrations Documentation](https://drift.simonbinder.eu/migrations/)
- [Migration Tests](https://drift.simonbinder.eu/migrations/tests/)
- [Step-by-Step Migrations](https://drift.simonbinder.eu/migrations/step_by_step/)
