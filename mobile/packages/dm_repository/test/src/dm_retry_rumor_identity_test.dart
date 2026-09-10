// ABOUTME: #6522 — our retry MUST re-wrap the stored rumor rather than mint a
// ABOUTME: fresh one, and a peer that re-mints must at least be observable.

import 'dart:async';
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
import 'package:unified_logger/unified_logger.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockMessageService extends Mock implements NIP17MessageService {}

class _FakeEvent extends Fake implements Event {}

const _owner =
    'a4f5c1b2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8';
const _peer =
    'b1c2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8f9a0';
const _otherPeer =
    'c2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8f9a0b1';
const _privateKey =
    '5426e5b8b4b0e2a1f5e8d3c7a9b2f4e6d8c0a2b4f6e8d0c2a4b6f8e0d2c4a6b8';

const _baseCreatedAt = 1700000000;
const _storedRumorId =
    '2222222222222222222222222222222222222222222222222222222222222222';
const _wrapId =
    '3333333333333333333333333333333333333333333333333333333333333333';

void main() {
  // Deliberately runs against a real DirectMessagesDao and a real database.
  // The mock suite in dm_repository_test.dart stubs the dedup DAO methods from
  // a shared setUp, so a test written there would pass whether or not the
  // behaviour under test holds — the #8399 / #7324 lesson.
  setUpAll(() {
    registerFallbackValue(_FakeEvent());
    registerFallbackValue(Duration.zero);
  });

  group('a retry re-wraps the stored rumor (#6522)', () {
    late AppDatabase db;
    late ConversationsDao conversationsDao;
    late DirectMessagesDao messagesDao;
    late OutgoingDmsDao outgoingDao;
    late _MockNostrClient nostrClient;
    late _MockMessageService messageService;
    late DmRepository repository;
    late String conversationId;

    setUp(() async {
      db = AppDatabase.test(NativeDatabase.memory());
      conversationsDao = ConversationsDao(db);
      messagesDao = DirectMessagesDao(db);
      outgoingDao = OutgoingDmsDao(db);
      nostrClient = _MockNostrClient();
      messageService = _MockMessageService();
      conversationId = DmRepository.computeConversationId(
        [_owner, _peer]..sort(),
      );

      when(() => nostrClient.connectedRelayCount).thenReturn(1);
      when(() => nostrClient.configuredRelayCount).thenReturn(1);
      when(
        () => nostrClient.queryEventsDetailed(
          any(),
          subscriptionId: any(named: 'subscriptionId'),
          useCache: any(named: 'useCache'),
          tempRelays: any(named: 'tempRelays'),
          requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          timeout: any(named: 'timeout'),
        ),
      ).thenAnswer(
        (_) async => (
          events: const <Event>[],
          timedOut: false,
          noRelays: false,
          anyRelayAnswered: false,
          unsettledRelays: const <String>[],
        ),
      );
      when(() => messageService.canSendTo(any())).thenAnswer((_) async => true);
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
      ).thenAnswer(
        (_) async => NIP17SendResult.success(
          rumorEventId: _storedRumorId,
          messageEventId: _wrapId,
          recipientPubkey: _peer,
        ),
      );
      when(
        () => messageService.publishSelfWrap(
          rumorEvent: any(named: 'rumorEvent'),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).thenAnswer(
        (_) async => NIP17SendResult.success(
          rumorEventId: _storedRumorId,
          messageEventId: _wrapId,
          recipientPubkey: _owner,
        ),
      );

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
      await db.close();
    });

    /// The rumor exactly as `sendMessage` would have stored it before the
    /// publish that failed.
    Event storedRumor() => Event.fromJson({
      'id': _storedRumorId,
      'pubkey': _owner,
      'created_at': _baseCreatedAt,
      'kind': EventKind.privateDirectMessage,
      'tags': [
        ['p', _peer],
      ],
      'content': 'are we still on for tomorrow?',
      'sig': '',
    });

    Future<void> enqueueFailedSend() async {
      await outgoingDao.enqueue(
        OutgoingDm(
          id: _storedRumorId,
          conversationId: conversationId,
          recipientPubkey: _peer,
          content: 'are we still on for tomorrow?',
          createdAt: _baseCreatedAt,
          rumorEventJson: jsonEncode(storedRumor().toJson()),
          recipientWrapStatus: OutgoingWrapStatus.failed,
          selfWrapStatus: OutgoingWrapStatus.failed,
          queuedAt: DateTime.now(),
          ownerPubkey: _owner,
        ),
      );
    }

    test(
      'republishes the SAME rumor id and created_at, so the receiver keys on '
      'one message',
      () async {
        await enqueueFailedSend();

        final _ = await repository.recoverFullSend(rumorId: _storedRumorId);

        final captured =
            verify(
                  () => messageService.sendRumor(
                    rumorEvent: captureAny(named: 'rumorEvent'),
                    recipientPubkey: any(named: 'recipientPubkey'),
                    targetRelays: any(named: 'targetRelays'),
                    selfWrapTargetRelays: any(named: 'selfWrapTargetRelays'),
                    awaitRecipientOk: any(named: 'awaitRecipientOk'),
                    selfWrapOnSoftUnconfirmed: any(
                      named: 'selfWrapOnSoftUnconfirmed',
                    ),
                    recipientWrapBuildTimeout: any(
                      named: 'recipientWrapBuildTimeout',
                    ),
                    selfWrapBuildTimeout: any(named: 'selfWrapBuildTimeout'),
                  ),
                ).captured.single
                as Event;

        // The whole of #6522 rests on this. A receiver dedups a re-wrapped
        // retry on the rumor id (primary key) and cannot dedup a re-minted
        // one at all, because a fresh id and created_at are indistinguishable
        // from a genuine second send. If this ever regresses, Divine starts
        // *causing* the duplicate bubbles #6522 tracks, for every peer.
        expect(
          captured.id,
          _storedRumorId,
          reason: 'a retry must re-wrap the stored rumor, never mint a new one',
        );
        expect(
          captured.createdAt,
          _baseCreatedAt,
          reason: 'created_at feeds the id hash; changing it forks the id',
        );
      },
    );

    test('never mints a fresh rumor on the recovery path', () async {
      await enqueueFailedSend();

      final _ = await repository.recoverFullSend(rumorId: _storedRumorId);

      // Guards the id assertion above against a future refactor that rebuilds
      // an identical-looking rumor through buildRumor: that would re-derive
      // created_at from the clock and silently fork the id.
      verifyNever(
        () => messageService.buildRumor(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          eventKind: any(named: 'eventKind'),
          additionalTags: any(named: 'additionalTags'),
          createdAt: any(named: 'createdAt'),
        ),
      );
    });

    test("the self-wrap recovery re-wraps the same rumor too, so the user's "
        'other device sees one message', () async {
      // recoverSelfWrap is the SECOND place a rumor is rebuilt from stored
      // JSON. It replays the sender's own cross-device copy, so a fresh
      // mint here duplicates the message on the user's other device rather
      // than on a peer's — the same defect, pointed inward.
      await outgoingDao.enqueue(
        OutgoingDm(
          id: _storedRumorId,
          conversationId: conversationId,
          recipientPubkey: _peer,
          content: 'are we still on for tomorrow?',
          createdAt: _baseCreatedAt,
          rumorEventJson: jsonEncode(storedRumor().toJson()),
          recipientWrapStatus: OutgoingWrapStatus.sent,
          selfWrapStatus: OutgoingWrapStatus.failed,
          queuedAt: DateTime.now(),
          ownerPubkey: _owner,
        ),
      );

      final _ = await repository.recoverSelfWrap(rumorId: _storedRumorId);

      final captured =
          verify(
                () => messageService.publishSelfWrap(
                  rumorEvent: captureAny(named: 'rumorEvent'),
                  targetRelays: any(named: 'targetRelays'),
                ),
              ).captured.single
              as Event;

      expect(captured.id, _storedRumorId);
      expect(captured.createdAt, _baseCreatedAt);
    });
  });

  group("a peer's re-minted retry is observable, not suppressed (#6522)", () {
    late AppDatabase db;
    late ConversationsDao conversationsDao;
    late DirectMessagesDao messagesDao;
    late _MockNostrClient nostrClient;
    late StreamController<Event> relay;
    late DmRepository repository;
    late Map<String, Event> rumorByWrapId;

    setUp(() async {
      await LogCaptureService().clearAllLogs();
      db = AppDatabase.test(NativeDatabase.memory());
      conversationsDao = ConversationsDao(db);
      messagesDao = DirectMessagesDao(db);
      nostrClient = _MockNostrClient();
      relay = StreamController<Event>();
      rumorByWrapId = <String, Event>{};

      when(() => nostrClient.connectedRelayCount).thenReturn(1);
      when(() => nostrClient.configuredRelayCount).thenReturn(1);
      when(
        () => nostrClient.queryEvents(
          any(),
          subscriptionId: any(named: 'subscriptionId'),
          useCache: any(named: 'useCache'),
        ),
      ).thenAnswer((_) async => const <Event>[]);
      when(
        () => nostrClient.queryEventsDetailed(
          any(),
          subscriptionId: any(named: 'subscriptionId'),
          useCache: any(named: 'useCache'),
          tempRelays: any(named: 'tempRelays'),
          requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          timeout: any(named: 'timeout'),
        ),
      ).thenAnswer(
        (_) async => (
          events: const <Event>[],
          timedOut: false,
          noRelays: false,
          anyRelayAnswered: false,
          unsettledRelays: const <String>[],
        ),
      );
      when(() => nostrClient.unsubscribe(any())).thenAnswer((_) async {});
      when(
        () => nostrClient.subscribe(
          any(),
          subscriptionId: any(named: 'subscriptionId'),
          tempRelays: any(named: 'tempRelays'),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).thenAnswer((_) => relay.stream);

      repository = DmRepository(
        nostrClient: nostrClient,
        directMessagesDao: messagesDao,
        conversationsDao: conversationsDao,
        userPubkey: _owner,
        signer: LocalNostrSigner(_privateKey),
        rumorDecryptor: (_, giftWrap) async => rumorByWrapId[giftWrap.id],
        nip04Decryptor: (_, ciphertext) async => ciphertext,
      );
      await repository.startListening();
    });

    tearDown(() async {
      await repository.stopListening();
      await relay.close();
      await db.close();
      // LogCaptureService is a process-global singleton; leaving entries
      // behind would leak into every later suite in the merged isolate.
      await LogCaptureService().clearAllLogs();
    });

    Future<void> settle() async {
      for (var i = 0; i < 8; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    Future<void> deliverNip17({
      required String wrapId,
      required String rumorId,
      required String text,
      required int createdAt,
      String senderPubkey = _peer,
    }) async {
      rumorByWrapId[wrapId] = Event.fromJson({
        'id': rumorId,
        'pubkey': senderPubkey,
        'created_at': createdAt,
        'kind': EventKind.privateDirectMessage,
        'tags': [
          ['p', _owner],
        ],
        'content': text,
        'sig': '',
      });
      relay.add(
        Event.fromJson({
          'id': wrapId,
          'pubkey': _peer,
          'created_at': createdAt,
          'kind': EventKind.giftWrap,
          'tags': [
            ['p', _owner],
          ],
          'content': 'wrapped-$wrapId',
          'sig': '',
        }),
      );
      await settle();
    }

    Future<List<DirectMessageRow>> storedMessages() async {
      final conversations = await conversationsDao.getAllConversations(
        ownerPubkey: _owner,
      );
      expect(conversations, hasLength(1));
      return messagesDao.getMessagesForConversation(
        conversations.single.id,
        ownerPubkey: _owner,
      );
    }

    /// The persist lines for [rumorId], as support would grep them.
    List<String> persistLinesFor(String rumorId) => LogCaptureService()
        .getRecentLogs()
        .map((entry) => entry.message)
        .where(
          (message) =>
              message.contains('Persisted NIP-17 DM') &&
              message.contains(rumorId),
        )
        .toList();

    String contentCorrelationFor(String rumorId) {
      final line = persistLinesFor(rumorId).single;
      final match = RegExp(
        r'contentCorrelation=([0-9a-f]{16})(?:\s|$)',
      ).firstMatch(line);
      expect(match, isNotNull);
      return match!.group(1)!;
    }

    test('a re-minted retry 30s later persists BOTH rows, because the receiver '
        'cannot tell it from a genuine repeat', () async {
      await deliverNip17(
        wrapId: 'w' * 64,
        rumorId: 'a' * 64,
        text: 'are we still on for tomorrow?',
        createdAt: _baseCreatedAt,
      );
      await deliverNip17(
        wrapId: 'x' * 64,
        rumorId: 'b' * 64,
        text: 'are we still on for tomorrow?',
        createdAt: _baseCreatedAt + 30,
      );

      // Pins the deliberate half of #6522. Collapsing the second row is
      // exactly the silent, unrecoverable loss #7324 fixed, so this must
      // not change without a protocol-level correlation signal.
      expect(
        await storedMessages(),
        hasLength(2),
        reason: 'no gate can match a fresh rumor id and created_at',
      );
    });

    test(
      'equal content has the same private correlation token, so a re-mint is '
      'greppable from a support log',
      () async {
        await deliverNip17(
          wrapId: 'w' * 64,
          rumorId: 'a' * 64,
          text: 'are we still on for tomorrow?',
          createdAt: _baseCreatedAt,
        );
        await deliverNip17(
          wrapId: 'x' * 64,
          rumorId: 'b' * 64,
          text: 'are we still on for tomorrow?',
          createdAt: _baseCreatedAt + 30,
        );

        expect(
          contentCorrelationFor('a' * 64),
          contentCorrelationFor('b' * 64),
        );
        for (final line in [
          ...persistLinesFor('a' * 64),
          ...persistLinesFor('b' * 64),
        ]) {
          expect(line, isNot(contains('are we still on for tomorrow?')));
          expect(line, isNot(contains('contentLength')));
        }
      },
    );

    test(
      'different content of the same length has a different private token',
      () async {
        await deliverNip17(
          wrapId: 'w' * 64,
          rumorId: 'a' * 64,
          text: 'are we still on for tomorrow?',
          createdAt: _baseCreatedAt,
        );
        await deliverNip17(
          wrapId: 'x' * 64,
          rumorId: 'b' * 64,
          text: 'meet me by the station at six',
          createdAt: _baseCreatedAt + 30,
        );

        // This proves the token correlates content, not length or a constant.
        expect('are we still on for tomorrow?'.length, 29);
        expect('meet me by the station at six'.length, 29);
        expect(
          contentCorrelationFor('a' * 64),
          isNot(contentCorrelationFor('b' * 64)),
        );
      },
    );

    test('equal content from another contact cannot be correlated', () async {
      await deliverNip17(
        wrapId: 'w' * 64,
        rumorId: 'a' * 64,
        text: 'are we still on for tomorrow?',
        createdAt: _baseCreatedAt,
      );
      await deliverNip17(
        wrapId: 'x' * 64,
        rumorId: 'b' * 64,
        text: 'are we still on for tomorrow?',
        createdAt: _baseCreatedAt + 30,
        senderPubkey: _otherPeer,
      );

      expect(
        contentCorrelationFor('a' * 64),
        isNot(contentCorrelationFor('b' * 64)),
      );
    });
  });
}
