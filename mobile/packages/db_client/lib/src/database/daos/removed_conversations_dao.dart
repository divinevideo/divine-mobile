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
  /// Keeps the earliest write after the removal. The user's own copies arrive
  /// out of order (NIP-59 backdates wraps, history pages newest first), so a
  /// copy processed later can move the rejoin back, never forward. A replay at
  /// or before the removal is not a rejoin.
  ///
  /// An explicit [isLocalSend] is a rejoin whatever its stamp says: the local
  /// action establishes that this send follows the removal. Both timestamps
  /// have second precision, so it can share the removal's second, and a clock
  /// set back since the removal can stamp it earlier; then the rejoin is
  /// recorded at the removal rather than refused.
  ///
  /// Returns whether the rejoin moved; false when the conversation was never
  /// removed, a replay's [at] is not after the removal, or the recorded rejoin
  /// is already at or before the time this write would record.
  Future<bool> markRejoined({
    required String conversationId,
    required String ownerPubkey,
    required int at,
    bool isLocalSend = false,
  }) async {
    if (isLocalSend) {
      final updated = await customUpdate(
        'UPDATE removed_conversations SET rejoined_at = MAX(?1, removed_at) '
        'WHERE conversation_id = ?2 AND owner_pubkey = ?3 '
        'AND (rejoined_at IS NULL OR rejoined_at > MAX(?1, removed_at))',
        variables: [
          Variable.withInt(at),
          Variable.withString(conversationId),
          Variable.withString(ownerPubkey),
        ],
        updates: {removedConversations},
        updateKind: UpdateKind.update,
      );
      return updated > 0;
    }
    final updated =
        await (update(removedConversations)..where(
              (t) =>
                  t.conversationId.equals(conversationId) &
                  t.ownerPubkey.equals(ownerPubkey) &
                  t.removedAt.isSmallerThanValue(at) &
                  (t.rejoinedAt.isNull() | t.rejoinedAt.isBiggerThanValue(at)),
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
