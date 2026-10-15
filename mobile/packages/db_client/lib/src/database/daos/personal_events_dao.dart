// ABOUTME: Data access for the signed-in user's own Nostr events.
// ABOUTME: Applies per-kind retention so the store cannot grow without bound.

import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';

part 'personal_events_dao.g.dart';

/// How long a personal event is kept.
///
/// Stored as an int column so the policy a row was written under is visible in
/// the database rather than re-derived from its kind at read time.
enum PersonalEventRetention {
  /// One row per `(pubkey, kind)`. Writing a newer version deletes the older
  /// one. Used for NIP-01 replaceable kinds (0, 3, 10000-19999), where only
  /// the latest version has ever been read.
  collapsing(0),

  /// Kept until the per-owner cap evicts it, newest first.
  durable(1),

  /// Latest explicitly retained outbound event per addressable coordinate.
  /// Survives the ordinary cache cap until owner-scoped destructive cleanup.
  retryIntent(2);

  const PersonalEventRetention(this.value);

  final int value;

  static PersonalEventRetention forKind(int kind) =>
      EventKind.isReplaceable(kind)
      ? PersonalEventRetention.collapsing
      : PersonalEventRetention.durable;
}

/// Upper bound on [PersonalEventRetention.durable] rows per owner.
///
/// The durable set is dominated by signed kind-34236 video events: one per
/// distinct signature, so one per upload plus one per metadata edit and per
/// subtitle republish. A row becomes unreachable once
/// `cleanupCompletedUploads` deletes the `PendingUpload` holding its
/// `nostrEventId`, and nothing else ever names it, so a cap is the only thing
/// that can collect them (#6986).
const int maxDurablePersonalEventsPerOwner = 200;

