// ABOUTME: Data Access Object for the durable content-report outbox.
// ABOUTME: Holds reports until the kind-1984 publish and Zendesk ticket land.

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

part 'pending_reports_dao.g.dart';

/// The two off-device channels a report row tracks. The moderation DM is not
/// here: it keeps its own `outgoing_dms` outbox.
enum ReportChannel { relay, zendesk }

/// Per-channel delivery state.
///
/// A channel that failed an attempt stays [pending] (with an incremented
/// attempt count) and is retried after backoff; it moves to [deadLetter] only
/// once it exhausts its attempt budget. There is deliberately no transient
/// "in-flight" state: a crash mid-drive leaves the channel [pending], so it is
/// simply retried, and republish/re-file are idempotent.
enum PendingReportChannelStatus { pending, done, deadLetter }

class UnknownPendingReportStatusException implements Exception {
  const UnknownPendingReportStatusException(this.rawValue);

  final String rawValue;

  @override
  String toString() {
    final known = PendingReportChannelStatus.values
        .map((e) => e.name)
        .join(', ');
    return 'UnknownPendingReportStatusException: '
        'unrecognised pending_reports channel status "$rawValue"; '
        'expected one of $known';
  }
}

@immutable
class PendingReport {
  const PendingReport({
    required this.reportId,
    required this.userPubkey,
    required this.eventJson,
    required this.zendeskPayload,
    required this.createdAt,
    this.targetRelays,
    this.relayStatus = PendingReportChannelStatus.pending,
    this.zendeskStatus = PendingReportChannelStatus.pending,
    this.relayAttempts = 0,
    this.zendeskAttempts = 0,
    this.lastError,
    this.lastAttemptAt,
  });

  final String reportId;
  final String userPubkey;
  final String eventJson;
  final String? targetRelays;
  final String zendeskPayload;
  final PendingReportChannelStatus relayStatus;
  final PendingReportChannelStatus zendeskStatus;
  final int relayAttempts;
  final int zendeskAttempts;
  final String? lastError;
  final DateTime? lastAttemptAt;
  final DateTime createdAt;

  /// The delivery state of one channel.
  PendingReportChannelStatus statusOf(ReportChannel channel) =>
      channel == ReportChannel.relay ? relayStatus : zendeskStatus;

  /// The attempt count of one channel.
  int attemptsOf(ReportChannel channel) =>
      channel == ReportChannel.relay ? relayAttempts : zendeskAttempts;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PendingReport &&
          runtimeType == other.runtimeType &&
          reportId == other.reportId;

  @override
  int get hashCode => reportId.hashCode;
}

