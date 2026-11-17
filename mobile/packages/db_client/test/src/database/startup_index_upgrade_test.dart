// ABOUTME: Verifies event-cache rotation never indexes or copies old payloads.
// ABOUTME: Preserves durable data and leaves retired rows for idle cleanup.
import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../drift/app_database/generated/schema.dart';

class _RecordingDatabase extends AppDatabase {
  _RecordingDatabase(super.e);
  final statements = <String>[];

  @override
  Future<void> customStatement(String statement, [List<dynamic>? args]) {
    statements.add(statement);
    return super.customStatement(statement, args);
  }
}

class _InterruptedDatabase extends AppDatabase {
  _InterruptedDatabase(super.e);

  @override
  Future<void> customStatement(String statement, [List<dynamic>? args]) async {
    await super.customStatement(statement, args);
    if (statement == 'ALTER TABLE event RENAME TO $retiredEventCacheTable') {
      throw StateError('interrupted cache rotation');
    }
  }
}

void main() {
  group('onUpgrade', () {
    test(
      'legacy normalization preserves retired indexes for idle cleanup',
      () async {
        final schema = await SchemaVerifier(GeneratedHelper()).schemaAt(1);
        schema.rawDatabase.execute(
          'CREATE INDEX idx_event_pubkey_kind_d_tag ON event (pubkey,kind)',
        );
        final db = _RecordingDatabase(schema.newConnection());
        addTearDown(db.close);
        expect(await db.nostrEventsDao.getEventCount(), 0);
        final index = await db
            .customSelect(
              'SELECT tbl_name FROM sqlite_master '
              "WHERE name='idx_event_pubkey_kind_d_tag'",
            )
            .getSingle();
        expect(index.read<String>('tbl_name'), retiredEventCacheTable);
        expect(
          db.statements.where(
            (sql) =>
                sql.contains('DROP INDEX') &&
                sql.contains('idx_event_pubkey_kind_d_tag'),
          ),
          isEmpty,
        );
      },
    );

    test(
      'an interrupted rotation rolls back both renames and retries cleanly',
      () async {
        final schema = await SchemaVerifier(GeneratedHelper()).schemaAt(34);
        schema.rawDatabase.execute(
          'INSERT INTO event '
          '(id,pubkey,created_at,kind,tags,content,sig,expire_at) '
          'VALUES (?,?,?,?,?,?,?,?)',
          ['a' * 64, 'b' * 64, 100, 1, '[]', 'cached', 'c' * 128, 4102444800],
        );
        final interrupted = _InterruptedDatabase(schema.newConnection());
        await expectLater(
          interrupted.customSelect('SELECT 1').get(),
          throwsA(isA<StateError>()),
        );
        await interrupted.close();
        expect(
          schema.rawDatabase
              .select(
                'SELECT content FROM event',
              )
              .single['content'],
          'cached',
        );
        expect(
          schema.rawDatabase.select(
            'SELECT name FROM sqlite_master '
            "WHERE name='retired_event_cache_v36'",
          ),
          isEmpty,
        );

        final retry = AppDatabase(schema.newConnection());
        addTearDown(retry.close);
        expect(await retry.nostrEventsDao.getEventCount(), 0);
        expect(
          (await retry
                  .customSelect(
                    'SELECT content FROM retired_event_cache_v36',
                  )
                  .getSingle())
              .read<String>('content'),
          'cached',
        );
      },
    );

    for (final hasRetiredTables in [false, true]) {
      test('re-upgrade after rollback keeps current indexes '
          '(retired=$hasRetiredTables)', () async {
        final schema = await SchemaVerifier(GeneratedHelper()).schemaAt(36);
        var db = AppDatabase(schema.newConnection());
        await db.customStatement(
          'INSERT INTO event '
          '(id,pubkey,created_at,kind,tags,content,sig,expire_at, '
          'signature_verified) '
          'VALUES (?,?,?,?,?,?,?,?,?)',
          [
            'a' * 64,
            'b' * 64,
            100,
            1,
            '[]',
            'current',
            'c' * 128,
            4102444800,
            1,
          ],
        );
        await db.close();
        if (hasRetiredTables) {
          schema.rawDatabase.execute(
            'CREATE TABLE retired_event_cache_v36 (id TEXT)',
          );
          schema.rawDatabase.execute(
            'CREATE TABLE retired_video_metrics_v36 (event_id TEXT)',
          );
        }
        // A shipped v35 build lowers user_version when opening a v36 file.
        schema.rawDatabase.execute('PRAGMA user_version = 35');
        db = AppDatabase(schema.newConnection());
        addTearDown(db.close);
        expect(await db.nostrEventsDao.getEventCount(), 1);
        final owner = await db
            .customSelect(
              'SELECT tbl_name FROM sqlite_master '
              "WHERE name='idx_event_verified_created_at_v36'",
            )
            .getSingle();
        expect(owner.read<String>('tbl_name'), 'event');
      });
    }

    for (final version in [34, 35]) {
      test(
        'v$version replaces caches without scanning them or losing drafts',
        () async {
          final verifier = SchemaVerifier(GeneratedHelper());
          final schema = await verifier.schemaAt(version);
          const eventIndexes = {
            'idx_event_kind_created_at': 'kind,created_at',
            'idx_event_pubkey_created_at': 'pubkey,created_at',
            'idx_event_pubkey_kind_d_tag_created_at':
                'pubkey,kind,d_tag,created_at',
            'idx_event_created_at': 'created_at',
            'idx_event_expire_at': 'expire_at',
          };
          for (final entry in eventIndexes.entries) {
            schema.rawDatabase.execute(
              'CREATE INDEX IF NOT EXISTS ${entry.key} '
              'ON event (${entry.value})',
            );
          }
          final id = 'a' * 64;
          schema.rawDatabase.execute(
            'INSERT INTO event (id,pubkey,created_at,kind,tags,content,sig, '
            'expire_at,signature_verified) VALUES (?,?,?,?,?,?,?,?,?)',
            [id, 'b' * 64, 100, 1, '[]', 'cached', 'c' * 128, 4102444800, 1],
          );
          schema.rawDatabase.execute(
            'INSERT INTO video_metrics '
            '(event_id,likes,updated_at) VALUES (?,7,100)',
            [id],
          );
          schema.rawDatabase.execute(
            'INSERT INTO drafts (id,created_at,last_modified,data) '
            "VALUES ('kept-draft',100,100,'{}')",
          );
          schema.rawDatabase.execute(
            'INSERT INTO personal_events '
            '(id,pubkey,kind,created_at,tags,content,sig,retention) '
            'VALUES (?,?,34236,100,?,?,?,1)',
            ['d' * 64, 'b' * 64, '[]', 'signed outbound', 'c' * 128],
          );
          final db = _RecordingDatabase(schema.newConnection());
          addTearDown(db.close);

          expect(await db.nostrEventsDao.getEventCount(), 0);
          expect(await db.select(db.videoMetrics).get(), isEmpty);
          expect((await db.select(db.drafts).get()).single.data, '{}');
          expect(
            (await db.select(db.personalEvents).get()).single.content,
            'signed outbound',
          );
          expect(
            (await db
                    .customSelect(
                      'SELECT content FROM retired_event_cache_v36',
                    )
                    .get())
                .single
                .read<String>('content'),
            'cached',
          );
          expect(
            (await db
                    .customSelect(
                      'SELECT likes FROM retired_video_metrics_v36',
                    )
                    .get())
                .single
                .read<int>('likes'),
            7,
          );
          expect(
            db.statements.where(
              (sql) =>
                  sql.contains('CREATE INDEX') &&
                  (sql.contains('ON retired_') ||
                      sql.contains('idx_event_verified_created_at ON event')),
            ),
            isEmpty,
          );
          final foreignKeys = await db
              .customSelect(
                'PRAGMA foreign_key_list(video_metrics)',
              )
              .get();
          expect(foreignKeys.single.read<String>('table'), 'event');
          final indexes = await db
              .customSelect(
                'PRAGMA index_list(event)',
              )
              .get();
          expect(
            indexes.map((row) => row.read<String>('name')),
            containsAll([
              'idx_event_verified_created_at_v36',
              ...eventIndexes.keys.map((name) => '${name}_v36'),
            ]),
          );
          final metricIndexes = await db
              .customSelect(
                'PRAGMA index_list(video_metrics)',
              )
              .get();
          expect(
            metricIndexes.map((row) => row.read<String>('name')),
            containsAll([
              'idx_metrics_loop_count_v36',
              'idx_metrics_likes_v36',
              'idx_metrics_views_v36',
            ]),
          );
          for (final name in eventIndexes.keys) {
            final owner = await db
                .customSelect(
                  'SELECT tbl_name FROM sqlite_master '
                  "WHERE type='index' AND name=?",
                  variables: [Variable.withString(name)],
                )
                .getSingle();
            expect(owner.read<String>('tbl_name'), retiredEventCacheTable);
          }
        },
      );
    }
  });
}
