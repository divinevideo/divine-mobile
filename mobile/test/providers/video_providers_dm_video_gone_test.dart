// ABOUTME: Tests for dmVideoMessageGone: which kept video DMs prune deletes
// ABOUTME: because their message was retracted or removed with its chat.

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/video_providers.dart';

void main() {
  group('dmVideoMessageGone', () {
    final owner = 'e' * 64;
    final messageId = 'a' * 64;
    const conversationId = 'conversation';
    late AppDatabase db;

    setUp(() => db = AppDatabase.test(NativeDatabase.memory()));

    tearDown(() => db.close());

    Future<void> insertVideoMessage() async {
      final inserted = await db.directMessagesDao.insertMessage(
        id: messageId,
        conversationId: conversationId,
        senderPubkey: 'b' * 64,
        content: 'https://media.example/blob',
        createdAt: 1757385263,
        giftWrapId: 'c' * 64,
        messageKind: 15,
        ownerPubkey: owner,
      );
      expect(inserted, isTrue);
    }

    test('counts a message its sender retracted as gone', () async {
      await insertVideoMessage();
      await db.directMessagesDao.markMessageDeleted(
        messageId,
        ownerPubkey: owner,
      );

      expect(await dmVideoMessageGone(db, owner)(messageId), isTrue);
    });

    test('counts a message removed with its conversation as gone', () async {
      await insertVideoMessage();
      await db.removedMessageIdsDao.captureForConversations(
        conversationIds: [conversationId],
        ownerPubkey: owner,
        removedAt: 1757385300,
      );
      await db.directMessagesDao.deleteConversationMessages(
        conversationId,
        ownerPubkey: owner,
      );

      expect(await dmVideoMessageGone(db, owner)(messageId), isTrue);
    });

    test('keeps a message that is shown', () async {
      await insertVideoMessage();

      expect(await dmVideoMessageGone(db, owner)(messageId), isFalse);
    });

    test(
      'keeps a message with no row, as while it downloads again after an '
      'account switch',
      () async {
        expect(await dmVideoMessageGone(db, owner)(messageId), isFalse);
      },
    );

    test('keeps a message gone only for another account', () async {
      await insertVideoMessage();
      await db.directMessagesDao.markMessageDeleted(
        messageId,
        ownerPubkey: owner,
      );

      expect(await dmVideoMessageGone(db, 'f' * 64)(messageId), isFalse);
    });
  });
}
