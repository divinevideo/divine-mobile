// ABOUTME: Regression coverage for #8408 — each post-sign-in cleanup pass
// ABOUTME: drops its rows in one transaction.

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

const _owner =
    'a4f5c1b2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8';
const _selfMessage =
    'd1c2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8f9a2';
const _selfWrap =
    'e1c2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8f9a3';
const _queuedA =
    'f1c2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8f9a4';
const _queuedB =
    'f2c2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8f9a5';
const _privateKey =
    '5426e5b8b4b0e2a1f5e8d3c7a9b2f4e6d8c0a2b4f6e8d0c2a4b6f8e0d2c4a6b8';

void main() {
  // Real DAOs on a real database. Both passes run once per sign-in, before
  // the first conversation read, and the mock suite never runs either one
  // against a real transaction (#8408).
  group('the post-sign-in cleanup transactions', () {
    final selfId = DmRepository.computeConversationId([_owner, _owner]);

    late AppDatabase db;
    late TransactionProbe probe;
    late ProbedConversationsDao conversations;
    late ProbedDirectMessagesDao messages;
    late ProbedOutgoingDmsDao outgoing;
    late DmRepository repository;

    setUp(() async {
      db = AppDatabase.test(NativeDatabase.memory());
      probe = TransactionProbe();
      conversations = ProbedConversationsDao(db, probe);
      messages = ProbedDirectMessagesDao(db, probe);
      outgoing = ProbedOutgoingDmsDao(db, probe);
      repository = DmRepository(
        nostrClient: _MockNostrClient(),
        directMessagesDao: messages,
        conversationsDao: conversations,
        outgoingDmsDao: outgoing,
        userPubkey: _owner,
        signer: LocalNostrSigner(_privateKey),
      );

      // A phantom self-conversation and two sends queued to their own
      // sender, as builds before #8351 and #8363 could leave behind.
      await conversations.upsertConversation(
        id: selfId,
        participantPubkeys: jsonEncode([_owner]),
        isGroup: false,
        createdAt: 1700000000,
        ownerPubkey: _owner,
      );
      await messages.insertMessage(
        id: _selfMessage,
        conversationId: selfId,
        senderPubkey: _owner,
        content: 'note to self',
        createdAt: 1700000000,
        giftWrapId: _selfWrap,
        ownerPubkey: _owner,
      );
      for (final id in [_queuedA, _queuedB]) {
        await outgoing.enqueue(
          OutgoingDm(
            id: id,
            conversationId: selfId,
            recipientPubkey: _owner,
            content: 'note to self',
            createdAt: 1700000000,
            rumorEventJson: '{}',
            recipientWrapStatus: OutgoingWrapStatus.failed,
            selfWrapStatus: OutgoingWrapStatus.failed,
            queuedAt: DateTime.utc(2026, 10),
            ownerPubkey: _owner,
          ),
        );
      }
      probe.reset();
    });

    tearDown(() async {
      await repository.stopListening();
      await db.close();
    });

    // Any conversation read waits for the passes to finish first.
    Future<void> runPasses() => repository.getConversation(selfId);

    Future<List<DirectMessageRow>> selfMessages() =>
        messages.getMessagesForConversation(selfId, ownerPubkey: _owner);

    group('removing phantom self-conversations', () {
      test('drops the messages and the row inside it', () async {
        await runPasses();

        expect(await selfMessages(), isEmpty);
        expect(probe.ranOnlyInside('deleteConversationMessages'), isTrue);
        expect(probe.ranOnlyInside('deleteConversation'), isTrue);
      });

      test('keeps the messages when dropping the row fails', () async {
        probe.failOn('deleteConversation');

        await runPasses();

        // The pass logs and retries on the next sign-in; until then the
        // conversation must not be left with its messages gone.
        expect(probe.inside['deleteConversationMessages'], 1);
        expect((await selfMessages()).map((row) => row.id), [_selfMessage]);
      });
    });

    group('removing self-addressed queued sends', () {
      test('drops every row inside it', () async {
        await runPasses();

        expect(await outgoing.getAllForOwner(_owner), isEmpty);
        expect(probe.inside['deleteById'], 2);
        expect(probe.ranOnlyInside('deleteById'), isTrue);
      });

      test('keeps every row when one removal fails', () async {
        probe.failOn('deleteById', skip: 1);

        await runPasses();

        expect(
          (await outgoing.getAllForOwner(_owner)).map((row) => row.id),
          unorderedEquals([_queuedA, _queuedB]),
        );
      });
    });
  });
}
