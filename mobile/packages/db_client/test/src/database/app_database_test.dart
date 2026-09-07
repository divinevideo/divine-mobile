// ABOUTME: Unit tests for AppDatabase startup cleanup functionality.
// ABOUTME: Tests automatic cleanup of expired data on database initialization.

import 'dart:io';

import 'package:db_client/db_client.dart' hide Filter;
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late AppDatabase database;
  late String tempDbPath;

  /// Valid 64-char hex pubkey for testing
  const testPubkey =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

  /// Helper to create a valid Nostr Event for testing.
  Event createEvent({
    String pubkey = testPubkey,
    int kind = 1,
    List<List<String>>? tags,
    String content = 'test content',
    int? createdAt,
  }) {
    final event = Event(pubkey, kind, tags ?? [], content, createdAt: createdAt)
      ..sig = 'testsig$testPubkey';
    return event;
  }

  /// Helper to get current Unix timestamp
  int nowUnix() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

  setUp(() async {
    final tempDir = Directory.systemTemp.createTempSync('app_db_test_');
    tempDbPath = '${tempDir.path}/test.db';

    database = AppDatabase.test(NativeDatabase(File(tempDbPath)));
  });

  tearDown(() async {
    await database.close();
    final file = File(tempDbPath);
    if (file.existsSync()) {
      file.deleteSync();
    }
    final dir = Directory(tempDbPath).parent;
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });

  group('AppDatabase', () {
    group('runStartupCleanup', () {
      test('deletes expired nostr events', () async {
        final dao = database.nostrEventsDao;

        // Insert expired and valid events
        final expiredEvent = createEvent(content: 'expired', createdAt: 1000);
        final validEvent = createEvent(content: 'valid', createdAt: 2000);

        final pastExpiry = nowUnix() - 100;
        final futureExpiry = nowUnix() + 3600;

        await dao.upsertEvent(expiredEvent, expireAt: pastExpiry);
        await dao.upsertEvent(validEvent, expireAt: futureExpiry);

        // Run cleanup
        final result = await database.runStartupCleanup();

        // Expired event should be deleted
        final expiredResult = await dao.getEventById(expiredEvent.id);
        expect(expiredResult, isNull);

        // Valid event should remain
        final validResult = await dao.getEventById(validEvent.id);
        expect(validResult, isNotNull);

        // Result should indicate what was cleaned
        expect(result.expiredEventsDeleted, equals(1));
      });

      test(
        'deletes expired profile stats that hold no follower counts',
        () async {
          // Insert stats with old cachedAt using proper Drift insert
          final oldTime = DateTime.now().subtract(const Duration(minutes: 10));
          await database
              .into(database.profileStats)
              .insert(
                ProfileStatsCompanion.insert(
                  pubkey: testPubkey,
                  videoCount: const Value(10),
                  cachedAt: oldTime,
                ),
              );

          // Run cleanup (default expiry is 5 minutes, entry is 10 minutes old)
          final result = await database.runStartupCleanup();

          // Expired stats should be deleted
          final stats = await database.profileStatsDao.getStats(testPubkey);
          expect(stats, isNull);

          expect(result.expiredProfileStatsDeleted, equals(1));
        },
      );

      test(
        'keeps expired profile stats that still hold follower counts',
        () async {
          // Startup cleanup runs on every cold start, so deleting this row
          // is how the follower baseline used to vanish overnight (#6902).
          final oldTime = DateTime.now().subtract(const Duration(minutes: 10));
          await database
              .into(database.profileStats)
              .insert(
                ProfileStatsCompanion.insert(
                  pubkey: testPubkey,
                  videoCount: const Value(10),
                  followerCount: const Value(100),
                  cachedAt: oldTime,
                ),
              );

          final result = await database.runStartupCleanup();

          expect(result.expiredProfileStatsDeleted, equals(0));
          final row = await database.profileStatsDao.getStatsRaw(testPubkey);
          expect(row!.followerCount, equals(100));
        },
      );

      test('deletes expired hashtag stats', () async {
        // Insert stats with old cachedAt using proper Drift insert
        final oldTime = DateTime.now().subtract(const Duration(hours: 2));
        await database
            .into(database.hashtagStats)
            .insert(
              HashtagStatsCompanion.insert(
                hashtag: 'flutter',
                videoCount: const Value(50),
                cachedAt: oldTime,
              ),
            );

        // Run cleanup (default expiry is 1 hour, entry is 2 hours old)
        final result = await database.runStartupCleanup();

        // Expired stats should be deleted
        final isFresh = await database.hashtagStatsDao.isCacheFresh();
        expect(isFresh, isFalse);

        expect(result.expiredHashtagStatsDeleted, equals(1));
      });

      test('deletes notifications cached more than 7 days ago', () async {
        final dao = database.notificationsDao;

        // Cached 8 days ago (older than the 7-day cache retention) → deleted.
        await database
            .into(database.notifications)
            .insert(
              NotificationsCompanion.insert(
                id: 'stale_cache',
                type: 'like',
                fromPubkey: testPubkey,
                timestamp: nowUnix(),
                cachedAt: DateTime.now().subtract(const Duration(days: 8)),
              ),
            );

        // Freshly cached but describing an 8-day-old event → must survive.
        // Retention keys on cachedAt, not the notification's content age, so
        // a still-current notification about an old event still hydrates the
        // next cold start.
        await database
            .into(database.notifications)
            .insert(
              NotificationsCompanion.insert(
                id: 'fresh_cache_old_content',
                type: 'like',
                fromPubkey: testPubkey,
                timestamp: nowUnix() - (8 * 24 * 60 * 60),
                cachedAt: DateTime.now(),
              ),
            );

        // Run cleanup
        final result = await database.runStartupCleanup();

        // Only the stale cache row should be deleted.
        final notifications = await dao.getAllNotifications();
        expect(notifications.length, equals(1));
        expect(notifications.first.id, equals('fresh_cache_old_content'));

        expect(result.oldNotificationsDeleted, equals(1));
      });

      test('returns cleanup result with all counts', () async {
        // Run cleanup on empty database
        final result = await database.runStartupCleanup();

        expect(result.expiredEventsDeleted, equals(0));
        expect(result.expiredProfileStatsDeleted, equals(0));
        expect(result.expiredHashtagStatsDeleted, equals(0));
        expect(result.oldNotificationsDeleted, equals(0));
      });

      test('handles cleanup when database is empty', () async {
        // Should not throw on empty database
        final result = await database.runStartupCleanup();

        expect(result.expiredEventsDeleted, equals(0));
        expect(result.expiredProfileStatsDeleted, equals(0));
        expect(result.expiredHashtagStatsDeleted, equals(0));
        expect(result.oldNotificationsDeleted, equals(0));
      });

      test('upgrade path — recreates outgoing_dms when missing', () async {
        // Simulate a damaged database after v2 migration: drop the table from
        // a fresh database, close, then reopen and assert the guarded recovery
        // path recreated the table, indexes, and that the DAO works.
        await database.customStatement('DROP TABLE outgoing_dms');

        // Confirm the precondition — table really is gone before reopen.
        final droppedCheck = await database
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='table' "
              "AND name='outgoing_dms'",
            )
            .get();
        expect(
          droppedCheck,
          isEmpty,
          reason: 'precondition: outgoing_dms must be missing before reopen',
        );

        await database.close();

        // Reopen the same on-disk file. `beforeOpen` should detect the
        // missing outgoing_dms table and recreate it as recovery.
        database = AppDatabase.test(NativeDatabase(File(tempDbPath)));

        // Trigger `beforeOpen` by issuing a query (Drift opens the
        // database lazily on first use).
        final tableCheck = await database
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='table' "
              "AND name='outgoing_dms'",
            )
            .get();
        expect(
          tableCheck,
          hasLength(1),
          reason: 'outgoing_dms must be re-created on reopen',
        );

        // Assert the indexes are in place too — the runtime path also
        // owns those, and a missing index would silently degrade
        // retry-sweep performance without failing the table check.
        final indexCheck = await database
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='index' "
              "AND tbl_name='outgoing_dms'",
            )
            .get();
        final indexNames = indexCheck
            .map((row) => row.read<String>('name'))
            .toSet();
        expect(
          indexNames,
          containsAll(<String>[
            'idx_outgoing_dms_owner_conversation',
            'idx_outgoing_dms_owner_recipient_status',
            'idx_outgoing_dms_owner_self_status',
            'idx_outgoing_dms_queued_at',
          ]),
        );

        // Finally, prove the DAO actually works against the upgraded
        // schema — a re-created table with mismatched columns or a
        // botched insert path would break this round-trip.
        final dao = database.outgoingDmsDao;
        final dm = OutgoingDm(
          id: 'upgrade-test-id',
          conversationId: 'conv-1',
          recipientPubkey: testPubkey,
          content: 'hello after upgrade',
          createdAt: 1700000000,
          rumorEventJson:
              '{"id":"upgrade-test-id","kind":14,"content":"hello"}',
          recipientWrapStatus: OutgoingWrapStatus.pending,
          selfWrapStatus: OutgoingWrapStatus.pending,
          queuedAt: DateTime.utc(2026, 5),
          ownerPubkey: testPubkey,
        );
        await dao.enqueue(dm);

        final fetched = await dao.getById('upgrade-test-id');
        expect(fetched, isNotNull);
        expect(fetched!.content, equals('hello after upgrade'));
        expect(fetched.recipientWrapStatus, OutgoingWrapStatus.pending);
        expect(fetched.selfWrapStatus, OutgoingWrapStatus.pending);
      });

      test('upgrade path — legacy v1 database migrates to v3', () async {
        // The generated `migration_test.dart` cannot cover this: both
        // `drift_schema_v1.json` and `drift_schema_v2.json` are dumps of the
        // same declared table set, so `schemaAt(1)` already hands back a
        // complete v2-shaped database. A real shipped v1 install is missing
        // the tables, columns, and `notifications` primary key that startup
        // repair used to add on every launch. Degrade a fresh database to
        // that shape, then reopen and assert `onUpgrade` normalizes it.
        await database.customStatement(
          'INSERT INTO event (id, pubkey, created_at, kind, tags, content, '
          "sig, expire_at) VALUES ('legacy-e1', 'p1', 100, 30023, "
          "'[[\"d\",\"legacy-slug\"]]', 'c', 's', 99999999999)",
        );
        await database.customStatement(
          'INSERT INTO notifications (id, type, from_pubkey, timestamp, '
          "is_read, cached_at) VALUES ('legacy-n1', 'like', 'p1', 100, 0, "
          "strftime('%s','now'))",
        );

        for (final table in _v1NormalizationTables) {
          await database.customStatement('DROP TABLE IF EXISTS $table');
        }
        for (final index in _v1NormalizationEventIndexes) {
          await database.customStatement('DROP INDEX IF EXISTS $index');
        }
        await database.customStatement('ALTER TABLE event DROP COLUMN d_tag');
        await database.customStatement(
          'DROP INDEX IF EXISTS idx_personal_reactions_addressable_id',
        );
        await database.customStatement(
          'ALTER TABLE personal_reactions DROP COLUMN addressable_id',
        );

        // Rebuild `notifications` with the pre-owner_pubkey single-column
        // primary key that shipped before the composite key landed.
        await database.customStatement(
          'DROP INDEX IF EXISTS idx_notification_owner_timestamp',
        );
        await database.customStatement(
          'ALTER TABLE notifications RENAME TO notifications_legacy_src',
        );
        await database.customStatement('''
          CREATE TABLE notifications (
            id TEXT NOT NULL PRIMARY KEY,
            type TEXT NOT NULL,
            from_pubkey TEXT NOT NULL,
            target_event_id TEXT NULL,
            target_pubkey TEXT NULL,
            content TEXT NULL,
            timestamp INTEGER NOT NULL,
            is_read INTEGER NOT NULL DEFAULT 0 CHECK (is_read IN (0, 1)),
            cached_at INTEGER NOT NULL
          )
        ''');
        await database.customStatement('''
          INSERT INTO notifications (id, type, from_pubkey, target_event_id,
            target_pubkey, content, timestamp, is_read, cached_at)
          SELECT id, type, from_pubkey, target_event_id, target_pubkey,
            content, timestamp, is_read, cached_at
          FROM notifications_legacy_src
        ''');
        await database.customStatement('DROP TABLE notifications_legacy_src');

        await database.customStatement('PRAGMA user_version = 1');
        await database.close();

        // Reopen the degraded file. Drift sees user_version 1 and runs
        // `onUpgrade`, which normalizes the legacy schema before any query.
        database = AppDatabase.test(NativeDatabase(File(tempDbPath)));

        final version = await database
            .customSelect('SELECT * FROM pragma_user_version()')
            .getSingle();
        expect(
          version.read<int>('user_version'),
          database.schemaVersion,
          reason: 'onUpgrade must record the current schema version',
        );

        final categoryTable = await database
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='table' "
              "AND name='clip_categories'",
            )
            .get();
        expect(
          categoryTable,
          hasLength(1),
          reason: 'the v3 step must run after legacy v1 normalization',
        );
        expect(await _columnNames(database, 'clips'), contains('category_id'));
        expect(await _columnNames(database, 'clips'), contains('archived_at'));

        for (final table in _v1NormalizationTables) {
          final rows = await database
              .customSelect(
                "SELECT name FROM sqlite_master WHERE type='table' "
                'AND name = ?',
                variables: [Variable.withString(table)],
              )
              .get();
          expect(rows, hasLength(1), reason: '$table must be re-created');
        }

        expect(
          await _columnNames(database, 'event'),
          contains('d_tag'),
          reason: 'event.d_tag must be re-added',
        );

        final backfilled = await database
            .customSelect("SELECT d_tag FROM event WHERE id = 'legacy-e1'")
            .getSingle();
        expect(
          backfilled.read<String?>('d_tag'),
          'legacy-slug',
          reason: 'd_tag must be backfilled from the stored tags JSON',
        );

        // `_collectTableInfo` rows are [name, type, notnull, dflt, pk].
        final notificationColumns = await _collectTableInfo(
          database,
          'notifications',
        );
        final ownerColumn = notificationColumns.firstWhere(
          (column) => column.first == 'owner_pubkey',
          orElse: () => <Object?>[],
        );
        expect(
          ownerColumn.isEmpty ? null : ownerColumn.last,
          isNot(anyOf(isNull, 0)),
          reason: 'notifications must be rebuilt with the composite key',
        );

        final preserved = await database
            .customSelect("SELECT id FROM notifications WHERE id = 'legacy-n1'")
            .get();
        expect(
          preserved,
          hasLength(1),
          reason: 'the rebuild must not drop existing notification rows',
        );
      });

      test('legacy normalization fixtures match recovery probe lists', () {
        expect(
          legacyV1NormalizationRepairTables,
          unorderedEquals(_v1NormalizationTables),
          reason:
              'the v2 recovery probe must check every table that legacy v1 '
              'normalization can recreate',
        );
        expect(
          legacyV1NormalizationRepairIndexes,
          unorderedEquals(_v1NormalizationRepairIndexes),
          reason:
              'the v2 recovery probe must check every index that legacy v1 '
              'normalization owns as recovery-critical',
        );
      });

      test('schema parity — fresh-install matches runtime CREATE-IF-NOT-EXISTS '
          'path column-for-column and index-for-index', () async {
        // The `outgoing_dms` table is defined by Drift for fresh installs
        // and by the v1 normalization/recovery SQL for legacy or repaired
        // databases. Both paths must agree exactly. This test inspects the
        // same database from both code paths and diffs the resulting
        // `outgoing_dms` shape.

        // Path 1: capture the fresh-install shape from the database
        // already opened by the outer `setUp` (Drift's `m.createAll()`
        // path). This represents a brand-new install.
        final freshColumns = await _collectTableInfo(database, 'outgoing_dms');
        final freshIndexes = await _collectIndexNames(database, 'outgoing_dms');

        expect(
          freshColumns,
          isNotEmpty,
          reason: 'precondition: fresh install should have outgoing_dms',
        );

        // Path 2: drop the table and reopen the same on-disk file so the
        // recovery path recreates it via the v1 normalization SQL.
        await database.customStatement('DROP TABLE outgoing_dms');
        // Drop the indexes too so recovery is responsible for recreating
        // them — otherwise stale indexes could mask a missing CREATE INDEX
        // statement.
        for (final indexName in freshIndexes) {
          await database.customStatement('DROP INDEX IF EXISTS $indexName');
        }
        await database.close();

        database = AppDatabase.test(NativeDatabase(File(tempDbPath)));
        // Trigger `beforeOpen` lazily.
        await database
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='table' "
              "AND name='outgoing_dms'",
            )
            .get();

        final recreatedColumns = await _collectTableInfo(
          database,
          'outgoing_dms',
        );
        final recreatedIndexes = await _collectIndexNames(
          database,
          'outgoing_dms',
        );

        // Column-by-column equality: `pragma table_info` returns
        // (name, type, notnull, dflt_value, pk) tuples. List equality
        // also catches column ordering drift, which sqlite preserves
        // across `CREATE TABLE` statements and would surface a
        // mis-ordered hand-written runtime SQL.
        expect(
          recreatedColumns,
          equals(freshColumns),
          reason:
              'runtime CREATE-IF-NOT-EXISTS path must produce the same '
              'columns as Drift `m.createAll()` — drift between the two '
              'is exactly the bug Liz flagged',
        );

        // Index name set equality. Drift and the runtime SQL may emit
        // CREATE INDEX statements in different orders, so set
        // semantics is the right comparison here.
        expect(
          recreatedIndexes,
          equals(freshIndexes),
          reason:
              'runtime CREATE-IF-NOT-EXISTS path must declare the same '
              'index set as Drift fresh-install',
        );
      });

      test(
        'upgrade path recreates pending_profile_saves when missing',
        () async {
          await database.customStatement('DROP TABLE pending_profile_saves');

          final droppedCheck = await database
              .customSelect(
                "SELECT name FROM sqlite_master WHERE type='table' "
                "AND name='pending_profile_saves'",
              )
              .get();
          expect(
            droppedCheck,
            isEmpty,
            reason: 'precondition: pending_profile_saves must be missing',
          );

          await database.close();
          database = AppDatabase.test(NativeDatabase(File(tempDbPath)));

          final tableCheck = await database
              .customSelect(
                "SELECT name FROM sqlite_master WHERE type='table' "
                "AND name='pending_profile_saves'",
              )
              .get();
          expect(
            tableCheck,
            hasLength(1),
            reason: 'pending_profile_saves must be re-created on reopen',
          );

          final dao = database.pendingProfileSavesDao;
          await dao.upsert(
            PendingProfileSaveEntry(
              userPubkey: testPubkey,
              payloadJson: '{"display_name":"upgrade"}',
              claimConfirmed: true,
              queuedAt: DateTime.utc(2026, 7, 13),
            ),
          );

          final fetched = await dao.get(testPubkey);
          expect(fetched, isNotNull);
          expect(fetched!.payloadJson, '{"display_name":"upgrade"}');
          expect(fetched.claimConfirmed, isTrue);
          expect(fetched.status, PendingProfileSaveStatus.pending);
        },
      );

      test(
        'schema parity — pending_profile_saves fresh-install matches runtime '
        'CREATE-IF-NOT-EXISTS path',
        () async {
          final freshColumns = await _collectTableInfo(
            database,
            'pending_profile_saves',
          );
          final freshIndexes = await _collectIndexNames(
            database,
            'pending_profile_saves',
          );
          expect(
            freshColumns,
            isNotEmpty,
            reason:
                'precondition: fresh install should have pending_profile_saves',
          );

          await database.customStatement('DROP TABLE pending_profile_saves');
          for (final indexName in freshIndexes) {
            await database.customStatement('DROP INDEX IF EXISTS $indexName');
          }
          await database.close();

          database = AppDatabase.test(NativeDatabase(File(tempDbPath)));
          await database
              .customSelect(
                "SELECT name FROM sqlite_master WHERE type='table' "
                "AND name='pending_profile_saves'",
              )
              .get();

          final recreatedColumns = await _collectTableInfo(
            database,
            'pending_profile_saves',
          );
          final recreatedIndexes = await _collectIndexNames(
            database,
            'pending_profile_saves',
          );

          expect(
            recreatedColumns,
            equals(freshColumns),
            reason:
                'runtime CREATE-IF-NOT-EXISTS path must produce the same '
                'columns as Drift `m.createAll()` for pending_profile_saves',
          );
          expect(
            recreatedIndexes,
            equals(freshIndexes),
            reason:
                'runtime CREATE-IF-NOT-EXISTS path must declare the same '
                'index set as Drift fresh-install for pending_profile_saves',
          );
        },
      );

      test('upgrade path recreates pending_view_events when missing', () async {
        await database.customStatement('DROP TABLE pending_view_events');

        final droppedCheck = await database
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='table' "
              "AND name='pending_view_events'",
            )
            .get();
        expect(
          droppedCheck,
          isEmpty,
          reason: 'precondition: pending_view_events must be missing',
        );

        await database.close();
        database = AppDatabase.test(NativeDatabase(File(tempDbPath)));

        final tableCheck = await database
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='table' "
              "AND name='pending_view_events'",
            )
            .get();
        expect(
          tableCheck,
          hasLength(1),
          reason: 'pending_view_events must be re-created on reopen',
        );

        final indexNames = await _collectIndexNames(
          database,
          'pending_view_events',
        );
        expect(
          indexNames,
          containsAll(<String>{
            'idx_pending_view_events_user_status',
            'idx_pending_view_events_created_at',
          }),
        );

        final dao = database.pendingViewEventsDao;
        await dao.enqueue(
          PendingViewEvent(
            id: 'upgrade-view-id',
            videoId: testPubkey,
            videoPubkey: testPubkey,
            userPubkey: testPubkey,
            watchDurationMs: 2500,
            trafficSource: 'home',
            status: PendingViewEventStatus.pending,
            createdAt: DateTime.utc(2026, 5),
          ),
        );

        final fetched = await dao.getById('upgrade-view-id');
        expect(fetched, isNotNull);
        expect(fetched!.status, PendingViewEventStatus.pending);
        expect(fetched.watchDurationMs, 2500);
      });

      test('schema parity — pending_view_events fresh-install matches runtime '
          'CREATE-IF-NOT-EXISTS path', () async {
        final freshColumns = await _collectTableInfo(
          database,
          'pending_view_events',
        );
        final freshIndexes = await _collectIndexNames(
          database,
          'pending_view_events',
        );

        expect(
          freshColumns,
          isNotEmpty,
          reason: 'precondition: fresh install should have pending_view_events',
        );

        await database.customStatement('DROP TABLE pending_view_events');
        for (final indexName in freshIndexes) {
          await database.customStatement('DROP INDEX IF EXISTS $indexName');
        }
        await database.close();

        database = AppDatabase.test(NativeDatabase(File(tempDbPath)));
        await database
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='table' "
              "AND name='pending_view_events'",
            )
            .get();

        final recreatedColumns = await _collectTableInfo(
          database,
          'pending_view_events',
        );
        final recreatedIndexes = await _collectIndexNames(
          database,
          'pending_view_events',
        );

        expect(recreatedColumns, equals(freshColumns));
        expect(recreatedIndexes, equals(freshIndexes));
      });

      test(
        'upgrade path recreates pending_product_events when missing',
        () async {
          await database.customStatement('DROP TABLE pending_product_events');

          final droppedCheck = await database
              .customSelect(
                "SELECT name FROM sqlite_master WHERE type='table' "
                "AND name='pending_product_events'",
              )
              .get();
          expect(
            droppedCheck,
            isEmpty,
            reason: 'precondition: pending_product_events must be missing',
          );

          await database.close();
          database = AppDatabase.test(NativeDatabase(File(tempDbPath)));

          final tableCheck = await database
              .customSelect(
                "SELECT name FROM sqlite_master WHERE type='table' "
                "AND name='pending_product_events'",
              )
              .get();
          expect(
            tableCheck,
            hasLength(1),
            reason: 'pending_product_events must be re-created on reopen',
          );

          final indexNames = await _collectIndexNames(
            database,
            'pending_product_events',
          );
          expect(
            indexNames,
            containsAll(<String>{
              'idx_pending_product_events_status_next_attempt',
              'idx_pending_product_events_created_at',
            }),
          );

          final dao = database.pendingProductEventsDao;
          await dao.enqueue(
            PendingProductEvent(
              id: 'upgrade-product-event-id',
              eventName: 'screen_time',
              payloadJson: '{"event_id":"upgrade-product-event-id"}',
              status: PendingProductEventStatus.pending,
              createdAt: DateTime.utc(2026, 7),
            ),
          );

          final fetched = await dao.getById('upgrade-product-event-id');
          expect(fetched, isNotNull);
          expect(fetched!.status, PendingProductEventStatus.pending);
          expect(fetched.eventName, 'screen_time');
        },
      );

      test(
        'schema parity — pending_product_events fresh-install matches runtime '
        'CREATE-IF-NOT-EXISTS path',
        () async {
          final freshColumns = await _collectTableInfo(
            database,
            'pending_product_events',
          );
          final freshIndexes = await _collectIndexNames(
            database,
            'pending_product_events',
          );

          expect(
            freshColumns,
            isNotEmpty,
            reason:
                'precondition: fresh install should have '
                'pending_product_events',
          );

          await database.customStatement('DROP TABLE pending_product_events');
          for (final indexName in freshIndexes) {
            await database.customStatement('DROP INDEX IF EXISTS $indexName');
          }
          await database.close();

          database = AppDatabase.test(NativeDatabase(File(tempDbPath)));
          await database
              .customSelect(
                "SELECT name FROM sqlite_master WHERE type='table' "
                "AND name='pending_product_events'",
              )
              .get();

          final recreatedColumns = await _collectTableInfo(
            database,
            'pending_product_events',
          );
          final recreatedIndexes = await _collectIndexNames(
            database,
            'pending_product_events',
          );

          expect(recreatedColumns, equals(freshColumns));
          expect(recreatedIndexes, equals(freshIndexes));
        },
      );

      test('upgrade path recreates pending_gift_wraps when missing', () async {
        await database.customStatement('DROP TABLE pending_gift_wraps');

        final droppedCheck = await database
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='table' "
              "AND name='pending_gift_wraps'",
            )
            .get();
        expect(
          droppedCheck,
          isEmpty,
          reason: 'precondition: pending_gift_wraps must be missing',
        );

        await database.close();
        database = AppDatabase.test(NativeDatabase(File(tempDbPath)));

        final tableCheck = await database
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='table' "
              "AND name='pending_gift_wraps'",
            )
            .get();
        expect(
          tableCheck,
          hasLength(1),
          reason: 'pending_gift_wraps must be re-created on reopen',
        );

        final indexNames = await _collectIndexNames(
          database,
          'pending_gift_wraps',
        );
        expect(
          indexNames,
          containsAll(<String>{'idx_pending_gift_wraps_owner_attempts'}),
        );

        final dao = database.pendingGiftWrapsDao;
        await dao.recordFailedDecrypt(
          giftWrapId: 'upgrade-wrap-id',
          ownerPubkey: testPubkey,
          rawJson: '{"id":"upgrade-wrap-id"}',
          createdAt: 1700000000,
        );
        final rows = await dao.getRetryable(
          ownerPubkey: testPubkey,
          maxAttempts: 10,
        );
        expect(rows, hasLength(1));
        expect(rows.single.attempts, 1);
      });

      test('schema parity — pending_gift_wraps fresh-install matches runtime '
          'CREATE-IF-NOT-EXISTS path', () async {
        final freshColumns = await _collectTableInfo(
          database,
          'pending_gift_wraps',
        );
        final freshIndexes = await _collectIndexNames(
          database,
          'pending_gift_wraps',
        );

        expect(
          freshColumns,
          isNotEmpty,
          reason: 'precondition: fresh install should have pending_gift_wraps',
        );

        await database.customStatement('DROP TABLE pending_gift_wraps');
        for (final indexName in freshIndexes) {
          await database.customStatement('DROP INDEX IF EXISTS $indexName');
        }
        await database.close();

        database = AppDatabase.test(NativeDatabase(File(tempDbPath)));
        await database
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='table' "
              "AND name='pending_gift_wraps'",
            )
            .get();

        final recreatedColumns = await _collectTableInfo(
          database,
          'pending_gift_wraps',
        );
        final recreatedIndexes = await _collectIndexNames(
          database,
          'pending_gift_wraps',
        );

        expect(recreatedColumns, equals(freshColumns));
        expect(recreatedIndexes, equals(freshIndexes));
      });

      test(
        'upgrade path recreates processed_gift_wraps when missing',
        () async {
          await database.customStatement('DROP TABLE processed_gift_wraps');

          final droppedCheck = await database
              .customSelect(
                "SELECT name FROM sqlite_master WHERE type='table' "
                "AND name='processed_gift_wraps'",
              )
              .get();
          expect(
            droppedCheck,
            isEmpty,
            reason: 'precondition: processed_gift_wraps must be missing',
          );

          await database.close();
          database = AppDatabase.test(NativeDatabase(File(tempDbPath)));

          final tableCheck = await database
              .customSelect(
                "SELECT name FROM sqlite_master WHERE type='table' "
                "AND name='processed_gift_wraps'",
              )
              .get();
          expect(
            tableCheck,
            hasLength(1),
            reason: 'processed_gift_wraps must be re-created on reopen',
          );

          final dao = database.processedGiftWrapsDao;
          await dao.record(
            giftWrapId: 'upgrade-wrap-id',
            ownerPubkey: testPubkey,
          );
          expect(await dao.hasGiftWrap('upgrade-wrap-id'), isTrue);
        },
      );

      test('schema parity — processed_gift_wraps fresh-install matches runtime '
          'CREATE-IF-NOT-EXISTS path', () async {
        final freshColumns = await _collectTableInfo(
          database,
          'processed_gift_wraps',
        );
        final freshIndexes = await _collectIndexNames(
          database,
          'processed_gift_wraps',
        );

        expect(
          freshColumns,
          isNotEmpty,
          reason:
              'precondition: fresh install should have processed_gift_wraps',
        );

        await database.customStatement('DROP TABLE processed_gift_wraps');
        for (final indexName in freshIndexes) {
          await database.customStatement('DROP INDEX IF EXISTS $indexName');
        }
        await database.close();

        database = AppDatabase.test(NativeDatabase(File(tempDbPath)));
        await database
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='table' "
              "AND name='processed_gift_wraps'",
            )
            .get();

        final recreatedColumns = await _collectTableInfo(
          database,
          'processed_gift_wraps',
        );
        final recreatedIndexes = await _collectIndexNames(
          database,
          'processed_gift_wraps',
        );

        expect(recreatedColumns, equals(freshColumns));
        expect(recreatedIndexes, equals(freshIndexes));
      });

      test('upgrade path — dedups duplicate live reactions before recreating '
          'the unique index', () async {
        final target = '1' * 64;
        // Drop the unique index so pre-index duplicate live rows can be
        // seeded (simulating a device that pre-dates #5419).
        await database.customStatement(
          'DROP INDEX IF EXISTS idx_dm_reactions_unique_live',
        );
        await database.customStatement('''
            INSERT INTO dm_message_reactions
              (id, conversation_id, target_message_id, target_message_author,
               reactor_pubkey, emoji, created_at, owner_pubkey, is_deleted)
            VALUES
              ('react_old', 'conv', '$target', 'author', '$testPubkey', 'a',
               100, '$testPubkey', 0),
              ('react_new', 'conv', '$target', 'author', '$testPubkey', 'b',
               200, '$testPubkey', 0)
          ''');

        await database.close();
        database = AppDatabase.test(NativeDatabase(File(tempDbPath)));

        // Trigger beforeOpen (dedup then CREATE UNIQUE INDEX). If the dedup
        // pass did not run first, CREATE UNIQUE INDEX would throw here on the
        // duplicate live rows.
        final rows = await database
            .customSelect(
              'SELECT id, is_deleted FROM dm_message_reactions '
              'ORDER BY created_at',
            )
            .get();
        expect(rows, hasLength(2));
        final live = rows.where((r) => r.read<int>('is_deleted') == 0).toList();
        expect(live, hasLength(1));
        expect(live.single.read<String>('id'), equals('react_new'));

        final indexes = await _collectIndexNames(
          database,
          'dm_message_reactions',
        );
        expect(indexes, contains('idx_dm_reactions_unique_live'));

        // Idempotency: reopening again keeps exactly one live row, no error.
        await database.close();
        database = AppDatabase.test(NativeDatabase(File(tempDbPath)));
        final live2 = await database
            .customSelect(
              'SELECT id FROM dm_message_reactions WHERE is_deleted = 0',
            )
            .get();
        expect(live2, hasLength(1));
        expect(live2.single.read<String>('id'), equals('react_new'));
      });

      test(
        'adds last_read_timestamp and backfills already-read rows on upgrade '
        '(#4977)',
        () async {
          // Simulate a pre-#4977 conversations table with no cursor column.
          await database.customStatement('DROP TABLE conversations');
          await database.customStatement('''
            CREATE TABLE conversations (
              id TEXT NOT NULL PRIMARY KEY,
              participant_pubkeys TEXT NOT NULL,
              is_group INTEGER NOT NULL DEFAULT 0,
              last_message_content TEXT,
              last_message_timestamp INTEGER,
              last_message_sender_pubkey TEXT,
              subject TEXT,
              is_read INTEGER NOT NULL DEFAULT 1,
              current_user_has_sent INTEGER NOT NULL DEFAULT 0,
              created_at INTEGER NOT NULL,
              owner_pubkey TEXT,
              dm_protocol TEXT
            )
          ''');
          await database.customStatement(
            'INSERT INTO conversations '
            '(id, participant_pubkeys, created_at, last_message_timestamp, '
            'is_read) VALUES '
            "('read_conv', '[\"a\",\"b\"]', 1, 200, 1), "
            "('unread_conv', '[\"a\",\"c\"]', 1, 300, 0)",
          );

          // Reopen → beforeOpen adds the column and runs the one-time backfill.
          await database.close();
          database = AppDatabase.test(NativeDatabase(File(tempDbPath)));

          final rows = await database
              .customSelect(
                'SELECT id, last_read_timestamp FROM conversations '
                'ORDER BY id',
              )
              .get();
          final byId = {
            for (final r in rows)
              r.read<String>('id'): r.readNullable<int>('last_read_timestamp'),
          };
          // Already-read row backfilled to its latest message; unread NULL.
          expect(byId['read_conv'], 200);
          expect(byId['unread_conv'], isNull);

          // Idempotent: a second open does not change the backfilled values.
          await database.close();
          database = AppDatabase.test(NativeDatabase(File(tempDbPath)));
          final again = await database
              .customSelect(
                'SELECT last_read_timestamp FROM conversations '
                "WHERE id = 'read_conv'",
              )
              .getSingle();
          expect(again.read<int>('last_read_timestamp'), 200);
        },
      );

      test('schema parity — dm_message_reactions fresh-install matches runtime '
          'CREATE-IF-NOT-EXISTS path', () async {
        final freshColumns = await _collectTableInfo(
          database,
          'dm_message_reactions',
        );
        final freshIndexes = await _collectIndexNames(
          database,
          'dm_message_reactions',
        );

        expect(
          freshColumns,
          isNotEmpty,
          reason:
              'precondition: fresh install should have dm_message_reactions',
        );

        await database.customStatement('DROP TABLE dm_message_reactions');
        for (final indexName in freshIndexes) {
          await database.customStatement('DROP INDEX IF EXISTS $indexName');
        }
        await database.close();

        database = AppDatabase.test(NativeDatabase(File(tempDbPath)));
        await database
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='table' "
              "AND name='dm_message_reactions'",
            )
            .get();

        final recreatedColumns = await _collectTableInfo(
          database,
          'dm_message_reactions',
        );
        final recreatedIndexes = await _collectIndexNames(
          database,
          'dm_message_reactions',
        );

        expect(recreatedColumns, equals(freshColumns));
        expect(recreatedIndexes, equals(freshIndexes));
      });

      test('does not delete non-expired data', () async {
        final eventsDao = database.nostrEventsDao;
        final profileStatsDao = database.profileStatsDao;
        final hashtagStatsDao = database.hashtagStatsDao;
        final notificationsDao = database.notificationsDao;

        // Insert valid (non-expired) data
        final validEvent = createEvent(content: 'valid');
        await eventsDao.upsertEvent(validEvent, expireAt: nowUnix() + 3600);

        await profileStatsDao.upsertStats(pubkey: testPubkey, videoCount: 10);

        await hashtagStatsDao.upsertHashtag(hashtag: 'dart', videoCount: 20);

        await notificationsDao.upsertNotification(
          id: 'recent',
          type: 'follow',
          fromPubkey: testPubkey,
          timestamp: nowUnix(),
        );

        // Run cleanup
        await database.runStartupCleanup();

        // All data should remain
        final event = await eventsDao.getEventById(validEvent.id);
        expect(event, isNotNull);

        final stats = await profileStatsDao.getStats(testPubkey);
        expect(stats, isNotNull);

        final hashtagFresh = await hashtagStatsDao.isCacheFresh();
        expect(hashtagFresh, isTrue);

        final notifications = await notificationsDao.getAllNotifications();
        expect(notifications.length, equals(1));
      });
    });

    group('schema repair', () {
      test(
        'repairs the v4 clip organization schema on a damaged current-version '
        'database',
        () async {
          await database.customSelect('SELECT 1').get();
          await database.close();
          final raw = sqlite3.open(tempDbPath);
          try {
            raw
              ..execute('ALTER TABLE clips RENAME TO clips_old;')
              ..execute('''
              CREATE TABLE clips (
                id TEXT NOT NULL PRIMARY KEY,
                draft_id TEXT,
                order_index INTEGER NOT NULL DEFAULT 0,
                duration_ms INTEGER NOT NULL,
                recorded_at INTEGER NOT NULL,
                data TEXT NOT NULL,
                file_path TEXT,
                thumbnail_path TEXT,
                owner_pubkey TEXT,
                deleted_at INTEGER
              )
            ''')
              ..execute('''
                INSERT INTO clips (
                  id,
                  draft_id,
                  order_index,
                  duration_ms,
                  recorded_at,
                  data,
                  file_path,
                  thumbnail_path,
                  owner_pubkey,
                  deleted_at
                )
                SELECT
                  id,
                  draft_id,
                  order_index,
                  duration_ms,
                  recorded_at,
                  data,
                  file_path,
                  thumbnail_path,
                  owner_pubkey,
                  deleted_at
                FROM clips_old
              ''')
              ..execute('DROP TABLE clips_old;')
              ..execute('DROP INDEX IF EXISTS idx_clip_category_id;')
              ..execute('DROP TABLE IF EXISTS clip_categories;')
              // Stays at the current version: an upgrade would set
              // `hadUpgrade` and skip the guarded probe entirely, leaving the
              // v4 migration — not the repair path — to do the work.
              ..execute('PRAGMA user_version = 4;');
          } finally {
            raw.close();
          }

          database = AppDatabase.test(NativeDatabase(File(tempDbPath)));
          await database.customSelect('SELECT 1').get();

          final columns = await database
              .customSelect('PRAGMA table_info(clips)')
              .get();
          final columnNames = {
            for (final row in columns) row.data['name'] as String,
          };
          expect(columnNames, contains('category_id'));
          expect(columnNames, contains('archived_at'));

          final categoryTable = await database
              .customSelect(
                "SELECT name FROM sqlite_master WHERE type='table' "
                "AND name='clip_categories'",
              )
              .get();
          expect(
            categoryTable,
            hasLength(1),
            reason: 'the probe must rebuild the category table it checks for',
          );

          final indexes = await database
              .customSelect(
                "SELECT name FROM sqlite_master WHERE type='index' "
                "AND name IN ('idx_clip_category_id', "
                "'idx_clip_category_owner_pubkey')",
              )
              .get();
          expect(
            indexes,
            hasLength(2),
            reason: 'both category indexes are recovery-critical',
          );

          // The category DAO has to work off the rebuilt table, not just
          // report that its name is back in sqlite_master.
          await database.clipCategoriesDao.upsertCategory(
            id: 'cat-repaired',
            name: 'Repaired',
            createdAt: DateTime(2026),
          );
          final categories = await database.clipCategoriesDao.getCategories();
          expect(categories.map((c) => c.id), contains('cat-repaired'));
        },
      );

      test('schema parity — clip_categories fresh-install matches runtime '
          'CREATE-IF-NOT-EXISTS path', () async {
        // Drift builds this table on a fresh install and migration, while
        // `_createClipCategoriesTableIfMissing` builds it during repair. The
        // two definitions live apart, so column order, nullability, defaults,
        // the primary key, and the indexes have to be pinned equal.
        final freshColumns = await _collectTableInfo(
          database,
          'clip_categories',
        );
        final freshIndexes = await _collectIndexNames(
          database,
          'clip_categories',
        );

        expect(
          freshColumns,
          isNotEmpty,
          reason: 'precondition: fresh install should have clip_categories',
        );

        await database.customStatement('DROP TABLE clip_categories');
        await database.close();

        database = AppDatabase.test(NativeDatabase(File(tempDbPath)));
        await database
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='table' "
              "AND name='clip_categories'",
            )
            .get();

        final recreatedColumns = await _collectTableInfo(
          database,
          'clip_categories',
        );
        final recreatedIndexes = await _collectIndexNames(
          database,
          'clip_categories',
        );

        expect(recreatedColumns, equals(freshColumns));
        expect(recreatedIndexes, equals(freshIndexes));
      });
    });

    group('identity caches (#3936)', () {
      test('upgrade path — pre-#3936 database gets both identity tables on '
          'reopen', () async {
        await database.customStatement('DROP TABLE identity_events');
        await database.customStatement('DROP TABLE identity_verifications');
        await database.close();

        database = AppDatabase.test(NativeDatabase(File(tempDbPath)));

        final tables = await database
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='table' "
              "AND name IN ('identity_events', 'identity_verifications')",
            )
            .get();
        expect(
          tables,
          hasLength(2),
          reason: 'both identity tables must be re-created on reopen',
        );

        await database.identityEventsDao.upsertEvent(
          pubkey: testPubkey,
          tagsJson: '[["i","github:alice","proof-a"]]',
          sourceKind: 10011,
        );
        final eventRow = await database.identityEventsDao.getEvent(testPubkey);
        expect(eventRow, isNotNull);

        await database.identityVerificationsDao.upsertVerification(
          pubkey: testPubkey,
          verifiedClaimsJson: '[]',
          checkedAtFloor: 100,
        );
        final verificationRow = await database.identityVerificationsDao
            .getVerification(testPubkey);
        expect(verificationRow, isNotNull);
      });

      test('recovery path — restores the staleness stamps on an existing '
          'identity_events table', () async {
        // The stamps arrived in v3 by altering a table that already existed,
        // so a damaged database can hold identity_events without them. The
        // probe only recovers what normalization can actually rebuild — if
        // these two drifted apart the probe would fire on every startup and
        // never repair anything.
        await database.customStatement(
          'ALTER TABLE identity_events DROP COLUMN source_created_at',
        );
        await database.customStatement(
          'ALTER TABLE identity_events DROP COLUMN source_event_id',
        );
        await database.close();

        database = AppDatabase.test(NativeDatabase(File(tempDbPath)));

        final columns = await _collectTableInfo(database, 'identity_events');
        final names = columns.map((column) => column.first).toList();
        expect(
          names,
          containsAll(<String>['source_created_at', 'source_event_id']),
          reason: 'the recovery probe must restore the v3 staleness stamps',
        );

        // A second reopen must find nothing left to repair.
        await database.close();
        database = AppDatabase.test(NativeDatabase(File(tempDbPath)));
        await database.identityEventsDao.upsertEvent(
          pubkey: testPubkey,
          tagsJson: '[["i","github:alice","proof-a"]]',
          sourceKind: 10011,
          sourceCreatedAt: 1700000000,
          sourceEventId: 'e' * 64,
        );
        final restored = await database.identityEventsDao.getEvent(testPubkey);
        expect(restored?.sourceCreatedAt, 1700000000);
        expect(restored?.sourceEventId, 'e' * 64);
      });

      test('schema parity — identity_events fresh-install matches runtime '
          'CREATE-IF-NOT-EXISTS path', () async {
        final freshColumns = await _collectTableInfo(
          database,
          'identity_events',
        );
        final freshIndexes = await _collectIndexNames(
          database,
          'identity_events',
        );

        expect(
          freshColumns,
          isNotEmpty,
          reason: 'precondition: fresh install should have identity_events',
        );

        await database.customStatement('DROP TABLE identity_events');
        await database.close();

        database = AppDatabase.test(NativeDatabase(File(tempDbPath)));
        await database
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='table' "
              "AND name='identity_events'",
            )
            .get();

        final recreatedColumns = await _collectTableInfo(
          database,
          'identity_events',
        );
        final recreatedIndexes = await _collectIndexNames(
          database,
          'identity_events',
        );

        expect(recreatedColumns, equals(freshColumns));
        expect(recreatedIndexes, equals(freshIndexes));
      });

      test('schema parity — identity_verifications fresh-install matches '
          'runtime CREATE-IF-NOT-EXISTS path', () async {
        final freshColumns = await _collectTableInfo(
          database,
          'identity_verifications',
        );
        final freshIndexes = await _collectIndexNames(
          database,
          'identity_verifications',
        );

        expect(
          freshColumns,
          isNotEmpty,
          reason:
              'precondition: fresh install should have '
              'identity_verifications',
        );

        await database.customStatement('DROP TABLE identity_verifications');
        await database.close();

        database = AppDatabase.test(NativeDatabase(File(tempDbPath)));
        await database
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='table' "
              "AND name='identity_verifications'",
            )
            .get();

        final recreatedColumns = await _collectTableInfo(
          database,
          'identity_verifications',
        );
        final recreatedIndexes = await _collectIndexNames(
          database,
          'identity_verifications',
        );

        expect(recreatedColumns, equals(freshColumns));
        expect(recreatedIndexes, equals(freshIndexes));
      });
    });

    group('vanished profiles', () {
      test(
        'upgrade path — existing database gets the table on reopen',
        () async {
          await database.customStatement('DROP TABLE vanished_profiles');
          await database.close();

          database = AppDatabase.test(NativeDatabase(File(tempDbPath)));

          final tables = await database
              .customSelect(
                "SELECT name FROM sqlite_master WHERE type='table' "
                "AND name='vanished_profiles'",
              )
              .get();
          expect(
            tables,
            hasLength(1),
            reason: 'vanished_profiles must be re-created on reopen',
          );

          await database.vanishedProfilesDao.markVanished(testPubkey);
          expect(
            await database.vanishedProfilesDao.isVanished(testPubkey),
            isTrue,
            reason: 'the recreated table must be writable',
          );
        },
      );

      test('schema parity — fresh install matches the runtime '
          'CREATE-IF-NOT-EXISTS path', () async {
        final freshColumns = await _collectTableInfo(
          database,
          'vanished_profiles',
        );
        final freshIndexes = await _collectIndexNames(
          database,
          'vanished_profiles',
        );

        expect(
          freshColumns,
          isNotEmpty,
          reason: 'precondition: fresh install should have vanished_profiles',
        );

        await database.customStatement('DROP TABLE vanished_profiles');
        await database.close();

        database = AppDatabase.test(NativeDatabase(File(tempDbPath)));
        await database
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='table' "
              "AND name='vanished_profiles'",
            )
            .get();

        final recreatedColumns = await _collectTableInfo(
          database,
          'vanished_profiles',
        );
        final recreatedIndexes = await _collectIndexNames(
          database,
          'vanished_profiles',
        );

        expect(recreatedColumns, equals(freshColumns));
        expect(recreatedIndexes, equals(freshIndexes));
      });

      test('survives startup cleanup', () async {
        // A vanish does not expire. If this table ever gets swept, a deleted
        // account starts rendering from cache again after a restart.
        await database.vanishedProfilesDao.markVanished(
          testPubkey,
          detectedAt: DateTime.now().subtract(const Duration(days: 400)),
        );

        await database.runStartupCleanup();

        expect(
          await database.vanishedProfilesDao.isVanished(testPubkey),
          isTrue,
          reason: 'vanished_profiles must not be swept by startup cleanup',
        );
      });
    });

    group('event table d_tag column', () {
      test(
        'upgrade path — adds, indexes, and backfills d_tag on reopen',
        () async {
          final dao = database.nostrEventsDao;

          // Rows that will pre-date the d_tag column: a video PRE event
          // with a d-tag, a PRE event without one, and a regular note.
          final videoEvent = createEvent(
            kind: 34236,
            tags: [
              ['d', 'legacy-video'],
              ['url', 'https://example.com/v.mp4'],
            ],
            createdAt: 1000,
          );
          final noDTagEvent = createEvent(
            kind: 30023,
            content: 'no d tag',
            createdAt: 1000,
          );
          final noteEvent = createEvent(createdAt: 1000);
          await dao.upsertEvent(videoEvent, expireAt: nowUnix() + 3600);
          await dao.upsertEvent(noDTagEvent, expireAt: nowUnix() + 3600);
          await dao.upsertEvent(noteEvent, expireAt: nowUnix() + 3600);

          // Simulate a legacy install that pre-dates the column: drop the
          // index that references it, then the column itself.
          await database.customStatement(
            'DROP INDEX idx_event_pubkey_kind_d_tag_created_at',
          );
          await database.customStatement('ALTER TABLE event DROP COLUMN d_tag');
          await database.close();

          // Reopen the same on-disk file. `beforeOpen` re-adds the column,
          // recreates the indexes, and backfills d_tag from the tags JSON.
          database = AppDatabase.test(NativeDatabase(File(tempDbPath)));

          final rows = await database
              .customSelect('SELECT id, d_tag FROM event')
              .get();
          final dTagsById = {
            for (final row in rows)
              row.read<String>('id'): row.readNullable<String>('d_tag'),
          };
          expect(dTagsById[videoEvent.id], equals('legacy-video'));
          // PRE event without a d-tag backfills to '' (NIP-01 default).
          expect(dTagsById[noDTagEvent.id], equals(''));
          // Non-parameterized-replaceable kinds stay NULL.
          expect(dTagsById[noteEvent.id], isNull);

          final indexNames = await _collectIndexNames(database, 'event');
          expect(
            indexNames,
            containsAll(<String>[
              'idx_event_kind_created_at',
              'idx_event_pubkey_created_at',
              'idx_event_pubkey_kind_d_tag_created_at',
              'idx_event_created_at',
              'idx_event_expire_at',
            ]),
          );

          // Prove the upsert path works against backfilled rows: a newer
          // version of the video replaces the legacy row.
          final newerVideo = createEvent(
            kind: 34236,
            tags: [
              ['d', 'legacy-video'],
              ['url', 'https://example.com/v2.mp4'],
            ],
            content: 'updated',
            createdAt: 2000,
          );
          await database.nostrEventsDao.upsertEvent(newerVideo);

          final results = await database.nostrEventsDao.getEventsByFilter(
            Filter(kinds: [34236]),
          );
          expect(results, hasLength(1));
          expect(results.first.content, equals('updated'));
        },
      );
    });

    group('DM send_batch_id column', () {
      test(
        'upgrade path — re-adds send_batch_id on outgoing_dms and '
        'direct_messages on reopen, and the re-added column is usable',
        () async {
          // Seed one row per table under the pre-drop schema, each carrying a
          // batch id, so the DROP exercises a populated column.
          await database.directMessagesDao.insertMessage(
            id: 'msg_pre',
            conversationId: 'conv_pre',
            senderPubkey: testPubkey,
            content: 'legacy group send',
            createdAt: 1700000000,
            giftWrapId: 'gw_pre',
            ownerPubkey: testPubkey,
            sendBatchId: 'batch-pre',
          );
          await database.outgoingDmsDao.enqueue(
            OutgoingDm(
              id: 'out_pre',
              conversationId: 'conv_pre',
              recipientPubkey: testPubkey,
              content: 'legacy outgoing',
              createdAt: 1700000000,
              rumorEventJson: '{"id":"out_pre","kind":14}',
              recipientWrapStatus: OutgoingWrapStatus.pending,
              selfWrapStatus: OutgoingWrapStatus.pending,
              queuedAt: DateTime.utc(2026, 5),
              ownerPubkey: testPubkey,
              sendBatchId: 'batch-pre',
            ),
          );

          // Simulate a legacy install that pre-dates the column.
          await database.customStatement(
            'ALTER TABLE outgoing_dms DROP COLUMN send_batch_id',
          );
          await database.customStatement(
            'ALTER TABLE direct_messages DROP COLUMN send_batch_id',
          );
          expect(
            await _columnNames(database, 'outgoing_dms'),
            isNot(contains('send_batch_id')),
          );
          expect(
            await _columnNames(database, 'direct_messages'),
            isNot(contains('send_batch_id')),
          );
          await database.close();

          // Reopen the same on-disk file. `beforeOpen` re-adds the column on
          // both DM tables. There is no backfill (unlike d_tag): the pre-drop
          // `batch-pre` values are gone, the column comes back empty.
          database = AppDatabase.test(NativeDatabase(File(tempDbPath)));

          expect(
            await _columnNames(database, 'outgoing_dms'),
            contains('send_batch_id'),
          );
          expect(
            await _columnNames(database, 'direct_messages'),
            contains('send_batch_id'),
          );

          // The re-added column is writable and readable end-to-end.
          await database.directMessagesDao.insertMessage(
            id: 'msg_post',
            conversationId: 'conv_post',
            senderPubkey: testPubkey,
            content: 'post-reopen group send',
            createdAt: 1700000100,
            giftWrapId: 'gw_post',
            ownerPubkey: testPubkey,
            sendBatchId: 'batch-post',
          );
          expect(
            await database.directMessagesDao.hasMessageWithSendBatchId(
              batchId: 'batch-post',
              ownerPubkey: testPubkey,
            ),
            isTrue,
          );

          await database.outgoingDmsDao.enqueue(
            OutgoingDm(
              id: 'out_post',
              conversationId: 'conv_post',
              recipientPubkey: testPubkey,
              content: 'post-reopen outgoing',
              createdAt: 1700000100,
              rumorEventJson: '{"id":"out_post","kind":14}',
              recipientWrapStatus: OutgoingWrapStatus.pending,
              selfWrapStatus: OutgoingWrapStatus.pending,
              queuedAt: DateTime.utc(2026, 5, 2),
              ownerPubkey: testPubkey,
              sendBatchId: 'batch-post',
            ),
          );
          final outgoing = await database.outgoingDmsDao.getById('out_post');
          expect(outgoing!.sendBatchId, equals('batch-post'));
        },
      );
    });

    group('personal_reactions addressable_id column (#6020)', () {
      test('upgrade path — re-adds addressable_id on personal_reactions on '
          'reopen, and the re-added column is usable', () async {
        // Seed a row under the pre-drop schema, so the DROP exercises a
        // populated table (mirrors the send_batch_id upgrade test).
        await database.personalReactionsDao.upsertReaction(
          targetEventId: 'target_pre',
          reactionEventId: 'reaction_pre',
          userPubkey: testPubkey,
          createdAt: 1700000000,
          addressableId: '34236:$testPubkey:pre-d-tag',
        );

        // Simulate a legacy install that pre-dates the column: drop the
        // index that references it, then the column itself.
        await database.customStatement(
          'DROP INDEX idx_personal_reactions_addressable_id',
        );
        await database.customStatement(
          'ALTER TABLE personal_reactions DROP COLUMN addressable_id',
        );
        expect(
          await _columnNames(database, 'personal_reactions'),
          isNot(contains('addressable_id')),
        );
        await database.close();

        // Reopen the same on-disk file. `beforeOpen` re-adds the column
        // and its index. There is no backfill at the DB layer: the
        // pre-drop coordinate is gone, the column comes back null for
        // that row (same contract as the DM send_batch_id upgrade).
        // Backfill is owned by LikesRepository: initialize() detects
        // null-coordinate rows and runs syncUserReactions(), whose
        // same-reaction-id exemption re-persists the coordinate from the
        // relay reaction's `a` tag even when the relay copy is not newer
        // (#6123). End-to-end pin: likes_repository/test/src/
        // likes_repository_pre_column_db_test.dart.
        database = AppDatabase.test(NativeDatabase(File(tempDbPath)));

        expect(
          await _columnNames(database, 'personal_reactions'),
          contains('addressable_id'),
        );
        expect(
          await _collectIndexNames(database, 'personal_reactions'),
          contains('idx_personal_reactions_addressable_id'),
        );

        // The re-added column is writable and readable end-to-end.
        await database.personalReactionsDao.upsertReaction(
          targetEventId: 'target_post',
          reactionEventId: 'reaction_post',
          userPubkey: testPubkey,
          createdAt: 1700000100,
          addressableId: '34236:$testPubkey:post-d-tag',
        );
        final byCoordinate = await database.personalReactionsDao
            .getReactionByAddressableId(
              addressableId: '34236:$testPubkey:post-d-tag',
              userPubkey: testPubkey,
            );
        expect(byCoordinate, isNotNull);
        expect(byCoordinate!.targetEventId, equals('target_post'));

        // The pre-drop row survived the ALTER TABLE DROP/ADD round trip
        // (SQLite's DROP COLUMN only removes that column; other columns
        // and rows are untouched), now with a null coordinate.
        final preDropRow = await database.personalReactionsDao.getReaction(
          targetEventId: 'target_pre',
          userPubkey: testPubkey,
        );
        expect(preDropRow, isNotNull);
        expect(preDropRow!.addressableId, isNull);
      });
    });
  });
}

