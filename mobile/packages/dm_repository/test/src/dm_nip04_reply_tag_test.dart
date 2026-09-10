// ABOUTME: #8507 — the kind-4 twin carries an `e` tag only when the replied-to
// ABOUTME: message arrived over NIP-04, so it is resolvable and already public.

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
const _kind4Id =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _rumorId =
    '2222222222222222222222222222222222222222222222222222222222222222';
const _wrapId =
    '3333333333333333333333333333333333333333333333333333333333333333';

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeEvent());
    registerFallbackValue(Duration.zero);
  });

  // Real DAOs: the rule turns on a stored row's arrival SHAPE
  // (`id == giftWrapId`), so a stubbed lookup would be asserting the stub.
  group('the kind-4 reply tag (#8507)', () {
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
      when(
        () => messageService.canSendTo(any()),
      ).thenAnswer((_) async => true);
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
    Future<void> seedLatchedThread() => conversationsDao.upsertConversation(
      id: conversationId,
      participantPubkeys: participants.join(','),
      isGroup: false,
      createdAt: _baseCreatedAt,
      lastMessageTimestamp: _baseCreatedAt,
      ownerPubkey: _owner,
      dmProtocol: 'nip04',
    );

    /// [giftWrapId] == [id] is the shape the NIP-04 receive path writes, and is
    /// what marks a row as having arrived over kind 4 (#8169).
    Future<void> storeMessage({
      required String id,
      required String giftWrapId,
      String senderPubkey = _peer,
    }) => messagesDao.insertMessage(
      id: id,
      conversationId: conversationId,
      senderPubkey: senderPubkey,
      content: 'earlier message',
      createdAt: _baseCreatedAt,
      giftWrapId: giftWrapId,
      ownerPubkey: _owner,
    );

    Future<List<List<String>>?> publishedKind4Tags() async {
      final calls = verify(
        () => nostrClient.publishEventAwaitOk(
          captureAny(),
          targetRelays: any(named: 'targetRelays'),
          timeout: any(named: 'timeout'),
          diagnosticTag: any(named: 'diagnosticTag'),
        ),
      ).captured;
      if (calls.isEmpty) return null;
      return (calls.last as Event).tags.map((t) => t.cast<String>()).toList();
    }

    Future<void> send({String? replyToId}) async {
      final _ = await repository.sendMessage(
        recipientPubkey: _peer,
        content: 'my reply',
        replyToId: replyToId,
      );
      await pumpEventQueue();
    }

    test(
      'tags a reply to a message that arrived over NIP-04, so the legacy '
      'recipient can resolve it',
      () async {
        await seedLatchedThread();
        // id == giftWrapId: arrived over kind 4, so this id is a real event
        // id already on relays.
        await storeMessage(id: _kind4Id, giftWrapId: _kind4Id);

        await send(replyToId: _kind4Id);

        expect(await publishedKind4Tags(), [
          ['p', _peer],
          ['e', _kind4Id],
        ]);
      },
    );

    test(
      'does NOT tag a reply to a message that arrived over NIP-17 — that id '
      'is a rumor id the recipient never saw and that is not public',
      () async {
        await seedLatchedThread();
        // id != giftWrapId: arrived wrapped, so `id` is the rumor id. It exists
        // only inside the seal; publishing it in a cleartext tag would leak a
        // stable identifier for a private message, and the recipient could not
        // resolve it anyway.
        await storeMessage(id: _rumorId, giftWrapId: _wrapId);

        await send(replyToId: _rumorId);

        expect(await publishedKind4Tags(), [
          ['p', _peer],
        ]);
      },
    );

    test(
      'does NOT expose a legacy-shaped self-authored NIP-17 wrap id',
      () async {
        await seedLatchedThread();
        // Before #2654, own NIP-17 sends stored the gift-wrap id in both
        // columns. The shape alone therefore cannot prove this was kind 4.
        await storeMessage(
          id: _wrapId,
          giftWrapId: _wrapId,
          senderPubkey: _owner,
        );

        await send(replyToId: _wrapId);

        expect(await publishedKind4Tags(), [
          ['p', _peer],
        ]);
      },
    );

    test('omits the tag when the reply target is unknown locally', () async {
      await seedLatchedThread();

      await send(replyToId: _kind4Id);

      expect(await publishedKind4Tags(), [
        ['p', _peer],
      ]);
    });

    test('omits the tag for a plain, non-reply message', () async {
      await seedLatchedThread();
      await storeMessage(id: _kind4Id, giftWrapId: _kind4Id);

      await send();

      expect(await publishedKind4Tags(), [
        ['p', _peer],
      ]);
    });
  });
}
