// ABOUTME: Tests durable report sweeps, reconnects, backoff, and acknowledgements.
// ABOUTME: Uses a real in-memory PendingReportsDao and a scripted driver.

import 'dart:async';
import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/report_retry_service.dart';

/// Scripted driver: per-(reportId, channel) result, or throw.
class _FakeDriver implements ReportChannelDriver {
  final Map<String, bool> _results = {};
  final Set<String> _throws = {};
  final List<String> calls = [];
  void Function(String)? onCall;

  String _key(String reportId, ReportChannel c) => '$reportId:${c.name}';

  void succeed(String reportId, ReportChannel c) =>
      _results[_key(reportId, c)] = true;
  void fail(String reportId, ReportChannel c) =>
      _results[_key(reportId, c)] = false;
  void throwOn(String reportId, ReportChannel c) =>
      _throws.add(_key(reportId, c));

  @override
  Future<bool> deliverReportChannel(
    PendingReport report,
    ReportChannel channel,
  ) async {
    final key = _key(report.reportId, channel);
    calls.add(key);
    onCall?.call(key);
    if (_throws.contains(key)) throw StateError('boom');
    return _results[key] ?? false;
  }
}

void main() {
  late AppDatabase database;
  late PendingReportsDao dao;
  late String tempDbPath;
  late _FakeDriver driver;
  late StreamController<bool> foreground;

  const user =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

  PendingReport makeReport({
    required String reportId,
    PendingReportChannelStatus relayStatus = PendingReportChannelStatus.pending,
    PendingReportChannelStatus zendeskStatus =
        PendingReportChannelStatus.pending,
    int relayAttempts = 0,
    int zendeskAttempts = 0,
    DateTime? lastAttemptAt,
  }) => PendingReport(
    reportId: reportId,
    userPubkey: user,
    eventJson: '{"id":"$reportId"}',
    zendeskPayload: '{}',
    relayStatus: relayStatus,
    zendeskStatus: zendeskStatus,
    relayAttempts: relayAttempts,
    zendeskAttempts: zendeskAttempts,
    lastAttemptAt: lastAttemptAt,
    createdAt: DateTime.utc(2026, 5),
  );

  ReportRetryService buildService({
    ReportRetryConfig config = const ReportRetryConfig(),
    DateTime Function()? now,
  }) => ReportRetryService(
    driver: driver,
    pendingReportsDao: dao,
    userPubkey: user,
    appForegroundStream: foreground.stream,
    retryConfig: config,
    now: now ?? DateTime.now,
  );

  setUp(() async {
    final tempDir = Directory.systemTemp.createTempSync('report_retry_test_');
    tempDbPath = '${tempDir.path}/test.db';
    database = AppDatabase.test(NativeDatabase(File(tempDbPath)));
    dao = database.pendingReportsDao;
    driver = _FakeDriver();
    foreground = StreamController<bool>.broadcast();
  });

  tearDown(() async {
    await foreground.close();
    await database.close();
    final file = File(tempDbPath);
    if (file.existsSync()) file.deleteSync();
    final dir = Directory(tempDbPath).parent;
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  group('ReportRetryService', () {
    test('deletes a report once both channels are delivered', () async {
      await dao.enqueue(makeReport(reportId: 'r1'));
      driver
        ..succeed('r1', ReportChannel.relay)
        ..succeed('r1', ReportChannel.zendesk);

      await buildService().sweep();

      expect(await dao.getById('r1'), isNull);
    });

    test('retires only the delivered channel and keeps the row', () async {
      await dao.enqueue(makeReport(reportId: 'r1'));
      driver
        ..fail('r1', ReportChannel.relay)
        ..succeed('r1', ReportChannel.zendesk);

      await buildService().sweep();

      final r = await dao.getById('r1');
      expect(r, isNotNull);
      expect(r!.zendeskStatus, PendingReportChannelStatus.done);
      expect(r.relayStatus, PendingReportChannelStatus.pending);
      expect(r.relayAttempts, 1);
    });

    test('a thrown driver error counts as a failed attempt', () async {
      await dao.enqueue(makeReport(reportId: 'r1'));
      driver
        ..throwOn('r1', ReportChannel.relay)
        ..succeed('r1', ReportChannel.zendesk);

      await buildService().sweep();

      final r = await dao.getById('r1');
      expect(r!.relayStatus, PendingReportChannelStatus.pending);
      expect(r.relayAttempts, 1);
    });

    test('skips a row still inside its backoff window', () async {
      final now = DateTime.utc(2026, 6, 1, 12);
      await dao.enqueue(
        makeReport(
          reportId: 'r1',
          relayAttempts: 1,
          zendeskAttempts: 1,
          // attempted 1s ago; backoff after 1 attempt is > 1s
          lastAttemptAt: now.subtract(const Duration(seconds: 1)),
        ),
      );
      driver
        ..succeed('r1', ReportChannel.relay)
        ..succeed('r1', ReportChannel.zendesk);

      await buildService(now: () => now).sweep();

      expect(driver.calls, isEmpty, reason: 'backoff must gate the drive');
      expect(await dao.getById('r1'), isNotNull);
    });

    test('drives a row once its backoff window has elapsed', () async {
      final now = DateTime.utc(2026, 6, 1, 12);
      await dao.enqueue(
        makeReport(
          reportId: 'r1',
          relayAttempts: 1,
          zendeskAttempts: 1,
          lastAttemptAt: now.subtract(const Duration(minutes: 10)),
        ),
      );
      driver
        ..succeed('r1', ReportChannel.relay)
        ..succeed('r1', ReportChannel.zendesk);

      await buildService(now: () => now).sweep();

      expect(await dao.getById('r1'), isNull);
    });

    test(
      'retains failed reports after ten attempts for later reconnect',
      () async {
        // A long outage has already used nine relay attempts.
        await dao.enqueue(
          makeReport(
            reportId: 'r1',
            zendeskStatus: PendingReportChannelStatus.done,
            relayAttempts: 9,
          ),
        );
        driver.fail('r1', ReportChannel.relay);

        // A long outage must not silently exhaust the report.
        await buildService().sweep();

        final r = await dao.getById('r1');
        expect(r, isNotNull);
        expect(r!.relayStatus, PendingReportChannelStatus.pending);
        expect(r.relayAttempts, 10);
      },
    );

    test(
      'a stalled channel cannot hold later reports past its deadline',
      () async {
        final held = Completer<bool>();
        final service = ReportRetryService(
          driver: _BlockedFirstDriver(held.future),
          pendingReportsDao: dao,
          userPubkey: user,
          appForegroundStream: foreground.stream,
          retryConfig: const ReportRetryConfig(attemptTimeout: Duration.zero),
        );
        await dao.enqueue(makeReport(reportId: 'slow'));
        await dao.enqueue(makeReport(reportId: 'next'));
        await service.sweep();
        expect(await dao.getById('next'), isNull);
        expect(
          (await dao.getById('slow'))!.relayStatus,
          PendingReportChannelStatus.pending,
        );
        held.complete(false);
      },
    );

    test('does not redeliver a later row retired during the sweep', () async {
      final held = Completer<bool>();
      final blocked = _BlockedFirstDriver(held.future);
      final service = ReportRetryService(
        driver: blocked,
        pendingReportsDao: dao,
        userPubkey: user,
        appForegroundStream: foreground.stream,
      );
      await dao.enqueue(makeReport(reportId: 'slow'));
      await dao.enqueue(makeReport(reportId: 'next'));
      final sweep = service.sweep();
      await blocked.started.future;
      await dao.markChannelDone(reportId: 'next', channel: ReportChannel.relay);
      await dao.markChannelDone(
        reportId: 'next',
        channel: ReportChannel.zendesk,
      );
      await dao.deleteIfDelivered('next');
      held.complete(true);
      await sweep;
      expect(blocked.calls.where((key) => key.startsWith('next:')), isEmpty);
    });

    test('a late acknowledgement retires the timed-out channel', () async {
      final held = Completer<bool>();
      final service = ReportRetryService(
        driver: _BlockedFirstDriver(held.future),
        pendingReportsDao: dao,
        userPubkey: user,
        appForegroundStream: foreground.stream,
        retryConfig: const ReportRetryConfig(attemptTimeout: Duration.zero),
      );
      await dao.enqueue(makeReport(reportId: 'slow'));
      await service.sweep();
      final acknowledged =
          (database.select(database.pendingReports)
                ..where((row) => row.reportId.equals('slow')))
              .watchSingleOrNull()
              .firstWhere((row) => row == null);
      held.complete(true);
      await acknowledged;
      expect(await dao.getRetryableForUser(userPubkey: user), isEmpty);
      await service.sweep(force: true);
      expect(await dao.getById('slow'), isNull);
    });

    test(
      'schedules a retry while the app stays open on the same network',
      () async {
        await dao.enqueue(makeReport(reportId: 'scheduled'));
        final firstAttempt = Completer<void>();
        driver.onCall = (key) {
          if (key == 'scheduled:relay' && !firstAttempt.isCompleted) {
            firstAttempt.complete();
          }
        };
        final service = buildService(
          config: const ReportRetryConfig(
            initialDelay: Duration.zero,
            maxDelay: Duration.zero,
          ),
        );
        addTearDown(service.dispose);
        await service.initialize();
        await firstAttempt.future;
        driver
          ..succeed('scheduled', ReportChannel.relay)
          ..succeed('scheduled', ReportChannel.zendesk);
        await database
            .select(database.pendingReports)
            .watch()
            .firstWhere((rows) => rows.isEmpty);
        expect(
          driver.calls.where((key) => key == 'scheduled:relay').length,
          greaterThan(1),
        );
      },
    );

    test('reconnect retries without a foreground transition', () async {
      final reconnect = StreamController<void>();
      final service = ReportRetryService(
        driver: driver,
        pendingReportsDao: dao,
        userPubkey: user,
        appForegroundStream: foreground.stream,
        retryTriggerStream: reconnect.stream,
      );
      addTearDown(service.dispose);
      addTearDown(reconnect.close);
      await service.initialize();
      await pumpEventQueue();
      await dao.enqueue(
        makeReport(
          reportId: 'offline',
          relayAttempts: 20,
          zendeskAttempts: 20,
          lastAttemptAt: DateTime.now(),
        ),
      );
      driver
        ..succeed('offline', ReportChannel.relay)
        ..succeed('offline', ReportChannel.zendesk);
      reconnect.add(null);
      await pumpEventQueue();
      expect(await dao.getById('offline'), isNull);
    });

    test(
      'a newly saved report is driven at once, without forcing the rest',
      () async {
        final queued = StreamController<void>();
        final service = ReportRetryService(
          driver: driver,
          pendingReportsDao: dao,
          userPubkey: user,
          appForegroundStream: foreground.stream,
          reportQueuedStream: queued.stream,
        );
        addTearDown(service.dispose);
        addTearDown(queued.close);
        await service.initialize();
        await pumpEventQueue();
        await dao.enqueue(
          makeReport(
            reportId: 'waiting',
            relayAttempts: 20,
            zendeskAttempts: 20,
            lastAttemptAt: DateTime.now(),
          ),
        );
        await dao.enqueue(makeReport(reportId: 'fresh'));
        driver
          ..succeed('fresh', ReportChannel.relay)
          ..succeed('fresh', ReportChannel.zendesk);
        queued.add(null);
        await pumpEventQueue();
        expect(await dao.getById('fresh'), isNull);
        expect(driver.calls, ['fresh:relay', 'fresh:zendesk']);
      },
    );

    test(
      'one slow channel does not prevent another channel delivering',
      () async {
        final relay = Completer<bool>();
        final concurrent = _ConcurrentDriver(relay.future);
        final service = ReportRetryService(
          driver: concurrent,
          pendingReportsDao: dao,
          userPubkey: user,
          appForegroundStream: foreground.stream,
        );
        await dao.enqueue(makeReport(reportId: 'slow'));
        final pass = service.sweep();
        await concurrent.zendeskStarted.future;
        await pumpEventQueue();
        expect(
          (await dao.getById('slow'))!.zendeskStatus,
          PendingReportChannelStatus.done,
        );
        relay.complete(true);
        await pass;
        expect(await dao.getById('slow'), isNull);
      },
    );

    test('reports in backoff do not starve newly queued reports', () async {
      for (var i = 0; i < 25; i++) {
        await dao.enqueue(
          makeReport(
            reportId: 'old-$i',
            relayAttempts: 20,
            zendeskAttempts: 20,
            lastAttemptAt: DateTime.now(),
          ),
        );
      }
      await dao.enqueue(makeReport(reportId: 'new'));
      driver
        ..succeed('new', ReportChannel.relay)
        ..succeed('new', ReportChannel.zendesk);
      await buildService().sweep();
      expect(await dao.getById('new'), isNull);
      expect(driver.calls, ['new:relay', 'new:zendesk']);
    });

    test('foreground true triggers a sweep', () async {
      await dao.enqueue(makeReport(reportId: 'r1'));
      driver
        ..succeed('r1', ReportChannel.relay)
        ..succeed('r1', ReportChannel.zendesk);
      final service = buildService();
      await service.initialize();

      foreground.add(true);
      // Drain the unawaited sweep deterministically rather than racing a timer.
      await pumpEventQueue();

      expect(await dao.getById('r1'), isNull);
      await service.dispose();
    });
    group('giving up', () {
      test('gives up on a destination that has failed too many times', () async {
        // Without a cap this row is retried on every foreground for the life of
        // the install, holding its signed event and payloads on the device.
        await dao.enqueue(
          makeReport(
            reportId: 'r1',
            relayStatus: PendingReportChannelStatus.done,
            zendeskAttempts: 2,
          ),
        );
        driver.fail('r1', ReportChannel.zendesk);
        driver.succeed('r1', ReportChannel.moderation);

        await buildService(
          config: const ReportRetryConfig(maxAttemptsPerChannel: 3),
        ).sweep();

        // Settled everywhere — delivered or given up on — so the row retires.
        expect(await dao.getById('r1'), isNull);
      });

      test('keeps retrying below the attempt cap', () async {
        await dao.enqueue(
          makeReport(
            reportId: 'r1',
            relayStatus: PendingReportChannelStatus.done,
          ),
        );
        driver.fail('r1', ReportChannel.zendesk);
        driver.succeed('r1', ReportChannel.moderation);

        await buildService(
          config: const ReportRetryConfig(maxAttemptsPerChannel: 3),
        ).sweep();

        final row = await dao.getById('r1');
        expect(row, isNotNull);
        expect(row!.zendeskStatus, PendingReportChannelStatus.pending);
      });
    });
  });
}

class _ConcurrentDriver implements ReportChannelDriver {
  _ConcurrentDriver(this.relay);
  final Future<bool> relay;
  final zendeskStarted = Completer<void>();
  @override
  Future<bool> deliverReportChannel(
    PendingReport report,
    ReportChannel channel,
  ) {
    if (channel == ReportChannel.relay) return relay;
    zendeskStarted.complete();
    return Future.value(true);
  }
}

class _BlockedFirstDriver implements ReportChannelDriver {
  _BlockedFirstDriver(this.held);
  final Future<bool> held;
  final started = Completer<void>();
  final calls = <String>[];
  @override
  Future<bool> deliverReportChannel(
    PendingReport report,
    ReportChannel channel,
  ) {
    calls.add('${report.reportId}:${channel.name}');
    if (report.reportId == 'slow' && channel == ReportChannel.relay) {
      if (!started.isCompleted) started.complete();
      return held;
    }
    return Future.value(true);
  }
}