/// Captures `pragma table_info(<table>)` as a list of comparable tuples.
///
/// Each entry is `(name, type, notnull, dflt_value)` — the four fields
/// that define the column shape. `cid` is intentionally dropped because
/// it is just the column ordinal and is already encoded by the list
/// position, and `pk` is included because the primary-key flag is part
/// of the shape contract. `dflt_value` is a string sqlite-renders for
/// defaults (e.g. `'0'`, `'14'`) so the same Dart-level default lands
/// at the same string from both the Drift and the runtime SQL paths.
Future<List<List<Object?>>> _collectTableInfo(
  AppDatabase db,
  String table,
) async {
  final rows = await db.customSelect('PRAGMA table_info($table)').get();
  return rows
      .map(
        (row) => <Object?>[
          row.read<String>('name'),
          row.read<String>('type'),
          row.read<int>('notnull'),
          row.readNullable<String>('dflt_value'),
          row.read<int>('pk'),
        ],
      )
      .toList();
}

/// Captures the set of index names attached to [table], excluding the
/// auto-generated `sqlite_autoindex_*` entries that sqlite adds for
/// primary keys. Returns a [Set] because Drift and the runtime SQL may
/// declare indexes in different orders.
Future<Set<String>> _collectIndexNames(AppDatabase db, String table) async {
  final rows = await db
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type='index' "
        "AND tbl_name='$table' AND name NOT LIKE 'sqlite_autoindex_%'",
      )
      .get();
  return rows.map((row) => row.read<String>('name')).toSet();
}

