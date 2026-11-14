// ABOUTME: Regression coverage for #9772 — a delete for everyone queued while
// ABOUTME: offline survives a plain account switch: it is still on the retry
// ABOUTME: worklist when the account comes back, reaches every member of the
// ABOUTME: room, and the history sync does not bring the message back.

import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/nip59/gift_wrap_util.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';

import 'support/live_dm_reads.dart';

class _MockNostrClient extends Mock implements NostrClient {
  _MockNostrClient() {
    stubQuietLiveDeletions(this);
  }
}

class _MockMessageService extends Mock implements NIP17MessageService {}

class _FakeEvent extends Fake implements Event {}

// Real key pairs: the self-copy below is sealed, wrapped and decrypted for
// real, so each pubkey has to belong to its secret.
final String _ownerSecret = '1' * 64;
final String _owner = getPublicKey(_ownerSecret);
final String _aliceSecret = '2' * 64;
final String _alice = getPublicKey(_aliceSecret);
final String _bob = getPublicKey('3' * 64);

final String _roomId = DmRepository.computeConversationId([
  _owner,
  _alice,
  _bob,
]);

const _sentAt = 1700000000;

/// Watchdog for a wrap the receive path never settles; nothing waits this
/// long on a passing run.
const _settleTimeout = Duration(seconds: 20);

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeEvent());
    // queryEventsDetailed takes a `Duration timeout` (#8212).
    registerFallbackValue(Duration.zero);
  });

  // Real DAOs over a real database: the switch deletes rows, and only a real
  // table can show which ones are left for the retry to read.
  group('a delete for everyone queued before a plain account switch', () {
    late AppDatabase db;
    late ConversationsDao conversationsDao;
    late DirectMessagesDao messagesDao;
    late ProcessedGiftWrapsDao processedDao;
    late PendingGiftWrapsDao pendingDao;
    late _MockNostrClient nostrClient;
    late _MockMessageService messageService;
    late StreamController<Event> relay;
    late DmRepository repository;

    /// Whether a relay confirms each wrap. Off is the device offline.
    late bool relayConfirms;

    /// The recipient of every kind-5 wrap handed to the wire, in order.
    late List<String> retractionRecipients;

    DmRepository createRepository() => DmRepository(
      nostrClient: nostrClient,
      messageService: messageService,
      directMessagesDao: messagesDao,
      conversationsDao: conversationsDao,
      processedGiftWrapsDao: processedDao,
      pendingGiftWrapsDao: pendingDao,
      userPubkey: _owner,
      signer: LocalNostrSigner(_ownerSecret),
    );

    setUp(() async {
      db = AppDatabase.test(NativeDatabase.memory());
      conversationsDao = ConversationsDao(db);
      messagesDao = DirectMessagesDao(db);
      processedDao = ProcessedGiftWrapsDao(db);
      pendingDao = PendingGiftWrapsDao(db);
      nostrClient = _MockNostrClient();
      messageService = _MockMessageService();
      relay = StreamController<Event>.broadcast();
      relayConfirms = true;
      retractionRecipients = [];

      when(() => nostrClient.connectedRelayCount).thenReturn(1);
      when(() => nostrClient.configuredRelayCount).thenReturn(1);
      // Inbox lookups answer and find no kind-10050, so a wrap the default
      // pool confirms counts as delivered (#8515).
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
      when(() => nostrClient.unsubscribe(any())).thenAnswer((_) async {});
      when(
        () => nostrClient.subscribe(
          any(that: isLiveDmRead),
          subscriptionId: any(named: 'subscriptionId'),
          tempRelays: any(named: 'tempRelays'),
          targetRelays: any(named: 'targetRelays'),
          onStoredEventsStart: any(named: 'onStoredEventsStart'),
          onStoredEventsEnd: any(named: 'onStoredEventsEnd'),
        ),
      ).thenAnswer((_) => relay.stream);

      when(
        () => messageService.buildDeletionRumor(
          targetEventId: any(named: 'targetEventId'),
          targetKind: any(named: 'targetKind'),
        ),
      ).thenAnswer(
        (invocation) => Event(_owner, EventKind.eventDeletion, [
          ['e', invocation.namedArguments[#targetEventId] as String],
          ['k', '${invocation.namedArguments[#targetKind]}'],
        ], ''),
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
          onSelfWrapDue: any(named: 'onSelfWrapDue'),
        ),
      ).thenAnswer((invocation) async {
        final rumor = invocation.namedArguments[#rumorEvent] as Event;
        final recipient = invocation.namedArguments[#recipientPubkey] as String;
        if (!relayConfirms) {
          return const NIP17SendResult.failure('no relay confirmed the wrap');
        }
        if (rumor.kind == EventKind.eventDeletion) {
          retractionRecipients.add(recipient);
        }
        return NIP17SendResult.success(
          rumorEventId: rumor.id,
          messageEventId: 'wrap-${rumor.id}-$recipient',
          recipientPubkey: recipient,
        );
      });

      repository = createRepository();
      await repository.startListening();
    });

    tearDown(() async {
      // stopListening() before closing the stream: onDone would otherwise arm
      // a reconnect timer that outlives this test.
      await repository.stopListening();
      await relay.close();
      await db.close();
    });

    /// Completes once the receive path has settled the gift wrap [id].
    Future<void> settled(String id) => db
        .customSelect(
          '''
          SELECT EXISTS (
            SELECT 1 FROM direct_messages WHERE gift_wrap_id = ?1
          ) OR EXISTS (
            SELECT 1 FROM processed_gift_wraps WHERE gift_wrap_id = ?1
          ) AS settled
          ''',
          variables: [Variable.withString(id)],
          readsFrom: {db.directMessages, db.processedGiftWraps},
        )
        .watchSingle()
        .firstWhere((row) => row.read<bool>('settled'))
        .timeout(
          _settleTimeout,
          onTimeout: () => fail('gift wrap $id was never settled'),
        );

    /// The owner's own message to the room, as Divine's group send builds it.
    Event ownGroupMessage() =>
        NIP17MessageService(
          signer: LocalNostrSigner(_ownerSecret),
          senderPublicKey: _owner,
          nostrService: nostrClient,
        ).buildGroupRumor(
          recipientPubkeys: [_alice, _bob],
          content: 'sent to the wrong room',
          createdAt: _sentAt,
        );

    /// The owner's self-copy of [rumor]: what the history sync downloads to
    /// restore the owner's own messages.
    Future<Event> selfCopyOf(Event rumor) async {
      final wrap = await buildGiftWrapFromHex(
        senderPrivateKeyHex: _ownerSecret,
        rumorJson: rumor.toJson(),
        receiverPublicKey: _owner,
      );
      return wrap!;
    }

    Future<void> receive(Event wrap) async {
      relay.add(wrap);
      await settled(wrap.id);
    }

    /// Deletes [rumorId] for everyone while no relay confirms anything, and
    /// waits out the first attempt, which the delete starts without awaiting.
    Future<void> deleteWhileOffline(String rumorId) async {
      relayConfirms = false;
      await repository.deleteMessageForEveryone(rumorId);
      await pumpEventQueue();
      expect(
        await repository.retryableMessageDeletions(),
        hasLength(1),
        reason: 'precondition: the offline delete left a queued retraction',
      );
    }

    /// The database half of a plain switch away from the owner, as
    /// `social_providers.dart` runs it, then the owner signing back in.
    Future<void> switchAwayAndBack() async {
      await repository.stopListening();
      await db.transaction(() async {
        await conversationsDao.retainMessageIdsForAccountSwitch(_owner);
        await messagesDao.clearForAccountSwitch(
          _owner,
          keepQueuedRetractions: true,
        );
        await conversationsDao.pinReadCursorsToLatestMessage(
          _owner,
          nowSeconds: _sentAt + 3600,
        );
        await conversationsDao.clearUnowned();
        await pendingDao.clearForAccountSwitch(_owner);
        await processedDao.clearForAccountSwitch(_owner);
      });
      repository = createRepository();
      await repository.startListening();
    }

    /// One pass of `OutgoingDmRetryService`'s deletion sweep.
    Future<List<DmMessageDeletionOutcome>> sweep() async => [
      for (final target in await repository.retryableMessageDeletions())
        await repository.retryMessageDeletion(
          rumorId: target.rumorId,
          automatic: true,
        ),
    ];

    test('without a switch, the sweep delivers it to every member', () async {
      final rumor = ownGroupMessage();
      await receive(await selfCopyOf(rumor));
      await deleteWhileOffline(rumor.id);

      relayConfirms = true;
      final outcomes = await sweep();

      expect(outcomes, equals([DmMessageDeletionOutcome.sent]));
      expect(retractionRecipients, unorderedEquals([_alice, _bob]));
    });

    test('reaches every member of the room once the account is back', () async {
      final rumor = ownGroupMessage();
      await receive(await selfCopyOf(rumor));
      await deleteWhileOffline(rumor.id);

      await switchAwayAndBack();
      relayConfirms = true;
      final outcomes = await sweep();

      expect(
        outcomes,
        equals([DmMessageDeletionOutcome.sent]),
        reason: 'the switch must leave the retraction on the worklist',
      );
      expect(retractionRecipients, unorderedEquals([_alice, _bob]));
    });

    test(
      'stays retracted when the history sync restores the message',
      () async {
        final rumor = ownGroupMessage();
        final selfCopy = await selfCopyOf(rumor);
        await receive(selfCopy);
        await deleteWhileOffline(rumor.id);

        await switchAwayAndBack();
        await receive(selfCopy);

        final row = await messagesDao.getMessageById(
          rumor.id,
          ownerPubkey: _owner,
        );
        expect(row, isNotNull, reason: 'the history sync stores the message');
        expect(
          row!.isDeleted,
          isTrue,
          reason: 'the sender deleted it; nothing on the relays says so yet',
        );
        expect(
          DirectMessagesDao.retractionsShownToSender,
          contains(row.deletionPublishStatus),
        );
        expect(row.conversationId, equals(_roomId));
      },
    );

    test('stays retracted when the history sync restores a message this '
        'device sent', () async {
      // A send stores the row under its own wrap, so the self-copy the
      // history sync downloads is a different wrap of the same rumor.
      final rumor = ownGroupMessage();
      await messagesDao.insertMessage(
        id: rumor.id,
        conversationId: _roomId,
        senderPubkey: _owner,
        content: rumor.content,
        createdAt: _sentAt,
        giftWrapId: 'wrap-sent-from-this-device',
        ownerPubkey: _owner,
      );
      await conversationsDao.upsertConversation(
        id: _roomId,
        participantPubkeys: '["$_owner","$_alice","$_bob"]',
        isGroup: true,
        createdAt: _sentAt,
        lastMessageContent: rumor.content,
        lastMessageTimestamp: _sentAt,
        lastMessageSenderPubkey: _owner,
        ownerPubkey: _owner,
      );
      await deleteWhileOffline(rumor.id);

      await switchAwayAndBack();
      await receive(await selfCopyOf(rumor));

      final row = await messagesDao.getMessageById(
        rumor.id,
        ownerPubkey: _owner,
      );
      expect(row!.isDeleted, isTrue);
      expect(row.giftWrapId, equals('wrap-sent-from-this-device'));
      expect(
        await repository.retryableMessageDeletions(),
        hasLength(1),
        reason: 'the retraction is still queued for the sweep',
      );
    });

    test('a newer message keeps its preview when the retraction is '
        'confirmed before the history comes back', () async {
      final rumor = ownGroupMessage();
      await receive(await selfCopyOf(rumor));
      final later = Event(
        _alice,
        EventKind.privateDirectMessage,
        [
          ['p', _owner],
          ['p', _bob],
        ],
        'a newer message from the room',
        createdAt: _sentAt + 60,
      );
      final laterWrap = await buildGiftWrapFromHex(
        senderPrivateKeyHex: _aliceSecret,
        rumorJson: later.toJson(),
        receiverPublicKey: _owner,
      );
      await receive(laterWrap!);
      await deleteWhileOffline(rumor.id);
      final before = await conversationsDao.getConversation(
        _roomId,
        ownerPubkey: _owner,
      );
      expect(
        before!.lastMessageTimestamp,
        equals(_sentAt + 60),
        reason: 'precondition: the newer message is the preview',
      );

      await switchAwayAndBack();
      relayConfirms = true;
      expect(await sweep(), equals([DmMessageDeletionOutcome.sent]));

      final after = await conversationsDao.getConversation(
        _roomId,
        ownerPubkey: _owner,
      );
      expect(
        after!.lastMessageTimestamp,
        equals(_sentAt + 60),
        reason:
            'the retracted message was never the preview, and the newer one '
            'is only missing until the history sync downloads it again',
      );
      expect(
        after.lastMessageContent,
        equals('a newer message from the room'),
      );
    });
  });
}
