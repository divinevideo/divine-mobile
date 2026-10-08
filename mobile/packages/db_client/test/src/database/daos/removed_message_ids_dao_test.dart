// ABOUTME: Tests the owner-scoped record of message and reaction ids removed
// ABOUTME: with their conversation. A kind-5 naming such an id has nothing left
// ABOUTME: to apply, so the wrap that carries it can be recorded as handled.

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const conversationA =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const conversationB =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  const ownerA =
      'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
  const ownerB =
      'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
  const peer =
      'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';

  String rumorId(String digit) => digit * 64;

  late AppDatabase database;
  late RemovedMessageIdsDao dao;

  setUp(() {
    database = AppDatabase.test(NativeDatabase.memory());
    dao = database.removedMessageIdsDao;
  });

  tearDown(() => database.close());

  Future<void> insertMessage({
    required String id,
    required String conversationId,
    required String owner,
  }) async {
    final inserted = await database.directMessagesDao.insertMessage(
      id: id,
      conversationId: conversationId,
      senderPubkey: peer,
      content: 'message $id',
      createdAt: 1700000000,
      giftWrapId: 'wrap-$id',
      ownerPubkey: owner,
    );
    expect(inserted, isTrue, reason: 'the fixture row must really exist');
  }

  Future<void> insertReaction({
    required String id,
    required String conversationId,
    required String owner,
  }) {
    return database.dmReactionsDao.upsertIncoming(
      id: id,
      conversationId: conversationId,
      targetMessageId: rumorId('9'),
      targetMessageAuthor: peer,
      reactorPubkey: peer,
      emoji: '🔥',
      createdAt: 1700000000,
      giftWrapId: 'reaction-wrap-$id',
      ownerPubkey: owner,
    );
  }

  group(RemovedMessageIdsDao, () {
    group('captureForConversations', () {
      test(
        'captures the id of every message and every reaction in the '
        'conversation',
        () async {
          await insertMessage(
            id: rumorId('1'),
            conversationId: conversationA,
            owner: ownerA,
          );
          await insertMessage(
            id: rumorId('2'),
            conversationId: conversationA,
            owner: ownerA,
          );
          await insertReaction(
            id: rumorId('3'),
            conversationId: conversationA,
            owner: ownerA,
          );

          await dao.captureForConversations(
            conversationIds: [conversationA],
            ownerPubkey: ownerA,
            removedAt: 100,
          );

          for (final id in [rumorId('1'), rumorId('2'), rumorId('3')]) {
            expect(
              await dao.contains(rumorId: id, ownerPubkey: ownerA),
              isTrue,
              reason: '$id was in the removed conversation',
            );
          }
        },
      );

      test('leaves the ids of other conversations uncaptured', () async {
        await insertMessage(
          id: rumorId('1'),
          conversationId: conversationA,
          owner: ownerA,
        );
        await insertMessage(
          id: rumorId('2'),
          conversationId: conversationB,
          owner: ownerA,
        );
        await insertReaction(
          id: rumorId('3'),
          conversationId: conversationB,
          owner: ownerA,
        );

        await dao.captureForConversations(
          conversationIds: [conversationA],
          ownerPubkey: ownerA,
          removedAt: 100,
        );

        expect(
          await dao.contains(rumorId: rumorId('2'), ownerPubkey: ownerA),
          isFalse,
        );
        expect(
          await dao.contains(rumorId: rumorId('3'), ownerPubkey: ownerA),
          isFalse,
        );
      });

      test('captures a message that was already soft-deleted', () async {
        // A deleted row is kept as dedup evidence, and a second kind-5 naming
        // it can still arrive, so it has to be in the set too.
        await insertMessage(
          id: rumorId('1'),
          conversationId: conversationA,
          owner: ownerA,
        );
        await database.directMessagesDao.markMessageDeleted(
          rumorId('1'),
          ownerPubkey: ownerA,
        );

        await dao.captureForConversations(
          conversationIds: [conversationA],
          ownerPubkey: ownerA,
          removedAt: 100,
        );

        expect(
          await dao.contains(rumorId: rumorId('1'), ownerPubkey: ownerA),
          isTrue,
        );
      });

      test('captures several conversations in one call', () async {
        await insertMessage(
          id: rumorId('1'),
          conversationId: conversationA,
          owner: ownerA,
        );
        await insertMessage(
          id: rumorId('2'),
          conversationId: conversationB,
          owner: ownerA,
        );

        await dao.captureForConversations(
          conversationIds: [conversationA, conversationB],
          ownerPubkey: ownerA,
          removedAt: 100,
        );

        expect(
          await dao.contains(rumorId: rumorId('1'), ownerPubkey: ownerA),
          isTrue,
        );
        expect(
          await dao.contains(rumorId: rumorId('2'), ownerPubkey: ownerA),
          isTrue,
        );
      });

      test(
        'captures only the given owner even when another account holds '
        'the same conversation id',
        () async {
          await insertMessage(
            id: rumorId('1'),
            conversationId: conversationA,
            owner: ownerA,
          );
          await insertMessage(
            id: rumorId('2'),
            conversationId: conversationA,
            owner: ownerB,
          );

          await dao.captureForConversations(
            conversationIds: [conversationA],
            ownerPubkey: ownerA,
            removedAt: 100,
          );

          expect(
            await dao.contains(rumorId: rumorId('1'), ownerPubkey: ownerA),
            isTrue,
          );
          expect(
            await dao.contains(rumorId: rumorId('2'), ownerPubkey: ownerA),
            isFalse,
            reason: "the other account's message is not this owner's to record",
          );
          expect(
            await dao.contains(rumorId: rumorId('1'), ownerPubkey: ownerB),
            isFalse,
            reason: 'a captured id must not be visible to another account',
          );
        },
      );

      test('captures a reaction only for the owner that holds it', () async {
        await insertReaction(
          id: rumorId('3'),
          conversationId: conversationA,
          owner: ownerA,
        );
        await insertReaction(
          id: rumorId('4'),
          conversationId: conversationA,
          owner: ownerB,
        );

        await dao.captureForConversations(
          conversationIds: [conversationA],
          ownerPubkey: ownerA,
          removedAt: 100,
        );

        expect(
          await dao.contains(rumorId: rumorId('3'), ownerPubkey: ownerA),
          isTrue,
        );
        expect(
          await dao.contains(rumorId: rumorId('4'), ownerPubkey: ownerA),
          isFalse,
          reason: "another account's reaction is not this owner's to record",
        );
      });

      test(
        'captures a legacy unowned message, because removal deletes it too',
        () async {
          // Rows written before multi-account carry no owner and are visible
          // to whichever account claims them. `deleteConversationMessages`
          // removes them for that account, so the capture has to as well or
          // a kind-5 naming one would still defer.
          final inserted = await database.directMessagesDao.insertMessage(
            id: rumorId('7'),
            conversationId: conversationA,
            senderPubkey: peer,
            content: 'legacy message',
            createdAt: 1700000000,
            giftWrapId: 'wrap-legacy',
          );
          expect(inserted, isTrue, reason: 'the fixture row must really exist');

          await dao.captureForConversations(
            conversationIds: [conversationA],
            ownerPubkey: ownerA,
            removedAt: 100,
          );

          expect(
            await dao.contains(rumorId: rumorId('7'), ownerPubkey: ownerA),
            isTrue,
          );
        },
      );

      test(
        'capturing the same conversation twice keeps the first time',
        () async {
          await insertMessage(
            id: rumorId('1'),
            conversationId: conversationA,
            owner: ownerA,
          );

          await dao.captureForConversations(
            conversationIds: [conversationA],
            ownerPubkey: ownerA,
            removedAt: 100,
          );
          await dao.captureForConversations(
            conversationIds: [conversationA],
            ownerPubkey: ownerA,
            removedAt: 200,
          );

          expect(
            await dao.contains(rumorId: rumorId('1'), ownerPubkey: ownerA),
            isTrue,
          );
          final stored = await database
              .customSelect(
                'SELECT removed_at FROM removed_message_ids WHERE rumor_id = ?',
                variables: [Variable.withString(rumorId('1'))],
              )
              .get();
          expect(stored, hasLength(1));
          expect(stored.single.read<int>('removed_at'), 100);
        },
      );

      test('capturing no conversations changes nothing', () async {
        await insertMessage(
          id: rumorId('1'),
          conversationId: conversationA,
          owner: ownerA,
        );

        await dao.captureForConversations(
          conversationIds: const [],
          ownerPubkey: ownerA,
          removedAt: 100,
        );

        expect(
          await dao.contains(rumorId: rumorId('1'), ownerPubkey: ownerA),
          isFalse,
        );
      });
    });

    group('contains', () {
      test('is false for an id that was never captured', () async {
        expect(
          await dao.contains(rumorId: rumorId('1'), ownerPubkey: ownerA),
          isFalse,
        );
      });
    });

    group('clearAllForUser', () {
      test('removes that owner only', () async {
        await insertMessage(
          id: rumorId('1'),
          conversationId: conversationA,
          owner: ownerA,
        );
        await insertMessage(
          id: rumorId('2'),
          conversationId: conversationA,
          owner: ownerB,
        );
        await dao.captureForConversations(
          conversationIds: [conversationA],
          ownerPubkey: ownerA,
          removedAt: 100,
        );
        await dao.captureForConversations(
          conversationIds: [conversationA],
          ownerPubkey: ownerB,
          removedAt: 100,
        );

        expect(await dao.clearAllForUser(ownerA), 1);

        expect(
          await dao.contains(rumorId: rumorId('1'), ownerPubkey: ownerA),
          isFalse,
        );
        expect(
          await dao.contains(rumorId: rumorId('2'), ownerPubkey: ownerB),
          isTrue,
          reason: 'clearing one account must not touch another',
        );
      });
    });
  });
}
