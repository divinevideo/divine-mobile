// dart format width=80
import 'package:db_client/src/database/app_database.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';
import 'generated/schema_v2.dart' as v2;
import 'generated/schema_v3.dart' as v3;
import 'generated/schema_v10.dart' as v10;
import 'generated/schema_v11.dart' as v11;
import 'generated/schema_v13.dart' as v13;
import 'generated/schema_v14.dart' as v14;
import 'generated/schema_v15.dart' as v15;
import 'generated/schema_v16.dart' as v16;
import 'generated/schema_v17.dart' as v17;
import 'generated/schema_v18.dart' as v18;
import 'generated/schema_v9.dart' as v9;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('schema validation', () {
    test('current schema version is 18', () {
      expect(AppDatabase(NativeDatabase.memory()).schemaVersion, 18);
    });

    test('v18 schema is valid and up to date', () async {
      final schema = await verifier.schemaAt(18);
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 18);
      await db.close();
    });

    test('v14 creates personal_events on a v12 database', () async {
      final schema = await verifier.schemaAt(12);
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 14);

      final rows = await db
          .customSelect(
            "SELECT name FROM sqlite_master "
            "WHERE type = 'table' AND name = 'personal_events'",
          )
          .get();
      expect(rows, hasLength(1));
      await db.close();
    });

    test(
      'a v11 database keeps its rows across the v14 upgrade',
      () async {
        // personal_events is a new table, so nothing is migrated into it. The
        // point of the check is that adding it does not disturb existing data.
        await verifier.testWithDataIntegrity(
          oldVersion: 11,
          newVersion: 14,
          createOld: v11.DatabaseAtV11.new,
          createNew: v14.DatabaseAtV14.new,
          openTestedDatabase: AppDatabase.new,
          createItems: (batch, oldDb) => batch.insert(
            oldDb.directMessages,
            v11.DirectMessagesCompanion.insert(
              id: 'c' * 64,
              conversationId: 'd' * 64,
              senderPubkey: 'a' * 64,
              content: 'a message that predates personal_events',
              createdAt: 1700000000,
              giftWrapId: 'b' * 64,
            ),
          ),
          validateItems: (newDb) async {
            final row = await newDb.select(newDb.directMessages).getSingle();
            expect(row.content, 'a message that predates personal_events');
            final personal = await newDb.select(newDb.personalEvents).get();
            expect(personal, isEmpty);
          },
        );
      },
    );

    test('v14 -> v15 creates pending_reports and it is writable', () async {
      await verifier.testWithDataIntegrity(
        oldVersion: 14,
        newVersion: 15,
        createOld: v14.DatabaseAtV14.new,
        createNew: v15.DatabaseAtV15.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, oldDb) {},
        validateItems: (newDb) async {
          // The new table exists and accepts a row after the migration.
          await newDb.customStatement(
            "INSERT INTO pending_reports (report_id, user_pubkey, event_json, "
            "zendesk_payload, relay_status, zendesk_status, created_at) "
            "VALUES ('r1', 'a', '{}', '{}', 'pending', 'pending', 1700000000)",
          );
          final rows = await newDb
              .customSelect('SELECT COUNT(*) AS c FROM pending_reports')
              .getSingle();
          expect(rows.data['c'], 1);
        },
      );
    });

    test(
      'v15 -> v16 creates saved_caption_styles with its owner index',
      () async {
        await verifier.testWithDataIntegrity(
          oldVersion: 15,
          newVersion: 16,
          createOld: v15.DatabaseAtV15.new,
          createNew: v16.DatabaseAtV16.new,
          openTestedDatabase: AppDatabase.new,
          createItems: (batch, oldDb) {
            // The step is additive, so seed a v15 row and require it back:
            // without this the test pins the new table and index while a
            // future destructive edit to the same step goes unnoticed.
            batch.insert(
              oldDb.clipCategories,
              v15.ClipCategoriesCompanion.insert(
                id: 'kept-across-v16',
                name: 'Existing category',
                createdAt: 1700000000,
              ),
            );
          },
          validateItems: (newDb) async {
            final kept = await newDb
                .customSelect(
                  "SELECT COUNT(*) AS c FROM clip_categories "
                  "WHERE id = 'kept-across-v16'",
                )
                .getSingle();
            expect(kept.data['c'], 1);

            // The new table exists and accepts a row after the migration.
            await newDb.customStatement(
              "INSERT INTO saved_caption_styles (id, name, style, order_index, "
              "created_at, owner_pubkey) "
              "VALUES ('s1', 'Intro', '{}', 0, 1700000000, 'a')",
            );
            final rows = await newDb
                .customSelect('SELECT COUNT(*) AS c FROM saved_caption_styles')
                .getSingle();
            expect(rows.data['c'], 1);

            // `createTable` does not emit `@TableIndex.sql` indexes, so the
            // upgrade step creates the owner index by hand; a fresh install
            // gets it from `createAll`. Both must agree.
            final indexes = await newDb
                .customSelect(
                  "SELECT name FROM sqlite_master WHERE type = 'index' "
                  "AND tbl_name = 'saved_caption_styles'",
                )
                .get();
            expect(
              [for (final row in indexes) row.data['name']],
              contains('idx_saved_caption_style_owner_pubkey'),
            );
          },
        );
      },
    );

    test(
      'v16 -> v17 creates saved_title_styles with its owner index',
      () async {
        await verifier.testWithDataIntegrity(
          oldVersion: 16,
          newVersion: 17,
          createOld: v16.DatabaseAtV16.new,
          createNew: v17.DatabaseAtV17.new,
          openTestedDatabase: AppDatabase.new,
          createItems: (batch, oldDb) {
            // The step is additive, so seed a v16 row and require it back —
            // the caption twin this table mirrors, so a destructive edit to
            // either step is caught here.
            batch.insert(
              oldDb.savedCaptionStyles,
              v16.SavedCaptionStylesCompanion.insert(
                id: 'kept-across-v17',
                name: 'Existing caption style',
                style: '{}',
                createdAt: 1700000000,
              ),
            );
          },
          validateItems: (newDb) async {
            final kept = await newDb
                .customSelect(
                  "SELECT COUNT(*) AS c FROM saved_caption_styles "
                  "WHERE id = 'kept-across-v17'",
                )
                .getSingle();
            expect(kept.data['c'], 1);

            // The new table exists and accepts a row after the migration.
            await newDb.customStatement(
              "INSERT INTO saved_title_styles (id, name, style, order_index, "
              "created_at, owner_pubkey) "
              "VALUES ('t1', 'Intro', '{}', 0, 1700000000, 'a')",
            );
            final rows = await newDb
                .customSelect('SELECT COUNT(*) AS c FROM saved_title_styles')
                .getSingle();
            expect(rows.data['c'], 1);

            // The upgrade step creates the owner index by hand; a fresh
            // install gets it from `createAll`. Both must agree.
            final indexes = await newDb
                .customSelect(
                  "SELECT name FROM sqlite_master WHERE type = 'index' "
                  "AND tbl_name = 'saved_title_styles'",
                )
                .get();
            expect(
              [for (final row in indexes) row.data['name']],
              contains('idx_saved_title_style_owner_pubkey'),
            );
          },
        );
      },
    );

    test(
      'v17 -> v18 creates scheduled_posts with its owner/status index',
      () async {
        await verifier.testWithDataIntegrity(
          oldVersion: 17,
          newVersion: 18,
          createOld: v17.DatabaseAtV17.new,
          createNew: v18.DatabaseAtV18.new,
          openTestedDatabase: AppDatabase.new,
          createItems: (batch, oldDb) {
            // The step is additive, so seed a v17 row and require it back.
            batch.insert(
              oldDb.savedTitleStyles,
              v17.SavedTitleStylesCompanion.insert(
                id: 'kept-across-v18',
                name: 'Existing title style',
                style: '{}',
                createdAt: 1700000000,
              ),
            );
          },
          validateItems: (newDb) async {
            final kept = await newDb
                .customSelect(
                  "SELECT COUNT(*) AS c FROM saved_title_styles "
                  "WHERE id = 'kept-across-v18'",
                )
                .getSingle();
            expect(kept.data['c'], 1);

            // The new table exists and accepts a row after the migration.
            await newDb.customStatement(
              "INSERT INTO scheduled_posts (event_id, owner_pubkey, draft_id, "
              "kind, signed_event_json, publish_at, status, created_at) "
              "VALUES ('e1', 'a', 'd1', 34236, '{}', 1800000000, "
              "'pendingSubmit', 1700000000)",
            );
            final rows = await newDb
                .customSelect('SELECT COUNT(*) AS c FROM scheduled_posts')
                .getSingle();
            expect(rows.data['c'], 1);

            // The upgrade step creates the index by hand; a fresh install
            // gets it from `createAll`. Both must agree.
            final indexes = await newDb
                .customSelect(
                  "SELECT name FROM sqlite_master WHERE type = 'index' "
                  "AND tbl_name = 'scheduled_posts'",
                )
                .get();
            expect(
              [for (final row in indexes) row.data['name']],
              contains('idx_scheduled_posts_owner_status'),
            );
          },
        );
      },
    );

    test(
      'a v10 direct message arrives at v11 with no twin already absorbed',
      () async {
        // twin_collapsed defaults to false for historical rows. Defaulting the
        // other way would let a genuine duplicate through on every row that
        // predates the column, which is the bug this column exists to stop.
        // See #8211.
        await verifier.testWithDataIntegrity(
          oldVersion: 10,
          newVersion: 14,
          createOld: v10.DatabaseAtV10.new,
          createNew: v14.DatabaseAtV14.new,
          openTestedDatabase: AppDatabase.new,
          createItems: (batch, oldDb) => batch.insert(
            oldDb.directMessages,
            v10.DirectMessagesCompanion.insert(
              id: 'e' * 64,
              conversationId: 'f' * 64,
              senderPubkey: 'a' * 64,
              content: 'a message that predates the twin marker',
              createdAt: 1700000000,
              giftWrapId: 'b' * 64,
            ),
          ),
          validateItems: (newDb) async {
            final row = await newDb.select(newDb.directMessages).getSingle();
            expect(row.content, 'a message that predates the twin marker');
            expect(row.twinCollapsed, 0);
          },
        );
      },
    );

    test(
      'a v9 direct message survives the upgrade with no pending deletion',
      () async {
        // The v10 columns are additive and nullable: an existing message must
        // arrive at current carrying no deletion, so the retry sweep does not pick
        // up every historical row as work. See #8165.
        await verifier.testWithDataIntegrity(
          oldVersion: 9,
          newVersion: 14,
          createOld: v9.DatabaseAtV9.new,
          createNew: v14.DatabaseAtV14.new,
          openTestedDatabase: AppDatabase.new,
          createItems: (batch, oldDb) => batch.insert(
            oldDb.directMessages,
            v9.DirectMessagesCompanion.insert(
              id: 'a' * 64,
              conversationId: 'b' * 64,
              senderPubkey: 'c' * 64,
              content: 'a message that predates the deletion columns',
              createdAt: 1700000000,
              giftWrapId: 'd' * 64,
            ),
          ),
          validateItems: (newDb) async {
            final row = await newDb.select(newDb.directMessages).getSingle();
            expect(row.content, 'a message that predates the deletion columns');
            expect(row.deletionRumorJson, isNull);
            expect(row.deletionPublishStatus, isNull);
          },
        );
      },
    );

    test('v8 schema migrates to v18', () async {
      final schema = await verifier.schemaAt(8);
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 18);
      const conversationId =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      const ownerPubkey =
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
      await db.removedConversationsDao.record(
        conversationId: conversationId,
        ownerPubkey: ownerPubkey,
        removedAt: 1700000000,
      );
      expect(
        await db.removedConversationsDao.removedAtFor(
          conversationId: conversationId,
          ownerPubkey: ownerPubkey,
        ),
        1700000000,
      );
      await db.close();
    });

    test('v7 schema migrates to v18', () async {
      final schema = await verifier.schemaAt(7);
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 18);
      await db.close();
    });

    test('v6 schema migrates to v18', () async {
      final schema = await verifier.schemaAt(6);
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 18);
      await db.close();
    });

    test('v5 schema migrates to v18', () async {
      final schema = await verifier.schemaAt(5);
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 18);
      await db.close();
    });

    test('v3 schema migrates to v18', () async {
      final schema = await verifier.schemaAt(3);
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 18);
      await db.close();
    });

    test('v2 schema migrates to v18', () async {
      final schema = await verifier.schemaAt(2);
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 18);
      await db.close();
    });

    test('legacy v1 schema migrates to v18', () async {
      final schema = await verifier.schemaAt(1);
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 18);
      await db.close();
    });

    test('migrates v2 profile statistic follower timestamps', () async {
      final schema = await verifier.schemaAt(2);
      final cachedAt =
          DateTime.now()
              .subtract(const Duration(hours: 10))
              .millisecondsSinceEpoch ~/
          1000;

      schema.rawDatabase.execute(
        'INSERT INTO profile_statistics '
        '(pubkey, video_count, follower_count, following_count, total_views, '
        'total_likes, cached_at) '
        'VALUES (?, NULL, ?, ?, NULL, NULL, ?)',
        ['withcounts', 12, 7, cachedAt],
      );
      schema.rawDatabase.execute(
        'INSERT INTO profile_statistics '
        '(pubkey, video_count, follower_count, following_count, total_views, '
        'total_likes, cached_at) '
        'VALUES (?, NULL, NULL, NULL, NULL, NULL, ?)',
        ['withoutcounts', cachedAt],
      );

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 18);

      final rows = await db
          .customSelect(
            'SELECT pubkey, follower_counts_updated_at '
            'FROM profile_statistics ORDER BY pubkey',
          )
          .get();
      final byPubkey = {
        for (final row in rows) row.read<String>('pubkey'): row,
      };

      expect(
        byPubkey['withcounts']!.read<int?>('follower_counts_updated_at'),
        cachedAt,
      );
      expect(byPubkey.containsKey('withoutcounts'), isFalse);
      await db.close();
    });

    test('v2 identity_events rows survive the upgrade unstamped', () async {
      await verifier.testWithDataIntegrity(
        oldVersion: 2,
        newVersion: 14,
        createOld: v2.DatabaseAtV2.new,
        createNew: v14.DatabaseAtV14.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, oldDb) => batch.insert(
          oldDb.identityEvents,
          v2.IdentityEventsData(
            pubkey: 'a' * 64,
            tagsJson: '[["i","github:alice","proof-a"]]',
            sourceKind: 10011,
          ),
        ),
        validateItems: (newDb) async {
          final row = await newDb.select(newDb.identityEvents).getSingle();
          expect(row.tagsJson, '[["i","github:alice","proof-a"]]');
          expect(row.sourceKind, 10011);
          // Nothing knows which event a pre-upgrade row came from, so it
          // stays out of the staleness comparison until the next read
          // stamps it.
          expect(row.sourceCreatedAt, null);
          expect(row.sourceEventId, null);
        },
      );
    });

    test(
      'v2 clips survive the migration uncategorized and unarchived',
      () async {
        final schema = await verifier.schemaAt(2);
        schema.rawDatabase.execute(
          'INSERT INTO clips (id, duration_ms, recorded_at, data) '
          'VALUES (?, ?, ?, ?)',
          ['clip-1', 3000, 1700000000, '{}'],
        );

        final db = AppDatabase(schema.newConnection());
        await verifier.migrateAndValidate(db, 18);

        final migrated = await db.clipsDao.getClipById('clip-1');
        expect(migrated?.id, 'clip-1');
        expect(migrated?.categoryId, null);
        expect(migrated?.archivedAt, null);
        await db.close();
      },
    );

    test(
      'v3 clips survive the migration uncategorized and unarchived',
      () async {
        final schema = await verifier.schemaAt(3);
        schema.rawDatabase.execute(
          'INSERT INTO clips (id, duration_ms, recorded_at, data) '
          'VALUES (?, ?, ?, ?)',
          ['clip-1', 3000, 1700000000, '{}'],
        );

        final db = AppDatabase(schema.newConnection());
        await verifier.migrateAndValidate(db, 18);

        final migrated = await db.clipsDao.getClipById('clip-1');
        expect(migrated?.id, 'clip-1');
        expect(migrated?.categoryId, null);
        expect(migrated?.archivedAt, null);
        await db.close();
      },
    );

    test('v6 copies a distinct pre-v5 vine id into the d-tag column', () async {
      await verifier.testWithDataIntegrity(
        oldVersion: 3,
        newVersion: 14,
        createOld: v3.DatabaseAtV3.new,
        createNew: v14.DatabaseAtV14.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, oldDb) {
          batch
            ..insert(
              oldDb.pendingViewEvents,
              v3.PendingViewEventsCompanion.insert(
                id: 'queued-with-d-tag',
                videoId: 'b' * 64,
                videoPubkey: 'c' * 64,
                videoVineId: const Value('the-d-tag'),
                userPubkey: 'd' * 64,
                watchDurationMs: 4200,
                trafficSource: 'feed',
                status: 'pending',
                createdAt:
                    DateTime.utc(2026, 8, 12).millisecondsSinceEpoch ~/ 1000,
              ),
            )
            ..insert(
              oldDb.pendingViewEvents,
              v3.PendingViewEventsCompanion.insert(
                id: 'queued-event-id-fallback',
                videoId: 'e' * 64,
                videoPubkey: 'c' * 64,
                videoVineId: Value('e' * 64),
                userPubkey: 'd' * 64,
                watchDurationMs: 2500,
                trafficSource: 'feed',
                status: 'pending',
                createdAt:
                    DateTime.utc(2026, 8, 12).millisecondsSinceEpoch ~/ 1000,
              ),
            );
        },
        validateItems: (newDb) async {
          final rows = await newDb.select(newDb.pendingViewEvents).get();
          expect(rows, hasLength(2));
          final byId = {for (final row in rows) row.id: row};
          expect(byId['queued-with-d-tag']!.videoAddressableDTag, 'the-d-tag');
          expect(byId['queued-event-id-fallback']!.videoAddressableDTag, null);
        },
      );
    });

    test(
      'v13 queued view rows arrive at v14 with no recording version',
      () async {
        // A pre-v14 row cannot say which build recorded it, and the build that
        // replays it is by construction a later one, so the replay omits the
        // version tag rather than guessing. See #9077.
        await verifier.testWithDataIntegrity(
          oldVersion: 13,
          newVersion: 14,
          createOld: v13.DatabaseAtV13.new,
          createNew: v14.DatabaseAtV14.new,
          openTestedDatabase: AppDatabase.new,
          createItems: (batch, oldDb) => batch.insert(
            oldDb.pendingViewEvents,
            v13.PendingViewEventsCompanion.insert(
              id: 'queued-before-v14',
              videoId: 'b' * 64,
              videoPubkey: 'c' * 64,
              videoAddressableDTag: const Value('the-d-tag'),
              userPubkey: 'd' * 64,
              watchDurationMs: 4200,
              phase: const Value('end'),
              trafficSource: 'feed',
              status: 'pending',
              createdAt:
                  DateTime.utc(2026, 9, 12).millisecondsSinceEpoch ~/ 1000,
            ),
          ),
          validateItems: (newDb) async {
            final row = await newDb.select(newDb.pendingViewEvents).getSingle();
            expect(row.phase, 'end');
            expect(row.videoAddressableDTag, 'the-d-tag');
            expect(row.appVersion, isNull);

            // And a row queued by the upgraded build records its version.
            await newDb
                .into(newDb.pendingViewEvents)
                .insert(
                  v14.PendingViewEventsCompanion.insert(
                    id: 'queued-at-v14',
                    videoId: 'b' * 64,
                    videoPubkey: 'c' * 64,
                    userPubkey: 'd' * 64,
                    watchDurationMs: 0,
                    phase: const Value('start'),
                    appVersion: const Value('1.0.24'),
                    trafficSource: 'feed',
                    status: 'pending',
                    createdAt: 1789000000,
                  ),
                );
            final versioned = await (newDb.select(
              newDb.pendingViewEvents,
            )..where((t) => t.id.equals('queued-at-v14'))).getSingle();
            expect(versioned.appVersion, '1.0.24');
          },
        );
      },
    );

    test('v7 queued view rows gain a NULL phase at v8', () async {
      final schema = await verifier.schemaAt(7);
      schema.rawDatabase.execute(
        'INSERT INTO pending_view_events '
        '(id, video_id, video_pubkey, user_pubkey, watch_duration_ms, '
        'traffic_source, status, created_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [
          'legacy-row',
          'b' * 64,
          'c' * 64,
          'd' * 64,
          4200,
          'feed',
          'pending',
          1786483200,
        ],
      );

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 18);

      final row = await db
          .customSelect(
            'SELECT phase FROM pending_view_events WHERE id = ?',
            variables: [Variable.withString('legacy-row')],
          )
          .getSingle();
      // Pre-phase rows must stay NULL: the replay path publishes them without
      // a phase tag so the relay still counts their view.
      expect(row.read<String?>('phase'), isNull);

      // And post-upgrade rows can carry the two-phase marker.
      await db.customStatement(
        'INSERT INTO pending_view_events '
        '(id, video_id, video_pubkey, user_pubkey, watch_duration_ms, '
        'traffic_source, status, created_at, phase) '
        "VALUES ('start-row', '${'b' * 64}', '${'c' * 64}', '${'d' * 64}', "
        "0, 'feed', 'pending', 1786483201, 'start')",
      );
      final phased = await db
          .customSelect(
            'SELECT phase FROM pending_view_events WHERE id = ?',
            variables: [Variable.withString('start-row')],
          )
          .getSingle();
      expect(phased.read<String?>('phase'), 'start');
      await db.close();
    });

    test(
      'v5 restores the follower column on an original-v3 database',
      () async {
        final schema = await verifier.schemaAt(3);
        // #6911 redefined v3 in place, so a database cut at the original v3
        // reports user_version 3 without the follower column — and hadUpgrade
        // suppresses the beforeOpen repair during the 3 -> 4 open.
        schema.rawDatabase.execute(
          'ALTER TABLE profile_statistics '
          'DROP COLUMN follower_counts_updated_at',
        );
        final cachedAt =
            DateTime.now()
                .subtract(const Duration(hours: 10))
                .millisecondsSinceEpoch ~/
            1000;
        schema.rawDatabase.execute(
          'INSERT INTO profile_statistics '
          '(pubkey, video_count, follower_count, following_count, total_views, '
          'total_likes, cached_at) '
          'VALUES (?, NULL, ?, ?, NULL, NULL, ?)',
          ['healme', 12, 7, cachedAt],
        );

        final db = AppDatabase(schema.newConnection());
        await verifier.migrateAndValidate(db, 18);

        final row = await db
            .customSelect(
              'SELECT follower_counts_updated_at FROM profile_statistics '
              'WHERE pubkey = ?',
              variables: [Variable.withString('healme')],
            )
            .getSingle();
        expect(row.read<int?>('follower_counts_updated_at'), cachedAt);
        await db.close();
      },
    );

    test('v12 backfills a NULL DM owner to the legacy sentinel and keeps the '
        'row readable', () async {
      // The column becomes NOT NULL because SQLite compares NULLs as
      // distinct inside a unique constraint, so a nullable owner in the key
      // would stop two legacy rows sharing a rumor id from collapsing.
      // `''` is the sentinel the account-switch deletes already used. See
      // #6645.
      await verifier.testWithDataIntegrity(
        oldVersion: 11,
        newVersion: 14,
        createOld: v11.DatabaseAtV11.new,
        createNew: v14.DatabaseAtV14.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, oldDb) {
          batch.insert(
            oldDb.directMessages,
            v11.DirectMessagesCompanion.insert(
              id: 'c' * 64,
              conversationId: 'd' * 64,
              senderPubkey: 'a' * 64,
              content: 'a message that predates owner scoping',
              createdAt: 1700000000,
              giftWrapId: '9' * 64,
            ),
          );
          batch.insert(
            oldDb.conversations,
            v11.ConversationsCompanion.insert(
              id: 'd' * 64,
              participantPubkeys: '["' + 'a' * 64 + '"]',
              createdAt: 1700000000,
            ),
          );
        },
        validateItems: (newDb) async {
          final message = await newDb.select(newDb.directMessages).getSingle();
          expect(message.ownerPubkey, isEmpty);
          final conversation = await newDb
              .select(newDb.conversations)
              .getSingle();
          expect(conversation.ownerPubkey, isEmpty);
        },
      );
    });

    test('v12 keeps the DM indexes the table rebuild drops', () async {
      // SQLite's table rebuild takes the old table's indexes with it, and
      // these are declared outside Drift's own index handling, so the
      // migration has to put them back explicitly.
      const dmIndexes = <String>[
        'idx_dm_conversation_id',
        'idx_dm_conversation_created',
        'idx_dm_gift_wrap_id',
        'idx_dm_sender',
        'idx_dm_owner_pubkey',
        'idx_dm_owner_conversation',
        'idx_conversation_last_message',
        'idx_conversation_is_read',
        'idx_conversation_owner_pubkey',
      ];

      final schema = await verifier.schemaAt(11);
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 18);

      final rows = await db
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
          .get();
      final present = rows.map((row) => row.read<String>('name')).toSet();
      expect(present, containsAll(dmIndexes));
      await db.close();
    });

    test(
      'v12 preserves ledger rows without guessing their processing outcome',
      () async {
        // An unmatched ledger row can be a reaction, deletion, unsupported
        // kind, tombstone-suppressed event, or collapsed protocol twin. The v11
        // schema records no outcome, so v12 must preserve it rather than infer
        // that it represents a stranded message. #6645.
        await verifier.testWithDataIntegrity(
          oldVersion: 11,
          newVersion: 14,
          createOld: v11.DatabaseAtV11.new,
          createNew: v14.DatabaseAtV14.new,
          openTestedDatabase: AppDatabase.new,
          createItems: (batch, oldDb) {
            batch.insert(
              oldDb.directMessages,
              v11.DirectMessagesCompanion.insert(
                id: '1' * 64,
                conversationId: '2' * 64,
                senderPubkey: '3' * 64,
                content: 'persisted',
                createdAt: 1700000000,
                giftWrapId: 'kept' * 16,
              ),
            );
            batch.insert(
              oldDb.processedGiftWraps,
              v11.ProcessedGiftWrapsCompanion.insert(
                giftWrapId: 'kept' * 16,
                processedAt: 1700000000,
                ownerPubkey: Value('a' * 64),
              ),
            );
            batch.insert(
              oldDb.processedGiftWraps,
              v11.ProcessedGiftWrapsCompanion.insert(
                giftWrapId: 'lost' * 16,
                processedAt: 1700000000,
                ownerPubkey: Value('b' * 64),
              ),
            );
          },
          validateItems: (newDb) async {
            final rows = await newDb.select(newDb.processedGiftWraps).get();
            final ledgered = rows.map((row) => row.giftWrapId).toSet();
            expect(
              ledgered,
              containsAll(['kept' * 16, 'lost' * 16]),
              reason:
                  'absence of a message row is not evidence of failed ingest',
            );
          },
        );
      },
    );

    test('v7 backfills the consolidated indexes onto a v6 database', () async {
      // The `List<Index>` getters these replace were never read by Drift, so
      // a v6 database has none of them. Folding the backfill into an earlier
      // `from <` block would silently skip every database already at v6.
      const consolidated = <String>[
        'idx_metrics_loop_count',
        'idx_metrics_likes',
        'idx_metrics_views',
        'idx_hashtag_video_count',
        'idx_notification_timestamp',
        'idx_notification_is_read',
        'idx_notification_owner_timestamp',
        'idx_pending_upload_status',
        'idx_pending_upload_created',
        'idx_personal_reactions_user',
        'idx_personal_reactions_reaction_id',
        'idx_personal_reactions_addressable_id',
        'idx_personal_reposts_user',
        'idx_personal_reposts_repost_id',
        'idx_personal_reposts_user_created',
      ];

      final schema = await verifier.schemaAt(6);
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 18);

      final rows = await db
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
          .get();
      final present = rows.map((row) => row.read<String>('name')).toSet();
      expect(present, containsAll(consolidated));
      await db.close();
    });
  });
}
