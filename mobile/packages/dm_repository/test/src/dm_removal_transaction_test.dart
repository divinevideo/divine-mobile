// ABOUTME: Regression coverage for #8408 — removing conversations writes the
// ABOUTME: tombstone and drops messages, rows and queues in one transaction.

import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';

import 'support/transaction_probe.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockReactionsRepository extends Mock implements DmReactionsRepository {}

const _owner =
    'a4f5c1b2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8';
const _peerA =
    'b1c2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8f9a0';
const _peerB =
    'c2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8f9a0b1';
const _messageWithA =
    'd1c2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8f9a2';
const _wrapWithA =
    'e1c2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8f9a3';
const _messageWithB =
    'd2c2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8f9a4';
const _wrapWithB =
    'e2c2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8f9a5';
const _privateKey =
    '5426e5b8b4b0e2a1f5e8d3c7a9b2f4e6d8c0a2b4f6e8d0c2a4b6f8e0d2c4a6b8';

void main() {
  // Real DAOs on a real database: the reactions-queue delete is the last
  // write each removal makes, so a throw from it must take every earlier
  // write back with it. The mock suite only checks that the transaction is
  // called (#8408).
  group('the removal transaction', () {
    final withA = DmRepository.computeConversationId([_owner, _peerA]..sort());
    final withB = DmRepository.computeConversationId([_owner, _peerB]..sort());

    late AppDatabase db;
    late TransactionProbe probe;
    late ProbedConversationsDao conversations;
    late ProbedDirectMessagesDao messages;
    late ProbedRemovedConversationsDao removed;
    late _MockReactionsRepository reactions;
    late DmRepository repository;

    setUp(() async {
      db = AppDatabase.test(NativeDatabase.memory());
      probe = TransactionProbe();
      conversations = ProbedConversationsDao(db, probe);
      messages = ProbedDirectMessagesDao(db, probe);
      removed = ProbedRemovedConversationsDao(db, probe);
      reactions = _MockReactionsRepository();
      when(
        () => reactions.deleteForConversations(
          any(),
          ownerPubkey: any(named: 'ownerPubkey'),
        ),
      ).thenAnswer((_) async => probe.record('reactions'));
      // Removal waits for the sign-in maintenance, which also asks the
      // reactions repository to tidy its queue; nothing is left to tidy.
      when(
        () => reactions.purgeStrandedByRemoval(
          ownerPubkey: any(named: 'ownerPubkey'),
        ),
      ).thenAnswer((_) async => 0);
      when(
        () => reactions.backfillQueuedRecipients(
          ownerPubkey: any(named: 'ownerPubkey'),
        ),
      ).thenAnswer((_) async => 0);

      repository = DmRepository(
        nostrClient: _MockNostrClient(),
        directMessagesDao: messages,
        conversationsDao: conversations,
        outgoingDmsDao: ProbedOutgoingDmsDao(db, probe),
        removedConversationsDao: removed,
        reactionsRepository: reactions,
        userPubkey: _owner,
        signer: LocalNostrSigner(_privateKey),
      );

      for (final (id, peer, messageId, wrapId) in [
        (withA, _peerA, _messageWithA, _wrapWithA),
        (withB, _peerB, _messageWithB, _wrapWithB),
      ]) {
        await conversations.upsertConversation(
          id: id,
          participantPubkeys: jsonEncode([_owner, peer]..sort()),
          isGroup: false,
          createdAt: 1700000000,
          ownerPubkey: _owner,
        );
        await messages.insertMessage(
          id: messageId,
          conversationId: id,
          senderPubkey: peer,
          content: 'hello',
          createdAt: 1700000000,
          giftWrapId: wrapId,
          ownerPubkey: _owner,
        );
      }
      probe.reset();
    });

    tearDown(() async {
      await repository.stopListening();
      await db.close();
    });

    Future<bool> intact(String id) async =>
        await conversations.getConversation(id, ownerPubkey: _owner) != null &&
        (await messages.getMessagesForConversation(
          id,
          ownerPubkey: _owner,
        )).isNotEmpty &&
        await removed.removedAtFor(conversationId: id, ownerPubkey: _owner) ==
            null;

    group('removeConversation', () {
      test('writes the tombstone and drops everything inside it', () async {
        expect(
          await repository.removeConversation(withA),
          ConversationRemovalOutcome.removed,
        );

        expect(probe.ranOnlyInside('record'), isTrue);
        expect(probe.ranOnlyInside('deleteConversationMessages'), isTrue);
        expect(probe.ranOnlyInside('deleteConversation'), isTrue);
        expect(probe.ranOnlyInside('deleteForConversation'), isTrue);
        expect(probe.ranOnlyInside('reactions'), isTrue);
      });

      test('leaves the conversation whole when the last write fails', () async {
        probe.failOn('reactions');

        await expectLater(
          repository.removeConversation(withA),
          throwsStateError,
        );

        // Without the transaction the thread would be gone while its queued
        // reactions survived to be sent into it (#7857).
        expect(await intact(withA), isTrue);
      });
    });

    group('removeConversations', () {
      test('writes the tombstones and drops everything inside it', () async {
        final outcome = await repository.removeConversations([withA, withB]);

        expect(outcome.removed, 2);
        expect(probe.ranOnlyInside('recordAll'), isTrue);
        expect(
          probe.ranOnlyInside('deleteMultipleConversationMessages'),
          isTrue,
        );
        expect(probe.ranOnlyInside('deleteMultiple'), isTrue);
        expect(probe.ranOnlyInside('deleteForConversations'), isTrue);
        expect(probe.ranOnlyInside('reactions'), isTrue);
      });

      test(
        'leaves every conversation whole when the last write fails',
        () async {
          probe.failOn('reactions');

          await expectLater(
            repository.removeConversations([withA, withB]),
            throwsStateError,
          );

          expect(await intact(withA), isTrue);
          expect(await intact(withB), isTrue);
        },
      );
    });
  });
}
