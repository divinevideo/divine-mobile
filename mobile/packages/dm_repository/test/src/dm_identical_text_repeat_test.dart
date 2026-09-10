// ABOUTME: Regression coverage for #7324 — two genuine messages carrying the
// ABOUTME: same short text seconds apart must both survive on the receiver,
// ABOUTME: while a cross-protocol dual-send twin is still collapsed.

import 'dart:async';
import 'dart:convert';

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
const _peer2 =
    'c2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8f9a0b1';
const _privateKey =
    '5426e5b8b4b0e2a1f5e8d3c7a9b2f4e6d8c0a2b4f6e8d0c2a4b6f8e0d2c4a6b8';

const _baseCreatedAt = 1700000000;

void main() {
  // Deliberately exercises the real DirectMessagesDao against a real
  // database. The mock-based suite in dm_repository_test.dart stubs
  // hasMatchingMessage to a constant in its top-level setUp, so a test
  // written there would pass whether or not the dedup is correct.
  setUpAll(() {
    // queryEventsDetailed takes a `Duration timeout`, so a stub matching on
    // it needs a fallback (#8212).
    registerFallbackValue(Duration.zero);
  });

  group('two genuine messages sharing their text', () {
    late AppDatabase db;
    late ConversationsDao conversationsDao;
    late DirectMessagesDao messagesDao;
    late _MockNostrClient nostrClient;
    late StreamController<Event> relay;
    late DmRepository repository;
    late Map<String, Event> rumorByWrapId;

    setUp(() async {
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
      // The own kind-10050 resolve reads through queryEventsDetailed (#8212).
      // Answered and empty: the relays replied and there is no list, so the
      // live subscription falls back to the default pool as before.
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
      // stopListening() before closing the stream: onDone would otherwise arm
      // a reconnect timer that outlives this test.
      await repository.stopListening();
      await relay.close();
      await db.close();
    });

    /// Waits for the serialized gift-wrap ingest to drain.
    Future<void> settle() async {
      for (var i = 0; i < 8; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    /// Feeds one NIP-17 gift wrap addressed to the owner, carrying a rumor
    /// authored by [author] (the peer unless overridden).
    Future<void> deliverNip17({
      required String wrapId,
      required String rumorId,
      required String text,
      required int createdAt,
      String author = _peer,
      List<List<String>> tags = const [
        ['p', _owner],
      ],
    }) async {
      rumorByWrapId[wrapId] = Event.fromJson({
        'id': rumorId,
        'pubkey': author,
        'created_at': createdAt,
        'kind': EventKind.privateDirectMessage,
        'tags': tags,
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

    /// Feeds one legacy kind-4 addressed to the owner. The injected decryptor
    /// is the identity, so [text] is both ciphertext and plaintext.
    Future<void> deliverNip04({
      required String id,
      required String text,
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
          'content': text,
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

    test('both are kept when they arrive two seconds apart', () async {
      await deliverNip17(
        wrapId: 'w' * 64,
        rumorId: 'a' * 64,
        text: 'ok',
        createdAt: _baseCreatedAt,
      );
      await deliverNip17(
        wrapId: 'x' * 64,
        rumorId: 'b' * 64,
        text: 'ok',
        createdAt: _baseCreatedAt + 2,
      );

      final stored = await storedMessages();
      expect(
        stored,
        hasLength(2),
        reason:
            'distinct rumor ids two seconds apart are two genuine messages; '
            'collapsing them dropped the second one permanently (#7324)',
      );
      expect(stored.map((m) => m.id), containsAll(['a' * 64, 'b' * 64]));
    });

    test('the cross-protocol twin of the first is still collapsed', () async {
      await deliverNip17(
        wrapId: 'w' * 64,
        rumorId: 'a' * 64,
        text: 'ok',
        createdAt: _baseCreatedAt,
      );
      // The dual-send's legacy copy: same text, a second later, unrelated id.
      await deliverNip04(
        id: 'c' * 64,
        text: 'ok',
        createdAt: _baseCreatedAt + 1,
      );

      expect(
        await storedMessages(),
        hasLength(1),
        reason: 'the protection #7324 must not cost: one message, one bubble',
      );
    });

    // A group send publishes one rumor per recipient — distinct ids, but a
    // single persisted row keyed to the first live success. The rumor-id
    // primary key therefore collapses only the first sibling's self-wrap
    // echo; the rest must be caught by the batch token.
    //
    // Recreates the conversation the send path leaves behind. Without it the
    // echoes resolve to a degenerate [self, self] pair and are discarded
    // before any dedup runs.
    Future<void> seedGroupSend() async {
      final participants = [_owner, _peer, _peer2]..sort();
      await conversationsDao.upsertConversation(
        id: DmRepository.computeConversationId(participants),
        participantPubkeys: jsonEncode(participants),
        isGroup: true,
        createdAt: _baseCreatedAt,
        ownerPubkey: _owner,
      );
    }

    Future<void> deliverSiblingEchoes({String? batchToken}) async {
      List<List<String>> tagsFor(String first, String second) => [
        ['p', first],
        ['p', second],
        if (batchToken != null) ['batch', batchToken],
      ];

      // Sibling rumors differ only in p-tag order, which is enough to give
      // them distinct ids while sharing content and the batch timestamp.
      await deliverNip17(
        wrapId: 'e' * 64,
        rumorId: '1' * 64,
        text: 'ok',
        createdAt: _baseCreatedAt,
        author: _owner,
        tags: tagsFor(_peer, _peer2),
      );
      await deliverNip17(
        wrapId: 'f' * 64,
        rumorId: '2' * 64,
        text: 'ok',
        createdAt: _baseCreatedAt,
        author: _owner,
        tags: tagsFor(_peer2, _peer),
      );
    }

    test(
      'sibling self-wrap echoes of one group send collapse to one row',
      () async {
        final batchToken = 'd' * 64;
        await seedGroupSend();
        await deliverSiblingEchoes(batchToken: batchToken);

        expect(
          await storedMessages(),
          hasLength(1),
          reason:
              'one group send is one bubble on the sender device, however many '
              'siblings its fan-out published',
        );
      },
    );

    test('legacy group echoes with no batch token still collapse', () async {
      await seedGroupSend();
      await deliverSiblingEchoes();

      expect(
        await storedMessages(),
        hasLength(1),
        reason:
            'a send enqueued before the durable batch token existed (#6046) '
            'falls back to the legacy content window',
      );
    });
  });
}
