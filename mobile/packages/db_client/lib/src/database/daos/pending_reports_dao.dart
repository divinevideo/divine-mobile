// ABOUTME: Data Access Object for the durable content-report outbox.
// ABOUTME: Tracks relay, support ticket, and private moderation delivery.

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

part 'pending_reports_dao.g.dart';

/// Independently retried destinations for a saved report.
enum ReportChannel { relay, zendesk, moderation }

/// Per-channel delivery state.
///
/// Failed attempts remain [pending] across restarts. The retry worker does not
/// exhaust a retry budget; [deadLetter] remains readable for stored rows.
/// There is no transient in-flight state to lose during a crash. Relay events
/// and moderation rumors keep stable ids; ticket retries are at-least-once.
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
    this.moderationPayload,
    this.moderationStatus = PendingReportChannelStatus.done,
    this.moderationAttempts = 0,
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
  final String? moderationPayload;
  final PendingReportChannelStatus moderationStatus;
  final int moderationAttempts;
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
      switch (channel) {
        ReportChannel.relay => relayStatus,
        ReportChannel.zendesk => zendeskStatus,
        ReportChannel.moderation => moderationStatus,
      };

  /// The attempt count of one channel.
  int attemptsOf(ReportChannel channel) => switch (channel) {
    ReportChannel.relay => relayAttempts,
    ReportChannel.zendesk => zendeskAttempts,
    ReportChannel.moderation => moderationAttempts,
  };

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
      moderationPayload: Value(report.moderationPayload),
      moderationStatus: Value(report.moderationStatus.name),
      moderationAttempts: Value(report.moderationAttempts),
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
      moderationPayload: row.moderationPayload,
      moderationStatus: _parseStatus(row.moderationStatus),
      moderationAttempts: row.moderationAttempts,
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
            (t.relayStatus.equals(pending) |
                t.zendeskStatus.equals(pending) |
                t.moderationStatus.equals(pending)),
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
      final attempts = _rowToModel(row).attemptsOf(channel);
      final nextAttempts = incrementAttempt ? attempts + 1 : attempts;

      final companion = PendingReportsCompanion(
        relayStatus: isRelay && status != null
            ? Value(status.name)
            : const Value.absent(),
        zendeskStatus: channel == ReportChannel.zendesk && status != null
            ? Value(status.name)
            : const Value.absent(),
        relayAttempts: isRelay && incrementAttempt
            ? Value(nextAttempts)
            : const Value.absent(),
        zendeskAttempts: channel == ReportChannel.zendesk && incrementAttempt
            ? Value(nextAttempts)
            : const Value.absent(),
        moderationStatus: channel == ReportChannel.moderation && status != null
            ? Value(status.name)
            : const Value.absent(),
        moderationAttempts:
            channel == ReportChannel.moderation && incrementAttempt
            ? Value(nextAttempts)
            : const Value.absent(),
        lastError: error != null ? Value(error) : const Value.absent(),
        // Only an actual attempt moves the clock. All three destinations share
        // it, so stamping it when one is retired would push the others a full
        // backoff interval further out for a delivery they had no part in.
        lastAttemptAt: incrementAttempt
            ? Value(DateTime.now())
            : const Value.absent(),
      );

      final rows = await (update(
        pendingReports,
      )..where((t) => t.reportId.equals(reportId))).write(companion);
      return rows > 0;
    });
  }

  /// Retire only after every requested destination has acknowledged the report.
  /// Retire a row once no destination is still waiting — delivered or given
  /// up on. [deleteIfDelivered] only retires a fully-delivered report, so a
  /// destination that can never succeed (no support-ticket credentials on this
  /// build, a message the policy gate refuses) would otherwise keep the row,
  /// and its signed event and payloads, on the device for the life of the
  /// install.
  Future<int> deleteIfSettled(String reportId) =>
      (delete(pendingReports)..where(
            (row) =>
                row.reportId.equals(reportId) &
                row.relayStatus
                    .equals(PendingReportChannelStatus.pending.name)
                    .not() &
                row.zendeskStatus
                    .equals(PendingReportChannelStatus.pending.name)
                    .not() &
                row.moderationStatus
                    .equals(PendingReportChannelStatus.pending.name)
                    .not(),
          ))
          .go();

  Future<int> deleteIfDelivered(String reportId) =>
      (delete(pendingReports)..where(
            (row) =>
                row.reportId.equals(reportId) &
                row.relayStatus.equals(PendingReportChannelStatus.done.name) &
                row.zendeskStatus.equals(PendingReportChannelStatus.done.name) &
                row.moderationStatus.equals(
                  PendingReportChannelStatus.done.name,
                ),
          ))
          .go();

  /// Freeze the signed event before any publish so every retry uses its id.
  Future<bool> saveSignedEvent(String reportId, String eventJson) async {
    final count =
        await (update(pendingReports)
              ..where((t) => t.reportId.equals(reportId)))
            .write(PendingReportsCompanion(eventJson: Value(eventJson)));
    return count == 1;
  }

  Future<int> deleteById(String reportId) {
    return (delete(
      pendingReports,
    )..where((t) => t.reportId.equals(reportId))).go();
  }

  /// Deletes every queued report belonging to [userPubkey].
  ///
  /// Called on the destructive account-wipe path (parity with the sibling
  /// `outgoing_dms` outbox) so a departing account's identity-bearing report
  /// rows are not orphaned. A plain account switch preserves them. #8053.
  Future<int> deleteAllForUser(String userPubkey) {
    return (delete(
      pendingReports,
    )..where((t) => t.userPubkey.equals(userPubkey))).go();
  }
}
