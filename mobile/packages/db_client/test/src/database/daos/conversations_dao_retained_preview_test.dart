// ABOUTME: Keeps an unread conversation across a partial history restore.
// ABOUTME: Startup repair preserves its known latest-message stamp.

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('backfillLatestMessagePreviews with partially restored history', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.test(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('keeps the unread preview ahead of downloaded messages', () async {
      final dao = db.conversationsDao;
      await dao.upsertConversation(
        id: 'chat',
        participantPubkeys: '["owner","peer"]',
        isGroup: false,
        createdAt: 1700000000,
        lastMessageContent: 'unread message outside the download window',
        lastMessageTimestamp: 1700000500,
        lastMessageCreatedAt: 1700000500,
        lastMessageSenderPubkey: 'peer',
        isRead: false,
        ownerPubkey: 'owner',
      );
      await dao.applyReadCursor('chat', 1700000300, ownerPubkey: 'owner');
      // A switch cleared the messages, and only an older wrap has returned.
      await db.directMessagesDao.insertMessage(
        id: 'older',
        conversationId: 'chat',
        senderPubkey: 'peer',
        content: 'older',
        createdAt: 1700000100,
        giftWrapId: 'older-wrap',
        ownerPubkey: 'owner',
      );

      // The next launch runs maintenance against this partial history.
      await dao.backfillLatestMessagePreviews(ownerPubkey: 'owner');
      final kept = await dao.getConversation('chat', ownerPubkey: 'owner');
      expect(kept!.lastMessageTimestamp, 1700000500);
      expect(kept.lastMessageCreatedAt, 1700000500);
      expect(kept.isRead, isFalse);

      // Another already-read message must not cover the missing unread one.
      await dao.upsertConversation(
        id: 'chat',
        participantPubkeys: '["owner","peer"]',
        isGroup: false,
        createdAt: 1700000000,
        lastMessageTimestamp: 1700000200,
        isRead: false,
        ownerPubkey: 'owner',
      );
      final after = await dao.getConversation('chat', ownerPubkey: 'owner');
      expect(after!.isRead, isFalse);
      expect(after.lastMessageTimestamp, 1700000500);
    });
  });
}
