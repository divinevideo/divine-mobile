// ABOUTME: Data access for the owner-scoped ids of messages and reactions
// ABOUTME: removed with their conversation, so a kind 5 naming one can settle.

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';

part 'removed_message_ids_dao.g.dart';

@DriftAccessor(tables: [RemovedMessageIds])
class RemovedMessageIdsDao extends DatabaseAccessor<AppDatabase>
    with _$RemovedMessageIdsDaoMixin {
  RemovedMessageIdsDao(super.attachedDatabase);

  /// Records the id of every message and reaction that removing
  /// [conversationIds] deletes for [ownerPubkey].
  ///
  /// Call it before the delete, inside the same transaction: the ids are read
  /// from the rows removal is about to delete, through the same predicates, so
  /// the two cannot disagree. Ids already recorded keep their first
  /// `removedAt`.
  Future<void> captureForConversations({
    required Iterable<String> conversationIds,
    required String ownerPubkey,
    required int removedAt,
  }) async {
    final ids = conversationIds.toList(growable: false);
    if (ids.isEmpty) return;
    final messageIds = await attachedDatabase.directMessagesDao
        .messageIdsForConversations(ids, ownerPubkey: ownerPubkey);
    final reactionIds = await attachedDatabase.dmReactionsDao
        .reactionIdsForConversations(
          conversationIds: ids,
          ownerPubkey: ownerPubkey,
        );
    await batch((batch) {
      batch.insertAll(
        removedMessageIds,
        [
          for (final rumorId in {...messageIds, ...reactionIds})
            RemovedMessageIdsCompanion.insert(
              ownerPubkey: ownerPubkey,
              rumorId: rumorId,
              removedAt: removedAt,
            ),
        ],
        mode: InsertMode.insertOrIgnore,
      );
    });
  }

  /// Whether [rumorId] was removed with its conversation for [ownerPubkey].
  Future<bool> contains({
    required String rumorId,
    required String ownerPubkey,
  }) async {
    final query = selectOnly(removedMessageIds)
      ..addColumns([removedMessageIds.rumorId])
      ..where(
        removedMessageIds.rumorId.equals(rumorId) &
            removedMessageIds.ownerPubkey.equals(ownerPubkey),
      )
      ..limit(1);
    return await query.getSingleOrNull() != null;
  }

  /// Deletes every recorded id for [ownerPubkey]; returns the rows removed.
  Future<int> clearAllForUser(String ownerPubkey) {
    return (delete(
      removedMessageIds,
    )..where((t) => t.ownerPubkey.equals(ownerPubkey))).go();
  }
}
