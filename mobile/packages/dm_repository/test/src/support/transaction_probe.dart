// ABOUTME: Real DAOs that note whether each write ran inside the transaction
// ABOUTME: ConversationsDao.runInTransaction opened, and can fail one (#8408).

import 'dart:async';

import 'package:db_client/db_client.dart';

final Object _insideTransaction = Object();

/// Whether the caller runs inside a transaction a [ProbedConversationsDao]
/// opened.
///
/// A zone value rather than a flag: a flag also reads true for a write that
/// ran outside while some other transaction happened to be open, and moving a
/// write out of its transaction is exactly the change these probes catch.
bool get insideProbedTransaction => Zone.current[_insideTransaction] == true;

/// What the probed DAOs saw, and the failure to inject.
///
/// The DAOs stay real, so the transaction is drift's own: a write the probe
/// fails rolls back everything the transaction wrote before it.
class TransactionProbe {
  /// Write name -> calls made inside a probed transaction.
  final Map<String, int> inside = {};

  /// Write name -> calls made outside any probed transaction.
  final Map<String, int> outside = {};

  String? _failOn;
  var _skip = 0;

  /// Whether [write] was called, and every call ran inside the transaction.
  bool ranOnlyInside(String write) =>
      (inside[write] ?? 0) > 0 && !outside.containsKey(write);

  /// Throws a [StateError] from the next call to [write], after letting [skip]
  /// calls through.
  void failOn(String write, {int skip = 0}) {
    _failOn = write;
    _skip = skip;
  }

  /// Forgets what was recorded, and any failure still armed.
  void reset() {
    inside.clear();
    outside.clear();
    _failOn = null;
    _skip = 0;
  }

  /// Notes a call to [write], and throws when it is the armed failure.
  void record(String write) {
    (insideProbedTransaction ? inside : outside).update(
      write,
      (calls) => calls + 1,
      ifAbsent: () => 1,
    );
    if (write != _failOn) return;
    if (_skip > 0) {
      _skip--;
      return;
    }
    _failOn = null;
    throw StateError('injected failure in $write');
  }
}

/// A real [ConversationsDao] whose transactions are visible to
/// [insideProbedTransaction], and whose writes report to [probe].
class ProbedConversationsDao extends ConversationsDao {
  /// Creates a probed DAO over [attachedDatabase].
  ProbedConversationsDao(super.attachedDatabase, this.probe);

  /// Where the writes report.
  final TransactionProbe probe;

  @override
  Future<T> runInTransaction<T>(Future<T> Function() action) => runZoned(
    () => super.runInTransaction(action),
    zoneValues: {_insideTransaction: true},
  );

  @override
  Future<void> upsertConversation({
    required String id,
    required String participantPubkeys,
    required bool isGroup,
    required int createdAt,
    String? lastMessageContent,
    String? lastMessageId,
    int? lastMessageTimestamp,
    int? lastMessageCreatedAt,
    String? lastMessageSenderPubkey,
    String? subject,
    bool isRead = true,
    bool currentUserHasSent = false,
    String? ownerPubkey,
    String? dmProtocol,
    bool forceUpdateLastMessage = false,
    bool isNewMessage = false,
  }) {
    probe.record('upsertConversation');
    return super.upsertConversation(
      id: id,
      participantPubkeys: participantPubkeys,
      isGroup: isGroup,
      createdAt: createdAt,
      lastMessageId: lastMessageId,
      lastMessageContent: lastMessageContent,
      lastMessageTimestamp: lastMessageTimestamp,
      lastMessageCreatedAt: lastMessageCreatedAt,
      lastMessageSenderPubkey: lastMessageSenderPubkey,
      subject: subject,
      isRead: isRead,
      currentUserHasSent: currentUserHasSent,
      ownerPubkey: ownerPubkey,
      dmProtocol: dmProtocol,
      forceUpdateLastMessage: forceUpdateLastMessage,
      isNewMessage: isNewMessage,
    );
  }

  @override
  Future<bool> markAsRead(String id, {String? ownerPubkey}) {
    probe.record('markAsRead');
    return super.markAsRead(id, ownerPubkey: ownerPubkey);
  }

  @override
  Future<int> deleteConversation(String id, {String? ownerPubkey}) {
    probe.record('deleteConversation');
    return super.deleteConversation(id, ownerPubkey: ownerPubkey);
  }

  @override
  Future<int> deleteMultiple(List<String> ids, {String? ownerPubkey}) {
    probe.record('deleteMultiple');
    return super.deleteMultiple(ids, ownerPubkey: ownerPubkey);
  }
}

/// A real [DirectMessagesDao] whose writes report to [probe].
class ProbedDirectMessagesDao extends DirectMessagesDao {
  /// Creates a probed DAO over [attachedDatabase].
  ProbedDirectMessagesDao(super.attachedDatabase, this.probe);

