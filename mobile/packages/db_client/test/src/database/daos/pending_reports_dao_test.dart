// ABOUTME: Unit tests for PendingReportsDao durable content-report outbox.
// ABOUTME: Covers enqueue, per-channel retirement, retry filtering, cleanup.

import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late PendingReportsDao dao;
  late String tempDbPath;

  const userA =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
  const userB =
      'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';

  PendingReport makeReport({
    required String reportId,
    String userPubkey = userA,
    PendingReportChannelStatus relayStatus = PendingReportChannelStatus.pending,
    PendingReportChannelStatus zendeskStatus =
        PendingReportChannelStatus.pending,
    int relayAttempts = 0,
    int zendeskAttempts = 0,
    String? targetRelays,
    DateTime? createdAt,
  }) {
    return PendingReport(
      reportId: reportId,
      userPubkey: userPubkey,
      eventJson: '{"id":"$reportId"}',
      targetRelays: targetRelays,
      zendeskPayload: '{"subject":"$reportId"}',
      relayStatus: relayStatus,
      zendeskStatus: zendeskStatus,
      relayAttempts: relayAttempts,
      zendeskAttempts: zendeskAttempts,
      createdAt: createdAt ?? DateTime.utc(2026, 5),
    );
  }

  setUp(() async {
    final tempDir = Directory.systemTemp.createTempSync(
      'pending_reports_test_',
    );
    tempDbPath = '${tempDir.path}/test.db';
    database = AppDatabase.test(NativeDatabase(File(tempDbPath)));
    dao = database.pendingReportsDao;
  });

  tearDown(() async {
    await database.close();
    final file = File(tempDbPath);
    if (file.existsSync()) file.deleteSync();
    final dir = Directory(tempDbPath).parent;
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  group('PendingReportsDao', () {
    group('enqueue', () {
      test('inserts a report with both channels pending', () async {
        await dao.enqueue(
          makeReport(reportId: 'r1', targetRelays: '["wss://x"]'),
        );

        final fetched = await dao.getById('r1');

        expect(fetched, isNotNull);
        expect(fetched!.userPubkey, userA);
        expect(fetched.eventJson, '{"id":"r1"}');
        expect(fetched.targetRelays, '["wss://x"]');
        expect(fetched.zendeskPayload, '{"subject":"r1"}');
        expect(fetched.relayStatus, PendingReportChannelStatus.pending);
        expect(fetched.zendeskStatus, PendingReportChannelStatus.pending);
        expect(fetched.relayAttempts, 0);
        expect(fetched.zendeskAttempts, 0);
      });

      test('ignores a duplicate report id rather than overwriting', () async {
        await dao.enqueue(makeReport(reportId: 'r1'));
        await dao.markChannelDone(
          reportId: 'r1',
          channel: ReportChannel.relay,
        );

        // A second enqueue of the same id must not reset the relay channel.
        await dao.enqueue(makeReport(reportId: 'r1'));

        final fetched = await dao.getById('r1');
        expect(fetched!.relayStatus, PendingReportChannelStatus.done);
      });
    });

    group('getRetryableForUser', () {
      test(
        'returns rows with at least one pending channel, oldest first',
        () async {
          await dao.enqueue(
            makeReport(reportId: 'older', createdAt: DateTime.utc(2026)),
          );
          await dao.enqueue(
            makeReport(reportId: 'newer', createdAt: DateTime.utc(2026, 6)),
          );

          final rows = await dao.getRetryableForUser(userPubkey: userA);

          expect(rows.map((r) => r.reportId), ['older', 'newer']);
        },
      );

      test('excludes a row whose channels are both retired', () async {
        await dao.enqueue(makeReport(reportId: 'done-both'));
        await dao.markChannelDone(
          reportId: 'done-both',
          channel: ReportChannel.relay,
        );
        await dao.markChannelDeadLetter(
          reportId: 'done-both',
          channel: ReportChannel.zendesk,
          error: 'gave up',
        );

        final rows = await dao.getRetryableForUser(userPubkey: userA);
        expect(rows, isEmpty);
      });

      test('keeps a row while any channel is still pending', () async {
        await dao.enqueue(makeReport(reportId: 'half'));
        await dao.markChannelDone(
          reportId: 'half',
          channel: ReportChannel.relay,
        );

        final rows = await dao.getRetryableForUser(userPubkey: userA);
        expect(rows.single.reportId, 'half');
        expect(rows.single.relayStatus, PendingReportChannelStatus.done);
        expect(rows.single.zendeskStatus, PendingReportChannelStatus.pending);
      });

      test('scopes to the requested user', () async {
        await dao.enqueue(makeReport(reportId: 'mine'));
        await dao.enqueue(makeReport(reportId: 'theirs', userPubkey: userB));

        final rows = await dao.getRetryableForUser(userPubkey: userA);
        expect(rows.map((r) => r.reportId), ['mine']);
      });

      test('honors limit', () async {
        for (var i = 0; i < 5; i++) {
          await dao.enqueue(
            makeReport(
              reportId: 'r$i',
              createdAt: DateTime.utc(2026, 1, i + 1),
            ),
          );
        }
        final rows = await dao.getRetryableForUser(userPubkey: userA, limit: 3);
        expect(rows, hasLength(3));
      });
    });

    group('channel transitions', () {
      test('markChannelDone retires only the named channel', () async {
        await dao.enqueue(makeReport(reportId: 'r1'));

        await dao.markChannelDone(
          reportId: 'r1',
          channel: ReportChannel.zendesk,
        );

        final r = await dao.getById('r1');
        expect(r!.zendeskStatus, PendingReportChannelStatus.done);
        expect(r.relayStatus, PendingReportChannelStatus.pending);
      });

      test(
        'recordChannelFailure increments attempts, keeps it pending',
        () async {
          await dao.enqueue(makeReport(reportId: 'r1'));

          await dao.recordChannelFailure(
            reportId: 'r1',
            channel: ReportChannel.relay,
            error: 'relay timeout',
          );

          final r = await dao.getById('r1');
          expect(r!.relayStatus, PendingReportChannelStatus.pending);
          expect(r.relayAttempts, 1);
          expect(r.zendeskAttempts, 0);
          expect(r.lastError, 'relay timeout');
        },
      );

      test('markChannelDeadLetter terminates the channel and counts the '
          'attempt', () async {
        await dao.enqueue(makeReport(reportId: 'r1', relayAttempts: 9));

        await dao.markChannelDeadLetter(
          reportId: 'r1',
          channel: ReportChannel.relay,
          error: 'exhausted',
        );

        final r = await dao.getById('r1');
        expect(r!.relayStatus, PendingReportChannelStatus.deadLetter);
        expect(r.relayAttempts, 10);
        expect(r.lastError, 'exhausted');
      });

      test('a transition on a missing row reports no update', () async {
        final updated = await dao.markChannelDone(
          reportId: 'ghost',
          channel: ReportChannel.relay,
        );
        expect(updated, isFalse);
      });
    });

    group('cleanup', () {
      test('deleteById removes one row', () async {
        await dao.enqueue(makeReport(reportId: 'r1'));
        await dao.deleteById('r1');
        expect(await dao.getById('r1'), isNull);
      });

      test('deleteAllForUser removes only that user rows', () async {
        await dao.enqueue(makeReport(reportId: 'mine'));
        await dao.enqueue(makeReport(reportId: 'theirs', userPubkey: userB));

        await dao.deleteAllForUser(userA);

        expect(await dao.getById('mine'), isNull);
        expect(await dao.getById('theirs'), isNotNull);
      });
    });

    group('status parsing', () {
      test(
        'a corrupt channel status throws rather than coercing to pending',
        () async {
          await dao.enqueue(makeReport(reportId: 'r1'));
          await database.customStatement(
            "UPDATE pending_reports SET relay_status = 'bogus' "
            "WHERE report_id = 'r1'",
          );

          expect(
            () => dao.getById('r1'),
            throwsA(isA<UnknownPendingReportStatusException>()),
          );
        },
      );
    });
  });
}
