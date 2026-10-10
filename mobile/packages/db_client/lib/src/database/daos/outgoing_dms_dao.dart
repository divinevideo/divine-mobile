// ABOUTME: Data Access Object for the durable outgoing-DM queue.
// ABOUTME: Tracks per-wrap publish status (recipient + self gift wrap)
// ABOUTME: so partial deliveries can be retried without double-delivering.

import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

part 'outgoing_dms_dao.g.dart';

String? _rumorIdFromJson(String rumorEventJson) {
  try {
    final decoded = jsonDecode(rumorEventJson);
    if (decoded is Map<String, dynamic>) {
      final value = decoded['id'];
      if (value is String && value.isNotEmpty) return value;
    }
  } on FormatException {
    return null;
  }
  return null;
}

/// Status of one of the two NIP-17 gift-wrap publishes for an outgoing DM.
///
/// Each row in `outgoing_dms` carries two of these — one for the
/// recipient gift wrap and one for the self-addressed gift wrap. They
/// transition independently so a partial delivery (recipient sent, self
/// failed) can be retried without re-publishing to the recipient.
enum OutgoingWrapStatus {
  /// Not yet attempted, or attempted and waiting for a relay reply.
  pending,

  /// Published and accepted by at least one relay.
  sent,

  /// Last attempt failed. `last_error` carries the reason; the retry
  /// service will replay this wrap (only) until `retry_count` reaches
  /// the policy cap.
  failed,

  /// A terminal policy refusal. The row remains visible as the sender's only
  /// durable copy, but retry queries must never re-drive it.
  blocked,

  /// The sender stopped this delivery. Terminal: retry queries never re-drive
  /// it. The row is kept only as the record that this recipient was not
  /// reached, for as long as the message it belongs to is still shown.
  cancelled,
}

/// Thrown when [OutgoingDmsDao] reads a row whose persisted wrap-status
/// string does not match any known [OutgoingWrapStatus].
///
/// This signals either database corruption or a downgrade from a future
/// schema that introduced new states. The DAO refuses to coerce the
/// unknown value back to [OutgoingWrapStatus.pending] because that would
/// silently re-activate a row the user (or a newer client) already moved
/// to a terminal state — for a retry queue, that risks double-delivery.
///
/// Callers (the retry service, the conversation BLoC) should treat this
/// as a non-recoverable read failure for the affected row: log it, skip
/// the row, and surface a corruption alert. It is never safe to retry
/// the publish based on an unrecognised status.
class UnknownOutgoingWrapStatusException implements Exception {
  const UnknownOutgoingWrapStatusException(this.rawValue);

  /// The raw string read from the database that did not parse.
  final String rawValue;

  @override
  String toString() {
    final known = OutgoingWrapStatus.values.map((e) => e.name).join(', ');
    return 'UnknownOutgoingWrapStatusException: '
        'unrecognised outgoing_dms wrap status "$rawValue"; '
        'expected one of $known';
  }
}

/// Domain model for one queued outgoing DM.
///
/// Independent of [OutgoingDmRow] (the Drift-generated row) so callers
/// at the repository / service / bloc layers don't import Drift types.
@immutable
class OutgoingDm {
  OutgoingDm({
    required this.id,
    required this.conversationId,
    required this.recipientPubkey,
    required this.content,
    required this.createdAt,
    required this.rumorEventJson,
    required this.recipientWrapStatus,
    required this.selfWrapStatus,
    required this.queuedAt,
    required this.ownerPubkey,
    this.messageKind = 14,
    this.replyToId,
    this.recipientWrapEventId,
    this.selfWrapEventId,
    this.retryCount = 0,
    this.recipientWrapLastError,
    this.selfWrapLastError,
    this.lastAttemptAt,
    this.sendBatchId,
  }) : rumorId = _rumorIdFromJson(rumorEventJson) ?? id;

  /// Opaque durable queue-row handle.
  ///
  /// This equals [rumorId] for 1:1 and legacy sends. Group sends use a
  /// per-recipient handle because every recipient shares one wire rumor while
  /// delivery state is tracked separately per recipient.
  final String id;
  final String conversationId;
  final String recipientPubkey;
  final String content;
  final int createdAt;
  final String rumorEventJson;
  final int messageKind;
  final String? replyToId;
  final OutgoingWrapStatus recipientWrapStatus;
  final OutgoingWrapStatus selfWrapStatus;
  final String? recipientWrapEventId;
  final String? selfWrapEventId;
  final int retryCount;

