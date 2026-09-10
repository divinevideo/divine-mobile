// ABOUTME: Proves what decides a conversation's dm_protocol latch. Twin
// ABOUTME: clearing lives in dm_protocol_unlatch_test.dart (#8499).

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

  // Real DirectMessagesDao and ConversationsDao against a real database. The
  // mock suite stubs the dedup predicates in a shared setUp, so the ordering
  // this file is about is invisible there (#8170) — and `dmProtocol` is
  // asserted nowhere else in the package.
  group('the dm_protocol latch', () {
    late AppDatabase db;
    late ConversationsDao conversationsDao;
    late DirectMessagesDao messagesDao;
    late ProcessedGiftWrapsDao processedDao;
    late _MockNostrClient nostrClient;
    late StreamController<Event> relay;
    late DmRepository repository;
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

    Future<void> deliverNip17({
      required String wrapId,
      required String rumorId,
      required String content,
      int createdAt = _baseCreatedAt,
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
      int createdAt = _baseCreatedAt,
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

    Future<String?> storedProtocol() async =>
        (await conversationsDao.getConversation(
          conversationId,
          ownerPubkey: _owner,
        ))?.dmProtocol;

    test(
      'kind-4 first latches the thread',
      () async {
        // The ordering that creates the dual-send steady state: an inbound
        // legacy copy decides the thread before any NIP-17 message lands.
        await deliverNip04(id: 'a' * 64, content: 'hello');
        expect(await storedProtocol(), 'nip04');
      },
    );

    // What CLEARS that latch is asserted in `dm_protocol_unlatch_test.dart`.
    // Until #8499 the answer was "almost nothing": the peer's NIP-17 twin was
    // collapsed onto the stored kind-4 and the handler returned before its
    // `dmProtocol: 'nip17'` upsert, so a peer speaking NIP-17 perfectly well
    // could not undo the latch and two dual-sending sides deadlocked. That
    // case used to be asserted here and now lives, inverted and split by
    // sender, alongside the change that fixed it.

    test(
      'NIP-17 first leaves the thread nip17, and the kind-4 twin cannot '
      'downgrade it',
      () async {
        // The mirror ordering. Same two events, opposite arrival order.
        await deliverNip17(
          wrapId: 'd' * 64,
          rumorId: 'e' * 64,
          content: 'hello',
        );
        expect(await storedProtocol(), 'nip17');

        await deliverNip04(id: 'f' * 64, content: 'hello');

        expect(
          await storedProtocol(),
          'nip17',
          reason:
              'the kind-4 handler dedups against the stored NIP-17 copy '
              'and returns before its own `?? nip04` upsert',
        );
      },
    );

    test(
      'a latched thread is also cleared by a NIP-17 message with no kind-4 '
      'twin',
      () async {
        await deliverNip04(id: '1' * 64, content: 'hello');
        expect(await storedProtocol(), 'nip04');

        // A genuinely new message from the peer — different text, so it is not
        // the twin of anything stored. The persist path still writes nip17.
        // Twin clearing lives in dm_protocol_unlatch_test.dart.
        await deliverNip17(
          wrapId: '2' * 64,
          rumorId: '3' * 64,
          content: 'a genuinely new message',
          createdAt: _baseCreatedAt + 600,
        );

        expect(
          await storedProtocol(),
          'nip17',
          reason: 'a non-twin rumor persists and reaches the clearing upsert',
        );
      },
    );
  });
}