  /// Where the writes report.
  final TransactionProbe probe;

  @override
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
  }) {
    probe.record('insertMessage');
    return super.insertMessage(
      id: id,
      conversationId: conversationId,
      senderPubkey: senderPubkey,
      content: content,
      createdAt: createdAt,
      giftWrapId: giftWrapId,
      messageKind: messageKind,
      replyToId: replyToId,
      subject: subject,
      tagsJson: tagsJson,
      fileType: fileType,
      encryptionAlgorithm: encryptionAlgorithm,
      decryptionKey: decryptionKey,
      decryptionNonce: decryptionNonce,
      fileHash: fileHash,
      originalFileHash: originalFileHash,
      fileSize: fileSize,
      dimensions: dimensions,
      blurhash: blurhash,
      thumbnailUrl: thumbnailUrl,
      ownerPubkey: ownerPubkey,
      sendBatchId: sendBatchId,
    );
  }

  @override
  Future<int> reassignMessages({
    required List<String> messageIds,
    required String toConversationId,
    required String ownerPubkey,
  }) {
    probe.record('reassignMessages');
    return super.reassignMessages(
      messageIds: messageIds,
      toConversationId: toConversationId,
      ownerPubkey: ownerPubkey,
    );
  }

  @override
  Future<int> deleteConversationMessages(
    String conversationId, {
    String? ownerPubkey,
  }) {
    probe.record('deleteConversationMessages');
    return super.deleteConversationMessages(
      conversationId,
      ownerPubkey: ownerPubkey,
    );
  }

  @override
  Future<int> deleteMultipleConversationMessages(
    List<String> conversationIds, {
    String? ownerPubkey,
  }) {
    probe.record('deleteMultipleConversationMessages');
    return super.deleteMultipleConversationMessages(
      conversationIds,
      ownerPubkey: ownerPubkey,
    );
  }
}

/// A real [OutgoingDmsDao] whose reads and writes report to [probe].
class ProbedOutgoingDmsDao extends OutgoingDmsDao {
  /// Creates a probed DAO over [attachedDatabase].
  ProbedOutgoingDmsDao(super.attachedDatabase, this.probe);

  /// Where the calls report.
  final TransactionProbe probe;

  @override
  Future<OutgoingDm?> getById(String id) {
    probe.record('getById');
    return super.getById(id);
  }

  @override
  Future<bool> markRecipientWrapStatus({
    required String id,
    required OutgoingWrapStatus status,
    String? eventId,
    String? lastError,
  }) {
    probe.record('markRecipientWrapStatus');
    return super.markRecipientWrapStatus(
      id: id,
      status: status,
      eventId: eventId,
      lastError: lastError,
    );
  }

  @override
  Future<bool> markSelfWrapStatus({
    required String id,
    required OutgoingWrapStatus status,
    String? eventId,
    String? lastError,
  }) {
    probe.record('markSelfWrapStatus');
    return super.markSelfWrapStatus(
      id: id,
      status: status,
      eventId: eventId,
      lastError: lastError,
    );
  }

  @override
  Future<bool> markRecipientCancelled(String id) {
    probe.record('markRecipientCancelled');
    return super.markRecipientCancelled(id);
  }

  @override
  Future<int> deleteById(String id) {
    probe.record('deleteById');
    return super.deleteById(id);
  }

  @override
  Future<int> deleteForConversation({
    required String conversationId,
    required String ownerPubkey,
  }) {
    probe.record('deleteForConversation');
    return super.deleteForConversation(
      conversationId: conversationId,
      ownerPubkey: ownerPubkey,
    );
  }

  @override
  Future<int> deleteForConversations({
    required Iterable<String> conversationIds,
    required String ownerPubkey,
  }) {
    probe.record('deleteForConversations');
    return super.deleteForConversations(
      conversationIds: conversationIds,
      ownerPubkey: ownerPubkey,
    );
  }
}

/// A real [RemovedConversationsDao] whose writes report to [probe].
class ProbedRemovedConversationsDao extends RemovedConversationsDao {
  /// Creates a probed DAO over [attachedDatabase].
  ProbedRemovedConversationsDao(super.attachedDatabase, this.probe);

  /// Where the writes report.
  final TransactionProbe probe;

  @override
  Future<void> record({
    required String conversationId,
    required String ownerPubkey,
    required int removedAt,
  }) {
    probe.record('record');
    return super.record(
      conversationId: conversationId,
      ownerPubkey: ownerPubkey,
      removedAt: removedAt,
    );
  }

  @override
  Future<void> recordAll({
    required Iterable<String> conversationIds,
    required String ownerPubkey,
    required int removedAt,
  }) {
    probe.record('recordAll');
    return super.recordAll(
      conversationIds: conversationIds,
      ownerPubkey: ownerPubkey,
      removedAt: removedAt,
    );
  }
}
