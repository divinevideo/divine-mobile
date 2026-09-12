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
  durable(1);

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
  /// Both halves run in one transaction, so a read can never observe an event
  /// without its retention having been applied. The Hive implementation this
  /// replaced wrote the event and its kind index as two separate awaited
  /// writes, leaving a window in which the event existed but was invisible to
  /// kind queries (#6280).
  Future<void> upsertPersonalEvent(Event event) async {
    final retention = PersonalEventRetention.forKind(event.kind);

    await transaction(() async {
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

  /// Deletes every row belonging to [pubkey].
  Future<int> deleteAllForOwner(String pubkey) =>
      (delete(personalEvents)..where((t) => t.pubkey.equals(pubkey))).go();

  /// Deletes every row, for every owner. Used by cache recovery.
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