@DriftAccessor(tables: [PendingReports])
class PendingReportsDao extends DatabaseAccessor<AppDatabase>
    with _$PendingReportsDaoMixin {
  PendingReportsDao(super.attachedDatabase);

  PendingReportsCompanion _modelToCompanion(PendingReport report) {
    return PendingReportsCompanion.insert(
      reportId: report.reportId,
      userPubkey: report.userPubkey,
      eventJson: report.eventJson,
      targetRelays: Value(report.targetRelays),
      zendeskPayload: report.zendeskPayload,
      relayStatus: report.relayStatus.name,
      zendeskStatus: report.zendeskStatus.name,
      relayAttempts: Value(report.relayAttempts),
      zendeskAttempts: Value(report.zendeskAttempts),
      lastError: Value(report.lastError),
      lastAttemptAt: Value(report.lastAttemptAt),
      createdAt: report.createdAt,
    );
  }

  PendingReport _rowToModel(PendingReportRow row) {
    return PendingReport(
      reportId: row.reportId,
      userPubkey: row.userPubkey,
      eventJson: row.eventJson,
      targetRelays: row.targetRelays,
      zendeskPayload: row.zendeskPayload,
      relayStatus: _parseStatus(row.relayStatus),
      zendeskStatus: _parseStatus(row.zendeskStatus),
      relayAttempts: row.relayAttempts,
      zendeskAttempts: row.zendeskAttempts,
      lastError: row.lastError,
      lastAttemptAt: row.lastAttemptAt,
      createdAt: row.createdAt,
    );
  }

  PendingReportChannelStatus _parseStatus(String raw) {
    for (final status in PendingReportChannelStatus.values) {
      if (status.name == raw) return status;
    }
    throw UnknownPendingReportStatusException(raw);
  }

  Future<void> enqueue(PendingReport report) async {
    await into(
      pendingReports,
    ).insert(_modelToCompanion(report), mode: InsertMode.insertOrIgnore);
  }

  Future<PendingReport?> getById(String reportId) async {
    final row = await (select(
      pendingReports,
    )..where((t) => t.reportId.equals(reportId))).getSingleOrNull();
    return row == null ? null : _rowToModel(row);
  }

  /// Reports for [userPubkey] with at least one channel still `pending`,
  /// oldest first. A row whose channels are all `done`/`deadLetter` is not
  /// retryable and is skipped.
  Future<List<PendingReport>> getRetryableForUser({
    required String userPubkey,
    int? limit,
  }) async {
    const pending = 'pending';
    final query = select(pendingReports)
      ..where(
        (t) =>
            t.userPubkey.equals(userPubkey) &
            (t.relayStatus.equals(pending) | t.zendeskStatus.equals(pending)),
      )
      ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]);
    if (limit != null) {
      query.limit(limit);
    }
    final rows = await query.get();
    return rows.map(_rowToModel).toList();
  }

  /// Marks [channel] delivered. Returns whether a row was updated.
  Future<bool> markChannelDone({
    required String reportId,
    required ReportChannel channel,
  }) {
    return _writeChannel(
      reportId,
      channel,
      status: PendingReportChannelStatus.done,
    );
  }

  /// Records a failed attempt on [channel]: increments its attempt count and
  /// stores the error, leaving the channel `pending` so a later sweep retries.
  Future<bool> recordChannelFailure({
    required String reportId,
    required ReportChannel channel,
    required String error,
  }) {
    return _writeChannel(
      reportId,
      channel,
      incrementAttempt: true,
      error: error,
    );
  }

  /// Terminates [channel] after it exhausts its attempt budget. The row is kept
  /// for inspection rather than deleted.
  Future<bool> markChannelDeadLetter({
    required String reportId,
    required ReportChannel channel,
    required String error,
  }) {
    return _writeChannel(
      reportId,
      channel,
      status: PendingReportChannelStatus.deadLetter,
      incrementAttempt: true,
      error: error,
    );
  }

  Future<bool> _writeChannel(
    String reportId,
    ReportChannel channel, {
    PendingReportChannelStatus? status,
    bool incrementAttempt = false,
    String? error,
  }) {
    return transaction(() async {
      final row = await (select(
        pendingReports,
      )..where((t) => t.reportId.equals(reportId))).getSingleOrNull();
      if (row == null) return false;

      final isRelay = channel == ReportChannel.relay;
      final attempts = isRelay ? row.relayAttempts : row.zendeskAttempts;
      final nextAttempts = incrementAttempt ? attempts + 1 : attempts;

      final companion = PendingReportsCompanion(
        relayStatus: isRelay && status != null
            ? Value(status.name)
            : const Value.absent(),
        zendeskStatus: !isRelay && status != null
            ? Value(status.name)
            : const Value.absent(),
        relayAttempts: isRelay && incrementAttempt
            ? Value(nextAttempts)
            : const Value.absent(),
        zendeskAttempts: !isRelay && incrementAttempt
            ? Value(nextAttempts)
            : const Value.absent(),
        lastError: error != null ? Value(error) : const Value.absent(),
        lastAttemptAt: Value(DateTime.now()),
      );

      final rows = await (update(
        pendingReports,
      )..where((t) => t.reportId.equals(reportId))).write(companion);
      return rows > 0;
    });
  }

  Future<int> deleteById(String reportId) {
    return (delete(
      pendingReports,
    )..where((t) => t.reportId.equals(reportId))).go();
  }

  /// Deletes every queued report belonging to [userPubkey]. Used on account
  /// switch/wipe so one account's reports never sweep under another.
  Future<int> deleteAllForUser(String userPubkey) {
    return (delete(
      pendingReports,
    )..where((t) => t.userPubkey.equals(userPubkey))).go();
  }
}
