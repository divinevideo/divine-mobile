import 'dart:convert';
import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'application history is owner-scoped and excludes deleted messages',
    () async {
      final db = AppDatabase.test(NativeDatabase.memory());
      addTearDown(db.close);
      final dao = db.directMessagesDao;
      for (final entry in [
        ('one', 'owner'),
        ('two', 'other'),
        ('gone', 'owner'),
      ]) {
        await dao.insertMessage(
          id: entry.$1,
          conversationId: 'conversation',
          senderPubkey: 'sender',
          content: 'request',
          createdAt: 1,
          giftWrapId: 'wrap-${entry.$1}',
          ownerPubkey: entry.$2,
          tagsJson: jsonEncode([
            ['divine', 'sound-request', '1'],
          ]),
        );
      }
      await dao.markMessageDeleted('gone', ownerPubkey: 'owner');
      final rows = await dao
          .watchApplicationMessages(ownerPubkey: 'owner', marker: 'divine')
          .first;
      expect(rows.map((row) => row.id), ['one']);
    },
  );
}
