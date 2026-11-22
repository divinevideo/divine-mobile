// ABOUTME: Regression coverage for #8408 — each send path stores its message,
// ABOUTME: conversation, read flip and queue transition in one transaction.

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart' as nostr_filter;
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';

import 'support/transaction_probe.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _FakeEvent extends Fake implements Event {}

// Real curve keys: the real message service encrypts every wrap.
const _ownerKey =
    '5426e5b8b4b0e2a1f5e8d3c7a9b2f4e6d8c0a2b4f6e8d0c2a4b6f8e0d2c4a6b8';
const _peerBKey =
    '6a1f2e3d4c5b6a7980f1e2d3c4b5a69788f9e0d1c2b3a4958677f8e9d0c1b2a3';
const _peerCKey =
    '7b2e3f4a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8f9a0b1c2d3e4f5a6';

const _poolRelay = 'wss://relay.divine.video';

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeEvent());
    registerFallbackValue(Duration.zero);
    registerFallbackValue(<nostr_filter.Filter>[]);
  });

  // Real DAOs on a real database, so a failure the probe injects rolls back
  // through drift's own transaction. The mock suite runs every transaction
  // inline, which no test there can tell from having none (#8408).
  group('the send persist transaction', () {
    final owner = getPublicKey(_ownerKey);
    final peerB = getPublicKey(_peerBKey);
    final peerC = getPublicKey(_peerCKey);
    final pairId = DmRepository.computeConversationId([owner, peerB]..sort());
    final groupId = DmRepository.computeConversationId(
      [owner, peerB, peerC]..sort(),
    );

    late AppDatabase db;
    late TransactionProbe probe;
    late ProbedConversationsDao conversations;
    late ProbedDirectMessagesDao messages;
    late ProbedOutgoingDmsDao outgoing;
    late _MockNostrClient nostrClient;
    late bool failPublishes;
    late DmRepository repository;

    setUp(() {
      db = AppDatabase.test(NativeDatabase.memory());
      probe = TransactionProbe();
      conversations = ProbedConversationsDao(db, probe);
      messages = ProbedDirectMessagesDao(db, probe);
      outgoing = ProbedOutgoingDmsDao(db, probe);
      nostrClient = _MockNostrClient();
      failPublishes = false;

      when(() => nostrClient.connectedRelayCount).thenReturn(1);
      when(() => nostrClient.configuredRelayCount).thenReturn(1);
      when(() => nostrClient.configuredRelays).thenReturn(const [_poolRelay]);
      when(() => nostrClient.isRelayAllowed(any())).thenReturn(true);
      // Every inbox lookup is answered, and finds no kind-10050 list.
      when(
        () => nostrClient.queryEventsDetailed(
          any(),
          subscriptionId: any(named: 'subscriptionId'),
          tempRelays: any(named: 'tempRelays'),
          relayTypes: any(named: 'relayTypes'),
          sendAfterAuth: any(named: 'sendAfterAuth'),
          useCache: any(named: 'useCache'),
          useQueryPool: any(named: 'useQueryPool'),
          timeout: any(named: 'timeout'),
          requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          acceptRelayClosedWhenOthersAnswered: any(
            named: 'acceptRelayClosedWhenOthersAnswered',
          ),
          silentRelayTimeout: any(named: 'silentRelayTimeout'),
        ),
      ).thenAnswer(
        (_) async =>
            (events: const <Event>[], timedOut: false, noRelays: false),
      );
      when(
        () => nostrClient.publishEventAwaitOk(
          any(),
          targetRelays: any(named: 'targetRelays'),
          timeout: any(named: 'timeout'),
          diagnosticTag: any(named: 'diagnosticTag'),
        ),
      ).thenAnswer((invocation) async {
        final event = invocation.positionalArguments.first as Event;
        return PublishOutcome(
          eventId: event.id,
          acceptedBy: failPublishes ? const [] : const [_poolRelay],
          rejectedBy: failPublishes
              ? const {_poolRelay: 'error: temporarily unavailable'}
              : const {},
          noResponseFrom: const [],
        );
      });
      when(
        () => nostrClient.publishEvent(
          any(),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).thenAnswer(
        (invocation) async => PublishSuccess(
          event: invocation.positionalArguments.first as Event,
        ),
      );

      final signer = LocalNostrSigner(_ownerKey);
      repository = DmRepository(
        nostrClient: nostrClient,
        messageService: NIP17MessageService(
          signer: signer,
          senderPublicKey: owner,
          nostrService: nostrClient,
        ),
        directMessagesDao: messages,
        conversationsDao: conversations,
        outgoingDmsDao: outgoing,
        userPubkey: owner,
        signer: signer,
      );
    });

    tearDown(() async {
      await repository.stopListening();
      await db.close();
    });

    Future<List<String>> storedIds(String conversationId) async => [
      for (final row in await messages.getMessagesForConversation(
        conversationId,
        ownerPubkey: owner,
      ))
        row.id,
    ];

    Future<ConversationRow?> conversation(String id) =>
        conversations.getConversation(id, ownerPubkey: owner);

    group('sending one-to-one', () {
      test('stores message, conversation, read flip and queue in it', () async {
        final result = await repository.sendMessage(
          recipientPubkey: peerB,
          content: 'hello',
        );

        expect(result.success, isTrue);
        expect(await storedIds(pairId), [result.rumorEventId]);
        expect(probe.ranOnlyInside('insertMessage'), isTrue);
        expect(probe.ranOnlyInside('upsertConversation'), isTrue);
        expect(probe.ranOnlyInside('markAsRead'), isTrue);
        expect(probe.ranOnlyInside('deleteById'), isTrue);
      });

      test('rolls all of it back when the queue transition fails', () async {
        probe.failOn('deleteById');

        final result = await repository.sendMessage(
          recipientPubkey: peerB,
          content: 'hello',
        );

        // The publish succeeded; only the local persist failed. Without the
        // transaction the message would be stored while its queue row still
        // read pending, and the sweep would replay a message already shown.
        expect(result.success, isTrue);
        expect(await storedIds(pairId), isEmpty);
        expect(await conversation(pairId), isNull);
        final row = await outgoing.getById(result.rumorEventId!);
        expect(row?.recipientWrapStatus, OutgoingWrapStatus.pending);
      });
    });

    group('surfacing a conversation after a refused send', () {
      test('creates it and flips it read in it', () async {
        failPublishes = true;

        final result = await repository.sendMessage(
          recipientPubkey: peerB,
          content: 'offline',
        );

        expect(result.success, isFalse);
        expect(await conversation(pairId), isNotNull);
        expect(probe.ranOnlyInside('upsertConversation'), isTrue);
        expect(probe.ranOnlyInside('markAsRead'), isTrue);
      });

      test('leaves no half-made conversation when the flip fails', () async {
        failPublishes = true;
        probe.failOn('markAsRead');

        final result = await repository.sendMessage(
          recipientPubkey: peerB,
          content: 'offline',
        );

        expect(result.success, isFalse);
        expect(probe.inside['upsertConversation'], 1);
        expect(await conversation(pairId), isNull);
      });
    });

    group('recovering a queued send', () {
      Future<String> queueRefusedSend() async {
        failPublishes = true;
        final result = await repository.sendMessage(
          recipientPubkey: peerB,
          content: 'retry me',
        );
        failPublishes = false;
        expect(result.success, isFalse);
        final rumorId = result.queuedRumorId!;
        expect(
          (await outgoing.getById(rumorId))?.recipientWrapStatus,
          OutgoingWrapStatus.failed,
        );
        probe.reset();
        return rumorId;
      }

      test('stores replay, conversation, read flip and queue in it', () async {
        final rumorId = await queueRefusedSend();

        final replay = await repository.recoverFullSend(rumorId: rumorId);

        expect(replay.success, isTrue);
        expect(await storedIds(pairId), [rumorId]);
        expect(probe.ranOnlyInside('insertMessage'), isTrue);
        expect(probe.ranOnlyInside('upsertConversation'), isTrue);
        expect(probe.ranOnlyInside('markAsRead'), isTrue);
        expect(probe.ranOnlyInside('deleteById'), isTrue);
      });

      test('rolls the replay back and keeps the queue row as it was', () async {
        final rumorId = await queueRefusedSend();
        probe.failOn('deleteById');

        final replay = await repository.recoverFullSend(rumorId: rumorId);

        expect(replay.success, isTrue, reason: 'the replay was published');
        expect(await storedIds(pairId), isEmpty);
        expect(
          (await outgoing.getById(rumorId))?.recipientWrapStatus,
          OutgoingWrapStatus.failed,
        );
      });

      test('spends retry budget on a replay it could not store', () async {
        final rumorId = await queueRefusedSend();
        final budgetBefore = (await outgoing.getById(rumorId))!.retryCount;
        probe.failOn('deleteById');

        final replay = await repository.recoverFullSend(rumorId: rumorId);

        expect(replay.success, isTrue, reason: 'the replay was published');
        // The rollback leaves the row for the sweep to re-drive. Unless the
        // attempt spends budget, a persist failure that keeps recurring has
        // the sweep republish the message on every pass, for ever.
        expect(
          (await outgoing.getById(rumorId))?.retryCount,
          budgetBefore + 1,
        );
      });
    });

    group('sending to a group', () {
      test(
        'stores message, conversation, read flip and queues in it',
        () async {
          final results = await repository.sendGroupMessage(
            recipientPubkeys: [peerB, peerC],
            content: 'hi both',
          );

          expect(results.map((result) => result.success), [true, true]);
          expect(await storedIds(groupId), hasLength(1));
          expect(probe.ranOnlyInside('insertMessage'), isTrue);
          expect(probe.ranOnlyInside('upsertConversation'), isTrue);
          expect(probe.ranOnlyInside('markAsRead'), isTrue);
          expect(probe.inside['deleteById'], 2);
          expect(probe.ranOnlyInside('deleteById'), isTrue);
        },
      );

      test('rolls back a finalized sibling with a failed one', () async {
        probe.failOn('deleteById', skip: 1);

        await expectLater(
          repository.sendGroupMessage(
            recipientPubkeys: [peerB, peerC],
            content: 'hi both',
          ),
          throwsStateError,
        );

        expect(await storedIds(groupId), isEmpty);
        expect(await conversation(groupId), isNull);
        final rows = await outgoing.getForConversation(
          conversationId: groupId,
          ownerPubkey: owner,
        );
        expect(
          rows.map((row) => row.recipientWrapStatus),
          [OutgoingWrapStatus.pending, OutgoingWrapStatus.pending],
        );
      });
    });

    group('sending a file', () {
      const metadata = DmFileMetadata(
        fileType: 'image/jpeg',
        encryptionAlgorithm: 'aes-gcm',
        decryptionKey:
            'f1e2d3c4b5a69788f9e0d1c2b3a4958677f8e9d0c1b2a3f4e5d6c7b8a9f0e1d2',
        decryptionNonce: 'a1b2c3d4e5f60718293a4b5c',
        fileHash:
            '0f1e2d3c4b5a69788f9e0d1c2b3a4958677f8e9d0c1b2a3f4e5d6c7b8a9f0e1d',
      );
      const fileUrl = 'https://media.example.com/encrypted-file';

      test('stores message, conversation and read flip in it', () async {
        final result = await repository.sendFileMessage(
          recipientPubkey: peerB,
          fileUrl: fileUrl,
          fileMetadata: metadata,
        );

        expect(result.success, isTrue);
        expect(await storedIds(pairId), [result.rumorEventId]);
        expect(probe.ranOnlyInside('insertMessage'), isTrue);
        expect(probe.ranOnlyInside('upsertConversation'), isTrue);
        expect(probe.ranOnlyInside('markAsRead'), isTrue);
      });

      test('rolls the message back when the read flip fails', () async {
        probe.failOn('markAsRead');

        await expectLater(
          repository.sendFileMessage(
            recipientPubkey: peerB,
            fileUrl: fileUrl,
            fileMetadata: metadata,
          ),
          throwsStateError,
        );

        expect(await storedIds(pairId), isEmpty);
        expect(await conversation(pairId), isNull);
      });
    });
  });
}
