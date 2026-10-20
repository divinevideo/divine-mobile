// ABOUTME: Regression coverage for #8187 — an uninitialized DmRepository must
// ABOUTME: not read or write another account's DM rows, which the DAOs happily
// ABOUTME: serve when handed a null owner.

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';

class _MockNostrClient extends Mock implements NostrClient {}

const _ownerA =
    'a4f5c1b2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8';
const _ownerB =
    'b1c2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8f9a0';
const _peer =
    'c2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8f9a0b1';

const _createdAt = 1700000000;

void main() {
  // Deliberately exercises the real DAOs against a real database. The
  // mock-based suite in dm_repository_test.dart stubs these methods with
  // `ownerPubkey: any(named: 'ownerPubkey')`, which matches null too — so a
  // test written there can prove the guard was reached but never that an
  // unguarded read would actually cross accounts.
  group('owner-scope boundary with two accounts on one device', () {
    late AppDatabase db;
    late ConversationsDao conversationsDao;
    late DirectMessagesDao messagesDao;
    late String conversationId;

    setUp(() async {
      db = AppDatabase.test(NativeDatabase.memory());
      conversationsDao = ConversationsDao(db);
      messagesDao = DirectMessagesDao(db);
      conversationId = DmRepository.computeConversationId([_ownerA, _peer]);

      // Seed A's conversation view. The composite (id, ownerPubkey) key also
      // permits a legacy view of that same conversation on the device.
      await conversationsDao.upsertConversation(
        id: conversationId,
        participantPubkeys: '["$_ownerA","$_peer"]',
        isGroup: false,
        createdAt: _createdAt,
        isRead: false,
        ownerPubkey: _ownerA,
      );

      for (final owner in [_ownerA, _ownerB]) {
        await messagesDao.insertMessage(
          id: 'rumor-for-$owner',
          conversationId: conversationId,
          senderPubkey: _peer,
          content: 'private to $owner',
          createdAt: _createdAt,
          giftWrapId: 'wrap-for-$owner',
          ownerPubkey: owner,
        );
      }
    });

    tearDown(() async {
      await db.close();
    });

    DmRepository buildRepository({required String userPubkey}) => DmRepository(
      nostrClient: _MockNostrClient(),
      directMessagesDao: messagesDao,
      conversationsDao: conversationsDao,
      userPubkey: userPubkey,
    );

    test('a null owner really does read across accounts at the DAO', () async {
      // The hazard the guards exist for. If this ever stops returning both
      // rows the DAO contract changed, and the repository-level tests below
      // would start passing for a reason that has nothing to do with #8187.
      final unscoped = await messagesDao.getMessagesForConversation(
        conversationId,
      );

      expect(unscoped, hasLength(2));
      expect(
        unscoped.map((row) => row.ownerPubkey),
        containsAll(<String>[_ownerA, _ownerB]),
      );
    });

    test('an initialized repository reads only its own rows', () async {
      final repository = buildRepository(userPubkey: _ownerA);

      final messages = await repository.getMessages(conversationId);

      expect(messages, hasLength(1));
      expect(messages.single.content, equals('private to $_ownerA'));
      expect(await repository.countMessagesInConversation(conversationId), 1);
    });

    test('an uninitialized repository reads nothing, not everything', () async {
      final repository = buildRepository(userPubkey: '');

      expect(await repository.watchConversations().first, isEmpty);
      expect(await repository.getConversations(), isEmpty);
      expect(await repository.watchAcceptedConversations().first, isEmpty);
      expect(await repository.watchPotentialRequests().first, isEmpty);
      expect(await repository.watchUnreadCount().first, 0);
      expect(await repository.watchUnreadAcceptedCount().first, 0);
      expect(await repository.getMessages(conversationId), isEmpty);
      expect(await repository.countMessagesInConversation(conversationId), 0);
      expect(await repository.watchMessages(conversationId).first, isEmpty);
      expect(await repository.getConversation(conversationId), isNull);
    });

    test(
      'dismissal keeps messages and acceptance state and restores',
      () async {
        final repository = buildRepository(userPubkey: _ownerA);
        addTearDown(repository.stopListening);
        await repository.setConversationDismissed(
          conversationId,
          dismissed: true,
        );
        final dismissed = (await repository.getConversation(conversationId))!;
        expect(dismissed.isDismissed, isTrue);
        expect(dismissed.isRead, isTrue);
        expect(dismissed.currentUserHasSent, isFalse);
        expect(await repository.getMessages(conversationId), hasLength(1));
        await repository.setConversationDismissed(
          conversationId,
          dismissed: false,
        );
        expect(
          (await repository.getConversation(conversationId))!.isDismissed,
          isFalse,
        );
        expect(await repository.getMessages(conversationId), hasLength(1));
      },
    );

    test(
      'an unknown owner cannot dismiss another account conversation',
      () async {
        final repository = buildRepository(userPubkey: '');
        addTearDown(repository.stopListening);
        await expectLater(
          repository.setConversationDismissed(conversationId, dismissed: true),
          throwsStateError,
        );
        final row = (await conversationsDao.getConversation(
          conversationId,
          ownerPubkey: _ownerA,
        ))!;
        expect(row.isDismissed, isFalse);
        expect(row.isRead, isFalse);
      },
    );

    group('read-marking outcomes', () {
      test('reports an existing row and repeated reads as success', () async {
        final repository = buildRepository(userPubkey: _ownerA);
        expect(await repository.markConversationAsRead(conversationId), isTrue);
        expect(await repository.markConversationAsRead(conversationId), isTrue);
        final row = await conversationsDao.getConversation(conversationId);
        expect(row!.isRead, isTrue);
      });

      test('reports missing and other-account rows as unavailable', () async {
        final repository = buildRepository(userPubkey: _ownerB);
        expect(
          await repository.markConversationAsRead(conversationId),
          isFalse,
        );
        expect(await repository.markConversationAsRead('missing'), isFalse);
        expect(
          await repository.markConversationsAsRead([conversationId]),
          isFalse,
        );
        final row = await conversationsDao.getConversation(conversationId);
        expect(row!.isRead, isFalse);
      });

      for (final includeMissing in [false, true]) {
        test('batch counts a legacy and owned copy once '
            '(missing: $includeMissing)', () async {
          await conversationsDao.upsertConversation(
            id: conversationId,
            participantPubkeys: '["$_ownerA","$_peer"]',
            isGroup: false,
            createdAt: _createdAt,
            isRead: false,
          );
          final repository = buildRepository(userPubkey: _ownerA);
          addTearDown(repository.stopListening);

          expect(
            await repository.markConversationsAsRead([
              conversationId,
              if (includeMissing) 'missing',
            ]),
            !includeMissing,
          );
          expect(
            (await repository.getConversation(conversationId))!.isRead,
            isTrue,
          );
        });
      }

      test('batch reports partial writes and accepts repeated ids', () async {
        final repository = buildRepository(userPubkey: _ownerA);
        expect(
          await repository.markConversationsAsRead([conversationId, 'missing']),
          isFalse,
        );
        expect(
          (await conversationsDao.getConversation(conversationId))!.isRead,
          isTrue,
        );
        expect(
          await repository.markConversationsAsRead([
            conversationId,
            conversationId,
          ]),
          isTrue,
        );
        expect(await repository.markConversationsAsRead(['missing']), isFalse);
        expect(await repository.markConversationsAsRead([]), isTrue);
      });
    });

    test('an uninitialized repository marks nobody read', () async {
      // `ConversationsDao.markAsRead` drops its owner clause entirely for a
      // null owner, leaving `UPDATE conversations SET is_read = 1 WHERE
      // id = ?` — which would advance A's cursor on behalf of a caller that
      // cannot name an owner at all.
      final repository = buildRepository(userPubkey: '');

      expect(await repository.markConversationAsRead(conversationId), isFalse);
      expect(
        await repository.markConversationsAsRead([conversationId]),
        isFalse,
      );

      final row = await conversationsDao.getConversation(
        conversationId,
        ownerPubkey: _ownerA,
      );
      expect(row, isNotNull);
      expect(row!.isRead, isFalse);
    });

    test('an uninitialized repository removes nobody', () async {
      final repository = buildRepository(userPubkey: '');

      await expectLater(
        repository.removeConversation(conversationId),
        throwsStateError,
      );
      await expectLater(
        repository.removeConversations([conversationId]),
        throwsStateError,
      );

      final conversation = await conversationsDao.getConversation(
        conversationId,
        ownerPubkey: _ownerA,
      );
      final messages = await messagesDao.getMessagesForConversation(
        conversationId,
      );
      expect(conversation, isNotNull);
      expect(messages, hasLength(2));
    });
  });
}
