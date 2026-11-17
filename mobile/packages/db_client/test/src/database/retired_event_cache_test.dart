// ABOUTME: Covers bounded retired-cache reclamation and durable-data isolation.
import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  setUp(() async {
    db = AppDatabase.test(NativeDatabase.memory());
    await db.customSelect('SELECT 1').get();
  });
  tearDown(() => db.close());

  test('does nothing on a fresh database', () async {
    expect(await RetiredEventCache(db).pruneBatch(), isFalse);
  });

  test(
    'deletes at most one batch and resumes with a new maintenance instance',
    () async {
      await db.customStatement(
        'CREATE TABLE retired_event_cache_v36 '
        '(id TEXT PRIMARY KEY, content TEXT)',
      );
      await db.customStatement(
        'CREATE TABLE retired_video_metrics_v36 '
        '(event_id TEXT PRIMARY KEY, likes INTEGER)',
      );
      await db.customStatement(
        'CREATE INDEX retired_content ON retired_event_cache_v36 (content)',
      );
      await db.batch((batch) {
        for (var i = 0; i < 501; i++) {
          final id = i.toRadixString(16).padLeft(64, '0');
          batch
            ..customStatement(
              'INSERT INTO retired_event_cache_v36 VALUES (?,?)',
              [id, 'cached'],
            )
            ..customStatement(
              'INSERT INTO retired_video_metrics_v36 VALUES (?,?)',
              [id, 7],
            );
        }
        batch.customStatement(
          'INSERT INTO drafts (id,created_at,last_modified,data) '
          "VALUES ('draft',100,100,'{}')",
        );
      });

      Future<int> count(String table) async =>
          (await db
                  .customSelect(
                    'SELECT count(*) AS n FROM $table',
                  )
                  .getSingle())
              .read<int>('n');

      expect(await RetiredEventCache(db).pruneBatch(), isTrue);
      expect(await count(retiredVideoMetricsTable), 251);
      expect(await count(retiredEventCacheTable), 501);
      expect(await RetiredEventCache(db).pruneBatch(), isTrue);
      expect(await count(retiredVideoMetricsTable), 1);
      expect(await RetiredEventCache(db).pruneBatch(), isTrue);
      expect(await count(retiredVideoMetricsTable), 0);
      expect(await count(retiredEventCacheTable), 501);
      expect(await RetiredEventCache(db).pruneBatch(), isTrue);
      expect(await count(retiredEventCacheTable), 251);
      while (await RetiredEventCache(db).pruneBatch()) {}

      expect(
        await db
            .customSelect(
              'SELECT name FROM sqlite_master WHERE name IN '
              "('retired_event_cache_v36','retired_video_metrics_v36',"
              "'retired_content')",
            )
            .get(),
        isEmpty,
      );
      expect((await db.select(db.drafts).get()).single.id, 'draft');
      expect(await db.nostrEventsDao.getEventCount(), 0);
    },
  );
}
