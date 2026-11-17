// ABOUTME: Opt-in large encrypted upgrade benchmark; uses synthetic data only.
import 'dart:convert';
import 'dart:io';
import 'package:db_client/db_client.dart';
import 'package:db_client/src/database/connection/connection_native.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

final measurements = <Map<String, Object?>>[];
final outputFile = File(
  const String.fromEnvironment('CACHE_BENCHMARK_OUTPUT').isEmpty
      ? '${Directory.systemTemp.path}/divine-event-cache-benchmark.json'
      : const String.fromEnvironment('CACHE_BENCHMARK_OUTPUT'),
);

const baseline = bool.fromEnvironment('BASELINE_V35');
const encrypted = bool.fromEnvironment('ENCRYPTED_CACHE', defaultValue: true);
void configure(Database db) {
  if (encrypted) applyCipherKey(db, key);
}

const eventCount = int.fromEnvironment(
  'CACHE_BENCHMARK_EVENT_COUNT',
  defaultValue: 200000,
);

class TargetDatabase extends AppDatabase {
  TargetDatabase(super.e);
  @override
  int get schemaVersion => baseline ? 35 : 36;
}

const key = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
Future<T> timed<T>(String label, Future<T> Function() operation) async {
  final watch = Stopwatch()..start();
  final result = await operation();
  measurements.add({'label': label, 'milliseconds': watch.elapsedMilliseconds});
  return result;
}

class Recorder extends QueryInterceptor {
  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String sql,
    List<Object?> args,
  ) => timed(sql, () => executor.runUpdate(sql, args));
  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String sql,
    List<Object?> args,
  ) async {
    final watch = Stopwatch()..start();
    final result = await executor.runSelect(sql, args);
    if (watch.elapsedMilliseconds > 10) {
      measurements.add({
        'label': sql,
        'milliseconds': watch.elapsedMilliseconds,
      });
    }
    return result;
  }
}

void main() {
  group('onUpgrade benchmark', () {
    test('profile healthy encrypted opens with a large cache', () async {
      final root = Directory.systemTemp.createTempSync('startup-profile-');
      addTearDown(() {
        outputFile.writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert(measurements),
        );
        if (root.existsSync()) root.deleteSync(recursive: true);
      });
      final file = File('${root.path}/cache.db');
      AppDatabase open() => TargetDatabase(
        NativeDatabase(
          file,
          setup: configure,
        ).interceptWith(Recorder()),
      );
      var db = AppDatabase.test(
        NativeDatabase(file, setup: configure),
      );
      await db.customSelect('SELECT 1').get();
      await db.close();
      final raw = sqlite3.open(file.path);
      configure(raw);
      final indexes = raw.select(
        "SELECT name,sql FROM sqlite_master WHERE type='index' "
        "AND name LIKE '%_v36'",
      );
      for (final index in indexes) {
        raw.execute('DROP INDEX ${index['name']}');
        if (!(index['name'] as String).contains('verified')) {
          raw.execute((index['sql'] as String).replaceAll('_v36', ''));
        }
      }
      final event = raw.prepare(
        'INSERT INTO event '
        '(id,pubkey,created_at,kind,tags,content,sig,expire_at, '
        'signature_verified) '
        'VALUES (?,?,?,?,?,?,?,?,?)',
      );
      final metrics = raw.prepare(
        'INSERT INTO video_metrics (event_id,likes,updated_at) VALUES (?,?,?)',
      );
      final profile = raw.prepare(
        'INSERT INTO user_profiles '
        '(pubkey,raw_data,created_at,event_id,last_fetched) VALUES (?,?,?,?,?)',
      );
      final watch = Stopwatch()..start();
      raw.execute('BEGIN');
      for (var i = 0; i < eventCount; i++) {
        final id = i.toRadixString(16).padLeft(64, '0');
        event.execute([
          id,
          'b' * 64,
          i,
          1,
          '[]',
          'x' * 2048,
          'c' * 128,
          4102444800,
          0,
        ]);
        metrics.execute([id, 0, 1]);
      }
      for (var i = 0; i < 5000; i++) {
        profile.execute([
          i.toRadixString(16).padLeft(64, '0'),
          'x' * 8192,
          1,
          'd' * 64,
          i,
        ]);
      }
      raw.execute('COMMIT');
      event.close();
      metrics.close();
      profile.close();
      raw
        ..execute('PRAGMA user_version = 34')
        ..close();
      measurements.add({
        'encrypted': encrypted,
        'target': baseline ? 35 : 36,
        'events': eventCount,
        'seedMilliseconds': watch.elapsedMilliseconds,
        'fileBytes': file.lengthSync(),
      });
      for (var launch = 0; launch < 2; launch++) {
        db = open();
        await timed('open $launch', () => db.customSelect('SELECT 1').get());
        await timed(
          'event expiry',
          () => db.nostrEventsDao.deleteExpiredEvents(null),
        );
        await timed('profile stats', () => db.profileStatsDao.deleteExpired());
        await timed(
          'notifications',
          () => db.notificationsDao.deleteCachedBefore(
            DateTime.now().subtract(const Duration(days: 7)),
          ),
        );
        await timed(
          'metrics orphans',
          () => db.videoMetricsDao.deleteOrphaned(),
        );
        await timed('profile cap', () => db.userProfilesDao.enforceRowCap());
        if (!baseline) {
          expect(await db.nostrEventsDao.getEventCount(), 0);
          await timed(
            'idle metrics batch',
            () => RetiredEventCache(db).pruneBatch(),
          );
        }
        await db.close();
      }
    }, timeout: const Timeout(Duration(minutes: 10)));
  });
}
