// ABOUTME: Keeps an unread conversation across a partial history restore.
// ABOUTME: Startup repair preserves its known latest-message stamp.

import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('retained conversation previews', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.test(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('keeps only visible boundary IDs until the preview changes', () async {
      final dao = db.conversationsDao;
      for (final owner in ['owner_a', 'owner_b']) {
        await dao.upsertConversation(
          id: 'chat',
          participantPubkeys: '["owner_a","owner_b"]',
          isGroup: false,
          createdAt: 100,
          lastMessageTimestamp: 200,
          ownerPubkey: owner,
        );
      }
      for (final entry in {'1': 'owner_a', '2': 'owner_b', '3': ''}.entries) {
        await db.directMessagesDao.insertMessage(
          id: entry.key * 64,
          conversationId: 'chat',
          senderPubkey: 'peer',
          content: 'boundary',
          createdAt: 200,
          giftWrapId: 'a${entry.key}' * 32,
          ownerPubkey: entry.value,
        );
      }

      await dao.retainMessageIdsForAccountSwitch('owner_a');
      await db.directMessagesDao.clearForAccountSwitch('owner_a');
      await dao.retainMessageIdsForAccountSwitch('owner_a');
      final row = (await dao.getConversation('chat', ownerPubkey: 'owner_a'))!;
      expect(
        (jsonDecode(row.retainedMessageIds!) as List).toSet(),
        {'1' * 64, '3' * 64},
      );
      expect(
        (await dao.getConversation(
          'chat',
          ownerPubkey: 'owner_b',
        ))!.retainedMessageIds,
        isNull,
      );

      await dao.upsertConversation(
        id: 'chat',
        participantPubkeys: '["owner_a","owner_b"]',
        isGroup: false,
        createdAt: 100,
        lastMessageTimestamp: 200,
        lastMessageContent: 'same-second preview refresh',
        forceUpdateLastMessage: true,
        ownerPubkey: 'owner_a',
      );
      await db.directMessagesDao.insertMessage(
        id: '1' * 64,
        conversationId: 'chat',
        senderPubkey: 'peer',
        content: 'partial history at the boundary',
        createdAt: 200,
        giftWrapId: 'a1' * 32,
        ownerPubkey: 'owner_a',
      );
      await dao.backfillLatestMessagePreviews(ownerPubkey: 'owner_a');
      final refreshed = (await dao.getConversation(
        'chat',
        ownerPubkey: 'owner_a',
      ))!;
      expect(
        (jsonDecode(refreshed.retainedMessageIds!) as List).toSet(),
        {'1' * 64, '3' * 64},
      );

      await dao.upsertConversation(
        id: 'chat',
        participantPubkeys: '["owner_a","owner_b"]',
        isGroup: false,
        createdAt: 100,
        lastMessageTimestamp: 300,
        ownerPubkey: 'owner_a',
      );
      expect(
        (await dao.getConversation(
          'chat',
          ownerPubkey: 'owner_a',
        ))!.retainedMessageIds,
        isNull,
      );
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
