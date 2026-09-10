// ABOUTME: Regression coverage for #8001 — a future-dated NIP-04 DM must not
// ABOUTME: raise the conversation's last_message_timestamp above now, because
// ABOUTME: the upsert's read gate would then never flip it unread again.

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

// Year 2100 — unconditionally beyond any plausible clock skew.
const _year2100 = 4102444800;

void main() {
  setUpAll(() {
    // queryEventsDetailed takes a `Duration timeout`, so a stub matching on
    // it needs a fallback (#8212).
    registerFallbackValue(Duration.zero);
  });

  group('a future-dated NIP-04 DM cannot freeze the unread badge', () {
    late AppDatabase db;
    late ConversationsDao conversationsDao;
    late DirectMessagesDao messagesDao;
    late _MockNostrClient nostrClient;
    late StreamController<Event> relay;
    late DmRepository repository;

    setUp(() async {
      db = AppDatabase.test(NativeDatabase.memory());
      conversationsDao = ConversationsDao(db);
      messagesDao = DirectMessagesDao(db);
      nostrClient = _MockNostrClient();
      relay = StreamController<Event>();

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
        // Every kind 4 in this group decrypts to its own ciphertext, so the
        // cross-protocol dedup window never collapses two distinct messages.
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

    /// Feeds one kind 4 addressed to the owner through the live subscription
    /// and waits for the serialized ingest to drain.
    Future<void> deliver({required String id, required int createdAt}) async {
      relay.add(
        Event.fromJson({
          'id': id,
          'pubkey': _peer,
          'created_at': createdAt,
          'kind': EventKind.directMessage,
          'tags': [
            ['p', _owner],
          ],
          'content': 'ciphertext-$id',
          'sig': '',
        }),
      );
      for (var i = 0; i < 8; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    /// Waits until the local clock crosses into the next second.
    ///
    /// Nostr timestamps are second-resolution and the DAO's read gate is a
    /// strict `>`, so a bounded forged message and an honest one delivered in
    /// the same second are indistinguishable to it. Bounded by one second.
    Future<void> nextSecond() async {
      final start = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      while (DateTime.now().millisecondsSinceEpoch ~/ 1000 == start) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    }

    final conversationId = DmRepository.computeConversationId([_owner, _peer]);

    Future<ConversationRow> conversation() async {
      final row = await conversationsDao.getConversation(
        conversationId,
        ownerPubkey: _owner,
      );
      return row!;
    }

    test('its timestamp is bounded to now on the conversation row', () async {
      await deliver(id: 'a' * 64, createdAt: _year2100);

      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final row = await conversation();
      expect(row.lastMessageTimestamp, closeTo(nowSec, 5));
      expect(row.createdAt, closeTo(nowSec, 5));
    });

    test(
      'a later genuine message still flips the thread back to unread',
      () async {
        // The user-visible failure: once last_message_timestamp holds a forged
        // future value, `incomingIsNewer` is false for every honest message
        // that follows, so is_read is never cleared and the preview freezes.
        await deliver(id: 'a' * 64, createdAt: _year2100);
        await conversationsDao.markAsRead(conversationId, ownerPubkey: _owner);
        expect((await conversation()).isRead, isTrue);

        await nextSecond();
        await deliver(
          id: 'b' * 64,
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );

        final row = await conversation();
        expect(row.isRead, isFalse);
        expect(row.lastMessageContent, 'ciphertext-${'b' * 64}');
      },
    );

    test('the read cursor is not dragged into the future', () async {
      await deliver(id: 'a' * 64, createdAt: _year2100);
      await conversationsDao.markAsRead(conversationId, ownerPubkey: _owner);

      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      expect((await conversation()).lastReadTimestamp, closeTo(nowSec, 5));
    });

    test('an honestly-dated message keeps its own timestamp', () async {
      const sentAt = 1700000000;
      await deliver(id: 'c' * 64, createdAt: sentAt);

      final row = await conversation();
      expect(row.lastMessageTimestamp, sentAt);
      final message = await messagesDao.getMessageById('c' * 64);
      expect(message!.createdAt, sentAt);
    });
  });
}
