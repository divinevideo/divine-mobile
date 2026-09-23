// ABOUTME: Data Access Object for the scheduled-post outbox (#3538).
// ABOUTME: Holds pre-signed future-dated events until the relay publishes them.

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

part 'scheduled_posts_dao.g.dart';

/// Lifecycle of one scheduled post, as the app knows it.
///
/// [pendingSubmit] means the event is signed but the relay has not accepted
/// it into its hold queue yet (offline, or the endpoint was unreachable).
/// [scheduled] means the relay holds it. [published] and [cancelled] are
/// terminal and their rows are deleted once the app has run the matching
/// side effects; [failed] stays readable so the user can retry.
enum ScheduledPostStatus {
  pendingSubmit,
  scheduled,
  published,
  failed,
  cancelled,
}

class UnknownScheduledPostStatusException implements Exception {
  const UnknownScheduledPostStatusException(this.rawValue);

  final String rawValue;

  @override
  String toString() {
    final known = ScheduledPostStatus.values.map((e) => e.name).join(', ');
    return 'UnknownScheduledPostStatusException: '
        'unrecognised scheduled_posts status "$rawValue"; '
        'expected one of $known';
  }
}

@immutable
class ScheduledPost {
  const ScheduledPost({
    required this.eventId,
    required this.ownerPubkey,
    required this.draftId,
    required this.kind,
    required this.signedEventJson,
    required this.publishAt,
    required this.createdAt,
    this.uploadId,
    this.expireAfterSecs,
    this.status = ScheduledPostStatus.pendingSubmit,
    this.failureReason,
    this.attempts = 0,
    this.lastAttemptAt,
  });

  final String eventId;
  final String ownerPubkey;
  final String draftId;
  final String? uploadId;
  final int kind;
  final String signedEventJson;

  /// Unix seconds; equals the signed event's `created_at`.
  final int publishAt;
  final int? expireAfterSecs;
  final ScheduledPostStatus status;
  final String? failureReason;
  final int attempts;
  final DateTime? lastAttemptAt;
  final DateTime createdAt;

  /// The publish time as a UTC [DateTime].
  DateTime get publishAtUtc =>
      DateTime.fromMillisecondsSinceEpoch(publishAt * 1000, isUtc: true);

  /// Whether the relay may still need this row: signed but not yet accepted,
  /// or accepted and waiting for its publish time.
  bool get isPending =>
      status == ScheduledPostStatus.pendingSubmit ||
      status == ScheduledPostStatus.scheduled;

