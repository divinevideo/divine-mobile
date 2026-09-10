// TDD: storage migration preserves history, deep-fetch coverage, DAO direct tests
import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/seen_videos_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppDatabase _inMemoryDb() => AppDatabase.test(NativeDatabase.memory());

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SeenVideosService storage migration', () {
    late AppDatabase db;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = _inMemoryDb();
      await db.customSelect('SELECT 1').get();
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'migrates existing SharedPreferences JSON to Drift on first init',
      () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'seen_video_metrics',
          '[{"videoId":"vid-1","firstSeenAt":1786164648252,"lastSeenAt":1786164648252,"loopCount":1,"totalWatchDurationMs":1000,"lastWatchDurationMs":1000},{"videoId":"vid-2","firstSeenAt":1786164648252,"lastSeenAt":1786164648252,"loopCount":2,"totalWatchDurationMs":2000,"lastWatchDurationMs":2000},{"videoId":"vid-3","firstSeenAt":1786164648252,"lastSeenAt":1786164648252,"loopCount":0,"totalWatchDurationMs":0,"lastWatchDurationMs":0}]',
        );

        final service = SeenVideosService(database: db);
        await service.initialize();

        expect(service.seenVideoCount, 3);
        expect(service.hasSeenVideo('vid-1'), isTrue);
        expect(service.hasSeenVideo('vid-2'), isTrue);
        expect(service.getVideoMetrics('vid-1')!.loopCount, 1);

        // initialize does not complete until the migration is durable.
        final count = await db.seenVideosDao.count();
        expect(count, 3);

        // Second service with same DB and prefs should hydrate from DB
        final service2 = SeenVideosService(database: db);
        await service2.initialize();
        expect(service2.hasSeenVideo('vid-1'), isTrue);
        expect(service2.hasSeenVideo('vid-3'), isTrue);
        expect(service2.seenVideoCount, 3);
      },
    );

    test(
      'hydrates from Drift even when prefs JSON was truncated to 1000',
      () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'seen_video_metrics',
          '[{"videoId":"vid-4","firstSeenAt":1786164648252,"lastSeenAt":1704153600000,"loopCount":0,"totalWatchDurationMs":0,"lastWatchDurationMs":0},{"videoId":"vid-5","firstSeenAt":1786164648252,"lastSeenAt":1704153600000,"loopCount":0,"totalWatchDurationMs":0,"lastWatchDurationMs":0}]',
        );
        final now = DateTime.now().millisecondsSinceEpoch;
        for (var i = 1; i <= 5; i++) {
          await db.seenVideosDao.markSeen(
            'vid-$i',
            firstSeenAt: now,
            lastSeenAt: now,
          );
        }
        await prefs.setBool('seen_videos_migrated_to_db', true);

        final service = SeenVideosService(database: db);
        await service.initialize();

        expect(service.seenVideoCount, 5);
        expect(service.hasSeenVideo('vid-1'), isTrue);
        expect(
          service.getSeenVideoIds(),
          containsAll(['vid-1', 'vid-2', 'vid-3', 'vid-4', 'vid-5']),
        );
      },
    );

    test('wasSeenRecently respects window', () async {
      final service = SeenVideosService(database: db);
      await service.initialize();
      await service.recordVideoView('vid-recent');
      expect(service.wasSeenRecently('vid-recent'), isTrue);
      expect(
        service.wasSeenRecently(
          'vid-recent',
          within: Duration.zero,
        ),
        isFalse,
      );
      expect(service.wasSeenRecently('vid-unknown'), isFalse);
    });

    test('clearSeenVideos clears both prefs and DB', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'seen_video_metrics',
        '[{"videoId":"vid-1","firstSeenAt":1786164648252,"lastSeenAt":1786164648252,"loopCount":0,"totalWatchDurationMs":0,"lastWatchDurationMs":0}]',
      );
      final service = SeenVideosService(database: db);
      await service.initialize();
      expect(service.seenVideoCount, 1);

      await service.clearSeenVideos();
      expect(service.seenVideoCount, 0);
      expect(await db.seenVideosDao.count(), 0);
      expect(prefs.getString('seen_video_metrics'), isNull);
    });

    test('clearSeenVideos propagates database deletion failures', () async {
      const videoId =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      final service = SeenVideosService(database: db);
      await service.initialize();
      await service.recordVideoView(videoId);
      expect(await db.seenVideosDao.count(), 1);
      await db.customStatement('''
        CREATE TRIGGER reject_seen_cleanup BEFORE DELETE ON seen_videos
        BEGIN SELECT RAISE(ABORT, 'seen cleanup failed'); END
      ''');

      await expectLater(service.clearSeenVideos(), throwsException);
      expect(await db.seenVideosDao.count(), 1);
    });

    test('persists across service instances via DB', () async {
      final service1 = SeenVideosService(database: db);
      await service1.initialize();
      await service1.recordVideoView('vid-persist');
      expect(await db.seenVideosDao.hasSeen('vid-persist'), isTrue);
      await service1.dispose();

      final service2 = SeenVideosService(database: db);
      await service2.initialize();
      expect(service2.hasSeenVideo('vid-persist'), isTrue);
    });

    test('batch mark refreshes a hydrated DB row before returning', () async {
      final prefs = await SharedPreferences.getInstance();
      final old =
          DateTime.now().millisecondsSinceEpoch -
          const Duration(days: 2).inMilliseconds;
      await db.seenVideosDao.markSeen(
        'vid-batch',
        firstSeenAt: old,
        lastSeenAt: old,
      );
      await prefs.setBool('seen_videos_migrated_to_db', true);
      final service = SeenVideosService(database: db);
      await service.initialize();

      await service.markVideosAsSeen(['vid-batch']);

      final row = (await db.seenVideosDao.getAll()).single;
      expect(row.firstSeenAt, old);
      expect(row.lastSeenAt, greaterThan(old));
    });

    test('DAO pruneExpired respects 1yr TTL', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final old = now - const Duration(days: 400).inMilliseconds;
      await db.seenVideosDao.markSeen(
        'vid-old',
        firstSeenAt: old,
        lastSeenAt: old,
      );
      await db.seenVideosDao.markSeen(
        'vid-fresh',
        firstSeenAt: now,
        lastSeenAt: now,
      );
      final pruned = await db.seenVideosDao.pruneExpired();
      expect(pruned, 1);
      expect(await db.seenVideosDao.hasSeen('vid-old'), isFalse);
      expect(await db.seenVideosDao.hasSeen('vid-fresh'), isTrue);
    });

    test('pure SharedPreferences fallback when no DB', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'seen_video_metrics',
        '[{"videoId":"vid-fallback","firstSeenAt":1786164648252,"lastSeenAt":${DateTime.now().millisecondsSinceEpoch},"loopCount":0,"totalWatchDurationMs":0,"lastWatchDurationMs":0}]',
      );
      final service = SeenVideosService();
      await service.initialize();
      expect(service.hasSeenVideo('vid-fallback'), isTrue);
      expect(service.wasSeenRecently('vid-fallback'), isTrue);
    });
  });
}
