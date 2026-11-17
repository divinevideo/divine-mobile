// ABOUTME: Keeps already-bounded profile caches out of startup eviction scans.
import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _EvictionRecorder extends QueryInterceptor {
  int evictions = 0;
  String? overflowQuery;
  List<Object?>? overflowArgs;
  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String sql,
    List<Object?> args,
  ) {
    if (sql.contains('DELETE FROM user_profiles')) evictions++;
    return executor.runUpdate(sql, args);
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String sql,
    List<Object?> args,
  ) {
    if (sql.contains('FROM user_profiles')) {
      overflowQuery = sql;
      overflowArgs = args;
    }
    return executor.runSelect(sql, args);
  }
}

void main() {
  group('enforceRowCap', () {
    test(
      'an at-cap cache skips payload eviction and checks a covering index',
      () async {
        final recorder = _EvictionRecorder();
        final db = AppDatabase.test(
          NativeDatabase.memory().interceptWith(recorder),
        );
        addTearDown(db.close);
        await db.customStatement(
          'INSERT INTO user_profiles '
          '(pubkey,created_at,event_id,last_fetched,raw_data) '
          'VALUES (?,?,?,?,?)',
          ['a' * 64, 100, 'b' * 64, 100, 'x' * 8192],
        );
        recorder.evictions = 0;
        expect(await db.userProfilesDao.enforceRowCap(maxRows: 1), 0);
        expect(recorder.evictions, 0);
        final query = recorder.overflowQuery!;
        final args = recorder.overflowArgs!;
        final plan = await db
            .customSelect(
              'EXPLAIN QUERY PLAN $query',
              variables: [Variable.withInt(args.single! as int)],
            )
            .get();
        expect(
          plan.map((row) => row.read<String>('detail')).join(' '),
          contains('COVERING INDEX'),
        );
      },
    );
  });
}