@DriftAccessor(tables: [PersonalEvents])
class PersonalEventsDao extends DatabaseAccessor<AppDatabase>
    with _$PersonalEventsDaoMixin {
  PersonalEventsDao(super.attachedDatabase);

  /// Stores [event] under the retention policy for its kind.
  ///
  /// Replaceable kinds replace the owner's previous row for that kind;
  /// everything else is appended and the owner's durable set is trimmed to
  /// [maxDurablePersonalEventsPerOwner].
  ///
  /// [retainForRetry] keeps one outbound addressable event per coordinate
  /// outside that cap. A normal cache write cannot unpin the same event.
  ///
  /// Both halves run in one transaction, so a read can never observe an event
  /// without its retention having been applied. The Hive implementation this
  /// replaced wrote the event and its kind index as two separate awaited
  /// writes, leaving a window in which the event existed but was invisible to
  /// kind queries (#6280).
  Future<void> upsertPersonalEvent(
    Event event, {
    bool retainForRetry = false,
  }) async {
    final dTag = retainForRetry ? _retryCoordinate(event) : null;
    if (retainForRetry && dTag == null) {
      throw ArgumentError('Retry retention requires an addressable event');
    }
    var retention = retainForRetry
        ? PersonalEventRetention.retryIntent
        : PersonalEventRetention.forKind(event.kind);

    await transaction(() async {
      if (retainForRetry) {
        final candidates = await _retryRows(event.pubkey, event.kind);
        for (final row in candidates) {
          final stored = _toEvent(row);
          if (_retryCoordinate(stored) != dTag) continue;
          // Follow NIP-01's timestamp and lowest-id tie ordering.
          if (stored.createdAt > event.createdAt ||
              (stored.createdAt == event.createdAt &&
                  stored.id.compareTo(event.id) < 0)) {
            return;
          }
          await (delete(
            personalEvents,
          )..where((t) => t.id.equals(row.id))).go();
        }
      } else {
        final existing = await (select(
          personalEvents,
        )..where((t) => t.id.equals(event.id))).getSingleOrNull();
        if (existing?.retention == PersonalEventRetention.retryIntent.value) {
          retention = PersonalEventRetention.retryIntent;
        }
      }
      if (retention == PersonalEventRetention.collapsing) {
        // Keep the newest version. The Hive store this replaced kept every
        // version and let readers sort, so an out-of-order write could not
        // make a read return an older event; collapsing unconditionally
        // would. Ties replace, so two publishes inside one second — Nostr
        // `created_at` is second-resolution — do not silently drop the later
        // one.
        final newestStoredRow = await customSelect(
          'SELECT MAX(created_at) AS newest_created_at '
          'FROM personal_events WHERE pubkey = ? AND kind = ?',
          variables: [
            Variable.withString(event.pubkey),
            Variable.withInt(event.kind),
          ],
          readsFrom: {personalEvents},
        ).getSingle();
        final newestStored = newestStoredRow.readNullable<int>(
          'newest_created_at',
        );
        if (newestStored != null && event.createdAt < newestStored) {
          return;
        }

        await (delete(personalEvents)..where(
              (t) => t.pubkey.equals(event.pubkey) & t.kind.equals(event.kind),
            ))
            .go();
      }

      await into(personalEvents).insertOnConflictUpdate(
        PersonalEventsCompanion.insert(
          id: event.id,
          pubkey: event.pubkey,
          kind: event.kind,
          createdAt: event.createdAt,
          tags: jsonEncode(event.tags),
          content: event.content,
          sig: event.sig,
          retention: retention.value,
        ),
      );

      if (retention == PersonalEventRetention.durable) {
        await _trimDurableRows(event.pubkey);
      }
    });
  }

  String? _retryCoordinate(Event event) {
    final tags = event.tags.where((tag) => tag.isNotEmpty && tag.first == 'd');
    if (event.kind < 30000 ||
        event.kind >= 40000 ||
        tags.length != 1 ||
        tags.single.length != 2) {
      return null;
    }
    return tags.single[1];
  }

  Future<List<PersonalEventRow>> _retryRows(String pubkey, int kind) =>
      (select(personalEvents)..where(
            (t) =>
                t.pubkey.equals(pubkey) &
                t.kind.equals(kind) &
                t.retention.equals(PersonalEventRetention.retryIntent.value),
          ))
          .get();

  /// Reads only an explicitly retained outbound intent, never a cached event.
  Future<Event?> getRetryEvent({
    required String pubkey,
    required int kind,
    required String dTag,
  }) async {
    final rows = await _retryRows(pubkey, kind);
    for (final row in rows) {
      final event = _toEvent(row);
      if (_retryCoordinate(event) == dTag) return event;
    }
    return null;
  }

  /// Drops the oldest durable rows past the per-owner cap.
  Future<void> _trimDurableRows(String pubkey) async {
    await customUpdate(
      'DELETE FROM personal_events WHERE id IN ( '
      'SELECT id FROM personal_events '
      'WHERE pubkey = ? AND retention = ? '
      'ORDER BY created_at DESC, id DESC '
      'LIMIT -1 OFFSET ? '
      ')',
      variables: [
        Variable.withString(pubkey),
        Variable.withInt(PersonalEventRetention.durable.value),
        Variable.withInt(maxDurablePersonalEventsPerOwner),
      ],
      updates: {personalEvents},
      updateKind: UpdateKind.delete,
    );
  }

  /// Returns the owner's event with [id], or null.
  Future<Event?> getById({required String pubkey, required String id}) async {
    final row =
        await (select(personalEvents)
              ..where((t) => t.id.equals(id) & t.pubkey.equals(pubkey)))
            .getSingleOrNull();
    if (row == null) return null;
    final events = await _decodeRows([row]);
    return events.isEmpty ? null : events.single;
  }

  /// Whether the owner has an event with [id].
  Future<bool> hasEvent({
    required String pubkey,
    required String id,
  }) async {
    final row =
        await (select(personalEvents)
              ..where((t) => t.id.equals(id) & t.pubkey.equals(pubkey))
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }

  /// Returns the owner's events of [kind], newest first.
  Future<List<Event>> getByKind({
    required String pubkey,
    required int kind,
  }) async {
    final rows =
        await (select(personalEvents)
              ..where((t) => t.pubkey.equals(pubkey) & t.kind.equals(kind))
              ..orderBy([
                (t) => OrderingTerm(
                  expression: t.createdAt,
                  mode: OrderingMode.desc,
                ),
              ]))
            .get();
    return _decodeRows(rows);
  }

  /// Returns all of the owner's events, newest first.
  Future<List<Event>> getAllForOwner(String pubkey) async {
    final rows =
        await (select(personalEvents)
              ..where((t) => t.pubkey.equals(pubkey))
              ..orderBy([
                (t) => OrderingTerm(
                  expression: t.createdAt,
                  mode: OrderingMode.desc,
                ),
              ]))
            .get();
    return _decodeRows(rows);
  }

  /// Clears disposable cache rows while preserving explicit outbound intents.
  /// Omit [pubkey] only for whole-app cache recovery.
  Future<int> deleteCachedEvents({String? pubkey}) =>
      (delete(personalEvents)..where(
            (t) =>
                t.retention
                    .equals(PersonalEventRetention.retryIntent.value)
                    .not() &
                (pubkey == null
                    ? const Constant(true)
                    : t.pubkey.equals(pubkey)),
          ))
          .go();

  /// Deletes every row belonging to [pubkey].
  Future<int> deleteAllForOwner(String pubkey) =>
      (delete(personalEvents)..where((t) => t.pubkey.equals(pubkey))).go();

  /// Deletes every row, including outbound intents, for a destructive reset.
  Future<int> deleteAll() => delete(personalEvents).go();

  /// Number of rows belonging to [pubkey].
  Future<int> countForOwner(String pubkey) async {
    final row = await customSelect(
      'SELECT COUNT(*) AS count FROM personal_events WHERE pubkey = ?',
      variables: [Variable.withString(pubkey)],
      readsFrom: {personalEvents},
    ).getSingle();
    return row.read<int>('count');
  }

  Future<List<Event>> _decodeRows(List<PersonalEventRow> rows) async {
    final events = <Event>[];
    for (final row in rows) {
      try {
        events.add(_toEvent(row));
      } on FormatException {
        // This table is a disposable cache. Quarantine a malformed JSON row
        // instead of letting one bad event disable every synchronous cache
        // reader for the rest of the signed-in session.
        await (delete(personalEvents)..where((t) => t.id.equals(row.id))).go();
      }
    }
    return events;
  }

  Event _toEvent(PersonalEventRow row) {
    final decodedTags = jsonDecode(row.tags);
    if (decodedTags is! List) {
      throw const FormatException('Event tags must be a JSON array');
    }
    final tags = <List<String>>[];
    for (final tag in decodedTags) {
      if (tag is! List) {
        throw const FormatException('Each event tag must be a JSON array');
      }
      tags.add(tag.map((value) => value.toString()).toList());
    }

    return Event(
        row.pubkey,
        row.kind,
        tags,
        row.content,
        createdAt: row.createdAt,
      )
      ..id = row.id
      ..sig = row.sig;
  }
}
