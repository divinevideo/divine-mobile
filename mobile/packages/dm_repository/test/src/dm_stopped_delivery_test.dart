// ABOUTME: A group message that reached some members and not others keeps a
// ABOUTME: record of the members whose delivery the sender stopped (#8180).

import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockMessageService extends Mock implements NIP17MessageService {}

class _FakeEvent extends Fake implements Event {}

const _owner =
    'a4f5c1b2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8';
const _memberA =
    'b1c2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8f9a0';
const _memberB =
    'c2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8f9a0b1';
const _memberC =
    'd3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8f9a0b1c2';
const _privateKey =
    '5426e5b8b4b0e2a1f5e8d3c7a9b2f4e6d8c0a2b4f6e8d0c2a4b6f8e0d2c4a6b8';

String _hex(int n) => n.toRadixString(16).padLeft(64, '0');

/// What the relay side answers for one wrap.
typedef _WrapOutcome =
    Future<NIP17SendResult> Function(
      Event rumor,
      String recipient,
    );

void main() {
  // Real DAOs against a real database: the rule under test is which queue
  // rows survive a cancel, and a mocked DAO would answer that with whatever
  // the test typed.
  group('a delivery the sender stopped', () {
    late AppDatabase db;
    late DirectMessagesDao messagesDao;
    late ConversationsDao conversationsDao;
    late OutgoingDmsDao outgoingDao;
    late _MockNostrClient nostrClient;
    late _MockMessageService messageService;
    late DmRepository repository;

    late _WrapOutcome messageWrap;
    late _WrapOutcome deletionWrap;

    /// Every wrap the repository asked the wire to carry, in order.
    late List<String> wire;
    var wrapCounter = 0;

    Future<NIP17SendResult> delivered(
      Event rumor,
      String recipient, {
      bool selfWrap = true,
    }) async => NIP17SendResult.success(
      rumorEventId: rumor.id,
      messageEventId: _hex(++wrapCounter),
      recipientPubkey: recipient,
      selfWrapPublished: selfWrap,
    );

    Future<NIP17SendResult> refusedByRelay(
      Event rumor,
      String recipient,
    ) async => const NIP17SendResult.failure('relay refused the wrap');

    setUpAll(() {
      registerFallbackValue(_FakeEvent());
      // queryEventsDetailed takes a `Duration timeout`.
      registerFallbackValue(Duration.zero);
    });

    setUp(() {
      db = AppDatabase.test(NativeDatabase.memory());
      messagesDao = DirectMessagesDao(db);
      conversationsDao = ConversationsDao(db);
      outgoingDao = db.outgoingDmsDao;
      nostrClient = _MockNostrClient();
      messageService = _MockMessageService();
      wire = <String>[];
      messageWrap = delivered;
      deletionWrap = delivered;

      // The relays answer and nobody advertises a kind 10050, so a wrap the
      // default pool confirms is scored delivered rather than held (#7317).
      when(
        () => nostrClient.queryEventsDetailed(
          any(),
          subscriptionId: any(named: 'subscriptionId'),
          useCache: any(named: 'useCache'),
          tempRelays: any(named: 'tempRelays'),
          requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          acceptRelayClosedWhenOthersAnswered: any(
            named: 'acceptRelayClosedWhenOthersAnswered',
          ),
          timeout: any(named: 'timeout'),
        ),
      ).thenAnswer(
        (_) async =>
            (events: const <Event>[], timedOut: false, noRelays: false),
      );
      when(() => messageService.canSendTo(any())).thenAnswer((_) async => true);
      // Mirrors NIP17MessageService.buildRumor and buildGroupRumor, which
      // are pure construction.
      when(
        () => messageService.buildRumor(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          eventKind: any(named: 'eventKind'),
          additionalTags: any(named: 'additionalTags'),
          createdAt: any(named: 'createdAt'),
        ),
      ).thenAnswer((invocation) {
        final named = invocation.namedArguments;
        return Event(
          _owner,
          (named[#eventKind] as int?) ?? EventKind.privateDirectMessage,
          [
            ['p', named[#recipientPubkey] as String],
            ...(named[#additionalTags] as List<List<String>>?) ?? const [],
          ],
          named[#content] as String,
          createdAt: named[#createdAt] as int?,
        );
      });
      when(
        () => messageService.buildGroupRumor(
          recipientPubkeys: any(named: 'recipientPubkeys'),
          content: any(named: 'content'),
          eventKind: any(named: 'eventKind'),
          additionalTags: any(named: 'additionalTags'),
          createdAt: any(named: 'createdAt'),
        ),
      ).thenAnswer((invocation) {
        final named = invocation.namedArguments;
        final ordered = [...named[#recipientPubkeys] as List<String>]..sort();
        return Event(
          _owner,
          (named[#eventKind] as int?) ?? EventKind.privateDirectMessage,
          [
            for (final pubkey in ordered) ['p', pubkey],
            ...(named[#additionalTags] as List<List<String>>?) ?? const [],
          ],
          named[#content] as String,
          createdAt: named[#createdAt] as int?,
        );
      });
      when(
        () => messageService.sendRumor(
          rumorEvent: any(named: 'rumorEvent'),
          recipientPubkey: any(named: 'recipientPubkey'),
          targetRelays: any(named: 'targetRelays'),
          selfWrapTargetRelays: any(named: 'selfWrapTargetRelays'),
          awaitRecipientOk: any(named: 'awaitRecipientOk'),
          selfWrapOnSoftUnconfirmed: any(named: 'selfWrapOnSoftUnconfirmed'),
          recipientWrapBuildTimeout: any(named: 'recipientWrapBuildTimeout'),
          selfWrapBuildTimeout: any(named: 'selfWrapBuildTimeout'),
        ),
      ).thenAnswer((invocation) {
        final rumor = invocation.namedArguments[#rumorEvent] as Event;
        final recipient = invocation.namedArguments[#recipientPubkey] as String;
        wire.add('kind=${rumor.kind} to=$recipient');
        return rumor.kind == EventKind.eventDeletion
            ? deletionWrap(rumor, recipient)
            : messageWrap(rumor, recipient);
      });

      repository = DmRepository(
        nostrClient: nostrClient,
        messageService: messageService,
        directMessagesDao: messagesDao,
        conversationsDao: conversationsDao,
        outgoingDmsDao: outgoingDao,
        userPubkey: _owner,
        signer: LocalNostrSigner(_privateKey),
      );
    });

    tearDown(() async {
      await repository.stopListening();
      await db.close();
    });

    Future<List<OutgoingDm>> queueRows(String conversationId) =>
        outgoingDao.getForConversation(
          conversationId: conversationId,
          ownerPubkey: _owner,
        );

    Future<OutgoingDm?> rowFor(String conversationId, String recipient) async {
      for (final row in await queueRows(conversationId)) {
        if (row.recipientPubkey == recipient) return row;
      }
      return null;
    }

    /// A group send to A and B. [outcomes] names what the relay answers per
    /// member; a member that is not named is delivered.
    Future<({String messageId, String conversationId})> sendToAAndB({
      Map<String, _WrapOutcome> outcomes = const {},
      String content = 'dinner at eight',
    }) async {
      messageWrap = (rumor, recipient) =>
          (outcomes[recipient] ?? delivered)(rumor, recipient);
      final results = await repository.sendGroupMessage(
        recipientPubkeys: [_memberA, _memberB],
        content: content,
      );
      // The wire rumor is shared by the batch, so every result that carries
      // an id carries the same one; a failure carries none, so read it from
      // the queue instead.
      final conversationId = DmRepository.computeConversationId([
        _owner,
        _memberA,
        _memberB,
      ]);
      final rows = await queueRows(conversationId);
      final messageId =
          results.map((r) => r.rumorEventId).whereType<String>().firstOrNull ??
          rows.firstWhere((row) => row.content == content).rumorId;
      return (messageId: messageId, conversationId: conversationId);
    }

    /// The shape #8180 is about: the message reached A and is stored, and
    /// the relay refused B, so one hard-failed row is left behind for B.
    Future<({String messageId, String conversationId, String rowForB})>
    sendReachingOnlyA({String content = 'dinner at eight'}) async {
      final sent = await sendToAAndB(
        outcomes: {_memberB: refusedByRelay},
        content: content,
      );
      OutgoingDm? forB;
      for (final row in await queueRows(sent.conversationId)) {
        if (row.recipientPubkey == _memberB && row.content == content) {
          forB = row;
        }
      }
      expect(forB, isNotNull, reason: 'the refused member keeps a queue row');
      expect(forB!.recipientWrapStatus, equals(OutgoingWrapStatus.failed));
      expect(
        await messagesDao.getMessageById(sent.messageId, ownerPubkey: _owner),
        isNotNull,
        reason: 'the message reached A, so it is stored',
      );
      return (
        messageId: sent.messageId,
        conversationId: sent.conversationId,
        rowForB: forB.id,
      );
    }

    Future<DirectMessageRow?> stored(String messageId) =>
        messagesDao.getMessageById(messageId, ownerPubkey: _owner);

    /// Stops B and pins that the stop is on record, so a later "still
    /// cancelled" cannot pass on a row that never was.
    Future<void> stopB(String rowId) async {
      await repository.cancelOutgoingSend(rumorId: rowId);
      final row = await outgoingDao.getById(rowId);
      expect(
        row?.recipientWrapStatus,
        equals(OutgoingWrapStatus.cancelled),
        reason: 'the stop landed',
      );
    }

    group('cancelOutgoingSend', () {
      test('keeps a record of the member when the message is stored', () async {
        final sent = await sendReachingOnlyA();

        final cancelled = await repository.cancelOutgoingSend(
          rumorId: sent.rowForB,
        );

        expect(cancelled, isTrue);
        final row = await outgoingDao.getById(sent.rowForB);
        expect(
          row,
          isNotNull,
          reason:
              'the bubble stays for the members who have the message, so '
              'the only record that B never got it must stay too',
        );
        expect(row!.recipientWrapStatus, equals(OutgoingWrapStatus.cancelled));
        expect(
          await outgoingDao.getRetryableForOwner(
            ownerPubkey: _owner,
            maxRetries: 5,
          ),
          isEmpty,
          reason: 'a stopped delivery must not be re-driven by the sweep',
        );
      });

      test('removes the row when no member has the message', () async {
        final sent = await sendToAAndB(
          outcomes: {_memberA: refusedByRelay, _memberB: refusedByRelay},
        );
        final forB = await rowFor(sent.conversationId, _memberB);
        expect(forB, isNotNull);
        expect(
          await messagesDao.getMessageById(sent.messageId, ownerPubkey: _owner),
          isNull,
          reason: 'nobody received it, so nothing is stored',
        );

        await repository.cancelOutgoingSend(rumorId: forB!.id);

        expect(
          await outgoingDao.getById(forB.id),
          isNull,
          reason: 'with no stored message the bubble is the row itself',
        );
      });

      test('removes a 1:1 row', () async {
        messageWrap = refusedByRelay;
        final result = await repository.sendMessage(
          recipientPubkey: _memberA,
          content: 'see you at eight',
        );
        final rowId = result.queuedRumorId;
        expect(rowId, isNotNull, reason: 'the failed send left a row');

        await repository.cancelOutgoingSend(rumorId: rowId!);

        expect(await outgoingDao.getById(rowId), isNull);
      });

      test('removes a 1:1 row even when its message is stored', () async {
        // A 1:1 message can be stored while its row is still failed: the
        // sender's own copy comes back from the relay before the recipient
        // is confirmed (#10012). There is one recipient, so "not sent to
        // everyone" does not describe it, and the row goes as before.
        messageWrap = refusedByRelay;
        final result = await repository.sendMessage(
          recipientPubkey: _memberA,
          content: 'see you at eight',
        );
        final rowId = result.queuedRumorId!;
        final row = await outgoingDao.getById(rowId);
        await messagesDao.insertMessage(
          id: row!.rumorId,
          conversationId: row.conversationId,
          senderPubkey: _owner,
          content: row.content,
          createdAt: row.createdAt,
          giftWrapId: _hex(0xecc2),
          ownerPubkey: _owner,
          sendBatchId: row.sendBatchId,
        );

        await repository.cancelOutgoingSend(rumorId: rowId);

        expect(await outgoingDao.getById(rowId), isNull);
      });

      test('changes nothing on a delivery already stopped', () async {
        final sent = await sendReachingOnlyA();
        await stopB(sent.rowForB);

        final again = await repository.cancelOutgoingSend(
          rumorId: sent.rowForB,
        );

        expect(again, isFalse);
        final row = await outgoingDao.getById(sent.rowForB);
        expect(
          row?.recipientWrapStatus,
          equals(OutgoingWrapStatus.cancelled),
          reason: 'a second stop must not remove the record the first left',
        );
      });

      // A delete for everyone that is unconfirmed or was refused keeps the
      // bubble on screen, so the record is still needed. In the app the batch
      // is cancelled before the retraction starts; these reach the same state
      // without it, as a retraction started elsewhere does.
      test('keeps a record while a delete for everyone is '
          'unconfirmed', () async {
        final sent = await sendReachingOnlyA();
        deletionWrap = (rumor, recipient) async => recipient == _memberB
            ? const NIP17SendResult.failure('no relay confirmed the wrap')
            : await delivered(rumor, recipient);
        await repository.deleteMessageForEveryone(sent.messageId);
        await pumpEventQueue();
        final message = await stored(sent.messageId);
        expect(message?.isDeleted, isTrue);
        expect(
          message?.deletionPublishStatus,
          equals(DirectMessagesDao.deletionPending),
        );

        await stopB(sent.rowForB);
      });

      test('keeps a record after a delete for everyone was refused', () async {
        final sent = await sendReachingOnlyA();
        deletionWrap = (rumor, recipient) async =>
            const NIP17SendResult.blocked(
              'blocked: recipient not permitted by send policy',
            );
        await repository.deleteMessageForEveryone(sent.messageId);
        await pumpEventQueue();
        final message = await stored(sent.messageId);
        expect(
          message?.isDeleted,
          isFalse,
          reason: 'a refused retraction puts the bubble back',
        );
        expect(
          message?.deletionPublishStatus,
          equals(DirectMessagesDao.deletionBlocked),
        );

        await stopB(sent.rowForB);
      });

      test('keeps a record for a refused delete for everyone that is still '
          'stored as deleted', () async {
        // The thread query shows this shape too, so the bubble is on screen.
        final sent = await sendReachingOnlyA();
        await messagesDao.markMessageDeletionBlocked(
          sent.messageId,
          restoreToThread: false,
          ownerPubkey: _owner,
        );
        final message = await stored(sent.messageId);
        expect(message?.isDeleted, isTrue);
        expect(
          message?.deletionPublishStatus,
          equals(DirectMessagesDao.deletionBlocked),
        );

        await stopB(sent.rowForB);
      });

      test('removes the row once a delete for everyone is confirmed', () async {
        final sent = await sendReachingOnlyA();
        deletionWrap = delivered;
        await repository.deleteMessageForEveryone(sent.messageId);
        await pumpEventQueue();
        final message = await stored(sent.messageId);
        expect(message?.isDeleted, isTrue);
        expect(
          message?.deletionPublishStatus,
          isNot(
            anyOf(
              DirectMessagesDao.deletionPending,
              DirectMessagesDao.deletionBlocked,
            ),
          ),
          reason: 'the retraction is settled, so the bubble has left',
        );
        expect(
          await outgoingDao.getById(sent.rowForB),
          isNotNull,
          reason: 'nothing cancelled the batch, so the failed row is live',
        );

        await repository.cancelOutgoingSend(rumorId: sent.rowForB);

        expect(
          await outgoingDao.getById(sent.rowForB),
          isNull,
          reason: 'no bubble is left for a record to describe',
        );
      });

      test('removes the row of a batch queued before its siblings shared '
          'one rumor id', () async {
        // Until the fix for #8188 each sibling carried its own rumor, and the
        // stored message carries the first confirmed one's. The row cannot
        // be matched to its message by rumor id, so it is dropped as before.
        final conversationId = DmRepository.computeConversationId([
          _owner,
          _memberA,
          _memberB,
        ]);
        await messagesDao.insertMessage(
          id: _hex(0xa1),
          conversationId: conversationId,
          senderPubkey: _owner,
          content: 'dinner at eight',
          createdAt: 1700000000,
          giftWrapId: _hex(0xa2),
          ownerPubkey: _owner,
          sendBatchId: 'batch-before-8188',
        );
        final rowId = _hex(0xb1);
        await outgoingDao.enqueue(
          OutgoingDm(
            id: rowId,
            conversationId: conversationId,
            recipientPubkey: _memberB,
            content: 'dinner at eight',
            createdAt: 1700000000,
            rumorEventJson: jsonEncode({'id': rowId, 'kind': 14}),
            recipientWrapStatus: OutgoingWrapStatus.failed,
            selfWrapStatus: OutgoingWrapStatus.failed,
            queuedAt: DateTime.utc(2026, 8),
            ownerPubkey: _owner,
            sendBatchId: 'batch-before-8188',
          ),
        );

        final cancelled = await repository.cancelOutgoingSend(rumorId: rowId);

        expect(cancelled, isTrue);
        expect(await outgoingDao.getById(rowId), isNull);
      });
    });

    group('cancelOutgoingBatch', () {
      test('keeps the members who were not reached and drops the member who '
          'only lacks the sender copy', () async {
        messageWrap = (rumor, recipient) => switch (recipient) {
          // Delivered, but the sender's own copy did not land: the row
          // stays behind to retry only that copy.
          _memberA => delivered(rumor, recipient, selfWrap: false),
          _memberB => refusedByRelay(rumor, recipient),
          // Written, with no OK back: still pending.
          _ => Future.value(
            const NIP17SendResult.failure(
              'no OK within the window',
              retryablePending: true,
            ),
          ),
        };
        final results = await repository.sendGroupMessage(
          recipientPubkeys: [_memberA, _memberB, _memberC],
          content: 'dinner at eight',
        );
        final messageId = results.first.rumorEventId!;
        final conversationId = DmRepository.computeConversationId([
          _owner,
          _memberA,
          _memberB,
          _memberC,
        ]);
        expect(await queueRows(conversationId), hasLength(3));

        final cancelled = await repository.cancelOutgoingBatch(
          rumorId: messageId,
        );

        expect(cancelled, equals(3));
        expect(
          await rowFor(conversationId, _memberA),
          isNull,
          reason: 'A has the message; only the sender copy was outstanding',
        );
        final forB = await rowFor(conversationId, _memberB);
        final forC = await rowFor(conversationId, _memberC);
        expect(forB?.recipientWrapStatus, equals(OutgoingWrapStatus.cancelled));
        expect(forC?.recipientWrapStatus, equals(OutgoingWrapStatus.cancelled));
      });

      test('removes every row when no member has the message', () async {
        final sent = await sendToAAndB(
          outcomes: {_memberA: refusedByRelay, _memberB: refusedByRelay},
        );
        expect(await queueRows(sent.conversationId), hasLength(2));

        final cancelled = await repository.cancelOutgoingBatch(
          rumorId: sent.messageId,
        );

        expect(cancelled, equals(2));
        expect(await queueRows(sent.conversationId), isEmpty);
      });

      test('leaves a member already stopped on record', () async {
        final sent = await sendReachingOnlyA();
        await stopB(sent.rowForB);

        final cancelled = await repository.cancelOutgoingBatch(
          rumorId: sent.messageId,
        );

        expect(cancelled, equals(0));
        final row = await outgoingDao.getById(sent.rowForB);
        expect(row?.recipientWrapStatus, equals(OutgoingWrapStatus.cancelled));
      });
    });

    group('deleteMessageForEveryone after the batch was cancelled', () {
      Future<({String messageId, String conversationId, String rowForB})>
      cancelledBatch() async {
        final sent = await sendReachingOnlyA();
        await repository.cancelOutgoingBatch(rumorId: sent.messageId);
        final row = await outgoingDao.getById(sent.rowForB);
        expect(
          row?.recipientWrapStatus,
          equals(OutgoingWrapStatus.cancelled),
          reason: 'the stopped member is on record before the retraction',
        );
        return sent;
      }

      test('drops the record once every member confirmed it', () async {
        final sent = await cancelledBatch();
        deletionWrap = delivered;

        await repository.deleteMessageForEveryone(sent.messageId);
        await pumpEventQueue();

        expect(
          await queueRows(sent.conversationId),
          isEmpty,
          reason:
              'the bubble has left the thread, so nothing is left for the '
              'record to describe',
        );
      });

      test('keeps the record while the retraction is unconfirmed', () async {
        final sent = await cancelledBatch();
        deletionWrap = (rumor, recipient) async =>
            const NIP17SendResult.failure('no relay confirmed the wrap');

        await repository.deleteMessageForEveryone(sent.messageId);
        await pumpEventQueue();

        final row = await outgoingDao.getById(sent.rowForB);
        expect(row?.recipientWrapStatus, equals(OutgoingWrapStatus.cancelled));
      });

      test('keeps the record when the retraction is refused', () async {
        final sent = await cancelledBatch();
        deletionWrap = (rumor, recipient) async =>
            const NIP17SendResult.blocked(
              'blocked: recipient not permitted by send policy',
            );

        await repository.deleteMessageForEveryone(sent.messageId);
        await pumpEventQueue();

        final row = await outgoingDao.getById(sent.rowForB);
        expect(row?.recipientWrapStatus, equals(OutgoingWrapStatus.cancelled));
      });

      test('drops only the records of the retracted message', () async {
        final first = await sendReachingOnlyA();
        final second = await sendReachingOnlyA(content: 'bring dessert');
        expect(second.messageId, isNot(equals(first.messageId)));
        await stopB(first.rowForB);
        await stopB(second.rowForB);
        deletionWrap = delivered;

        await repository.deleteMessageForEveryone(first.messageId);
        await pumpEventQueue();

        expect(await outgoingDao.getById(first.rowForB), isNull);
        final other = await outgoingDao.getById(second.rowForB);
        expect(
          other?.recipientWrapStatus,
          equals(OutgoingWrapStatus.cancelled),
          reason: 'the other message is still shown and still missed B',
        );
      });
    });

    group('recovery of a stopped row', () {
      Future<({String messageId, String conversationId, String rowForB})>
      stoppedRow() async {
        final sent = await sendReachingOnlyA();
        await repository.cancelOutgoingSend(rumorId: sent.rowForB);
        final row = await outgoingDao.getById(sent.rowForB);
        expect(
          row?.recipientWrapStatus,
          equals(OutgoingWrapStatus.cancelled),
          reason: 'the row exists, so a missing-row refusal is not the cause',
        );
        return sent;
      }

      test('recoverFullSend refuses it and publishes nothing', () async {
        final sent = await stoppedRow();
        messageWrap = delivered;
        wire.clear();

        await expectLater(
          repository.recoverFullSend(rumorId: sent.rowForB),
          throwsArgumentError,
        );

        expect(wire, isEmpty);
        final row = await outgoingDao.getById(sent.rowForB);
        expect(row?.recipientWrapStatus, equals(OutgoingWrapStatus.cancelled));
      });

      test('recoverSelfWrap refuses it and publishes nothing', () async {
        final sent = await stoppedRow();

        await expectLater(
          repository.recoverSelfWrap(rumorId: sent.rowForB),
          throwsArgumentError,
        );

        verifyNever(
          () => messageService.publishSelfWrap(
            rumorEvent: any(named: 'rumorEvent'),
            targetRelays: any(named: 'targetRelays'),
          ),
        );
      });
    });

    group('a stop that lands while the wrap is in flight', () {
      /// What a publish that outlives the stop can come back with, other
      /// than a delivery. None of them reached the member.
      final notDelivered = <String, NIP17SendResult>{
        'is refused': const NIP17SendResult.failure('relay refused the wrap'),
        'gets no answer': const NIP17SendResult.failure(
          'no OK within the window',
          retryablePending: true,
        ),
        'is blocked and the row would be retained':
            const NIP17SendResult.blocked(
              'blocked: recipient retired',
              disposition: NIP17BlockedSendDisposition.retain,
            ),
      };

      Future<void> expectStillStoppedAndIdle(String rowId) async {
        final row = await outgoingDao.getById(rowId);
        expect(row?.recipientWrapStatus, equals(OutgoingWrapStatus.cancelled));
        expect(row?.selfWrapStatus, equals(OutgoingWrapStatus.cancelled));
        expect(
          await outgoingDao.getRetryableForOwner(
            ownerPubkey: _owner,
            maxRetries: 5,
          ),
          isEmpty,
          reason: 'the sweep must not pick the member up again',
        );
        expect(await outgoingDao.getStillPendingForOwner(_owner), isEmpty);
      }

      group('recoverFullSend', () {
        test('drops the record when its publish lands', () async {
          final sent = await sendReachingOnlyA();
          // The retry is on the wire when the user stops B.
          messageWrap = (rumor, recipient) async {
            await stopB(sent.rowForB);
            return delivered(rumor, recipient);
          };

          final result = await repository.recoverFullSend(
            rumorId: sent.rowForB,
          );

          expect(result.success, isTrue, reason: 'the wrap did land');
          expect(
            await outgoingDao.getById(sent.rowForB),
            isNull,
            reason: 'B has the message, so nothing stays on record against B',
          );
          expect(await stored(sent.messageId), isNotNull);
        });

        for (final MapEntry(key: name, value: outcome)
            in notDelivered.entries) {
          test('leaves the record alone when its publish $name', () async {
            final sent = await sendReachingOnlyA();
            messageWrap = (rumor, recipient) async {
              await stopB(sent.rowForB);
              return outcome;
            };

            final result = await repository.recoverFullSend(
              rumorId: sent.rowForB,
            );

            expect(result.success, isFalse);
            await expectStillStoppedAndIdle(sent.rowForB);
          });
        }

        test('removes the record when its publish is blocked and the '
            'refused intent must not stay visible', () async {
          final sent = await sendReachingOnlyA();
          messageWrap = (rumor, recipient) async {
            await stopB(sent.rowForB);
            return const NIP17SendResult.blocked(
              'blocked: recipient not permitted by send policy',
              disposition: NIP17BlockedSendDisposition.discard,
            );
          };

          final result = await repository.recoverFullSend(
            rumorId: sent.rowForB,
          );

          expect(result.blocked, isTrue);
          expect(await outgoingDao.getById(sent.rowForB), isNull);
        });
      });

      group('sendGroupMessage', () {
        final conversationId = DmRepository.computeConversationId([
          _owner,
          _memberA,
          _memberB,
        ]);

        /// B is stopped while B's own wrap is in flight, after the message
        /// was stored through A; the relay then answers B with [outcome].
        Future<List<NIP17SendResult>> sendStoppingBMidFlight(
          _WrapOutcome outcome,
        ) {
          messageWrap = (rumor, recipient) async {
            if (recipient != _memberB) return delivered(rumor, recipient);
            final forB = await rowFor(conversationId, _memberB);
            await messagesDao.insertMessage(
              id: rumor.id,
              conversationId: conversationId,
              senderPubkey: _owner,
              content: rumor.content,
              createdAt: rumor.createdAt,
              giftWrapId: _hex(0xecc1),
              tagsJson: jsonEncode(rumor.tags),
              ownerPubkey: _owner,
              sendBatchId: forB!.sendBatchId,
            );
            await stopB(forB.id);
            return outcome(rumor, recipient);
          };
          return repository.sendGroupMessage(
            recipientPubkeys: [_memberA, _memberB],
            content: 'dinner at eight',
          );
        }

        test('drops the record when the publish to that member '
            'lands', () async {
          final results = await sendStoppingBMidFlight(delivered);

          expect(results.map((r) => r.success), equals([true, true]));
          expect(
            await rowFor(conversationId, _memberB),
            isNull,
            reason: 'B has the message, so nothing stays on record against B',
          );
        });

        for (final MapEntry(key: name, value: outcome)
            in notDelivered.entries) {
          test('leaves the record alone when the publish to that member '
              '$name', () async {
            final results = await sendStoppingBMidFlight(
              (rumor, recipient) async => outcome,
            );

            expect(results.map((r) => r.success), equals([true, false]));
            final forB = await rowFor(conversationId, _memberB);
            expect(forB, isNotNull);
            await expectStillStoppedAndIdle(forB!.id);
          });
        }
      });
    });

    group('sendGroupMessage', () {
      test('does not publish to a member stopped while the batch was still '
          'sending', () async {
        final conversationId = DmRepository.computeConversationId([
          _owner,
          _memberA,
          _memberB,
        ]);
        // While A's wrap is in flight the message gets stored (in the app the
        // sender's own copy comes back from the relay) and the user stops B.
        messageWrap = (rumor, recipient) async {
          if (recipient == _memberA) {
            final forB = await rowFor(conversationId, _memberB);
            await messagesDao.insertMessage(
              id: rumor.id,
              conversationId: conversationId,
              senderPubkey: _owner,
              content: rumor.content,
              createdAt: rumor.createdAt,
              giftWrapId: _hex(0xecc0),
              tagsJson: jsonEncode(rumor.tags),
              ownerPubkey: _owner,
              sendBatchId: forB!.sendBatchId,
            );
            await repository.cancelOutgoingSend(rumorId: forB.id);
          }
          return delivered(rumor, recipient);
        };

        final results = await repository.sendGroupMessage(
          recipientPubkeys: [_memberA, _memberB],
          content: 'dinner at eight',
        );

        final forB = await rowFor(conversationId, _memberB);
        expect(
          forB?.recipientWrapStatus,
          equals(OutgoingWrapStatus.cancelled),
          reason: 'the stop is on record',
        );
        expect(
          wire,
          equals(['kind=${EventKind.privateDirectMessage} to=$_memberA']),
          reason: 'B was stopped before its wrap was published',
        );
        expect(results.map((r) => r.success), equals([true, false]));
      });
    });
  });
}
