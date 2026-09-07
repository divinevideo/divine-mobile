// ABOUTME: Tests for ReportRetryService sweep, backoff, dead-letter, cleanup.
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

  test('dead-letters a channel at the attempt cap and keeps the row', () async {
    // zendesk already delivered; relay on its final attempt.
    await dao.enqueue(
      makeReport(
        reportId: 'r1',
        zendeskStatus: PendingReportChannelStatus.done,
        relayAttempts: 9,
      ),
    );
    driver.fail('r1', ReportChannel.relay);

    // Default config caps at 10 attempts per channel.
    await buildService().sweep();

    final r = await dao.getById('r1');
    expect(r, isNotNull);
    expect(r!.relayStatus, PendingReportChannelStatus.deadLetter);
    expect(r.relayAttempts, 10);
  });

  test('foreground true triggers a sweep', () async {
    await dao.enqueue(makeReport(reportId: 'r1'));
    driver
      ..succeed('r1', ReportChannel.relay)
      ..succeed('r1', ReportChannel.zendesk);
    final service = buildService();
    await service.initialize();

    foreground.add(true);
    // let the unawaited sweep run
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(await dao.getById('r1'), isNull);
    await service.dispose();
  });
}
