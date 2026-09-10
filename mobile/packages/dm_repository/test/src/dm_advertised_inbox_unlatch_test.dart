// ABOUTME: #8519 — a peer advertising a kind-10050 proves NIP-17 capability
// ABOUTME: without sending anything, which unlatches a one-way thread.

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
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockMessageService extends Mock implements NIP17MessageService {}

class _FakeEvent extends Fake implements Event {}

const _owner =
    'a4f5c1b2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8';
const _peer =
    'b1c2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8f9a0';
const _privateKey =
    '5426e5b8b4b0e2a1f5e8d3c7a9b2f4e6d8c0a2b4f6e8d0c2a4b6f8e0d2c4a6b8';

const _baseCreatedAt = 1700000000;
const _rumorId =
    '2222222222222222222222222222222222222222222222222222222222222222';
const _wrapId =
    '3333333333333333333333333333333333333333333333333333333333333333';

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeEvent());
    registerFallbackValue(Duration.zero);
  });

  // Real DAOs: the assertion is on the persisted `dm_protocol`, and on whether
  // the SAME send skipped its kind-4 twin as a result.
  group('unlatching from an advertised kind-10050 (#8519)', () {
    late AppDatabase db;
    late ConversationsDao conversationsDao;
    late DirectMessagesDao messagesDao;
    late ProcessedGiftWrapsDao processedDao;
    late _MockNostrClient nostrClient;
    late _MockMessageService messageService;
    late DmRepository repository;

    final participants = [_owner, _peer]..sort();
    late String conversationId;

    setUp(() async {
      db = AppDatabase.test(NativeDatabase.memory());
      conversationsDao = ConversationsDao(db);
      messagesDao = DirectMessagesDao(db);
      processedDao = ProcessedGiftWrapsDao(db);
      nostrClient = _MockNostrClient();
      messageService = _MockMessageService();
      conversationId = DmRepository.computeConversationId(participants);

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
      // The leg OK-confirms its kind 4 (#8262), so it calls
      // `publishEventAwaitOk`. Stubbing `publishEvent` here would leave the
      // real call unstubbed and the capture below empty.
      when(
        () => nostrClient.publishEventAwaitOk(
          any(),
          targetRelays: any(named: 'targetRelays'),
          timeout: any(named: 'timeout'),
          diagnosticTag: any(named: 'diagnosticTag'),
        ),
      ).thenAnswer(
        (_) async => const PublishOutcome(
          eventId: 'nip04-reply-tag-probe',
          acceptedBy: ['wss://relay.divine.video'],
          rejectedBy: <String, String>{},
          noResponseFrom: <String>[],
        ),
      );
      when(() => messageService.canSendTo(any())).thenAnswer((_) async => true);
      // Real rumor construction: the NIP-17 leg's tags are not what this file
      // asserts, but a null rumor stops `sendMessage` before the kind-4 twin.
      when(
        () => messageService.buildRumor(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          eventKind: any(named: 'eventKind'),
          additionalTags: any(named: 'additionalTags'),
          createdAt: any(named: 'createdAt'),
        ),
      ).thenAnswer(
        (inv) => Event(
          _owner,
          EventKind.privateDirectMessage,
          [
            ['p', _peer],
          ],
          inv.namedArguments[#content] as String,
        ),
      );
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
          rumorEventId: _rumorId,
          messageEventId: _wrapId,
          recipientPubkey: _peer,
        ),
      );

      repository = DmRepository(
        nostrClient: nostrClient,
        messageService: messageService,
        directMessagesDao: messagesDao,
        conversationsDao: conversationsDao,
        processedGiftWrapsDao: processedDao,
        userPubkey: _owner,
        signer: LocalNostrSigner(_privateKey),
      );
    });

    tearDown(() async {
      await db.close();
    });

    /// A thread latched to 'nip04' so the fallback gate is open.
    /// Makes the recipient's kind-10050 lookup answer [state].
    ///
    /// `found` needs a real kind-10050 authored by the recipient; the two
    /// negative states differ only in the flags, which is exactly the
    /// distinction #7317 says must not be collapsed.
    void stubInboxResolution(DmInboxResolution state) {
      when(
        () => nostrClient.queryEventsDetailed(
          any(),
          subscriptionId: any(named: 'subscriptionId'),
          useCache: any(named: 'useCache'),
          tempRelays: any(named: 'tempRelays'),
          requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          timeout: any(named: 'timeout'),
        ),
      ).thenAnswer((_) async {
        switch (state) {
          case DmInboxResolution.found:
            return (
              events: [
                Event.fromJson({
                  'id': 'a' * 64,
                  'pubkey': _peer,
                  'created_at': _baseCreatedAt,
                  'kind': EventKind.dmRelaysList,
                  'tags': [
                    ['relay', 'wss://inbox.example.com'],
                  ],
                  'content': '',
                  'sig': '',
                }),
              ],
              timedOut: false,
              noRelays: false,
              anyRelayAnswered: false,
              unsettledRelays: const <String>[],
            );
          case DmInboxResolution.absent:
            return (
              events: const <Event>[],
              timedOut: false,
              noRelays: false,
              anyRelayAnswered: false,
              unsettledRelays: const <String>[],
            );
          case DmInboxResolution.unreadable:
            // A failed read, not an answer.
            return (
              events: const <Event>[],
              timedOut: true,
              noRelays: false,
              anyRelayAnswered: false,
              unsettledRelays: const <String>[],
            );
        }
      });
    }

    Future<void> seedLatchedThread() => conversationsDao.upsertConversation(
      id: conversationId,
      participantPubkeys: participants.join(','),
      isGroup: false,
      createdAt: _baseCreatedAt,
      lastMessageTimestamp: _baseCreatedAt,
      ownerPubkey: _owner,
      dmProtocol: 'nip04',
    );

    Future<String?> storedProtocol() async =>
        (await conversationsDao.getConversation(
          conversationId,
          ownerPubkey: _owner,
        ))?.dmProtocol;

    Future<PublishOutcome> kind4Publish() => nostrClient.publishEventAwaitOk(
      any(),
      targetRelays: any(named: 'targetRelays'),
      timeout: any(named: 'timeout'),
      diagnosticTag: any(named: 'diagnosticTag'),
    );

    void verifyKind4Published({required bool expected}) {
      if (expected) {
        verify(kind4Publish).called(greaterThanOrEqualTo(1));
      } else {
        verifyNever(kind4Publish);
      }
    }

    Future<void> send() async {
      final _ = await repository.sendMessage(
        recipientPubkey: _peer,
        content: 'hello',
      );
      await pumpEventQueue();
    }

    test('an advertised kind-10050 clears the latch, and the SAME send already '
        'skips its kind-4 twin', () async {
      await seedLatchedThread();
      stubInboxResolution(DmInboxResolution.found);

      await send();

      expect(await storedProtocol(), 'nip17');
      // The unlatch runs before the persist transaction, so the gate — which
      // reads the protocol that transaction loads — is already closed. A
      // later-only fix would have published one more cleartext copy.
      verifyKind4Published(expected: false);
    });

    test(
      'no advertised inbox leaves the thread latched and still dual-sends',
      () async {
        await seedLatchedThread();
        stubInboxResolution(DmInboxResolution.absent);

        await send();

        // `absent` is a real answer: the peer advertises nothing, so there is
        // no evidence they read NIP-17 and the legacy copy is still their
        // only readable one.
        expect(await storedProtocol(), 'nip04');
        verifyKind4Published(expected: true);
      },
    );

    test(
      'an unreadable lookup is not evidence and must not unlatch (#7317)',
      () async {
        await seedLatchedThread();
        stubInboxResolution(DmInboxResolution.unreadable);

        await send();

        // The read failed. Treating that like `absent` — or like `found` —
        // is the mistake #7317 exists to prevent: one is an answer, the
        // other is the absence of one.
        expect(await storedProtocol(), 'nip04');
        verifyKind4Published(expected: true);
      },
    );
  });

  // A sibling group, deliberately not nested inside the one above: a nested
  // group would make that group's `setUp` a shared one and start it counting
  // against the #8399 stub ratchet.
  group('the retry sweep unlatches on the same evidence (#8519)', () {
    late AppDatabase db;
    late ConversationsDao conversationsDao;
    late DirectMessagesDao messagesDao;
    late ProcessedGiftWrapsDao processedDao;
    late OutgoingDmsDao outgoingDao;
    late _MockNostrClient nostrClient;
    late _MockMessageService messageService;
    late DmRepository repository;

    final participants = [_owner, _peer]..sort();
    late String conversationId;

    setUp(() async {
      db = AppDatabase.test(NativeDatabase.memory());
      conversationsDao = ConversationsDao(db);
      messagesDao = DirectMessagesDao(db);
      processedDao = ProcessedGiftWrapsDao(db);
      outgoingDao = OutgoingDmsDao(db);
      nostrClient = _MockNostrClient();
      messageService = _MockMessageService();
      conversationId = DmRepository.computeConversationId(participants);

      when(() => nostrClient.connectedRelayCount).thenReturn(1);
      when(() => nostrClient.configuredRelayCount).thenReturn(1);
      when(() => messageService.canSendTo(any())).thenAnswer((_) async => true);
      // The sweep republishes the stored rumor; the unlatch runs before this,
      // so the outcome does not decide the assertion either way.
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
          rumorEventId: _rumorId,
          messageEventId: _wrapId,
          recipientPubkey: _peer,
        ),
      );

      repository = DmRepository(
        nostrClient: nostrClient,
        messageService: messageService,
        directMessagesDao: messagesDao,
        conversationsDao: conversationsDao,
        processedGiftWrapsDao: processedDao,
        outgoingDmsDao: outgoingDao,
        userPubkey: _owner,
        signer: LocalNostrSigner(_privateKey),
      );
    });

    tearDown(() async {
      await db.close();
    });

    void stubInboxResolution(DmInboxResolution state) {
      when(
        () => nostrClient.queryEventsDetailed(
          any(),
          subscriptionId: any(named: 'subscriptionId'),
          useCache: any(named: 'useCache'),
          tempRelays: any(named: 'tempRelays'),
          requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          timeout: any(named: 'timeout'),
        ),
      ).thenAnswer((_) async {
        switch (state) {
          case DmInboxResolution.found:
            return (
              events: [
                Event.fromJson({
                  'id': 'a' * 64,
                  'pubkey': _peer,
                  'created_at': _baseCreatedAt,
                  'kind': EventKind.dmRelaysList,
                  'tags': [
                    ['relay', 'wss://inbox.example.com'],
                  ],
                  'content': '',
                  'sig': '',
                }),
              ],
              timedOut: false,
              noRelays: false,
              anyRelayAnswered: false,
              unsettledRelays: const <String>[],
            );
          case DmInboxResolution.absent:
            return (
              events: const <Event>[],
              timedOut: false,
              noRelays: false,
              anyRelayAnswered: false,
              unsettledRelays: const <String>[],
            );
          case DmInboxResolution.unreadable:
            return (
              events: const <Event>[],
              timedOut: true,
              noRelays: false,
              anyRelayAnswered: false,
              unsettledRelays: const <String>[],
            );
        }
      });
    }

    /// A latched thread with one queued rumor for the sweep to drive.
    Future<void> seedLatchedThreadWithQueuedSend() async {
      await conversationsDao.upsertConversation(
        id: conversationId,
        participantPubkeys: participants.join(','),
        isGroup: false,
        createdAt: _baseCreatedAt,
        lastMessageTimestamp: _baseCreatedAt,
        ownerPubkey: _owner,
        dmProtocol: 'nip04',
      );
      final rumor = Event.fromJson({
        'id': _rumorId,
        'pubkey': _owner,
        'created_at': _baseCreatedAt,
        'kind': EventKind.privateDirectMessage,
        'tags': [
          ['p', _peer],
        ],
        'content': 'hello',
        'sig': '',
      });
      await outgoingDao.enqueue(
        OutgoingDm(
          id: _rumorId,
          conversationId: conversationId,
          recipientPubkey: _peer,
          content: 'hello',
          createdAt: _baseCreatedAt,
          rumorEventJson: jsonEncode(rumor.toJson()),
          recipientWrapStatus: OutgoingWrapStatus.pending,
          selfWrapStatus: OutgoingWrapStatus.pending,
          queuedAt: DateTime.now(),
          ownerPubkey: _owner,
        ),
      );
    }

    Future<String?> storedProtocol() async =>
        (await conversationsDao.getConversation(
          conversationId,
          ownerPubkey: _owner,
        ))?.dmProtocol;

    test(
      'a sweep pass that reads an advertised kind-10050 clears the latch',
      () async {
        await seedLatchedThreadWithQueuedSend();
        stubInboxResolution(DmInboxResolution.found);

        final _ = await repository.recoverFullSend(rumorId: _rumorId);

        // Without this the sweep could re-read the peer's inbox on every pass
        // and still leave the next foreground send publishing a cleartext
        // twin it already had the evidence to skip.
        expect(await storedProtocol(), 'nip17');
      },
    );

    test(
      'a sweep pass on an unreadable lookup leaves the thread latched',
      () async {
        await seedLatchedThreadWithQueuedSend();
        stubInboxResolution(DmInboxResolution.unreadable);

        final _ = await repository.recoverFullSend(rumorId: _rumorId);

        expect(await storedProtocol(), 'nip04');
      },
    );
  });
}
