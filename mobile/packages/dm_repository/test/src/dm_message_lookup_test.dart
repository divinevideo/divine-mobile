// ABOUTME: Account-scoped inbound wrap routing from real SQLite evidence.
import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';

class _Nostr extends Mock implements NostrClient {}

void main() {
  late AppDatabase db;
  late DmRepository repo;
  var hidden = <String>{};
  var followed = <String>{};
  setUp(() {
    db = AppDatabase.test(NativeDatabase.memory());
    hidden = {};
    followed = {};
    repo = DmRepository(
      nostrClient: _Nostr(),
      userPubkey: 'owner',
      directMessagesDao: db.directMessagesDao,
      conversationsDao: db.conversationsDao,
      processedGiftWrapsDao: db.processedGiftWrapsDao,
      watchWrapAudience: (_) => Stream.value((
        hidden: hidden,
        followed: followed,
        supportPubkey: 'support',
      )),
    );
  });
  tearDown(() => db.close());
  Future<DmWrapLookup> lookup(String wrap, {String owner = 'owner'}) =>
      repo.watchWrapLookup(ownerPubkey: owner, giftWrapId: wrap).first;
  Future<void> message({
    String sender = 'peer',
    String wrap = 'original',
  }) async {
    await db.directMessagesDao.insertMessage(
      id: 'rumor',
      ownerPubkey: 'owner',
      senderPubkey: sender,
      conversationId: 'room',
      giftWrapId: wrap,
      content: 'sample',
      createdAt: 100,
    );
    await db.conversationsDao.upsertConversation(
      id: 'room',
      participantPubkeys: '["owner","peer"]',
      createdAt: 100,
      isGroup: false,
      ownerPubkey: 'owner',
    );
  }

  test(
    'only an exact inbound alias yields the live request or conversation',
    () async {
      await message();
      Future<void> duplicate(String wrap, String sender) =>
          db.processedGiftWrapsDao.record(
            giftWrapId: wrap,
            ownerPubkey: 'owner',
            verifiedDuplicate: (
              messageId: 'rumor',
              conversationId: 'room',
              sender: sender,
            ),
          );
      await duplicate('alias', 'peer');
      await duplicate('mismatch', 'other');
      expect(await lookup('mismatch'), isA<DmWrapSuppressed>());
      final request = await lookup('alias') as DmWrapFound;
      expect(
        (request.messageId, request.conversationId, request.isRequest),
        ('rumor', 'room', true),
      );
      followed = {'peer'};
      expect((await lookup('alias') as DmWrapFound).isRequest, isFalse);
      hidden = {'peer'};
      expect(await lookup('alias'), isA<DmWrapSuppressed>());
      expect(await lookup('alias', owner: 'other'), isA<DmWrapSuppressed>());
      hidden = {};
      await db.directMessagesDao.markMessageDeleted(
        'rumor',
        ownerPubkey: 'owner',
      );
      expect(await lookup('original'), isA<DmWrapDeleted>());
      await db.delete(db.directMessages).go();
      expect(await lookup('alias'), isA<DmWrapDeleted>());
    },
  );
  test(
    'self copies, removed rows, and terminal outcomes never navigate',
    () async {
      await message(sender: 'owner');
      expect(await lookup('original'), isA<DmWrapNotInbound>());
      await db.customStatement(
        "UPDATE direct_messages SET sender_pubkey = 'peer'",
      );
      await db.removedConversationsDao.record(
        conversationId: 'room',
        ownerPubkey: 'owner',
        removedAt: 100,
      );
      expect(await lookup('original'), isA<DmWrapSuppressed>());
      for (final wrap in ['reaction', 'deletion']) {
        await db.processedGiftWrapsDao.record(
          giftWrapId: wrap,
          ownerPubkey: 'owner',
        );
        expect(await lookup(wrap), isA<DmWrapSuppressed>());
      }
      expect(await lookup('unknown'), isA<DmWrapPending>());
    },
  );
}
