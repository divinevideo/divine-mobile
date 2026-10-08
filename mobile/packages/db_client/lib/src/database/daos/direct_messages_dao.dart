// ABOUTME: Data Access Object for NIP-17 direct message persistence.
// ABOUTME: Provides CRUD operations for decrypted DM storage and
// ABOUTME: conversation-scoped queries with reactive streams.
// ABOUTME: All queries are scoped by ownerPubkey for multi-account isolation.

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';

part 'direct_messages_dao.g.dart';

/// Which arrival protocol a stored `direct_messages` row must have for
/// [DirectMessagesDao.hasMatchingMessage] to treat it as a duplicate.
///
/// This is not `Conversations.dmProtocol`, which classifies a whole
/// *conversation* for send routing. This names one stored *row*, and it is
/// derived rather than stored: the NIP-04 receive path writes the wire event
/// id into both `id` and `gift_wrap_id`, while every NIP-17 path writes a
/// rumor id distinct from its gift-wrap id.
enum DmDedupCounterpart {
  /// Only a row that arrived over NIP-04 counts. Asked by the NIP-17 receive
  /// path: a near-identical row from its *own* protocol is a genuine earlier
  /// message, not this one.
  nip04Copy,

  /// Only a row that arrived over NIP-17 counts. Mirror of [nip04Copy], asked
  /// by the NIP-04 receive path.
  nip17Copy,

  /// No arrival constraint. For the self-send paths that match the user's own
  /// persisted message rather than a cross-protocol twin.
  unconstrained,
}

