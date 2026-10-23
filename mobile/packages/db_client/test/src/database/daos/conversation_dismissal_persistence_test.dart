import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('conversation dismissal persistence', () {
    late AppDatabase database;
    late Directory temp;
    final owner = 'a' * 64;
    final peer = 'b' * 64;
    final id = 'c' * 64;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('dismissal_persistence_');
      database = AppDatabase.test(NativeDatabase(File('${temp.path}/db')));
    });
    tearDown(() async {
      await database.close();
      await temp.delete(recursive: true);
    });

    Future<void> replay({
      String? account,
      int timestamp = 100,
      bool read = false,
      bool force = false,
    }) => database.conversationsDao.upsertConversation(
      id: id,
      participantPubkeys: '["$owner","$peer"]',
      isGroup: false,
      createdAt: 100,
      lastMessageTimestamp: timestamp,
      ownerPubkey: account ?? owner,
      isRead: read,
      forceUpdateLastMessage: force,
    );

    Future<void> message(
      String messageId, {
      int timestamp = 100,
      String? sender,
    }) => database.directMessagesDao.insertMessage(
      id: messageId,
      conversationId: id,
      senderPubkey: sender ?? peer,
      content: 'Message',
      createdAt: timestamp,
      giftWrapId: messageId,
      ownerPubkey: owner,
    );

    Future<void> dismiss() => database.conversationsDao.setDismissed(
      id,
      ownerPubkey: owner,
      dismissed: true,
    );

    Future<bool> isDismissed({String? account}) async =>
        (await database.conversationsDao.getConversation(
          id,
          ownerPubkey: account ?? owner,
        ))!.isDismissed;

    Future<void> switchAway() async {
      await database.directMessagesDao.clearForAccountSwitch(owner);
      await database.conversationsDao.clearForAccountSwitch(owner);
    }

    test(
      'synced boundary precedes history; a same-second new ID restores it',
      () async {
        await database.conversationsDao.applySyncedDismissal(
          id,
          ownerPubkey: owner,
          dismissed: true,
          boundaryTimestamp: 100,
          knownMessageIds: {'known'},
        );
        await message('known');
        await replay();
        expect(await isDismissed(), isTrue);
        await message('new');
        await replay();
        expect(await isDismissed(), isFalse);
        // Replaying the same account intent must not hide that new arrival.
        await database.conversationsDao.applySyncedDismissal(
          id,
          ownerPubkey: owner,
          dismissed: true,
          boundaryTimestamp: 100,
          knownMessageIds: {'known'},
        );
        expect(await isDismissed(), isFalse);
        expect(
          (await database.conversationsDao.getConversation(
            id,
            ownerPubkey: owner,
          ))!.isRead,
          isFalse,
        );
      },
    );

    test(
      'remote dismissal never reads newer local messages or another account',
      () async {
        await replay(timestamp: 200);
        await replay(account: peer, timestamp: 50);
        await database.conversationsDao.applySyncedDismissal(
          id,
          ownerPubkey: owner,
          dismissed: true,
          boundaryTimestamp: 100,
        );
        expect(await isDismissed(), isFalse);
        expect(await isDismissed(account: peer), isFalse);
        final row = (await database.conversationsDao.getConversation(
          id,
          ownerPubkey: owner,
        ))!;
        expect(row.lastMessageTimestamp, 200);
        expect(row.isRead, isFalse);
      },
    );

    test(
      'rebuilding history after account cleanup retains dismissal',
      () async {
        await replay();
        await database.conversationsDao.setDismissed(
          id,
          ownerPubkey: owner,
          dismissed: true,
        );
        expect(
          (await database.conversationsDao.getConversation(
            id,
            ownerPubkey: owner,
          ))!.isDismissed,
          isTrue,
        );
        await database.conversationsDao.clearForAccountSwitch(owner);
        expect(
          await database.conversationsDao.getConversation(
            id,
            ownerPubkey: owner,
          ),
          isNull,
        );
        await replay();
        final restored = (await database.conversationsDao.getConversation(
          id,
          ownerPubkey: owner,
        ))!;
        expect(restored.isDismissed, isTrue);
        expect(restored.isRead, isTrue);
        expect(restored.currentUserHasSent, isFalse);
      },
    );

    test(
      'replay and older history survive switching and reopening the database',
      () async {
        await message('d' * 64);
        await replay();
        await dismiss();
        await switchAway();
        await database.close();
        database = AppDatabase.test(NativeDatabase(File('${temp.path}/db')));
        await message('d' * 64);
        await replay();
        expect(await isDismissed(), isTrue);
        await message('e' * 64, timestamp: 90);
        await replay(timestamp: 90);
        expect(await isDismissed(), isTrue);
      },
    );

    test(
      'a distinct same-second incoming message clears the saved dismissal',
      () async {
        await message('d' * 64);
        await replay();
        await dismiss();
        await switchAway();
        await message('d' * 64);
        await replay();
        expect(await isDismissed(), isTrue);
        await message('e' * 64);
        await replay();
        expect(await isDismissed(), isFalse);
        await switchAway();
        await message('d' * 64);
        await replay();
        expect(await isDismissed(), isFalse);
      },
    );

    for (final incoming in [true, false]) {
      test(
        'newer ${incoming ? 'incoming' : 'outgoing'} messages restore',
        () async {
          await message('d' * 64);
          await replay();
          await dismiss();
          await message(
            'e' * 64,
            timestamp: 101,
            sender: incoming ? peer : owner,
          );
          await replay(timestamp: 101, read: !incoming);
          expect(await isDismissed(), isFalse);
          expect(
            (await database.conversationsDao.getConversation(
              id,
              ownerPubkey: owner,
            ))!.isRead,
            !incoming,
          );
        },
      );
    }

    test('replaying a previously deleted message retains dismissal', () async {
      await message('d' * 64);
      await replay();
      await message('e' * 64, timestamp: 90);
      await database.directMessagesDao.markMessageDeleted(
        'd' * 64,
        ownerPubkey: owner,
      );
      // Sender deletion is a soft-delete; its id remains known even when the
      // preview is repaired to the older remaining message before dismissal.
      await replay(timestamp: 90, force: true);
      await dismiss();
      await switchAway();
      // Model the wrap arriving before its kind-5 deletion during recovery.
      await message('d' * 64);
      await replay();
      expect(await isDismissed(), isTrue);
      await database.directMessagesDao.markMessageDeleted(
        'd' * 64,
        ownerPubkey: owner,
      );
      await message('e' * 64, timestamp: 90);
      await replay(timestamp: 90, force: true);
      expect(await isDismissed(), isTrue);
    });

    test(
      'dismissal remembers message ids from a visible legacy cache row',
      () async {
        await database.directMessagesDao.insertMessage(
          id: 'd' * 64,
          conversationId: id,
          senderPubkey: peer,
          content: 'Legacy message',
          createdAt: 100,
          giftWrapId: 'e' * 64,
          ownerPubkey: '',
        );
        await replay(account: '');
        await dismiss();
        await switchAway();
        await message('d' * 64);
        await replay();
        expect(await isDismissed(), isTrue);
      },
    );

    test(
      'another known account cannot supply this account’s replay ids',
      () async {
        await database.directMessagesDao.insertMessage(
          id: 'd' * 64,
          conversationId: id,
          senderPubkey: peer,
          content: 'Other account copy',
          createdAt: 100,
          giftWrapId: 'e' * 64,
          ownerPubkey: peer,
        );
        await replay();
        await dismiss();
        await switchAway();
        await message('d' * 64);
        await replay();
        expect(await isDismissed(), isFalse);
      },
    );

    for (final timestamp in [100, 200, 201]) {
      test(
        'read cursor beyond dismissal classifies recovered '
        'timestamp $timestamp',
        () async {
          await message('d' * 64);
          await replay();
          await dismiss();
          // A self-addressed read marker can arrive before the rest of history.
          await database.conversationsDao.applyReadCursor(
            id,
            200,
            ownerPubkey: owner,
          );
          final before = (await database.conversationsDao.getConversation(
            id,
            ownerPubkey: owner,
          ))!;
          expect(before.lastReadTimestamp, 200);
          expect(before.isDismissed, isTrue);
          await message('e' * 64, timestamp: timestamp);
          await replay(timestamp: timestamp);
          final restored = (await database.conversationsDao.getConversation(
            id,
            ownerPubkey: owner,
          ))!;
          expect(restored.isDismissed, isFalse);
          expect(restored.lastReadTimestamp, 200);
          expect(restored.isRead, timestamp <= 200);
        },
      );
    }

    test('metadata-only refresh classifies stored incoming arrivals', () async {
      await message('d' * 64);
      await replay();
      await dismiss();
      await database.conversationsDao.applyReadCursor(
        id,
        200,
        ownerPubkey: owner,
      );
      await message('e' * 64, timestamp: 200);
      await database.conversationsDao.upsertConversation(
        id: id,
        participantPubkeys: '["$owner","$peer"]',
        isGroup: false,
        createdAt: 100,
        ownerPubkey: owner,
      );
      final row = (await database.conversationsDao.getConversation(
        id,
        ownerPubkey: owner,
      ))!;
      expect(row.isDismissed, isFalse);
      expect(row.isRead, isTrue);
      expect(row.lastReadTimestamp, 200);
    });

    test('explicit Restore removes the retained marker', () async {
      await replay();
      await dismiss();
      await database.conversationsDao.setDismissed(
        id,
        ownerPubkey: owner,
        dismissed: false,
      );
      await switchAway();
      await replay();
      expect(await isDismissed(), isFalse);
    });

    test(
      'account data deletion clears only that account’s retained state',
      () async {
        await replay();
        await dismiss();
        await replay(account: peer);
        expect(await isDismissed(account: peer), isFalse);
        await database.conversationsDao.setDismissed(
          id,
          ownerPubkey: peer,
          dismissed: true,
        );
        await switchAway();
        await database.conversationsDao.clearDismissalsForOwner(owner);
        await replay();
        expect(await isDismissed(), isFalse);
        expect(await isDismissed(account: peer), isTrue);
      },
    );
  });
}
