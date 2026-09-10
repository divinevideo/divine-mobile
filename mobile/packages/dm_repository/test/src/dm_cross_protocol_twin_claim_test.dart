// ABOUTME: Regression coverage for #8211 — a stored cross-protocol twin may
// ABOUTME: absorb one arrival, not every same-text arrival in the window.

import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';

class _MockNostrClient extends Mock implements NostrClient {}

const _owner =
    'a4f5c1b2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8';
const _peer =
    'b1c2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8f9a0';
const _privateKey =
    '5426e5b8b4b0e2a1f5e8d3c7a9b2f4e6d8c0a2b4f6e8d0c2a4b6f8e0d2c4a6b8';

const _baseCreatedAt = 1700000000;

void main() {
  setUpAll(() {
    registerFallbackValue(Duration.zero);
  });

  // Drives the real DirectMessagesDao against a real database. The mock suite
  // stubs hasMatchingMessage to a constant in its top-level setUp, so a test
  // written there cannot observe any of this (#8170).
  group('a stored cross-protocol twin', () {
    late AppDatabase db;
    late ConversationsDao conversationsDao;
    late DirectMessagesDao messagesDao;
    late ProcessedGiftWrapsDao processedDao;
    late _MockNostrClient nostrClient;
    late StreamController<Event> relay;
    late DmRepository repository;

    /// Gift-wrap id -> the rumor it decrypts to, so a wrap can be pushed
    /// through the real receive path without any NIP-59 crypto.
    late Map<String, Event> rumors;

    final participants = [_owner, _peer]..sort();
    late String conversationId;

    setUp(() async {
      db = AppDatabase.test(NativeDatabase.memory());
      conversationsDao = ConversationsDao(db);
      messagesDao = DirectMessagesDao(db);
      processedDao = ProcessedGiftWrapsDao(db);
      nostrClient = _MockNostrClient();
      relay = StreamController<Event>();
      rumors = <String, Event>{};
      conversationId = DmRepository.computeConversationId(participants);

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
        processedGiftWrapsDao: processedDao,
        userPubkey: _owner,
        signer: LocalNostrSigner(_privateKey),
        rumorDecryptor: (_, giftWrap) async => rumors[giftWrap.id],
        nip04Decryptor: (_, ciphertext) async => ciphertext,
      );
      await repository.startListening();
    });

    tearDown(() async {
      await repository.stopListening();
      await relay.close();
      await db.close();
    });

    Future<void> settle() async {
      for (var i = 0; i < 8; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    Future<void> seedConversation() => conversationsDao.upsertConversation(
      id: conversationId,
      participantPubkeys: participants.join(','),
      isGroup: false,
      createdAt: _baseCreatedAt,
      lastMessageTimestamp: _baseCreatedAt,
      ownerPubkey: _owner,
    );

    /// One kind-4 from the peer, already stored. The NIP-04 receive path
    /// writes the wire event id into BOTH columns, which is what marks a row
    /// as the twin a NIP-17 rumor may collapse onto.
    Future<void> storePeerNip04(String id, {required String content}) async {
      await seedConversation();
      await messagesDao.insertMessage(
        id: id,
        conversationId: conversationId,
        senderPubkey: _peer,
        content: content,
        createdAt: _baseCreatedAt,
        giftWrapId: id,
        ownerPubkey: _owner,
      );
    }

    /// Pushes a NIP-17 gift wrap whose rumor carries [content].
    Future<void> deliverNip17({
      required String wrapId,
      required String rumorId,
      required String content,
      required int createdAt,
    }) async {
      rumors[wrapId] = Event.fromJson({
        'id': rumorId,
        'pubkey': _peer,
        'created_at': createdAt,
        'kind': EventKind.privateDirectMessage,
        'tags': [
          ['p', _owner],
        ],
        'content': content,
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
          'content': 'wrapped',
          'sig': '',
        }),
      );
      await settle();
    }

    Future<void> deliverNip04({
      required String id,
      required String content,
      required int createdAt,
    }) async {
      relay.add(
        Event.fromJson({
          'id': id,
          'pubkey': _peer,
          'created_at': createdAt,
          'kind': EventKind.directMessage,
          'tags': [
            ['p', _owner],
          ],
          'content': content,
          'sig': '',
        }),
      );
      await settle();
    }

    Future<int> storedCount() async {
      final rows = await messagesDao.getMessagesForConversation(
        conversationId,
        ownerPubkey: _owner,
      );
      return rows.length;
    }

    test('absorbs one NIP-17 arrival, not every one in the window', () async {
      // The peer sent three messages carrying the same text. Only the first
      // one's kind-4 fallback landed, so the later two arrive over NIP-17
      // alone. Before #8211 the single stored kind-4 satisfied both — three
      // messages in, one bubble out, measured on device.
      await storePeerNip04('a' * 64, content: 'ok');
      expect(await storedCount(), 1);

      await deliverNip17(
        wrapId: 'b' * 64,
        rumorId: 'c' * 64,
        content: 'ok',
        createdAt: _baseCreatedAt + 1,
      );
      await deliverNip17(
        wrapId: 'd' * 64,
        rumorId: 'e' * 64,
        content: 'ok',
        createdAt: _baseCreatedAt + 3,
      );

      expect(
        await storedCount(),
        2,
        reason:
            'the stored kind-4 is the twin of exactly one rumor, so the '
            'second same-text rumor is a genuine message and must survive '
            '(#8211)',
      );
    });

    test('still collapses the one twin it was dual-sent with', () async {
      // Control for the test above: with no second arrival, the twin must
      // still be collapsed, or this would be a dedup regression rather than
      // a fix (#7324 in the other direction).
      await storePeerNip04('a' * 64, content: 'ok');

      await deliverNip17(
        wrapId: 'b' * 64,
        rumorId: 'c' * 64,
        content: 'ok',
        createdAt: _baseCreatedAt + 1,
      );

      expect(await storedCount(), 1);
    });

    test('records a suppressed kind-4 in the processed ledger', () async {
      // The NIP-17 side burns a suppressed wrap in the ledger; the NIP-04
      // side did not, so the live subscription's two-day `since` overlap
      // re-delivered the same kind-4 on every launch and paid a full
      // remote-signer decrypt each time to reach the same answer (#8211).
      await seedConversation();
      await messagesDao.insertMessage(
        id: 'a' * 64,
        conversationId: conversationId,
        senderPubkey: _peer,
        content: 'ok',
        createdAt: _baseCreatedAt,
        giftWrapId: 'f' * 64,
        ownerPubkey: _owner,
      );

      final suppressed = 'b' * 64;
      await deliverNip04(
        id: suppressed,
        content: 'ok',
        createdAt: _baseCreatedAt + 1,
      );

      expect(await storedCount(), 1, reason: 'the kind-4 is the twin');
      expect(
        await processedDao.hasGiftWrap(suppressed),
        isTrue,
        reason: 'the suppression must be remembered across replays (#8211)',
      );
    });
  });
}
