// ABOUTME: Data Access Object for the durable product analytics outbox.
// ABOUTME: Stores first-party product events until ingest accepts them.

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

part 'pending_product_events_dao.g.dart';

enum PendingProductEventStatus { pending, publishing, failed, deadLetter }

class UnknownPendingProductEventStatusException implements Exception {
  const UnknownPendingProductEventStatusException(this.rawValue);

  final String rawValue;

  @override
  String toString() {
    final known = PendingProductEventStatus.values
        .map((status) => status.name)
        .join(', ');
    return 'UnknownPendingProductEventStatusException: '
        'unrecognised pending_product_events status "$rawValue"; '
        'expected one of $known';
  }
}

@immutable
class PendingProductEvent {
  const PendingProductEvent({
    required this.id,
    required this.eventName,
    required this.payloadJson,
    required this.status,
    required this.createdAt,
    this.attemptCount = 0,
    this.nextAttemptAt,
    this.lastError,
    this.ownerPubkey,
  });

  final String id;
  final String eventName;
  final String payloadJson;
  final PendingProductEventStatus status;
  final int attemptCount;
  final DateTime? nextAttemptAt;
  final String? lastError;
  final DateTime createdAt;

  /// Hex pubkey of the account that produced this event, or null for legacy
  /// rows enqueued before owner scoping existed.
  final String? ownerPubkey;
}