@DriftAccessor(tables: [DirectMessages])
class DirectMessagesDao extends DatabaseAccessor<AppDatabase>
    with _$DirectMessagesDaoMixin {
  DirectMessagesDao(super.attachedDatabase);

  /// Soft-deleted locally; the kind-5 wrap still needs a confirmed delivery.
  static const String deletionPending = 'deletion_pending';

  /// A relay confirmed the wrap for every recipient. Terminal.
  static const String _deletionSent = 'deletion_sent';

  /// Send policy blocked every recipient that failed. Terminal, and NOT a
  /// claim of full delivery — recipients outside the block may already have
  /// received the retraction.
  ///
  /// Public because the repository maps it to the failed-retraction bubble
  /// state (#8201).
  static const String deletionBlocked = 'deletion_blocked';

  /// Build a filter expression that returns rows owned by [ownerPubkey]
  /// **or** legacy rows with no owner.
  ///
  /// A legacy row is `''` after the v12 migration and `NULL` before it. Both
  /// arms are kept: the delete side (`clearForAccountSwitch`, `clearUnowned`)
  /// has always matched on either, and an older binary writing `NULL` between
  /// an upgrade and the migration must stay readable. Testing only `IS NULL`
  /// would make every backfilled row invisible to its own account (#6645).
  Expression<bool> _visibleToOwner(
    $DirectMessagesTable row,
    String? ownerPubkey,
  ) {
    if (ownerPubkey == null) return const Constant(true);
    final exactOwner = row.ownerPubkey.equals(ownerPubkey);
    final legacy = row.ownerPubkey.equals('') | row.ownerPubkey.isNull();
    final ownedCopy = directMessages.createAlias('owned_direct_message');
    final exactCopyExists = existsQuery(
      selectOnly(ownedCopy)
        ..addColumns([ownedCopy.id])
        ..where(
          ownedCopy.id.equalsExp(row.id) &
              ownedCopy.ownerPubkey.equals(ownerPubkey),
        ),
    );
    return exactOwner | (legacy & exactCopyExists.not());
  }

  /// Rows the sender must still be able to recognize in the conversation.
  ///
  /// A pending or refused own retraction is deliberately visible even though
  /// `is_deleted` is already true. The message disappears only after every
  /// recipient confirms the deletion.
  Expression<bool> _visibleInThread(
    $DirectMessagesTable t,
    String? ownerPubkey,
  ) {
    final uncertainOwnRetraction = ownerPubkey == null
        ? const Constant(false)
        : t.senderPubkey.equals(ownerPubkey) &
              t.deletionPublishStatus.isIn([deletionPending, deletionBlocked]);
    return t.isDeleted.equals(false) | uncertainOwnRetraction;
  }

  /// Insert a decrypted DM, returning whether a row was actually written.
  ///
  /// Uses `INSERT OR IGNORE` so that violations on either the primary key
  /// (`id`, `owner_pubkey`) **or** the UNIQUE index on `gift_wrap_id` are
  /// handled gracefully without throwing. A `false` return means a local
  /// uniqueness constraint skipped the row, and callers must avoid advancing
  /// receive-side state that depends on a newly persisted message.
  ///
  /// NIP-17 rumor events are immutable — the same rumor ID always carries
  /// the same content. Rumor uniqueness is owner-scoped, while gift-wrap IDs
  /// remain globally unique because a wrap has exactly one recipient.
  ///
  /// For kind 14 (text), only [content] is used.
  /// For kind 15 (file), [content] holds the file URL and file metadata
  /// fields are populated from the event tags.
  Future<bool> insertMessage({
    required String id,
    required String conversationId,
    required String senderPubkey,
    required String content,
    required int createdAt,
    required String giftWrapId,
    int messageKind = 14,
    String? replyToId,
    String? subject,
    String? tagsJson,
    String? fileType,
    String? encryptionAlgorithm,
    String? decryptionKey,
    String? decryptionNonce,
    String? fileHash,
    String? originalFileHash,
    int? fileSize,
    String? dimensions,
    String? blurhash,
    String? thumbnailUrl,
    String? ownerPubkey,
    String? sendBatchId,
  }) async {
    final inserted = await into(directMessages).insertReturningOrNull(
      DirectMessagesCompanion.insert(
        id: id,
        conversationId: conversationId,
        senderPubkey: senderPubkey,
        content: content,
        createdAt: createdAt,
        giftWrapId: giftWrapId,
        messageKind: Value(messageKind),
        replyToId: Value(replyToId),
        subject: Value(subject),
        tagsJson: Value(tagsJson),
        fileType: Value(fileType),
        encryptionAlgorithm: Value(encryptionAlgorithm),
        decryptionKey: Value(decryptionKey),
        decryptionNonce: Value(decryptionNonce),
        fileHash: Value(fileHash),
        originalFileHash: Value(originalFileHash),
        fileSize: Value(fileSize),
        dimensions: Value(dimensions),
        blurhash: Value(blurhash),
        thumbnailUrl: Value(thumbnailUrl),
        // A caller with no owner is writing an unattributed row; `''` is
        // this schema's legacy sentinel and is what the composite key
        // needs, since a NULL cannot participate in it (#6645).
        ownerPubkey: Value(ownerPubkey ?? ''),
        sendBatchId: Value(sendBatchId),
      ),
      mode: InsertMode.insertOrIgnore,
    );
    return inserted != null;
  }

  /// Every row in a conversation, **including** soft-deleted ones, oldest
  /// first.
  ///
  /// [getMessagesForConversation] filters `is_deleted`, which is right for
  /// rendering and wrong for repair: the group-conversation recovery pass
  /// (#8407) reconstructs a destroyed room's membership from the stored
  /// rumor `p` tags, and a room whose surviving rows happen to be soft-deleted
  /// would otherwise look like an ordinary 1:1.
  ///
  /// Oldest first so a caller walking a reply chain sees a parent before its
  /// children.
  Future<List<DirectMessageRow>> getAllMessagesForConversationIncludingDeleted(
    String conversationId, {
    required String ownerPubkey,
  }) {
    return (select(directMessages)
          ..where(
            (t) =>
                t.conversationId.equals(conversationId) &
                _visibleToOwner(t, ownerPubkey),
          )
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .get();
  }

  /// Re-point an explicit set of messages at [toConversationId].
  ///
  /// Deliberately keyed on message ids rather than a source conversation.
  /// #8401 deleted a `reassignConversation({fromConversationId, ...})` whose
  /// whole-conversation shape is what let a startup pass fold a group into a
  /// 1:1 and erase its other participants; taking ids makes that bulk merge
  /// unexpressible here.
  ///
  /// Returns the number of rows moved.
  Future<int> reassignMessages({
    required List<String> messageIds,
    required String toConversationId,
    required String ownerPubkey,
  }) {
    if (messageIds.isEmpty) return Future.value(0);
    return (update(directMessages)..where(
          (t) => t.id.isIn(messageIds) & _visibleToOwner(t, ownerPubkey),
        ))
        .write(
          DirectMessagesCompanion(conversationId: Value(toConversationId)),
        );
  }

  /// Get messages for a conversation, newest first.
  ///
  /// Excludes confirmed soft-deleted messages while retaining own messages
  /// whose delete-for-everyone delivery is still pending or failed.
  Future<List<DirectMessageRow>> getMessagesForConversation(
    String conversationId, {
    int? limit,
    int? offset,
    String? ownerPubkey,
  }) {
    final query = select(directMessages)
      ..where(
        (t) =>
            t.conversationId.equals(conversationId) &
            _visibleInThread(t, ownerPubkey) &
            _visibleToOwner(t, ownerPubkey),
      )
      ..orderBy([
        (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
        // `id` is the rumor event hash: this secondary sort is a stable but
        // arbitrary tie-break for messages sharing a `createdAt` second. Keep
        // it `id DESC` to match ConversationsDao.backfillLatestMessagePreviews
        // so the inbox preview agrees with the open conversation's newest row.
        (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
      ]);
    if (limit != null) query.limit(limit, offset: offset);
    return query.get();
  }

  /// Watch messages for a conversation (reactive stream), newest first.
  ///
  /// Excludes confirmed soft-deleted messages while retaining own messages
  /// whose delete-for-everyone delivery is still pending or failed.
  Stream<List<DirectMessageRow>> watchMessagesForConversation(
    String conversationId, {
    int? limit,
    String? ownerPubkey,
  }) {
    final query = select(directMessages)
      ..where(
        (t) =>
            t.conversationId.equals(conversationId) &
            _visibleInThread(t, ownerPubkey) &
            _visibleToOwner(t, ownerPubkey),
      )
      ..orderBy([
        (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
        // `id` is the rumor event hash: this secondary sort is a stable but
        // arbitrary tie-break for messages sharing a `createdAt` second. Keep
        // it `id DESC` to match ConversationsDao.backfillLatestMessagePreviews
        // so the inbox preview agrees with the open conversation's newest row.
        (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
      ]);
    if (limit != null) query.limit(limit);
    return query.watch();
  }

  /// Soft-delete a message by rumor event ID (NIP-09 kind 5).
  ///
  /// Sets `is_deleted = true` instead of removing the row so the
  /// `gift_wrap_id` remains for deduplication.
  ///
  /// Returns `true` if the row was updated, `false` if [rumorId] was not
  /// found.
  Future<bool> markMessageDeleted(String rumorId, {String? ownerPubkey}) async {
    final rows =
        await (update(directMessages)..where(
              (t) => t.id.equals(rumorId) & _visibleToOwner(t, ownerPubkey),
            ))
            .write(const DirectMessagesCompanion(isDeleted: Value(true)));
    return rows > 0;
  }

  /// Soft-delete [rumorId] and durably record the kind-5 rumor that still
  /// has to reach the recipient.
  ///
  /// One write, so a crash between recording the user's intent and storing
  /// the rumor cannot lose the retraction. The sender's conversation query
  /// keeps the row visible with pending styling, while
  /// `deletion_publish_status = 'deletion_pending'` keeps it on the retry
  /// worklist until every recipient confirms the wrap. Mirrors
  /// `DmReactionsDao.markOwnDeletionPending`.
  ///
  /// Returns `true` if the row was updated, `false` if [rumorId] was not
  /// found.
  Future<bool> markMessageDeletionPending(
    String rumorId, {
    required String deletionRumorJson,
    String? ownerPubkey,
  }) async {
    final rows =
        await (update(directMessages)..where(
              (t) => t.id.equals(rumorId) & _visibleToOwner(t, ownerPubkey),
            ))
            .write(
              DirectMessagesCompanion(
                isDeleted: const Value(true),
                deletionRumorJson: Value(deletionRumorJson),
                deletionPublishStatus: const Value(deletionPending),
              ),
            );
    return rows > 0;
  }

  /// A relay confirmed the deletion wrap: drop the stored rumor and move the
  /// row to the terminal `'deletion_sent'` status so the sweep stops.
  Future<bool> markMessageDeletionSent(String rumorId, {String? ownerPubkey}) =>
      _settleMessageDeletion(
        rumorId,
        status: _deletionSent,
        // Delivered, so there is nothing left to replay.
        retainRumor: false,
        // Delivered: keep the row retracted.
        restoreToThread: false,
        ownerPubkey: ownerPubkey,
      );

  /// Send policy blocked every failed recipient: stop re-driving a send that
  /// will always be refused, but record it as `'deletion_blocked'` rather than
  /// `'deletion_sent'`. Other recipients may already have succeeded.
  ///
  /// The reaction path collapses these two, reasoning that a blocked peer
  /// never received the reaction either so the removal is moot. That does not
  /// transfer to a message, which may well have been delivered before the
  /// block took effect — calling it sent would misreport a message the peer
  /// still holds.
  ///
  /// The rumor is **kept** (#8226). It is the retraction's event identity: a
  /// replay would keep every attempt one kind-5, where rebuilding mints a
  /// fresh id per attempt. The warning affordance can move the row back to
  /// pending and replay this exact payload.
  ///
  /// [restoreToThread] keeps the original bubble recognizable while its
  /// failed status explains that deletion was not confirmed for everyone.
  ///
  /// "Blocked" is not always a send-policy verdict: the marker it derives from
  /// is a substring match with several Keycast sources, so #7337's
  /// scope-denied signer 403 lands here too.
  Future<bool> markMessageDeletionBlocked(
    String rumorId, {
    required bool restoreToThread,
    String? ownerPubkey,
  }) => _settleMessageDeletion(
    rumorId,
    status: deletionBlocked,
    retainRumor: true,
    restoreToThread: restoreToThread,
    ownerPubkey: ownerPubkey,
  );

  /// Move a deletion row to a terminal [status].
  ///
  /// [retainRumor] and [restoreToThread] are required rather than defaulted:
  /// whether the payload survives, and whether the message comes back, are the
  /// whole difference between the two terminal states, so a future third
  /// caller has to decide both deliberately.
  ///
  /// `is_deleted` is written in both directions rather than left absent: a
  /// restored blocked row is visible AND still holds a rumor, so a later
  /// confirmed retraction of it reaching [markMessageDeletionSent] has to hide
  /// it again rather than leave it on screen.
  Future<bool> _settleMessageDeletion(
    String rumorId, {
    required String status,
    required bool retainRumor,
    required bool restoreToThread,
    String? ownerPubkey,
  }) async {
    final rows =
        await (update(directMessages)..where(
              (t) => t.id.equals(rumorId) & _visibleToOwner(t, ownerPubkey),
            ))
            .write(
              DirectMessagesCompanion(
                deletionRumorJson: retainRumor
                    ? const Value.absent()
                    : const Value(null),
                isDeleted: Value(!restoreToThread),
                deletionPublishStatus: Value(status),
              ),
            );
    return rows > 0;
  }

  /// Own deletions still awaiting confirmed delivery, oldest first — the
  /// retry sweep's worklist.
  ///
  /// Scoped to rows this account authored *and* soft-deleted, so a peer's
  /// deletion applied locally is never re-published from this device.
  Future<List<DirectMessageRow>> getRetryableOwnMessageDeletions({
    required String ownerPubkey,
  }) {
    return (select(directMessages)
          ..where(
            (t) =>
                _visibleToOwner(t, ownerPubkey) &
                t.senderPubkey.equals(ownerPubkey) &
                t.isDeleted.equals(true) &
                t.deletionRumorJson.isNotNull() &
                t.deletionPublishStatus.equals(deletionPending),
          )
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .get();
  }

  /// Look up a message by rumor event ID.
  ///
  /// Used to validate sender pubkey before applying a kind 5 deletion.
  Future<DirectMessageRow?> getMessageById(String id, {String? ownerPubkey}) {
    return (select(directMessages)..where(
          (t) => t.id.equals(id) & _visibleToOwner(t, ownerPubkey),
        ))
        .getSingleOrNull();
  }

  /// Check if a gift wrap event has already been processed (dedup).
  ///
  /// Intentionally NOT scoped by `ownerPubkey`: gift-wrap event IDs are
  /// globally unique per the Nostr protocol, so cross-account dedup
  /// prevents re-processing the same relay event for multiple local accounts.
  Future<bool> hasGiftWrap(String giftWrapId) async {
    final query = selectOnly(directMessages)
      ..where(directMessages.giftWrapId.equals(giftWrapId))
      ..addColumns([directMessages.id]);
    final result = await query.getSingleOrNull();
    return result != null;
  }

  /// Which of [giftWrapIds] already have a persisted message row. Batched
  /// counterpart to [hasGiftWrap]: one `IN` query instead of N single-id
  /// lookups, used by the history-drain dedup probe to avoid a per-wrap DB
  /// round trip. Like [hasGiftWrap], it is NOT scoped by `ownerPubkey`
  /// (gift-wrap IDs are globally unique). Returns an empty set for an empty
  /// input.
  Future<Set<String>> giftWrapIdsPresent(Set<String> giftWrapIds) async {
    if (giftWrapIds.isEmpty) return const <String>{};
    final query = selectOnly(directMessages)
      ..addColumns([directMessages.giftWrapId])
      ..where(directMessages.giftWrapId.isIn(giftWrapIds));
    final rows = await query.get();
    final present = <String>{};
    for (final row in rows) {
      final id = row.read(directMessages.giftWrapId);
      if (id != null) present.add(id);
    }
    return present;
  }

  /// Restricts a dedup match to rows that arrived over [counterpart]'s
  /// protocol, read off the two id columns.
  ///
  /// The NIP-04 receive path stores the wire event id in BOTH `id` and
  /// `gift_wrap_id`; every NIP-17 path stores a rumor id distinct from its
  /// gift-wrap id. Both columns are `NOT NULL`, so `id = gift_wrap_id` is a
  /// plain two-valued predicate and its negation is exact.
  Expression<bool> _arrivedOverCounterpart(DmDedupCounterpart counterpart) {
    final arrivedOverNip04 = directMessages.id.equalsExp(
      directMessages.giftWrapId,
    );
    return switch (counterpart) {
      DmDedupCounterpart.nip04Copy => arrivedOverNip04,
      DmDedupCounterpart.nip17Copy => arrivedOverNip04.not(),
      DmDedupCounterpart.unconstrained => const Constant(true),
    };
  }

  /// Whether a message with the same sender and content is already stored in
  /// [conversationId] within ±[windowSeconds] **and** arrived over the
  /// protocol named by [counterpart].
  ///
  /// This answers the SELF-AUTHORED question — "have I already persisted this
  /// send?" — with existence semantics, which is what those callers need: a
  /// group send's siblings all match the one local row the fan-out wrote, and
  /// every one of them must be suppressed. Prefer [hasMessageWithSendBatchId]
  /// when the batch token is available, since it matches exactly instead of
  /// heuristically. Self-authored callers pass
  /// [DmDedupCounterpart.unconstrained], because the row may carry either
  /// arrival shape: every NIP-17 send path before #2654 wrote the gift-wrap id
  /// into both columns, so a row from that window reads as NIP-04 (#8211).
  ///
  /// For the CROSS-PROTOCOL twin — a dual-send that put one message on the
  /// wire twice, as a NIP-17 rumor and a NIP-04 event with unrelated ids —
  /// use [claimCrossProtocolTwin] instead. Existence is the wrong question
  /// there: a twin is 1:1, and asking existence let one stored copy swallow
  /// every same-text arrival in the window (#8211). Same-protocol replays need
  /// no help from either method — the primary key on (`id`, `owner_pubkey`)
  /// and the UNIQUE index on `gift_wrap_id` already make [insertMessage] a
  /// no-op for them.
  Future<bool> hasMatchingMessage({
    required String conversationId,
    required String senderPubkey,
    required String content,
    required int createdAt,
    required DmDedupCounterpart counterpart,
    int windowSeconds = 5,
    String? ownerPubkey,
  }) async {
    final query = selectOnly(directMessages)
      ..where(
        _dedupWindow(
          conversationId: conversationId,
          senderPubkey: senderPubkey,
          content: content,
          createdAt: createdAt,
          counterpart: counterpart,
          windowSeconds: windowSeconds,
          ownerPubkey: ownerPubkey,
        ),
      )
      ..addColumns([directMessages.id])
      ..limit(1);
    final result = await query.getSingleOrNull();
    return result != null;
  }

  /// The `(sender, content, ~time)` dedup window, shared by
  /// [hasMatchingMessage] and [claimCrossProtocolTwin] so the arrival-shape
  /// rule has exactly one definition.
  Expression<bool> _dedupWindow({
    required String conversationId,
    required String senderPubkey,
    required String content,
    required int createdAt,
    required DmDedupCounterpart counterpart,
    required int windowSeconds,
    required String? ownerPubkey,
  }) {
    return directMessages.conversationId.equals(conversationId) &
        directMessages.senderPubkey.equals(senderPubkey) &
        directMessages.content.equals(content) &
        directMessages.createdAt.isBiggerOrEqualValue(
          createdAt - windowSeconds,
        ) &
        directMessages.createdAt.isSmallerOrEqualValue(
          createdAt + windowSeconds,
        ) &
        _arrivedOverCounterpart(counterpart) &
        _visibleToOwner(directMessages, ownerPubkey);
  }

  /// Claims the cross-protocol twin of an arriving message, marking it so no
  /// later arrival can claim it again. Returns true when one was claimed,
  /// meaning the caller must drop the arriving event as a duplicate.
  ///
  /// This is the dual-send question, and it is deliberately NOT
  /// [hasMatchingMessage]. That method asks whether a matching row *exists* —
  /// correct for a self-authored send, which any number of echoes may
  /// legitimately match. A twin is 1:1: one message put on the wire twice
  /// yields exactly one counterpart, so a stored copy may absorb exactly one.
  /// Asking existence let a single stored NIP-04 row swallow every same-text
  /// NIP-17 arrival inside the window — #7324's own symptom, surviving in the
  /// NIP-04-first ordering (#8211). Measured on device before this fix: three
  /// messages sent, one bubble shown.
  ///
  /// The claim is ONE statement on purpose — an `UPDATE ... WHERE id IN
  /// (SELECT ... LIMIT 1)`. A drift transaction does not serialize the
  /// statements issued inside it, so a select-then-update pair can interleave
  /// with a concurrent claim and hand the same row to both arrivals. Here the
  /// affected row count comes back from the same write, with no await point in
  /// between.
  ///
  /// [counterpart] names the protocol the twin must have arrived over.
  /// [DmDedupCounterpart.unconstrained] cannot identify a twin and is a caller
  /// error.
  Future<bool> claimCrossProtocolTwin({
    required String conversationId,
    required String senderPubkey,
    required String content,
    required int createdAt,
    required DmDedupCounterpart counterpart,
    int windowSeconds = 5,
    String? ownerPubkey,
  }) async {
    if (counterpart == DmDedupCounterpart.unconstrained) {
      throw ArgumentError.value(
        counterpart,
        'counterpart',
        'A twin must name the protocol it arrived over',
      );
    }

    final unclaimed = selectOnly(directMessages)
      ..addColumns([directMessages.id])
      ..where(
        _dedupWindow(
              conversationId: conversationId,
              senderPubkey: senderPubkey,
              content: content,
              createdAt: createdAt,
              counterpart: counterpart,
              windowSeconds: windowSeconds,
              ownerPubkey: ownerPubkey,
            ) &
            directMessages.twinCollapsed.equals(false),
      )
      ..orderBy([OrderingTerm(expression: directMessages.createdAt)])
      ..limit(1);

    final claimed =
        await (update(directMessages)..where(
              (t) =>
                  t.id.isInQuery(unclaimed) &
                  t.ownerPubkey.equals(ownerPubkey ?? ''),
            ))
            .write(const DirectMessagesCompanion(twinCollapsed: Value(true)));
    return claimed > 0;
  }

  /// Whether a message tagged with group-send [batchId] is already persisted
  /// for [ownerPubkey]. The collision-proof replacement for
  /// [hasMatchingMessage] on the group-send / recovery dedup path: a group
  /// send persists ONE local message for the whole fan-out, stamped with the
  /// batch's durable id (`DirectMessages.sendBatchId`). Recovery of a later
  /// sibling — or the happy-path persist racing a concurrent recovery — asks
  /// this to avoid inserting a second copy.
  ///
  /// Scoped by strict `owner_pubkey` equality (not legacy fallback): generated
  /// send ids are only stamped on the owner's sends, including self-wrap echoes
  /// received on another device, so the NULL-owner legacy branch would only
  /// widen the match with nothing to gain.
  Future<bool> hasMessageWithSendBatchId({
    required String batchId,
    required String ownerPubkey,
  }) async {
    final query = selectOnly(directMessages)
      ..where(
        directMessages.sendBatchId.equals(batchId) &
            directMessages.ownerPubkey.equals(ownerPubkey),
      )
      ..addColumns([directMessages.id])
      ..limit(1);
    final result = await query.getSingleOrNull();
    return result != null;
  }

  /// Ids of every message, deleted ones included, that
  /// [deleteConversationMessages] would remove from [conversationIds] for
  /// [ownerPubkey].
  ///
  /// Shares the delete's owner predicate, so an id captured here is exactly an
  /// id that removal then deletes.
  Future<List<String>> messageIdsForConversations(
    Iterable<String> conversationIds, {
    required String ownerPubkey,
  }) async {
    final ids = conversationIds.toList(growable: false);
    if (ids.isEmpty) return const [];
    final query = selectOnly(directMessages)
      ..addColumns([directMessages.id])
      ..where(
        directMessages.conversationId.isIn(ids) &
            _visibleToOwner(directMessages, ownerPubkey),
      );
    final rows = await query.get();
    return [for (final row in rows) row.read(directMessages.id)!];
  }

  /// Delete all messages in a conversation.
  ///
  /// Returns the number of deleted rows.
  Future<int> deleteConversationMessages(
    String conversationId, {
    String? ownerPubkey,
  }) {
    return (delete(directMessages)..where(
          (t) =>
              t.conversationId.equals(conversationId) &
              _visibleToOwner(t, ownerPubkey),
        ))
        .go();
  }

  /// Delete a single message by ID.
  Future<int> deleteMessage(String id, {String? ownerPubkey}) {
    return (delete(directMessages)..where(
          (t) => t.id.equals(id) & _visibleToOwner(t, ownerPubkey),
        ))
        .go();
  }

  /// Delete messages for multiple conversations in a single batch.
  Future<int> deleteMultipleConversationMessages(
    List<String> conversationIds, {
    String? ownerPubkey,
  }) {
    if (conversationIds.isEmpty) return Future.value(0);
    return (delete(directMessages)..where(
          (t) =>
              t.conversationId.isIn(conversationIds) &
              _visibleToOwner(t, ownerPubkey),
        ))
        .go();
  }

  /// Count messages in a conversation.
  Future<int> countMessages(
    String conversationId, {
    String? ownerPubkey,
  }) async {
    final query = selectOnly(directMessages)
      ..where(
        directMessages.conversationId.equals(conversationId) &
            _visibleToOwner(directMessages, ownerPubkey),
      )
      ..addColumns([directMessages.id.count()]);
    final result = await query.getSingle();
    return result.read(directMessages.id.count()) ?? 0;
  }

  /// Deletes DMs for the departing account plus unattributed legacy rows.
  ///
  /// Ambiguous rows must never cross an account boundary and become visible to
  /// the incoming account. Rows owned by every other known account survive.
  Future<int> clearForAccountSwitch(String ownerPubkey) {
    return (delete(directMessages)..where(
          (t) =>
              t.ownerPubkey.equals(ownerPubkey) |
              t.ownerPubkey.isNull() |
              t.ownerPubkey.equals(''),
        ))
        .go();
  }

  /// Deletes only messages owned by [ownerPubkey].
  Future<int> deleteAllForOwner(String ownerPubkey) {
    return (delete(
      directMessages,
    )..where((t) => t.ownerPubkey.equals(ownerPubkey))).go();
  }

  /// Deletes only unattributed legacy rows when the departing account is
  /// unknown, preserving every row with a valid owner.
  Future<int> clearUnowned() {
    return (delete(
      directMessages,
    )..where((t) => t.ownerPubkey.isNull() | t.ownerPubkey.equals(''))).go();
  }
}
