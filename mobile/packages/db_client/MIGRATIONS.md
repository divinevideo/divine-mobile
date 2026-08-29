# Drift Database Migrations

This document describes how to manage database migrations for the `db_client` package using [Drift](https://drift.simonbinder.eu/).

## Current Schema Version

**Version: 12** (see `app_database.dart`).

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

Version 12 adds `personal_events`, replacing the hand-rolled `personal_events` /
`personal_events_metadata` Hive boxes (#6986). It deliberately has no `expire_at`
column: `deleteExpiredEvents` on the shared `event` table removes rows whose
`expire_at` IS NULL as well as past-dated ones, so a personal event stored there
would be destroyed on the next cold start. Retention is decided per row instead —
replaceable kinds collapse to one row per `(pubkey, kind)`, everything else is
trimmed to a per-owner cap. The `from < 12` step creates the indexes explicitly,
because `createTable` does not emit `@TableIndex.sql` indexes and a fresh install
would otherwise disagree with an upgraded database — the same divergence v7 had to
backfill.

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