/// Tables that `AppDatabase`'s v1 normalization creates when missing. A
/// shipped v1 install predates some subset of these; the legacy-upgrade test
/// drops all of them to reproduce the oldest shape.
const _v1NormalizationTables = <String>[
  'personal_reposts',
  'nip05_verifications',
  'pending_actions',
  'clips',
  'clip_categories',
  'drafts',
  'direct_messages',
  'conversations',
  'outgoing_dms',
  'pending_profile_saves',
  'dm_message_reactions',
  'pending_view_events',
  'pending_reports',
  'pending_product_events',
  'pending_gift_wraps',
  'processed_gift_wraps',
  'identity_events',
  'identity_verifications',
  'vanished_profiles',
  'seen_videos',
];

/// `event` indexes owned by the normalization SQL rather than by Drift's
/// `m.createAll()`. Dropped alongside `event.d_tag` so the legacy-upgrade
/// test starts from a database that never had them.
const _v1NormalizationEventIndexes = <String>[
  'idx_event_kind_created_at',
  'idx_event_pubkey_created_at',
  'idx_event_pubkey_kind_d_tag_created_at',
  'idx_event_created_at',
  'idx_event_expire_at',
];

/// Recovery-critical indexes owned by normalization SQL.
const _v1NormalizationRepairIndexes = <String>[
  ..._v1NormalizationEventIndexes,
  'idx_dm_reactions_unique_live',
  'idx_pending_product_events_owner',
  'idx_personal_reactions_addressable_id',
  'idx_notification_owner_timestamp',
  'idx_seen_videos_last_seen_at',
  'idx_clip_category_id',
  'idx_clip_category_owner_pubkey',
];

/// The set of column names on [table] per `pragma table_info`.
Future<Set<String>> _columnNames(AppDatabase db, String table) async {
  final rows = await db.customSelect('PRAGMA table_info($table)').get();
  return rows.map((row) => row.read<String>('name')).toSet();
}