  /// Last error from a failed recipient-wrap publish, independent of
  /// [selfWrapLastError]. See the table doc on
  /// `OutgoingDms.recipientWrapLastError` for why the two wraps carry
  /// their own error channels.
  final String? recipientWrapLastError;

  /// Last error from a failed self-wrap publish.
  final String? selfWrapLastError;

  final DateTime? lastAttemptAt;
  final DateTime queuedAt;
  final String ownerPubkey;

  /// Durable, collision-proof id of one send invocation. Unique for a 1:1
  /// send and shared by every per-recipient sibling of a group fan-out. The
  /// repository uses it to separate same-second identical sends, while the
  /// conversation state also uses it for group batch membership. NULL only
  /// for legacy rows.
  final String? sendBatchId;

  /// The kind-14/15 wire rumor id, stable across retries and recipients.
  ///
  /// Legacy and malformed fixtures fall back to [id]. Production rows always
  /// store the complete rumor JSON before publishing. Parsed once when the
  /// model is created because conversation state reads this value per bubble.
  final String rumorId;

  /// Whether **both** wraps have landed. The repository deletes the
  /// queue row only when this is true (in the same transaction that
  /// inserts the corresponding `direct_messages` row).
  bool get isFullyDelivered =>
      recipientWrapStatus == OutgoingWrapStatus.sent &&
      selfWrapStatus == OutgoingWrapStatus.sent;

  /// Whether either wrap is still in a retryable failed state. The
  /// retry service uses this filter to enumerate work.
  bool get hasRetryableFailure =>
      recipientWrapStatus == OutgoingWrapStatus.failed ||
      selfWrapStatus == OutgoingWrapStatus.failed;

  OutgoingDm copyWith({
    String? id,
    String? conversationId,
    String? recipientPubkey,
    String? content,
    int? createdAt,
    String? rumorEventJson,
    int? messageKind,
    String? replyToId,
    OutgoingWrapStatus? recipientWrapStatus,
    OutgoingWrapStatus? selfWrapStatus,
    String? recipientWrapEventId,
    String? selfWrapEventId,
    int? retryCount,
    String? recipientWrapLastError,
    String? selfWrapLastError,
    DateTime? lastAttemptAt,
    DateTime? queuedAt,
    String? ownerPubkey,
    String? sendBatchId,
  }) => OutgoingDm(
    id: id ?? this.id,
    conversationId: conversationId ?? this.conversationId,
    recipientPubkey: recipientPubkey ?? this.recipientPubkey,
    content: content ?? this.content,
    createdAt: createdAt ?? this.createdAt,
    rumorEventJson: rumorEventJson ?? this.rumorEventJson,
    messageKind: messageKind ?? this.messageKind,
    replyToId: replyToId ?? this.replyToId,
    recipientWrapStatus: recipientWrapStatus ?? this.recipientWrapStatus,
    selfWrapStatus: selfWrapStatus ?? this.selfWrapStatus,
    recipientWrapEventId: recipientWrapEventId ?? this.recipientWrapEventId,
    selfWrapEventId: selfWrapEventId ?? this.selfWrapEventId,
    retryCount: retryCount ?? this.retryCount,
    recipientWrapLastError:
        recipientWrapLastError ?? this.recipientWrapLastError,
    selfWrapLastError: selfWrapLastError ?? this.selfWrapLastError,
    lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
    queuedAt: queuedAt ?? this.queuedAt,
    ownerPubkey: ownerPubkey ?? this.ownerPubkey,
    sendBatchId: sendBatchId ?? this.sendBatchId,
  );

  // Full value equality. `id` alone is NOT sufficient: bloc states carry
  // `List<OutgoingDm>` inside Equatable props, so an id-only == makes a
  // pending row compare equal to the same row re-read as failed — Bloc.emit
  // then suppresses the state change and the failed bubble never repaints
  // while the conversation is open.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OutgoingDm &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          conversationId == other.conversationId &&
          recipientPubkey == other.recipientPubkey &&
          content == other.content &&
          createdAt == other.createdAt &&
          rumorEventJson == other.rumorEventJson &&
          messageKind == other.messageKind &&
          replyToId == other.replyToId &&
          recipientWrapStatus == other.recipientWrapStatus &&
          selfWrapStatus == other.selfWrapStatus &&
          recipientWrapEventId == other.recipientWrapEventId &&
          selfWrapEventId == other.selfWrapEventId &&
          retryCount == other.retryCount &&
          recipientWrapLastError == other.recipientWrapLastError &&
          selfWrapLastError == other.selfWrapLastError &&
          lastAttemptAt == other.lastAttemptAt &&
          queuedAt == other.queuedAt &&
          ownerPubkey == other.ownerPubkey &&
          sendBatchId == other.sendBatchId;

