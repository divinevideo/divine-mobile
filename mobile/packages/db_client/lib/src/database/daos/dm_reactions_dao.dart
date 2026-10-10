// ABOUTME: DAO for NIP-25 emoji reactions on NIP-17 direct messages.
// ABOUTME: Handles optimistic insert + placeholder swap, soft-delete on
// ABOUTME: supersede or NIP-09, and reactive watch for chip rendering.

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';

part 'dm_reactions_dao.g.dart';

/// DAO for the `dm_message_reactions` table.
///
/// Two write paths, both enforcing the cap-at-one storage invariant (#5419):
/// at most one live reaction per `(target_message_id, reactor_pubkey,
/// owner_pubkey)`, backed by the partial unique index
/// `idx_dm_reactions_unique_live`.
/// - **Outgoing**: [insertOwnReactionSuperseding] soft-deletes any prior live
///   reaction by this reactor on the target, then writes a row with a
///   placeholder id plus `publishStatus = 'pending'` and the serialized rumor
///   JSON — all in one transaction. Once the publish lands, [swapPlaceholderId]
///   marks the row `'sent'` and clears the JSON.
/// - **Incoming**: [upsertIncoming] de-dups on `(id, owner_pubkey)` (the rumor
///   id is stable across the recipient and self gift-wraps) and collapses a
///   new-id same-tuple reaction to the most recent, soft-deleting the loser so
///   the live set stays capped at one.
@DriftAccessor(tables: [DmMessageReactions])
class DmReactionsDao extends DatabaseAccessor<AppDatabase>
    with _$DmReactionsDaoMixin {
  DmReactionsDao(super.attachedDatabase);

  /// `publish_status` value for a soft-deleted own reaction whose NIP-09
  /// kind-5 deletion still needs durable (re)delivery. The row is
  /// `is_deleted = 1` (hidden from the chip) but keeps its stored deletion
  /// rumor in `rumor_event_json` so the retry sweep can re-drive it.
  static const String _deletionPendingStatus = 'deletion_pending';

  /// Terminal `publish_status` for a deletion whose kind-5 reached a relay.
  static const String _deletionSentStatus = 'deletion_sent';

  /// Terminal-for-the-sweep `publish_status` for a deletion that send policy
  /// refused. The stored rumor remains available for an explicit user retry.
  static const String deletionRefused = 'deletion_refused';

  /// Terminal `publish_status` for an outgoing reaction the send policy (#176
  /// protected-minor DM restriction) refused. Not retryable — excluded from
  /// [getRetryableOwnReactions] — since retrying only re-hits the same policy.
  static const String _blockedStatus = 'blocked';

  /// Insert an optimistic outgoing row before the publish attempt, atomically
  /// superseding any prior LIVE reactions by this reactor on this target.
  ///
  /// [placeholderId] is the rumor id used while the publish is in flight; once
  /// it lands, call [swapPlaceholderId] to mark the row `sent`.
  ///
  /// Enforces the cap-at-one storage invariant (#5419) at the write boundary:
  /// in one transaction it soft-deletes every prior live row for
  /// `(targetMessageId, reactorPubkey, ownerPubkey)` and then inserts the new
  /// pending row. The partial unique index `idx_dm_reactions_unique_live` is
  /// the backstop. The final insert uses [InsertMode.insertOrIgnore] so a
  /// concurrent second cubit's racing insert is a silent no-op (cap holds, no
  /// crash) instead of a UNIQUE-constraint throw — the dual-cubit race the
  /// issue targets.
  ///
  /// One narrow path bypasses that ignore: re-reacting the same emoji within
  /// one wall-clock second of removing it rebuilds a byte-identical rumor id,
  /// which collides with the row just soft-deleted by `removeOwn`. That row is
  /// resurrected (flipped live, `publishStatus = 'pending'`) rather than
  /// dropped, so the re-reaction is not silently lost.
  ///
  /// [recipientPubkeys] is the JSON-encoded gift-wrap recipient set, stored on
  /// the row so a retry replays it instead of re-deriving it (#7880). Pass
  /// `null` when the recipients are not known yet; on the resurrect path
  /// above, `null` keeps the set the row already holds.
  ///
  /// Returns the ids of the superseded prior live rows so the caller can emit
  /// NIP-09 kind-5 deletions on the wire (outside this transaction).
  Future<List<String>> insertOwnReactionSuperseding({
    required String placeholderId,
    required String conversationId,
    required String targetMessageId,
    required String targetMessageAuthor,
    required String reactorPubkey,
    required String emoji,
    required int createdAt,
    required String ownerPubkey,
    required String rumorEventJson,
    String? recipientPubkeys,
  }) {
    return transaction(() async {
      final priors =
          await (select(dmMessageReactions)..where(
                (t) =>
                    t.targetMessageId.equals(targetMessageId) &
                    t.reactorPubkey.equals(reactorPubkey) &
                    t.ownerPubkey.equals(ownerPubkey) &
                    t.isDeleted.equals(false),
              ))
              .get();
      final superseded = <String>[];
      for (final prior in priors) {
        if (prior.id == placeholderId) continue;
        await (update(dmMessageReactions)..where(
              (t) => t.id.equals(prior.id) & t.ownerPubkey.equals(ownerPubkey),
            ))
            .write(const DmMessageReactionsCompanion(isDeleted: Value(true)));
        superseded.add(prior.id);
      }

      // A react → remove → re-react with the SAME emoji inside one wall-clock
      // second rebuilds an identical rumor id, so [placeholderId] collides
      // with the row just soft-deleted by `removeOwn`. That row is excluded
      // from `priors` (live-only), so the [InsertMode.insertOrIgnore] below
      // would discard this *wanted* re-reaction against the primary key.
      // Resurrect it instead. Scoped to `is_deleted = 1` so a still-live
      // same-id row (idempotent double-tap) keeps its publish status and is
      // left to the no-op insert.
      final resurrected =
          await (update(dmMessageReactions)..where(
                (t) =>
                    t.id.equals(placeholderId) &
                    t.ownerPubkey.equals(ownerPubkey) &
                    t.isDeleted.equals(true),
              ))
              .write(
                DmMessageReactionsCompanion(
                  isDeleted: const Value(false),
                  publishStatus: const Value('pending'),
                  rumorEventJson: Value(rumorEventJson),
                  giftWrapId: const Value(null),
                  // An unknown set must not erase one the row already holds.
                  recipientPubkeys: recipientPubkeys == null
                      ? const Value.absent()
                      : Value(recipientPubkeys),
                ),
              );
      if (resurrected > 0) {
        return superseded;
      }

      await into(dmMessageReactions).insert(
        DmMessageReactionsCompanion.insert(
          id: placeholderId,
          conversationId: conversationId,
          targetMessageId: targetMessageId,
          targetMessageAuthor: targetMessageAuthor,
          reactorPubkey: reactorPubkey,
          emoji: emoji,
          createdAt: createdAt,
          ownerPubkey: ownerPubkey,
          giftWrapId: const Value(null),
          rumorEventJson: Value(rumorEventJson),
          publishStatus: const Value('pending'),
          recipientPubkeys: Value(recipientPubkeys),
        ),
        mode: InsertMode.insertOrIgnore,
      );
      return superseded;
    });
  }

  /// Swap the placeholder id for the real rumor event id once publish
  /// landed. Clears `rumorEventJson` (no longer needed for retry) and
  /// marks `publishStatus = 'sent'`.
  Future<void> swapPlaceholderId({
    required String placeholderId,
    required String realRumorId,
    required String ownerPubkey,
    String? giftWrapId,
  }) async {
    await (update(dmMessageReactions)..where(
          (t) => t.id.equals(placeholderId) & t.ownerPubkey.equals(ownerPubkey),
        ))
        .write(
          DmMessageReactionsCompanion(
            id: Value(realRumorId),
            giftWrapId: Value(giftWrapId),
            rumorEventJson: const Value(null),
            publishStatus: const Value('sent'),
          ),
        );
  }

  /// Mark an outgoing row as `'failed'` after a publish attempt threw.
  /// Keeps the `rumorEventJson` for retry.
  Future<void> markFailed({
    required String placeholderId,
    required String ownerPubkey,
  }) async {
    await (update(dmMessageReactions)..where(
          (t) => t.id.equals(placeholderId) & t.ownerPubkey.equals(ownerPubkey),
        ))
        .write(
          const DmMessageReactionsCompanion(publishStatus: Value('failed')),
        );
  }

  /// Mark an outgoing row as `'pending'` — used by retry to surface
  /// in-flight state in the persistent layer so a cubit rebuild
  /// (auth flip, hot-restart, navigation) recovers the correct UI.
  Future<void> markPending({
    required String id,
    required String ownerPubkey,
  }) async {
    await (update(
      dmMessageReactions,
    )..where((t) => t.id.equals(id) & t.ownerPubkey.equals(ownerPubkey))).write(
      const DmMessageReactionsCompanion(publishStatus: Value('pending')),
    );
  }

  /// Mark an outgoing row terminally `'blocked'` — the send policy refused the
  /// recipient (#176). Clears `rumorEventJson` so the row can never be selected
  /// by [getRetryableOwnReactions] (which requires a stored rumor), making the
  /// block terminal on both the status and the rumor-presence predicate.
  Future<void> markBlocked({
    required String id,
    required String ownerPubkey,
  }) async {
    await (update(
      dmMessageReactions,
    )..where((t) => t.id.equals(id) & t.ownerPubkey.equals(ownerPubkey))).write(
      const DmMessageReactionsCompanion(
        publishStatus: Value(_blockedStatus),
        rumorEventJson: Value(null),
      ),
    );
  }

  /// Soft-delete a row (NIP-09 kind 5 deletion received, or own-reaction
  /// supersede when toggling a different emoji).
  Future<int> softDelete({
    required String id,
    required String ownerPubkey,
  }) async {
    return (update(dmMessageReactions)
          ..where((t) => t.id.equals(id) & t.ownerPubkey.equals(ownerPubkey)))
        .write(const DmMessageReactionsCompanion(isDeleted: Value(true)));
  }

  /// Hard-delete a failed-and-discarded pending row (long-press dismiss).
  Future<int> deleteById({
    required String id,
    required String ownerPubkey,
  }) async {
    return (delete(
      dmMessageReactions,
    )..where((t) => t.id.equals(id) & t.ownerPubkey.equals(ownerPubkey))).go();
  }

  /// Upsert an incoming reaction, enforcing the cap-at-one storage invariant
  /// (#5419) at the write boundary.
  ///
  /// - **Same rumor id** (recipient + self gift-wrap, or relay replay):
  ///   resolves on the primary key `(id, owner_pubkey)` and updates the stable
  ///   fields in place. `is_deleted` is deliberately left untouched so a prior
  ///   kind-5 removal is not resurrected by a replayed wrap. An own row still
  ///   waiting to be sent — a reaction or its kind-5 removal — that has no
  ///   recipient set only takes the gift-wrap id: its conversation is the one
  ///   its recipients are later proven against, while the echo's is inferred
  ///   from wherever the message is filed now (#7880).
  /// - **New rumor id, same `(target, reactor, owner)` tuple**: keeps the most
  ///   recent by `(created_at, id)`. If the incoming is newest it supersedes
  ///   (soft-deletes) the prior live rows and lands live; if an existing live
  ///   row is newer (out-of-order / replayed delivery) the incoming is recorded
  ///   as already-deleted so gift-wrap dedup and history are preserved without
  ///   violating the partial unique index `idx_dm_reactions_unique_live`.
  ///
  /// The final insert uses [InsertMode.insertOrIgnore] as a race backstop so a
  /// concurrent writer can never turn this into a UNIQUE-constraint throw.
  Future<void> upsertIncoming({
    required String id,
    required String conversationId,
    required String targetMessageId,
    required String targetMessageAuthor,
    required String reactorPubkey,
    required String emoji,
    required int createdAt,
    required String giftWrapId,
    required String ownerPubkey,
  }) {
    return transaction(() async {
      final existing =
          await (select(dmMessageReactions)
                ..where(
                  (t) => t.id.equals(id) & t.ownerPubkey.equals(ownerPubkey),
                )
                ..limit(1))
              .getSingleOrNull();
      if (existing != null) {
        if (existing.reactorPubkey == ownerPubkey &&
            existing.rumorEventJson != null &&
            existing.recipientPubkeys == null) {
          await (update(dmMessageReactions)..where(
                (t) => t.id.equals(id) & t.ownerPubkey.equals(ownerPubkey),
              ))
              .write(
                DmMessageReactionsCompanion(giftWrapId: Value(giftWrapId)),
              );
          return;
        }
        // Same rumor id: update stable fields in place, never `is_deleted`.
        await into(dmMessageReactions).insertOnConflictUpdate(
          DmMessageReactionsCompanion.insert(
            id: id,
            conversationId: conversationId,
            targetMessageId: targetMessageId,
            targetMessageAuthor: targetMessageAuthor,
            reactorPubkey: reactorPubkey,
            emoji: emoji,
            createdAt: createdAt,
            ownerPubkey: ownerPubkey,
            giftWrapId: Value(giftWrapId),
          ),
        );
        return;
      }

      final liveForTuple =
          await (select(dmMessageReactions)..where(
                (t) =>
                    t.targetMessageId.equals(targetMessageId) &
                    t.reactorPubkey.equals(reactorPubkey) &
                    t.ownerPubkey.equals(ownerPubkey) &
                    t.isDeleted.equals(false),
              ))
              .get();
      final hasNewerLive = liveForTuple.any(
        (r) =>
            r.createdAt > createdAt ||
            (r.createdAt == createdAt && r.id.compareTo(id) > 0),
      );
      if (!hasNewerLive) {
        // Incoming is the newest: supersede every prior live row for the tuple.
        for (final r in liveForTuple) {
          await (update(dmMessageReactions)..where(
                (t) => t.id.equals(r.id) & t.ownerPubkey.equals(ownerPubkey),
              ))
              .write(const DmMessageReactionsCompanion(isDeleted: Value(true)));
        }
      }
      await into(dmMessageReactions).insert(
        DmMessageReactionsCompanion.insert(
          id: id,
          conversationId: conversationId,
          targetMessageId: targetMessageId,
          targetMessageAuthor: targetMessageAuthor,
          reactorPubkey: reactorPubkey,
          emoji: emoji,
          createdAt: createdAt,
          ownerPubkey: ownerPubkey,
          giftWrapId: Value(giftWrapId),
          isDeleted: Value(hasNewerLive),
        ),
        mode: InsertMode.insertOrIgnore,
      );
    });
  }

  /// Reactive stream of every visible reaction in [conversationId] for the
  /// account [ownerPubkey]. Refused own removals remain visible as warnings
  /// even though their local reaction is already soft-deleted.
  Stream<List<DmReactionRow>> watchForConversation({
    required String conversationId,
    required String ownerPubkey,
  }) {
    final query = select(dmMessageReactions)
      ..where(
        (t) =>
            t.conversationId.equals(conversationId) &
            t.ownerPubkey.equals(ownerPubkey) &
            (t.isDeleted.equals(false) |
                (t.isDeleted.equals(true) &
                    t.reactorPubkey.equals(ownerPubkey) &
                    t.publishStatus.equals(deletionRefused))),
      )
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    return query.watch();
  }

  /// Fetch this user's own outgoing reactions that a retry sweep should
  /// re-drive: live rows authored by [ownerPubkey] whose publish is
  /// `'failed'` or still `'pending'`, that still carry the rumor JSON needed
  /// to replay the gift wrap.
  ///
  /// Soft-deleted rows (superseded / removed) and already-`'sent'` rows (whose
  /// JSON is cleared on [swapPlaceholderId]) are excluded, so a re-driven
  /// reaction is always a genuinely undelivered one. Ordered oldest-first so
  /// retries drain in send order.
  Future<List<DmReactionRow>> getRetryableOwnReactions({
    required String ownerPubkey,
  }) {
    return (select(dmMessageReactions)
          ..where(
            (t) =>
                t.ownerPubkey.equals(ownerPubkey) &
                t.reactorPubkey.equals(ownerPubkey) &
                t.isDeleted.equals(false) &
                t.rumorEventJson.isNotNull() &
                t.publishStatus.isIn(const ['failed', 'pending']) &
                _notSuppressedByRemoval(t),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  /// Soft-delete an own reaction AND record its NIP-09 kind-5 deletion rumor
  /// for durable (re)delivery.
  ///
  /// The row leaves the live set immediately (`is_deleted = 1`, so the chip
  /// hides on the same frame as the tap) but keeps [deletionRumorJson] and
  /// `publish_status = 'deletion_pending'` so the retry sweep can re-drive the
  /// kind-5 until a relay confirms it — closing the gap where a removal made
  /// offline (or on a flaky relay) was silently dropped. Overloads the
  /// existing `rumor_event_json` column with the deletion rumor: the prior
  /// add-reaction rumor is no longer needed once the reaction is removed.
  Future<void> markOwnDeletionPending({
    required String id,
    required String ownerPubkey,
    required String deletionRumorJson,
  }) async {
    await (update(
      dmMessageReactions,
    )..where((t) => t.id.equals(id) & t.ownerPubkey.equals(ownerPubkey))).write(
      DmMessageReactionsCompanion(
        isDeleted: const Value(true),
        publishStatus: const Value(_deletionPendingStatus),
        rumorEventJson: Value(deletionRumorJson),
      ),
    );
  }

  /// Mark a pending own-reaction deletion as delivered: clears the stored
  /// deletion rumor and moves the row to the terminal `'deletion_sent'` status
  /// so the sweep stops re-driving it. The row stays `is_deleted = 1`.
  Future<void> markDeletionSent({
    required String id,
    required String ownerPubkey,
  }) async {
    await (update(
      dmMessageReactions,
    )..where((t) => t.id.equals(id) & t.ownerPubkey.equals(ownerPubkey))).write(
      const DmMessageReactionsCompanion(
        publishStatus: Value(_deletionSentStatus),
        rumorEventJson: Value(null),
      ),
    );
  }

  /// Record that send policy refused a pending own-reaction deletion.
  ///
  /// The row stays soft-deleted and leaves the automatic retry worklist, but
  /// retains the exact kind-5 rumor so a user-driven retry can replay it.
  Future<void> markDeletionRefused({
    required String id,
    required String ownerPubkey,
  }) async {
    await (update(
      dmMessageReactions,
    )..where((t) => t.id.equals(id) & t.ownerPubkey.equals(ownerPubkey))).write(
      const DmMessageReactionsCompanion(publishStatus: Value(deletionRefused)),
    );
  }

  /// Fetch this user's own soft-deleted reactions whose kind-5 deletion still
  /// needs durable delivery (`publish_status = 'deletion_pending'` with a
  /// stored deletion rumor). Ordered oldest-first so removals drain in order.
  Future<List<DmReactionRow>> getRetryableOwnDeletions({
    required String ownerPubkey,
  }) {
    return (select(dmMessageReactions)
          ..where(
            (t) =>
                t.ownerPubkey.equals(ownerPubkey) &
                t.reactorPubkey.equals(ownerPubkey) &
                t.isDeleted.equals(true) &
                t.rumorEventJson.isNotNull() &
                t.publishStatus.equals(_deletionPendingStatus) &
                _notSuppressedByRemoval(t),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  /// Whether [ownerPubkey] has an own reaction removal for
  /// [targetMessageId] that has not reached a relay.
  ///
  /// Pending removals are intentionally hidden from the conversation stream,
  /// while refused removals remain available for manual retry. Querying the
  /// durable queue prevents a newer reaction from making either row
  /// unreachable in the UI.
  Future<bool> hasOutstandingOwnDeletion({
    required String targetMessageId,
    required String ownerPubkey,
  }) async {
    final query = selectOnly(dmMessageReactions)
      ..addColumns([dmMessageReactions.id])
      ..where(
        dmMessageReactions.targetMessageId.equals(targetMessageId) &
            dmMessageReactions.ownerPubkey.equals(ownerPubkey) &
            dmMessageReactions.reactorPubkey.equals(ownerPubkey) &
            dmMessageReactions.isDeleted.equals(true) &
            dmMessageReactions.rumorEventJson.isNotNull() &
            dmMessageReactions.publishStatus.isIn(const [
              _deletionPendingStatus,
              deletionRefused,
            ]),
      )
      ..limit(1);
    return (await query.get()).isNotEmpty;
  }

  /// Store [recipientPubkeys] on a row that has none yet.
  ///
  /// Never replaces a stored set: a later resolution must not narrow or widen
  /// what the row was queued with. That includes a stored value the
  /// repository cannot use, which only corruption produces; such a row is
  /// resolved again on every attempt instead. [conversationId] is the
  /// conversation the set was worked out from, and the write is skipped when
  /// the row has since moved to another one (for example by
  /// [reassignForTargetMessages]), where that set would be wrong.
  ///
  /// Returns the number of rows written — `0` when the row already has
  /// recipients, has left [conversationId], or does not exist for
  /// [ownerPubkey].
  Future<int> setRecipientPubkeysIfMissing({
    required String id,
    required String ownerPubkey,
    required String conversationId,
    required String recipientPubkeys,
  }) {
    return (update(dmMessageReactions)..where(
          (t) =>
              t.id.equals(id) &
              t.ownerPubkey.equals(ownerPubkey) &
              t.conversationId.equals(conversationId) &
              t.recipientPubkeys.isNull(),
        ))
        .write(
          DmMessageReactionsCompanion(
            recipientPubkeys: Value(recipientPubkeys),
          ),
        );
  }

  /// Fetch this user's own unsent rows that carry no recipient set (#7880):
  /// reactions and kind-5 removals queued before recipients were stored,
  /// queued while they could not be established, or moved by the
  /// group-recovery pass since.
  ///
  /// A row still holding its rumor JSON can still be sent — by the retry
  /// sweep, or for a refused removal by a user retry — so those are the rows
  /// whose recipients must be established while the state they come from can
  /// still be read.
  Future<List<DmReactionRow>> getOwnQueuedRowsMissingRecipients({
    required String ownerPubkey,
  }) {
    return (select(dmMessageReactions)..where(
          (t) =>
              t.ownerPubkey.equals(ownerPubkey) &
              t.reactorPubkey.equals(ownerPubkey) &
              t.rumorEventJson.isNotNull() &
              t.recipientPubkeys.isNull(),
        ))
        .get();
  }

  /// Return a single reaction row by stable reaction rumor id, or `null`
  /// when no row matches in this account's view.
  Future<DmReactionRow?> getById({
    required String id,
    required String ownerPubkey,
  }) {
    final query = select(dmMessageReactions)
      ..where((t) => t.id.equals(id) & t.ownerPubkey.equals(ownerPubkey))
      ..limit(1);
    return query.getSingleOrNull();
  }

  /// Has the gift wrap with id `giftWrapId` already produced a row? Used by the
  /// receive pipeline to short-circuit before decryption work. Returns
  /// `true` only when a non-null match exists in this account's view.
  Future<bool> hasGiftWrap({
    required String giftWrapId,
    required String ownerPubkey,
  }) async {
    final query = selectOnly(dmMessageReactions)
      ..addColumns([dmMessageReactions.id])
      ..where(
        dmMessageReactions.giftWrapId.equals(giftWrapId) &
            dmMessageReactions.ownerPubkey.equals(ownerPubkey),
      )
      ..limit(1);
    return (await query.get()).isNotEmpty;
  }

  /// `true` when this reaction is NOT suppressed by a removed-conversation
  /// tombstone — i.e. no `removed_conversations` marker for the same
  /// `(conversation_id, owner_pubkey)` covers its `created_at`.
  ///
  /// Mirrors the message-suppression rule in `DmRepository`
  /// (`createdAt <= removedAt` is removed history): a reaction created *after*
  /// the removal belongs to a conversation the counterparty has since
  /// recreated, so it must still be delivered. Tombstones outlive the
  /// `conversations` row on purpose, which is why this keys on them rather
  /// than on conversation existence — a plain existence check would silently
  /// drop every queued reaction after an account switch, which deletes the
  /// leaving account's `conversations` rows while preserving its retry queue
  /// (#6984).
  Expression<bool> _notSuppressedByRemoval($DmMessageReactionsTable t) {
    final tombstones = attachedDatabase.removedConversations;
    return notExistsQuery(
      selectOnly(tombstones)
        ..addColumns([tombstones.conversationId])
        ..where(
          tombstones.conversationId.equalsExp(t.conversationId) &
              tombstones.ownerPubkey.equalsExp(t.ownerPubkey) &
              t.createdAt.isSmallerOrEqual(tombstones.removedAt),
        ),
    );
  }

  /// Delete reaction rows stranded by a conversation removal that predates the
  /// removal-time cleanup (#7857).
  ///
  /// Before that fix, removing a conversation left its `dm_message_reactions`
  /// rows behind. Those rows are an outgoing queue, so the retry sweep kept
  /// re-driving them and could publish a gift wrap into a conversation the
  /// user had removed. Rows written after the tombstone belong to a recreated
  /// conversation and are kept — same rule as [_notSuppressedByRemoval].
  ///
  /// Idempotent: a no-op once the account has none left.
  Future<int> deleteSuppressedByRemoval({required String ownerPubkey}) {
    return (delete(dmMessageReactions)..where(
          (t) =>
              t.ownerPubkey.equals(ownerPubkey) &
              _notSuppressedByRemoval(t).not(),
        ))
        .go();
  }

  /// The rows of [ownerPubkey] in [conversationIds]: what conversation removal
  /// deletes, and what [reactionIdsForConversations] reads first.
  Expression<bool> _inConversationsOf(
    $DmMessageReactionsTable row,
    List<String> conversationIds,
    String ownerPubkey,
  ) =>
      row.conversationId.isIn(conversationIds) &
      row.ownerPubkey.equals(ownerPubkey);

  /// Ids of every reaction row, deleted ones included, that
  /// [deleteForConversations] would remove from [conversationIds] for
  /// [ownerPubkey].
  ///
  /// Both filter through the same [_inConversationsOf], so an id read here is
  /// exactly an id that removal then deletes. Returns an empty list when
  /// [conversationIds] is empty.
  Future<List<String>> reactionIdsForConversations({
    required Iterable<String> conversationIds,
    required String ownerPubkey,
  }) async {
    final ids = conversationIds.toList(growable: false);
    if (ids.isEmpty) return const [];
    final query = selectOnly(dmMessageReactions)
      ..addColumns([dmMessageReactions.id])
      ..where(_inConversationsOf(dmMessageReactions, ids, ownerPubkey));
    final rows = await query.get();
    return [for (final row in rows) row.read(dmMessageReactions.id)!];
  }

  /// Delete every reaction row in [conversationIds] for [ownerPubkey].
  ///
  /// Conversation removal calls this inside the same transaction as the
  /// message/conversation/`outgoing_dms` deletes. Unlike
  /// [deleteNonRetryableForOwner], this deletes retryable rows too: removal is
  /// an explicit intent to stop sending, not a data-portability cleanup.
  ///
  /// No-op returning `0` when [conversationIds] is empty.
  Future<int> deleteForConversations({
    required Iterable<String> conversationIds,
    required String ownerPubkey,
  }) {
    final ids = conversationIds.toList(growable: false);
    if (ids.isEmpty) return Future.value(0);
    return (delete(
      dmMessageReactions,
    )..where((t) => _inConversationsOf(t, ids, ownerPubkey))).go();
  }

  /// Re-point reactions whose target message moved to another conversation.
  ///
  /// `conversation_id` here is the conversation the *target message* belongs
  /// to, and the live render index is
  /// `(conversation_id, target_message_id) WHERE is_deleted = 0`. So a caller
  /// that moves messages between conversations must move their reactions in
  /// the same transaction, or the chips stop rendering on the moved messages
  /// and the rows are stranded — which is also the outgoing queue for
  /// unpublished reactions and kind-5 removals (#7857).
  ///
  /// Used by the group-conversation recovery pass (#8407).
  ///
  /// The stored recipient set goes too: it was worked out from the
  /// conversation the row is leaving, and is worked out again from the one it
  /// joins (#7880).
  ///
  /// No-op returning `0` when [targetMessageIds] is empty.
  Future<int> reassignForTargetMessages({
    required Iterable<String> targetMessageIds,
    required String toConversationId,
    required String ownerPubkey,
  }) {
    final ids = targetMessageIds.toList(growable: false);
    if (ids.isEmpty) return Future.value(0);
    return (update(dmMessageReactions)..where(
          (t) =>
              t.targetMessageId.isIn(ids) & t.ownerPubkey.equals(ownerPubkey),
        ))
        .write(
          DmMessageReactionsCompanion(
            conversationId: Value(toConversationId),
            recipientPubkeys: const Value(null),
          ),
        );
  }

  /// Move the received reactions on [targetMessageId] into
  /// [toConversationId], the conversation that message was just stored in.
  ///
  /// A reaction names its target and the target's author, never the room, so
  /// one that arrives before its message is filed under a 1:1 inferred from
  /// those two. Chips render by `(conversation_id, target_message_id)`, so
  /// it would never show on a message that then lands in a group (#8271).
  ///
  /// Only rows with no `publish_status` move: the ones [upsertIncoming]
  /// wrote. The account's own queued, sent, blocked and removal rows stay
  /// where they are with their stored recipients, which a retry replays
  /// (#7880). That is why this is not [reassignForTargetMessages], which
  /// moves every row and clears that set.
  ///
  /// Returns the number of rows moved.
  Future<int> adoptReceivedForTargetMessage({
    required String targetMessageId,
    required String toConversationId,
    required String ownerPubkey,
  }) {
    return (update(dmMessageReactions)..where(
          (t) =>
              t.targetMessageId.equals(targetMessageId) &
              t.ownerPubkey.equals(ownerPubkey) &
              t.publishStatus.isNull() &
              t.conversationId.equals(toConversationId).not(),
        ))
        .write(
          DmMessageReactionsCompanion(conversationId: Value(toConversationId)),
        );
  }

  /// Delete everything owned by [ownerPubkey]. Sign-out cleanup.
  Future<int> deleteAllForOwner(String ownerPubkey) async {
    return (delete(
      dmMessageReactions,
    )..where((t) => t.ownerPubkey.equals(ownerPubkey))).go();
  }

  /// Delete owner-scoped reaction rows that can be recovered from relays.
  ///
  /// Non-destructive account switches preserve retryable own rows because their
  /// stored `rumor_event_json` is the only durable payload for unpublished
  /// reactions and for pending or refused kind-5 removals.
  Future<int> deleteNonRetryableForOwner(String ownerPubkey) async {
    return (delete(dmMessageReactions)..where((t) {
          final retryableOwnReaction =
              t.reactorPubkey.equals(ownerPubkey) &
              t.isDeleted.equals(false) &
              t.rumorEventJson.isNotNull() &
              t.publishStatus.isIn(const ['failed', 'pending']);
          final retryableOwnDeletion =
              t.reactorPubkey.equals(ownerPubkey) &
              t.isDeleted.equals(true) &
              t.rumorEventJson.isNotNull() &
              t.publishStatus.isIn(const [
                _deletionPendingStatus,
                deletionRefused,
              ]);
          return t.ownerPubkey.equals(ownerPubkey) &
              (retryableOwnReaction | retryableOwnDeletion).not();
        }))
        .go();
  }
}
