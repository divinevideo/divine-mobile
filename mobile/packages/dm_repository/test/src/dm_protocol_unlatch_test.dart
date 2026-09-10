// ABOUTME: #8499 — a peer's NIP-17 twin clears the nip04 protocol latch;
// ABOUTME: a self-authored twin must not, as only the peer's capability counts.

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

  // Real DAOs on a real database. The claim, the early return and the upsert
  // all have to run for the unlatch to be observable at all, and the mock
  // suite stubs the dedup predicates in a shared setUp (#8170).
  group('clearing the nip04 latch on a peer NIP-17 twin (#8499)', () {
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

    /// Seeds a latched thread holding one kind-4-shaped row from [sender].
    /// The NIP-04 receive path writes the wire id into BOTH columns, and that
    /// is what marks a row as the twin a NIP-17 rumor may collapse onto.
    Future<void> seedLatchedThreadWithKind4({
      required String id,
      required String sender,
      required String content,
    }) async {
      await conversationsDao.upsertConversation(
        id: conversationId,
        participantPubkeys: participants.join(','),
        isGroup: false,
        createdAt: _baseCreatedAt,
        lastMessageTimestamp: _baseCreatedAt,
        ownerPubkey: _owner,
        dmProtocol: 'nip04',
      );
      await messagesDao.insertMessage(
        id: id,
        conversationId: conversationId,
        senderPubkey: sender,
        content: content,
        createdAt: _baseCreatedAt,
        giftWrapId: id,
        ownerPubkey: _owner,
      );
    }

    Future<void> deliverGiftWrap({
      required String wrapId,
      required String rumorId,
      required String author,
      required String content,
    }) async {
      final recipient = author == _owner ? _peer : _owner;
      rumors[wrapId] = Event.fromJson({
        'id': rumorId,
        'pubkey': author,
        'created_at': _baseCreatedAt,
        'kind': EventKind.privateDirectMessage,
        'tags': [
          ['p', recipient],
        ],
        'content': content,
        'sig': '',
      });
      relay.add(
        Event.fromJson({
          'id': wrapId,
          'pubkey': author,
          'created_at': _baseCreatedAt,
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

    Future<String?> storedProtocol() async =>
        (await conversationsDao.getConversation(
          conversationId,
          ownerPubkey: _owner,
        ))?.dmProtocol;

    test(
      "a peer's twin clears the latch, even though the rumor itself is "
      'dropped as a duplicate',
      () async {
        await seedLatchedThreadWithKind4(
          id: 'a' * 64,
          sender: _peer,
          content: 'hello',
        );
        expect(await storedProtocol(), 'nip04');

        await deliverGiftWrap(
          wrapId: 'b' * 64,
          rumorId: 'c' * 64,
          author: _peer,
          content: 'hello',
        );

        // The twin is the ONLY place this evidence appears — the rumor is
        // discarded, so before #8499 the proof went with it.
        expect(await storedProtocol(), 'nip17');
      },
    );

    test(
      'a self-authored twin does NOT clear the latch — only the peer '
      'speaking NIP-17 is evidence about the peer',
      () async {
        // The branch that claims the twin is an `else`: it catches a peer's
        // rumor AND a self-authored 1:1 rumor with no send batch token. Without
        // the `!isSentByMe` gate this path would clear on our own self-wrap.
        await seedLatchedThreadWithKind4(
          id: 'd' * 64,
          sender: _owner,
          content: 'my own message',
        );
        expect(await storedProtocol(), 'nip04');

        await deliverGiftWrap(
          wrapId: 'e' * 64,
          rumorId: 'f' * 64,
          author: _owner,
          content: 'my own message',
        );

        expect(await storedProtocol(), 'nip04');
      },
    );

    test(
      'a later peer NIP-17 after the unlatch leaves the thread nip17',
      () async {
        // The first wrap claims the kind-4 twin and clears. The second wrap
        // is not a twin (`claimCrossProtocolTwin` already consumed it) so it
        // persists; this pins that later path must not downgrade the thread.
        await seedLatchedThreadWithKind4(
          id: '1' * 64,
          sender: _peer,
          content: 'hello',
        );
        await deliverGiftWrap(
          wrapId: '2' * 64,
          rumorId: '3' * 64,
          author: _peer,
          content: 'hello',
        );
        expect(await storedProtocol(), 'nip17');

        await deliverGiftWrap(
          wrapId: '4' * 64,
          rumorId: '5' * 64,
          author: _peer,
          content: 'hello',
        );
        expect(await storedProtocol(), 'nip17');
      },
    );
  });
}