  @override
  int get hashCode => Object.hash(
    id,
    conversationId,
    recipientPubkey,
    content,
    createdAt,
    rumorEventJson,
    messageKind,
    replyToId,
    recipientWrapStatus,
    selfWrapStatus,
    recipientWrapEventId,
    selfWrapEventId,
    retryCount,
    recipientWrapLastError,
    selfWrapLastError,
    lastAttemptAt,
    queuedAt,
    ownerPubkey,
    sendBatchId,
  );

  @override
  String toString() =>
      'OutgoingDm{id: $id, conversation: $conversationId, '
      'recipient: $recipientWrapStatus, self: $selfWrapStatus, '
      'retry: $retryCount}';
}

@DriftAccessor(tables: [OutgoingDms])
class OutgoingDmsDao extends DatabaseAccessor<AppDatabase>
    with _$OutgoingDmsDaoMixin {
  OutgoingDmsDao(super.attachedDatabase);

  // ---------------------------------------------------------------------
  // Mapping
  // ---------------------------------------------------------------------

  OutgoingDmsCompanion _modelToCompanion(OutgoingDm dm) {
    return OutgoingDmsCompanion.insert(
      id: dm.id,
      conversationId: dm.conversationId,
      recipientPubkey: dm.recipientPubkey,
      content: dm.content,
      createdAt: dm.createdAt,
      rumorEventJson: dm.rumorEventJson,
      messageKind: Value(dm.messageKind),
      replyToId: Value(dm.replyToId),
      recipientWrapStatus: dm.recipientWrapStatus.name,
      selfWrapStatus: dm.selfWrapStatus.name,
      recipientWrapEventId: Value(dm.recipientWrapEventId),
      selfWrapEventId: Value(dm.selfWrapEventId),
      retryCount: Value(dm.retryCount),
      recipientWrapLastError: Value(dm.recipientWrapLastError),
      selfWrapLastError: Value(dm.selfWrapLastError),
      lastAttemptAt: Value(dm.lastAttemptAt),
      queuedAt: dm.queuedAt,
      ownerPubkey: dm.ownerPubkey,
      sendBatchId: Value(dm.sendBatchId),
    );
  }

  OutgoingDm _rowToModel(OutgoingDmRow row) {
    return OutgoingDm(
      id: row.id,
      conversationId: row.conversationId,
      recipientPubkey: row.recipientPubkey,
      content: row.content,
      createdAt: row.createdAt,
      rumorEventJson: row.rumorEventJson,
      messageKind: row.messageKind,
      replyToId: row.replyToId,
      recipientWrapStatus: _parseStatus(row.recipientWrapStatus),
      selfWrapStatus: _parseStatus(row.selfWrapStatus),
      recipientWrapEventId: row.recipientWrapEventId,
      selfWrapEventId: row.selfWrapEventId,
      retryCount: row.retryCount,
      recipientWrapLastError: row.recipientWrapLastError,
      selfWrapLastError: row.selfWrapLastError,
      lastAttemptAt: row.lastAttemptAt,
      queuedAt: row.queuedAt,
      ownerPubkey: row.ownerPubkey,
      sendBatchId: row.sendBatchId,
    );
  }

  /// Parse a persisted wrap-status string back to [OutgoingWrapStatus].
  ///
  /// Throws [UnknownOutgoingWrapStatusException] when [raw] does not
  /// match any known case. Coercing unknown values to
  /// [OutgoingWrapStatus.pending] would put corrupt or future-schema
  /// rows back into the retry service's active set — for a retry queue
  /// that risks double-delivery, so we fail loudly instead.
  OutgoingWrapStatus _parseStatus(String raw) {
    for (final status in OutgoingWrapStatus.values) {
      if (status.name == raw) return status;
    }
    throw UnknownOutgoingWrapStatusException(raw);
  }

  // ---------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------

  /// Enqueue a new outgoing DM with both wraps in [OutgoingWrapStatus.pending].
  ///
  /// Uses `INSERT OR IGNORE` semantics: when a row with [OutgoingDm.id]
  /// already exists, this call is a true no-op — the existing row's
  /// mutable delivery state (`recipient_wrap_status`, `self_wrap_status`,
  /// `retry_count`, `last_error`, `last_attempt_at`, the published wrap
  /// event ids) is preserved. Use [markRecipientWrapStatus],
  /// [markSelfWrapStatus], or [incrementRetry] to update a row in place.
  Future<void> enqueue(OutgoingDm dm) async {
    await into(
      outgoingDms,
    ).insert(_modelToCompanion(dm), mode: InsertMode.insertOrIgnore);
  }

  /// Update the recipient gift-wrap status for [id]. Pass [eventId] when
  /// transitioning to [OutgoingWrapStatus.sent] so the published id is
  /// recorded for downstream debugging. Pass [lastError] when transitioning
  /// to [OutgoingWrapStatus.failed]; it lands in `recipient_wrap_last_error`
  /// so the self-wrap's own error history is never overwritten.
  Future<bool> markRecipientWrapStatus({
    required String id,
    required OutgoingWrapStatus status,
    String? eventId,
    String? lastError,
  }) async {
    final rows = await (update(outgoingDms)..where((t) => t.id.equals(id)))
        .write(
          OutgoingDmsCompanion(
            recipientWrapStatus: Value(status.name),
            recipientWrapEventId: eventId != null
                ? Value(eventId)
                : const Value.absent(),
            recipientWrapLastError: lastError != null
                ? Value(lastError)
                : const Value.absent(),
            lastAttemptAt: Value(DateTime.now()),
          ),
        );
    return rows > 0;
  }

  /// Retain [id] as a terminal, non-retryable policy refusal.
  ///
  /// Both wraps must leave `pending`: the pending-row recovery query selects a
  /// row when either wrap is pending, and a recipient refusal means the
  /// self-wrap was never attempted.
  Future<bool> markRecipientBlocked({
    required String id,
    required String lastError,
  }) async {
    final rows = await (update(outgoingDms)..where((t) => t.id.equals(id)))
        .write(
          OutgoingDmsCompanion(
            recipientWrapStatus: Value(OutgoingWrapStatus.blocked.name),
            selfWrapStatus: Value(OutgoingWrapStatus.blocked.name),
            recipientWrapLastError: Value(lastError),
            lastAttemptAt: Value(DateTime.now()),
          ),
        );
    return rows > 0;
  }

  /// Retain [id] as a delivery the sender stopped.
  ///
  /// Both wraps leave `pending` and `failed`, for the same reason as
  /// [markRecipientBlocked]: the retry and recovery queries select a row when
  /// either wrap is in one of those states. The last error is left as it was.
  Future<bool> markRecipientCancelled(String id) async {
    final rows = await (update(outgoingDms)..where((t) => t.id.equals(id)))
        .write(
          OutgoingDmsCompanion(
            recipientWrapStatus: Value(OutgoingWrapStatus.cancelled.name),
            selfWrapStatus: Value(OutgoingWrapStatus.cancelled.name),
          ),
        );
    return rows > 0;
  }

  /// Update the self-addressed gift-wrap status for [id]. Same per-wrap
  /// error semantics as [markRecipientWrapStatus] — [lastError] writes to
  /// `self_wrap_last_error` only.
  Future<bool> markSelfWrapStatus({
    required String id,
    required OutgoingWrapStatus status,
    String? eventId,
    String? lastError,
  }) async {
    final rows = await (update(outgoingDms)..where((t) => t.id.equals(id)))
        .write(
          OutgoingDmsCompanion(
            selfWrapStatus: Value(status.name),
            selfWrapEventId: eventId != null
                ? Value(eventId)
                : const Value.absent(),
            selfWrapLastError: lastError != null
                ? Value(lastError)
                : const Value.absent(),
            lastAttemptAt: Value(DateTime.now()),
          ),
        );
    return rows > 0;
  }

  /// Increment the retry count for [id]. The retry service calls this
  /// after scheduling a replay regardless of the eventual outcome —
  /// backoff caps growth at the policy max.
  ///
  /// Implemented as a typed Drift `update().write()` inside a transaction
  /// so the [DateTime] write goes through the same codec
  /// `markRecipientWrapStatus` / `markSelfWrapStatus` use. The earlier raw
  /// `customUpdate` form wrote `Variable<int>(millisecondsSinceEpoch)`
  /// while the codec is configured for seconds-since-epoch
  /// (`store_date_time_values_as_text: false` in `drift_schema_v1.json`),
  /// so reads decoded the value ~1000× in the future. Going through the
  /// codec is the only durable fix — `incrementRetry` and the
  /// `markXxxWrapStatus` writers must not disagree about the unit.
  Future<bool> incrementRetry(String id) async {
    return transaction(() async {
      final row = await (select(
        outgoingDms,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (row == null) return false;

      final affected =
          await (update(outgoingDms)..where((t) => t.id.equals(id))).write(
            OutgoingDmsCompanion(
              retryCount: Value(row.retryCount + 1),
              lastAttemptAt: Value(DateTime.now()),
            ),
          );
      return affected > 0;
    });
  }

  /// Reset the retry count for [id] to zero, handing the row back to the
  /// retry sweep with a fresh budget. Called by the repository's manual
  /// Resend path: soft-unconfirmed attempts burn the shared budget, and a
  /// row at the sweep's `maxRetries` cap is otherwise abandoned by
  /// [getRetryableForOwner] forever — an explicit user resend is the signal
  /// to re-arm it. Returns `false` when no row exists for [id].
  Future<bool> resetRetryCount(String id) async {
    final affected = await (update(outgoingDms)..where((t) => t.id.equals(id)))
        .write(const OutgoingDmsCompanion(retryCount: Value(0)));
    return affected > 0;
  }

  /// Delete the row for [id]. Called by the repository in the same
  /// transaction that promotes the message to `direct_messages` once
  /// both wraps are sent (atomicity prevents a watcher window where the
  /// message is in neither table) — and called directly by the user's
  /// "Cancel send" action while the message is still pending or failed.
  Future<int> deleteById(String id) {
    return (delete(outgoingDms)..where((t) => t.id.equals(id))).go();
  }

  /// Deletes queued sends for one conversation and owner.
  Future<int> deleteForConversation({
    required String conversationId,
    required String ownerPubkey,
  }) {
    return (delete(outgoingDms)..where(
          (t) =>
              t.conversationId.equals(conversationId) &
              t.ownerPubkey.equals(ownerPubkey),
        ))
        .go();
  }

  /// Deletes queued sends for multiple conversations and one owner.
  Future<int> deleteForConversations({
    required Iterable<String> conversationIds,
    required String ownerPubkey,
  }) {
    final ids = conversationIds.toList(growable: false);
    if (ids.isEmpty) return Future.value(0);
    return (delete(outgoingDms)..where(
          (t) => t.conversationId.isIn(ids) & t.ownerPubkey.equals(ownerPubkey),
        ))
        .go();
  }

  /// Delete every queued outgoing DM owned by [ownerPubkey].
  ///
  /// Mirrors [DirectMessagesDao.clearForAccountSwitch]: cleanup calls
  /// this from the signout / account-switch path so a different
  /// account's retry service never picks up the previous user's
  /// in-flight rows. Returns the number of rows removed.
  Future<int> clearAllForUser(String ownerPubkey) {
    return (delete(
      outgoingDms,
    )..where((t) => t.ownerPubkey.equals(ownerPubkey))).go();
  }

  // ---------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------

  /// Fetch the queue row for [id], or `null` if not enqueued.
  Future<OutgoingDm?> getById(String id) async {
    final query = select(outgoingDms)..where((t) => t.id.equals(id));
    final row = await query.getSingleOrNull();
    return row == null ? null : _rowToModel(row);
  }

  /// Watch every row in [conversationId] for the given account, newest
  /// first. Empty stream if no enqueued sends.
  ///
  /// The conversation BLoC merges this with `watchMessagesForConversation`
  /// to render a unified timeline including pending / failed bubbles.
  Stream<List<OutgoingDm>> watchForConversation({
    required String conversationId,
    required String ownerPubkey,
  }) {
    final query = select(outgoingDms)
      ..where(
        (t) =>
            t.conversationId.equals(conversationId) &
            t.ownerPubkey.equals(ownerPubkey),
      )
      ..orderBy([
        (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
      ]);
    return query.watch().map((rows) => rows.map(_rowToModel).toList());
  }

  /// One-shot read of the durable queue rows for [conversationId], scoped to
  /// [ownerPubkey], newest first — the non-reactive companion to
  /// [watchForConversation]. The conversation bloc uses it to reflect a send's
  /// terminal outcome immediately, rather than waiting on a watch tick that can
  /// be dropped when it fires while a bloc event handler is mid-flight.
  Future<List<OutgoingDm>> getForConversation({
    required String conversationId,
    required String ownerPubkey,
  }) async {
    final query = select(outgoingDms)
      ..where(
        (t) =>
            t.conversationId.equals(conversationId) &
            t.ownerPubkey.equals(ownerPubkey),
      )
      ..orderBy([
        (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
      ]);
    final rows = await query.get();
    return rows.map(_rowToModel).toList();
  }

  /// Finds one owner-scoped queue row carrying [rumorId] on the wire.
  ///
  /// Group rows use per-recipient queue handles, so their primary-key `id`
  /// differs from the shared rumor id exposed by an optimistic message bubble.
  Future<OutgoingDm?> getByRumorId({
    required String rumorId,
    required String ownerPubkey,
  }) async {
    final query = select(outgoingDms)
      ..where((t) => t.ownerPubkey.equals(ownerPubkey));
    for (final row in await query.get()) {
      if (_rumorIdFromJson(row.rumorEventJson) == rumorId) {
        return _rowToModel(row);
      }
    }
    return null;
  }

  /// Watch every row for the given account, oldest first.
  ///
  /// Used by the retry service / a future "X messages failed" badge in
  /// the inbox app bar.
  Stream<List<OutgoingDm>> watchAllForOwner(String ownerPubkey) {
    final query = select(outgoingDms)
      ..where((t) => t.ownerPubkey.equals(ownerPubkey))
      ..orderBy([(t) => OrderingTerm(expression: t.queuedAt)]);
    return query.watch().map((rows) => rows.map(_rowToModel).toList());
  }

  /// Fetch every row for the given account, oldest first.
  ///
  /// The one-shot companion to [watchAllForOwner], for a caller that needs
  /// the queue once and must not open a stream query to get it.
  Future<List<OutgoingDm>> getAllForOwner(String ownerPubkey) async {
    final query = select(outgoingDms)
      ..where((t) => t.ownerPubkey.equals(ownerPubkey))
      ..orderBy([(t) => OrderingTerm(expression: t.queuedAt)]);
    final rows = await query.get();
    return rows.map(_rowToModel).toList();
  }

  /// Fetch all rows for [ownerPubkey] where at least one wrap is still
  /// in [OutgoingWrapStatus.failed]. Excludes rows that have exhausted
  /// the retry budget (caller decides what to do with those, typically
  /// surface a manual retry affordance).
  Future<List<OutgoingDm>> getRetryableForOwner({
    required String ownerPubkey,
    required int maxRetries,
  }) async {
    final query = select(outgoingDms)
      ..where(
        (t) =>
            t.ownerPubkey.equals(ownerPubkey) &
            t.retryCount.isSmallerThanValue(maxRetries) &
            (t.recipientWrapStatus.equals(OutgoingWrapStatus.failed.name) |
                t.selfWrapStatus.equals(OutgoingWrapStatus.failed.name)),
      )
      ..orderBy([(t) => OrderingTerm(expression: t.queuedAt)]);
    final rows = await query.get();
    return rows.map(_rowToModel).toList();
  }

  /// Fetch all rows for [ownerPubkey] still in
  /// [OutgoingWrapStatus.pending] for either wrap. Used to recover
  /// in-flight sends after an app kill that interrupted the publish
  /// before the row could be marked sent or failed.
  Future<List<OutgoingDm>> getStillPendingForOwner(String ownerPubkey) async {
    final query = select(outgoingDms)
      ..where(
        (t) =>
            t.ownerPubkey.equals(ownerPubkey) &
            (t.recipientWrapStatus.equals(OutgoingWrapStatus.pending.name) |
                t.selfWrapStatus.equals(OutgoingWrapStatus.pending.name)),
      )
      ..orderBy([(t) => OrderingTerm(expression: t.queuedAt)]);
    final rows = await query.get();
    return rows.map(_rowToModel).toList();
  }
}