  ScheduledPost copyWith({
    ScheduledPostStatus? status,
    String? failureReason,
    bool clearFailureReason = false,
    int? attempts,
    DateTime? lastAttemptAt,
  }) {
    return ScheduledPost(
      eventId: eventId,
      ownerPubkey: ownerPubkey,
      draftId: draftId,
      uploadId: uploadId,
      kind: kind,
      signedEventJson: signedEventJson,
      publishAt: publishAt,
      expireAfterSecs: expireAfterSecs,
      status: status ?? this.status,
      failureReason: clearFailureReason
          ? null
          : (failureReason ?? this.failureReason),
      attempts: attempts ?? this.attempts,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      createdAt: createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScheduledPost &&
          runtimeType == other.runtimeType &&
          eventId == other.eventId &&
          status == other.status &&
          failureReason == other.failureReason &&
          attempts == other.attempts &&
          lastAttemptAt == other.lastAttemptAt;

  @override
  int get hashCode =>
      Object.hash(eventId, status, failureReason, attempts, lastAttemptAt);
}

@DriftAccessor(tables: [ScheduledPosts])
class ScheduledPostsDao extends DatabaseAccessor<AppDatabase>
    with _$ScheduledPostsDaoMixin {
  ScheduledPostsDao(super.attachedDatabase);

  static const List<ScheduledPostStatus> _pendingStatuses = [
    ScheduledPostStatus.pendingSubmit,
    ScheduledPostStatus.scheduled,
  ];

  ScheduledPostsCompanion _modelToCompanion(ScheduledPost post) {
    return ScheduledPostsCompanion.insert(
      eventId: post.eventId,
      ownerPubkey: post.ownerPubkey,
      draftId: post.draftId,
      uploadId: Value(post.uploadId),
      kind: post.kind,
      signedEventJson: post.signedEventJson,
      publishAt: post.publishAt,
      expireAfterSecs: Value(post.expireAfterSecs),
      status: post.status.name,
      failureReason: Value(post.failureReason),
      attempts: Value(post.attempts),
      lastAttemptAt: Value(post.lastAttemptAt),
      createdAt: post.createdAt,
    );
  }

  ScheduledPost _rowToModel(ScheduledPostRow row) {
    return ScheduledPost(
      eventId: row.eventId,
      ownerPubkey: row.ownerPubkey,
      draftId: row.draftId,
      uploadId: row.uploadId,
      kind: row.kind,
      signedEventJson: row.signedEventJson,
      publishAt: row.publishAt,
      expireAfterSecs: row.expireAfterSecs,
      status: _parseStatus(row.status),
      failureReason: row.failureReason,
      attempts: row.attempts,
      lastAttemptAt: row.lastAttemptAt,
      createdAt: row.createdAt,
    );
  }

  ScheduledPostStatus _parseStatus(String raw) {
    for (final status in ScheduledPostStatus.values) {
      if (status.name == raw) return status;
    }
    throw UnknownScheduledPostStatusException(raw);
  }

  /// Stores [post]. A row with the same event id is left untouched: the id
  /// is a hash over the signed content, so a repeat is the same post.
  Future<void> enqueue(ScheduledPost post) async {
    await into(
      scheduledPosts,
    ).insert(_modelToCompanion(post), mode: InsertMode.insertOrIgnore);
  }

  Future<ScheduledPost?> getById(String eventId) async {
    final row = await (select(
      scheduledPosts,
    )..where((t) => t.eventId.equals(eventId))).getSingleOrNull();
    return row == null ? null : _rowToModel(row);
  }

  Future<ScheduledPost?> getByDraftId(String draftId) async {
    final row = await (select(
      scheduledPosts,
    )..where((t) => t.draftId.equals(draftId))).getSingleOrNull();
    return row == null ? null : _rowToModel(row);
  }

  /// Every row of [ownerPubkey], soonest publish time first.
  Future<List<ScheduledPost>> listForOwner(String ownerPubkey) async {
    final rows = await _ownerQuery(ownerPubkey).get();
    return rows.map(_rowToModel).toList();
  }

  /// Emits [listForOwner] again after every write to the table.
  Stream<List<ScheduledPost>> watchForOwner(String ownerPubkey) {
    return _ownerQuery(
      ownerPubkey,
    ).watch().map((rows) => rows.map(_rowToModel).toList());
  }

  /// Rows of [ownerPubkey] the relay may still act on — see
  /// [ScheduledPost.isPending].
  Future<List<ScheduledPost>> pendingForOwner(String ownerPubkey) async {
    final rows =
        await (_ownerQuery(ownerPubkey)..where(
              (t) => t.status.isIn(_pendingStatuses.map((s) => s.name)),
            ))
            .get();
    return rows.map(_rowToModel).toList();
  }

  SimpleSelectStatement<$ScheduledPostsTable, ScheduledPostRow> _ownerQuery(
    String ownerPubkey,
  ) {
    return select(scheduledPosts)
      ..where((t) => t.ownerPubkey.equals(ownerPubkey))
      ..orderBy([(t) => OrderingTerm(expression: t.publishAt)]);
  }

  /// Moves a row to [status]. [failureReason] replaces the stored reason
  /// (clear it with [clearFailureReason]); [attemptedAt] records a submission
  /// attempt and increments the attempt count. Returns whether a row changed.
  Future<bool> updateStatus({
    required String eventId,
    ScheduledPostStatus? status,
    String? failureReason,
    bool clearFailureReason = false,
    DateTime? attemptedAt,
  }) {
    return transaction(() async {
      final row = await (select(
        scheduledPosts,
      )..where((t) => t.eventId.equals(eventId))).getSingleOrNull();
      if (row == null) return false;

      final companion = ScheduledPostsCompanion(
        status: status != null ? Value(status.name) : const Value.absent(),
        failureReason: clearFailureReason
            ? const Value(null)
            : failureReason != null
            ? Value(failureReason)
            : const Value.absent(),
        attempts: attemptedAt != null
            ? Value(row.attempts + 1)
            : const Value.absent(),
        lastAttemptAt: attemptedAt != null
            ? Value(attemptedAt)
            : const Value.absent(),
      );

      final rows = await (update(
        scheduledPosts,
      )..where((t) => t.eventId.equals(eventId))).write(companion);
      return rows > 0;
    });
  }

  Future<int> deleteById(String eventId) {
    return (delete(
      scheduledPosts,
    )..where((t) => t.eventId.equals(eventId))).go();
  }

  /// Deletes every row belonging to [ownerPubkey].
  ///
  /// Called on the destructive account-wipe path, like the sibling outboxes.
  /// A plain account switch preserves the rows: the relay publishes the held
  /// ones regardless, and a row not yet handed off waits here for its account
  /// to sign back in.
  Future<int> deleteAllForUser(String ownerPubkey) {
    return (delete(
      scheduledPosts,
    )..where((t) => t.ownerPubkey.equals(ownerPubkey))).go();
  }
}
