// ABOUTME: Data access for owner-scoped removed-conversation tombstones.
// ABOUTME: Prevents replayed relay history from resurrecting removed DMs.

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';

part 'removed_conversations_dao.g.dart';

@DriftAccessor(tables: [RemovedConversations])
class RemovedConversationsDao extends DatabaseAccessor<AppDatabase>
    with _$RemovedConversationsDaoMixin {
  RemovedConversationsDao(super.attachedDatabase);

  /// Records a removal at [removedAt], replacing an earlier one.
  ///
  /// Clears any rejoin, so leaving a group again keeps it out until the user
  /// writes in it once more.
  Future<void> record({
    required String conversationId,
    required String ownerPubkey,
    required int removedAt,
  }) {
    return into(removedConversations).insertOnConflictUpdate(
      RemovedConversationsCompanion.insert(
        conversationId: conversationId,
        ownerPubkey: ownerPubkey,
        removedAt: removedAt,
        rejoinedAt: const Value(null),
      ),
    );
  }

  /// [record] for each of [conversationIds] in one batch.
  Future<void> recordAll({
    required Iterable<String> conversationIds,
    required String ownerPubkey,
    required int removedAt,
  }) async {
    await batch((batch) {
      batch.insertAllOnConflictUpdate(
        removedConversations,
        [
          for (final conversationId in conversationIds)
            RemovedConversationsCompanion.insert(
              conversationId: conversationId,
              ownerPubkey: ownerPubkey,
              removedAt: removedAt,
              rejoinedAt: const Value(null),
            ),
        ],
      );
    });
  }

  Future<int?> removedAtFor({
    required String conversationId,
    required String ownerPubkey,
  }) async {
    final row = await tombstoneFor(
      conversationId: conversationId,
      ownerPubkey: ownerPubkey,
    );
    return row?.removedAt;
  }

  /// The removal of [conversationId] for [ownerPubkey], with its rejoin, or
  /// null when it was never removed.
  Future<RemovedConversation?> tombstoneFor({
    required String conversationId,
    required String ownerPubkey,
  }) {
    return (select(removedConversations)..where(
          (t) =>
              t.conversationId.equals(conversationId) &
              t.ownerPubkey.equals(ownerPubkey),
        ))
        .getSingleOrNull();
  }

  /// Records that the user wrote in a removed conversation again at [at].
  ///
  /// Only the first rejoin after a removal counts, so a later one never moves
  /// the instant forward. Returns whether a rejoin was recorded; false when the
  /// conversation was never removed or is already rejoined.
  Future<bool> markRejoined({
    required String conversationId,
    required String ownerPubkey,
    required int at,
  }) async {
    final updated =
        await (update(removedConversations)..where(
              (t) =>
                  t.conversationId.equals(conversationId) &
                  t.ownerPubkey.equals(ownerPubkey) &
                  t.rejoinedAt.isNull(),
            ))
            .write(RemovedConversationsCompanion(rejoinedAt: Value(at)));
    return updated > 0;
  }

  Future<int> clearAllForUser(String ownerPubkey) {
    return (delete(
      removedConversations,
    )..where((t) => t.ownerPubkey.equals(ownerPubkey))).go();
  }
}