@DriftAccessor(tables: [PendingProductEvents])
class PendingProductEventsDao extends DatabaseAccessor<AppDatabase>
    with _$PendingProductEventsDaoMixin {
  PendingProductEventsDao(super.attachedDatabase);

  PendingProductEventsCompanion _modelToCompanion(PendingProductEvent event) {
    return PendingProductEventsCompanion.insert(
      id: event.id,
      eventName: event.eventName,
      payloadJson: event.payloadJson,
      status: event.status.name,
      attemptCount: Value(event.attemptCount),
      nextAttemptAt: Value(event.nextAttemptAt),
      lastError: Value(event.lastError),
      createdAt: event.createdAt,
      ownerPubkey: Value(event.ownerPubkey),
    );
  }

  PendingProductEvent _rowToModel(PendingProductEventRow row) {
    return PendingProductEvent(
      id: row.id,
      eventName: row.eventName,
      payloadJson: row.payloadJson,
      status: _parseStatus(row.status),
      attemptCount: row.attemptCount,
      nextAttemptAt: row.nextAttemptAt,
      lastError: row.lastError,
      createdAt: row.createdAt,
      ownerPubkey: row.ownerPubkey,
    );
  }

  PendingProductEventStatus _parseStatus(String raw) {
    for (final status in PendingProductEventStatus.values) {
      if (status.name == raw) return status;
    }
    throw UnknownPendingProductEventStatusException(raw);
  }

  Future<void> enqueue(PendingProductEvent event) async {
    await into(
      pendingProductEvents,
    ).insert(_modelToCompanion(event), mode: InsertMode.insertOrIgnore);
  }

  Future<PendingProductEvent?> getById(String id) async {
    final row = await (select(
      pendingProductEvents,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
    return row == null ? null : _rowToModel(row);
  }

  /// Returns retryable events for [ownerPubkey].
  ///
  /// A null [ownerPubkey] returns only ownerless rows. Signed flushes must not
  /// pick those up because they would be published under whichever account is
  /// active rather than the account that produced the event.
  Future<List<PendingProductEvent>> getRetryable({
    required DateTime now,
    required int limit,
    String? ownerPubkey,
  }) async {
    final query = select(pendingProductEvents)
      ..where(
        (table) =>
            (table.status.equals(PendingProductEventStatus.pending.name) |
                table.status.equals(PendingProductEventStatus.failed.name)) &
            (table.nextAttemptAt.isNull() |
                table.nextAttemptAt.isSmallerOrEqualValue(now)) &
            _ownedBy(table.ownerPubkey, ownerPubkey),
      )
      ..orderBy([(table) => OrderingTerm(expression: table.createdAt)])
      ..limit(limit);
    final rows = await query.get();
    return rows.map(_rowToModel).toList();
  }

  Expression<bool> _ownedBy(
    GeneratedColumn<String> column,
    String? ownerPubkey,
  ) {
    if (ownerPubkey == null) return column.isNull();
    return column.equals(ownerPubkey);
  }

  Future<bool> markPublishing(String id) async {
    final rows =
        await (update(
          pendingProductEvents,
        )..where((table) => table.id.equals(id))).write(
          PendingProductEventsCompanion(
            status: Value(PendingProductEventStatus.publishing.name),
          ),
        );
    return rows > 0;
  }

  Future<bool> markFailed(
    String id,
    String error, {
    required DateTime nextAttemptAt,
  }) async {
    return transaction(() async {
      final row = await (select(
        pendingProductEvents,
      )..where((table) => table.id.equals(id))).getSingleOrNull();
      if (row == null) return false;
      final rows =
          await (update(
            pendingProductEvents,
          )..where((table) => table.id.equals(id))).write(
            PendingProductEventsCompanion(
              status: Value(PendingProductEventStatus.failed.name),
              attemptCount: Value(row.attemptCount + 1),
              nextAttemptAt: Value(nextAttemptAt),
              lastError: Value(error),
            ),
          );
      return rows > 0;
    });
  }

  Future<bool> markDeadLetter(String id, String error) async {
    final rows =
        await (update(
          pendingProductEvents,
        )..where((table) => table.id.equals(id))).write(
          PendingProductEventsCompanion(
            status: Value(PendingProductEventStatus.deadLetter.name),
            lastError: Value(error),
          ),
        );
    return rows > 0;
  }

  Future<int> resetPublishingToPending() {
    return (update(pendingProductEvents)..where(
          (table) =>
              table.status.equals(PendingProductEventStatus.publishing.name),
        ))
        .write(
          PendingProductEventsCompanion(
            status: Value(PendingProductEventStatus.pending.name),
          ),
        );
  }

  Future<int> deleteById(String id) {
    return (delete(
      pendingProductEvents,
    )..where((table) => table.id.equals(id))).go();
  }

  /// Deletes every queued product event belonging to [ownerPubkey].
  ///
  /// Rows are already filtered to the current owner at flush time, so these
  /// never publish under another account's signature. They were simply never
  /// deleted when their owner was removed from the device (#8314).
  ///
  /// Legacy rows predating the owner column carry NULL and are left alone;
  /// they flush under whoever is active, which is existing behaviour.
  Future<int> deleteForOwner(String ownerPubkey) {
    return (delete(
      pendingProductEvents,
    )..where((table) => table.ownerPubkey.equals(ownerPubkey))).go();
  }

  Future<int> deleteAll() => delete(pendingProductEvents).go();

  /// Removes expired rows, then trims the oldest survivors to [maxRecords].
  Future<int> prune({
    required DateTime cutoff,
    required int maxRecords,
  }) async {
    return transaction(() async {
      final deleted = await (delete(
        pendingProductEvents,
      )..where((table) => table.createdAt.isSmallerOrEqualValue(cutoff))).go();
      final survivors =
          await (selectOnly(pendingProductEvents)
                ..addColumns([pendingProductEvents.id])
                ..orderBy([
                  OrderingTerm.asc(pendingProductEvents.createdAt),
                ]))
              .get();
      final surplus = survivors.length - maxRecords;
      if (surplus <= 0) return deleted;
      final oldestIds = survivors
          .take(surplus)
          .map((row) => row.read(pendingProductEvents.id))
          .whereType<String>()
          .toList();
      return deleted +
          await (delete(
            pendingProductEvents,
          )..where((table) => table.id.isIn(oldestIds))).go();
    });
  }
}
