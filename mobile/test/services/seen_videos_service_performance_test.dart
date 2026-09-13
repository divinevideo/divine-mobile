import 'dart:async';
import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/performance_monitoring_service.dart';
import 'package:openvine/services/seen_videos_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Database extends Mock implements AppDatabase {}

class _SeenDao extends Mock implements SeenVideosDao {}

class _Preferences extends Mock implements SharedPreferences {}

class _Trace implements PerformanceTrace {
  final attributes = <String, String>{};
  final metrics = <String, int>{};
  final stopped = Completer<void>();
  int stopCount = 0;

  @override
  void putAttribute(String attribute, String value) =>
      attributes[attribute] = value;

  @override
  void setMetric(String metric, int value) => metrics[metric] = value;

  @override
  Future<void> stop() {
    stopCount++;
    return stopped.future;
  }
}

class _Monitor implements PerformanceTraceMonitor {
  final traces = <String, List<_Trace>>{};

  @override
  PerformanceTrace startOperationTrace(String traceName) {
    final trace = _Trace();
    traces.putIfAbsent(traceName, () => []).add(trace);
    return trace;
  }

  void finishStops() {
    for (final trace in traces.values.expand((traces) => traces)) {
      trace.stopped.complete();
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('SeenVideosService performance', () {
    const videoId =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    late _Monitor monitor;
    late _Database database;
    late _SeenDao dao;
    late SharedPreferences prefs;
    late SeenVideosService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      monitor = _Monitor();
      database = _Database();
      dao = _SeenDao();
      when(() => database.seenVideosDao).thenReturn(dao);
      when(() => dao.pruneExpired()).thenAnswer((_) async => 0);
      service = SeenVideosService(
        database: database,
        prefsOverride: prefs,
        performanceMonitor: monitor,
      );
    });

    tearDown(() async {
      monitor.finishStops();
      await service.dispose();
    });

    test(
      'separates database waiting from merge and concurrent feed waits',
      () async {
        final read = Completer<List<SeenVideoRow>>();
        when(() => dao.getAll()).thenAnswer((_) => read.future);
        await prefs.setBool(
          SeenVideosService.seenVideosMigratedStorageKey,
          true,
        );

        final initialization = service.initialize();
        final firstWait = service.initializeForFeed();
        final secondWait = service.initializeForFeed();
        var feedFinished = false;
        unawaited(firstWait.then((_) => feedFinished = true));
        await pumpEventQueue();

        final initializationTrace =
            monitor.traces['seen_videos_initialize']!.single;
        expect(feedFinished, isFalse);
        expect(initializationTrace.metrics, contains('preferences_decode_ms'));
        expect(
          initializationTrace.metrics,
          isNot(contains('database_read_ms')),
        );
        expect(initializationTrace.stopCount, 0);

        read.complete([
          const SeenVideoRow(videoId: videoId, firstSeenAt: 1, lastSeenAt: 2),
        ]);
        await Future.wait([initialization, firstWait, secondWait]);

        expect(service.hasSeenVideo(videoId), isTrue);
        expect(initializationTrace.attributes['completion'], 'success');
        expect(initializationTrace.metrics['database_rows'], 1);
        expect(initializationTrace.metrics['seen_count'], 1);
        expect(initializationTrace.metrics, contains('database_read_ms'));
        expect(initializationTrace.metrics, contains('database_merge_ms'));
        expect(initializationTrace.stopCount, 1);
        for (final trace in monitor.traces['feed_wait_seen_history']!) {
          expect(trace.attributes, {
            'initialization_state': 'in_progress',
            'completion': 'ready',
          });
          expect(trace.metrics, contains('wait_ms'));
          expect(trace.stopCount, 1);
          // Native telemetry completion is deliberately still pending.
          expect(trace.stopped.isCompleted, isFalse);
        }
        await service.initializeForFeed();
        await service.initialize();
        expect(monitor.traces['seen_videos_initialize'], hasLength(1));
        expect(monitor.traces['feed_wait_seen_history'], hasLength(2));
        verify(() => dao.getAll()).called(1);
      },
    );

    test(
      'a feed may start initialization and reports a partial database read',
      () async {
        await prefs.setString(
          SeenVideosService.seenVideosMetricsStorageKey,
          jsonEncode([
            SeenVideoMetrics(
              videoId: videoId,
              firstSeenAt: DateTime(2026),
              lastSeenAt: DateTime(2026),
            ).toJson(),
          ]),
        );
        when(() => dao.getAll()).thenThrow(StateError('read unavailable'));

        await service.initializeForFeed();

        expect(service.isInitialized, isTrue);
        expect(service.hasSeenVideo(videoId), isTrue);
        final trace = monitor.traces['seen_videos_initialize']!.single;
        expect(trace.attributes['completion'], 'partial');
        expect(trace.attributes['failed_phase'], 'database_read_ms');
        expect(trace.metrics['preferences_json_chars'], greaterThan(0));
        expect(trace.metrics, contains('database_read_ms'));
        expect(trace.metrics, isNot(contains('database_merge_ms')));
        expect(trace.stopCount, 1);
        expect(
          monitor
              .traces['feed_wait_seen_history']!
              .single
              .attributes['initialization_state'],
          'not_started',
        );
      },
    );

    test(
      'malformed history records the decode failure and closes the trace',
      () async {
        await prefs.setString(
          SeenVideosService.seenVideosMetricsStorageKey,
          '{',
        );

        await service.initialize();

        final trace = monitor.traces['seen_videos_initialize']!.single;
        expect(trace.attributes['completion'], 'partial');
        expect(trace.attributes['failed_phase'], 'preferences_decode_ms');
        expect(trace.metrics, contains('preferences_decode_ms'));
        expect(trace.metrics, isNot(contains('database_read_ms')));
        expect(trace.stopCount, 1);
        verifyNever(() => dao.getAll());
      },
    );

    test('legacy preference write failures are labeled partial', () async {
      final failingPrefs = _Preferences();
      when(
        () => failingPrefs.getStringList(
          SeenVideosService.legacySeenVideosStorageKey,
        ),
      ).thenReturn([videoId]);
      when(() => failingPrefs.setString(any(), any())).thenThrow(
        StateError('write unavailable'),
      );
      when(() => failingPrefs.remove(any())).thenAnswer((_) async => true);
      service = SeenVideosService(
        prefsOverride: failingPrefs,
        performanceMonitor: monitor,
      );

      await service.initialize();

      final trace = monitor.traces['seen_videos_initialize']!.single;
      expect(trace.attributes['completion'], 'partial');
      expect(trace.attributes['failed_phase'], 'legacy_migration_ms');
      expect(trace.metrics, contains('legacy_migration_ms'));
      expect(trace.stopCount, 1);
      expect(service.hasSeenVideo(videoId), isTrue);
    });

    for (final migrationFails in [false, true]) {
      test('records migration work (failure: $migrationFails)', () async {
        await prefs.setStringList(
          SeenVideosService.legacySeenVideosStorageKey,
          [videoId],
        );
        when(() => dao.getAll()).thenAnswer((_) async => []);
        when(() => dao.markSeenBatch(any())).thenAnswer((_) async {
          if (migrationFails) throw StateError('write unavailable');
        });

        await service.initialize();

        final trace = monitor.traces['seen_videos_initialize']!.single;
        expect(trace.metrics, contains('legacy_migration_ms'));
        expect(trace.metrics, contains('database_migration_ms'));
        expect(trace.metrics['database_rows'], 0);
        expect(trace.metrics['seen_count'], 1);
        expect(
          trace.attributes['completion'],
          migrationFails ? 'partial' : 'success',
        );
        expect(
          trace.attributes['failed_phase'],
          migrationFails ? 'database_migration_ms' : null,
        );
        expect(trace.stopCount, 1);
        expect(service.hasSeenVideo(videoId), isTrue);
      });
    }

    test(
      'preferences-only startup reports counts without database phases',
      () async {
        service = SeenVideosService(
          prefsOverride: prefs,
          performanceMonitor: monitor,
        );
        await service.initialize();
        final trace = monitor.traces['seen_videos_initialize']!.single;
        expect(trace.attributes['storage'], 'preferences');
        expect(trace.attributes['completion'], 'success');
        expect(trace.metrics['seen_count'], 0);
        expect(trace.metrics['metrics_count'], 0);
        expect(trace.metrics, isNot(contains('database_read_ms')));
        expect(trace.stopCount, 1);
      },
    );
  });
}
