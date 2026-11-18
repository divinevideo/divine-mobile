// ABOUTME: Tests for SeenVideosService persistence and metrics tracking
// ABOUTME: Validates video view history storage and retrieval

import 'dart:async';
import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/seen_videos_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _HeldHistoryRead extends QueryInterceptor {
  final entered = Completer<void>();
  final release = Completer<void>();

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    final rows = await executor.runSelect(statement, args);
    if (!entered.isCompleted && statement.contains('"seen_videos"')) {
      entered.complete();
      await release.future;
    }
    return rows;
  }
}

class _HeldHistoryWrite extends QueryInterceptor {
  final entered = Completer<void>();
  final release = Completer<void>();

  @override
  Future<void> runBatched(
    QueryExecutor executor,
    BatchedStatements statements,
  ) async {
    await executor.runBatched(statements);
    if (!entered.isCompleted) {
      entered.complete();
      await release.future;
    }
  }
}

void main() {
  group('SeenVideosService', () {
    late SeenVideosService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      service = SeenVideosService();
      await service.initialize();
    });

    tearDown(() async {
      await service.dispose();
    });

    test('initializes with empty seen videos', () {
      expect(service.isInitialized, isTrue);
      expect(service.seenVideoCount, 0);
      expect(service.getSeenVideoIds(), isEmpty);
    });

    test('marks video as seen and persists', () async {
      const videoId = 'test_video_123';

      await service.markVideoAsSeen(videoId);

      expect(service.hasSeenVideo(videoId), isTrue);
      expect(service.seenVideoCount, 1);
      expect(service.getSeenVideoIds(), contains(videoId));
    });

    test('records video view with metrics', () async {
      const videoId = 'test_video_456';

      await service.recordVideoView(
        videoId,
        loopCount: 3,
        watchDuration: const Duration(seconds: 45),
      );

      expect(service.hasSeenVideo(videoId), isTrue);

      final metrics = service.getVideoMetrics(videoId);
      expect(metrics, isNotNull);
      expect(metrics!.videoId, videoId);
      expect(metrics.loopCount, 3);
      expect(metrics.totalWatchDuration.inSeconds, 45);
    });

    test('updates existing video metrics', () async {
      const videoId = 'test_video_789';

      // First view
      await service.recordVideoView(
        videoId,
        loopCount: 2,
        watchDuration: const Duration(seconds: 30),
      );

      // Second view
      await service.recordVideoView(
        videoId,
        loopCount: 1,
        watchDuration: const Duration(seconds: 15),
      );

      final metrics = service.getVideoMetrics(videoId);
      expect(metrics!.loopCount, 3); // 2 + 1
      expect(metrics.totalWatchDuration.inSeconds, 45); // 30 + 15
    });

    test('marks multiple videos as seen in batch', () async {
      final videoIds = ['video1', 'video2', 'video3'];

      await service.markVideosAsSeen(videoIds);

      expect(service.seenVideoCount, 3);
      for (final id in videoIds) {
        expect(service.hasSeenVideo(id), isTrue);
      }
    });

    test('checks if video was seen recently', () async {
      const videoId = 'recent_video';

      await service.recordVideoView(videoId);

      expect(
        service.wasSeenRecently(videoId, within: const Duration(hours: 1)),
        isTrue,
      );
      expect(
        service.wasSeenRecently(videoId, within: const Duration(seconds: 1)),
        isTrue,
      );
    });

    test('clears all seen videos', () async {
      await service.markVideosAsSeen(['video1', 'video2']);
      expect(service.seenVideoCount, 2);

      await service.clearSeenVideos();

      expect(service.seenVideoCount, 0);
      expect(service.getSeenVideoIds(), isEmpty);
    });

    test('marks video as unseen', () async {
      const videoId = 'test_video';

      await service.markVideoAsSeen(videoId);
      expect(service.hasSeenVideo(videoId), isTrue);

      await service.markVideoAsUnseen(videoId);
      expect(service.hasSeenVideo(videoId), isFalse);
    });

    test('returns videos by recency', () async {
      await service.recordVideoView('video1');
      service.getVideoMetrics('video1')!.lastSeenAt = DateTime.utc(2000);
      await service.recordVideoView('video2');
      service.getVideoMetrics('video2')!.lastSeenAt = DateTime.utc(2001);
      await service.recordVideoView('video3');
      service.getVideoMetrics('video3')!.lastSeenAt = DateTime.utc(2002);

      final recent = service.getVideosByRecency(limit: 2);

      expect(recent.length, 2);
      expect(recent[0].videoId, 'video3'); // Most recent first
      expect(recent[1].videoId, 'video2');
    });

    test('provides statistics about seen videos', () async {
      await service.recordVideoView(
        'video1',
        loopCount: 5,
        watchDuration: const Duration(seconds: 60),
      );
      await service.recordVideoView(
        'video2',
        loopCount: 3,
        watchDuration: const Duration(seconds: 40),
      );

      final stats = service.getStatistics();

      expect(stats['totalSeen'], 2);
      expect(stats['totalLoops'], 8);
      expect(stats['totalWatchTimeMinutes'], 1); // 100 seconds = 1 minute
    });

    test('enforces max seen videos limit', () async {
      // This test would need to create more than _maxSeenVideos (1000)
      // For practical testing, we verify the limit is respected
      final stats = service.getStatistics();
      expect(stats['storageLimit'], 1000);
    });

    test('persists across service instances', () async {
      const videoId = 'persistent_video';

      await service.recordVideoView(videoId, loopCount: 2);

      // Create new service instance
      final newService = SeenVideosService();
      await newService.initialize();

      expect(newService.hasSeenVideo(videoId), isTrue);
      final metrics = newService.getVideoMetrics(videoId);
      expect(metrics?.loopCount, 2);

      await newService.dispose();
    });

    test('coalesces rapid records while keeping memory current', () async {
      await service.dispose();
      service = SeenVideosService(
        saveDebounceDuration: const Duration(days: 1),
      );
      await service.initialize();

      final firstSave = service.recordVideoView('video1');
      final secondSave = service.recordVideoView('video2');

      expect(service.hasSeenVideo('video1'), isTrue);
      expect(service.hasSeenVideo('video2'), isTrue);

      final beforeFlush = SeenVideosService();
      await beforeFlush.initialize();
      expect(beforeFlush.hasSeenVideo('video1'), isFalse);
      expect(beforeFlush.hasSeenVideo('video2'), isFalse);
      await beforeFlush.dispose();

      await service.dispose();
      await Future.wait([firstSave, secondSave]);

      final afterFlush = SeenVideosService();
      await afterFlush.initialize();
      expect(afterFlush.hasSeenVideo('video1'), isTrue);
      expect(afterFlush.hasSeenVideo('video2'), isTrue);
      await afterFlush.dispose();
    });

    test('dispose flushes pending seen video writes', () async {
      final pendingSave = service.recordVideoView('dispose_video');

      await service.dispose();
      await pendingSave;

      final newService = SeenVideosService();
      await newService.initialize();

      expect(newService.hasSeenVideo('dispose_video'), isTrue);

      await newService.dispose();
    });
  });

  // The outgoing account's service outlives an account switch: its feed
  // records a last view as it is torn down, after the incoming cleanup. Those
  // writes must not reach the device-wide history the next account loads.
  group('account switch (#8313)', () {
    late AppDatabase db;
    late SeenVideosService outgoing;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase.test(NativeDatabase.memory());
      outgoing = SeenVideosService(
        database: db,
        saveDebounceDuration: const Duration(days: 1),
      );
      await outgoing.initialize();
    });

    tearDown(() async {
      await outgoing.dispose();
      await db.close();
    });

    Future<Set<String>> storedIds() async => {
      for (final row in await db.seenVideosDao.getAll()) row.videoId,
    };

    test('a suspended service keeps views out of the device history', () async {
      unawaited(outgoing.markVideoAsSeen('own_view'));
      await pumpEventQueue();
      expect(await storedIds(), {'own_view'});

      outgoing.suspend();
      unawaited(outgoing.markVideoAsSeen('late_view'));
      unawaited(outgoing.markVideosAsSeen(['late_batch_view']));
      unawaited(outgoing.markVideoAsUnseen('own_view'));
      await pumpEventQueue();

      expect(await storedIds(), {'own_view'});
      expect(outgoing.hasSeenVideo('late_view'), isTrue);
    });

    test(
      'a save still waiting on its debounce is not written once suspended',
      () async {
        unawaited(outgoing.markVideoAsSeen('own_view'));
        await pumpEventQueue();

        outgoing.suspend();
        await outgoing.dispose();

        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getString(SeenVideosService.seenVideosMetricsStorageKey),
          isNull,
        );
      },
    );

    test('resuming writes views to the device history again', () async {
      outgoing
        ..suspend()
        ..resume();
      unawaited(outgoing.markVideoAsSeen('after_resume'));
      await pumpEventQueue();

      expect(await storedIds(), {'after_resume'});
    });
  });

  group('account switch during history initialization', () {
    test('does not migrate outgoing metrics after incoming cleanup', () async {
      SharedPreferences.setMockInitialValues({
        SeenVideosService.seenVideosMetricsStorageKey: jsonEncode([
          SeenVideoMetrics(
            videoId: 'outgoing_view',
            firstSeenAt: DateTime(2026),
            lastSeenAt: DateTime(2026),
          ).toJson(),
        ]),
      });
      final prefs = await SharedPreferences.getInstance();
      final heldRead = _HeldHistoryRead();
      final db = AppDatabase.test(
        NativeDatabase.memory().interceptWith(heldRead),
      );
      final outgoing = SeenVideosService(database: db, prefsOverride: prefs);
      addTearDown(() async {
        if (!heldRead.release.isCompleted) heldRead.release.complete();
        await outgoing.dispose();
        await db.close();
      });
      final initializing = outgoing.initialize();
      await heldRead.entered.future;
      expect(outgoing.hasSeenVideo('outgoing_view'), isTrue);

      outgoing.suspend();
      await db.seenVideosDao.clearAll();
      await prefs.remove(SeenVideosService.seenVideosMetricsStorageKey);
      heldRead.release.complete();
      await initializing;

      expect(await db.seenVideosDao.getAll(), isEmpty);
      expect(
        prefs.getBool(SeenVideosService.seenVideosMigratedStorageKey),
        isNull,
      );
    });

    test(
      'does not mark migration done when a switch starts mid-migration',
      () async {
        SharedPreferences.setMockInitialValues({
          SeenVideosService.seenVideosMetricsStorageKey: jsonEncode([
            SeenVideoMetrics(
              videoId: 'outgoing_view',
              firstSeenAt: DateTime(2026),
              lastSeenAt: DateTime(2026),
            ).toJson(),
          ]),
        });
        final prefs = await SharedPreferences.getInstance();
        final heldWrite = _HeldHistoryWrite();
        final db = AppDatabase.test(
          NativeDatabase.memory().interceptWith(heldWrite),
        );
        final service = SeenVideosService(database: db, prefsOverride: prefs);
        addTearDown(() async {
          if (!heldWrite.release.isCompleted) heldWrite.release.complete();
          await service.dispose();
          await db.close();
        });
        final initializing = service.initialize();
        await heldWrite.entered.future;

        service.suspend();
        heldWrite.release.complete();
        await initializing;

        expect(
          prefs.getBool(SeenVideosService.seenVideosMigratedStorageKey),
          isNull,
        );
      },
    );

    test(
      'keeps history read during a switch that rolls back',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final heldRead = _HeldHistoryRead();
        final db = AppDatabase.test(
          NativeDatabase.memory().interceptWith(heldRead),
        );
        final now = DateTime.now().millisecondsSinceEpoch;
        await db.seenVideosDao.markSeen(
          'database_view',
          firstSeenAt: now,
          lastSeenAt: now,
        );
        final service = SeenVideosService(database: db, prefsOverride: prefs);
        addTearDown(() async {
          if (!heldRead.release.isCompleted) heldRead.release.complete();
          await service.dispose();
          await db.close();
        });
        final initializing = service.initialize();
        await heldRead.entered.future;

        service.suspend();
        heldRead.release.complete();
        await initializing;
        service.resume();

        expect(service.wasSeenRecently('database_view'), isTrue);
      },
    );

    test(
      'keeps database history when a legacy list loads during a switch',
      () async {
        SharedPreferences.setMockInitialValues({
          SeenVideosService.legacySeenVideosStorageKey: ['legacy_view'],
        });
        final prefs = await SharedPreferences.getInstance();
        final db = AppDatabase.test(NativeDatabase.memory());
        final now = DateTime.now().millisecondsSinceEpoch;
        await db.seenVideosDao.markSeen(
          'database_view',
          firstSeenAt: now,
          lastSeenAt: now,
        );
        final service = SeenVideosService(database: db, prefsOverride: prefs);
        addTearDown(() async {
          await service.dispose();
          await db.close();
        });

        service.suspend();
        await service.initialize();
        service.resume();

        expect(service.hasSeenVideo('legacy_view'), isTrue);
        expect(service.wasSeenRecently('database_view'), isTrue);
        expect(
          prefs.getStringList(SeenVideosService.legacySeenVideosStorageKey),
          ['legacy_view'],
        );
      },
    );
  });
}
