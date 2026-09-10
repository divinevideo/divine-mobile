// ABOUTME: Regression coverage for #8211 — an own-send row written before
// ABOUTME: #2654 carries the NIP-04 id shape and must not grow a duplicate.

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

  // Drives the real DirectMessagesDao against a real database. The
  // mock suite stubs hasMatchingMessage to a constant in its top-level
  // setUp, so a test written there cannot observe this at all (#8170).
  group('an own-send row carrying the pre-#2654 id shape', () {
    late AppDatabase db;
    late ConversationsDao conversationsDao;
    late DirectMessagesDao messagesDao;
    late _MockNostrClient nostrClient;
    late StreamController<Event> relay;
    late DmRepository repository;

    final participants = [_owner, _peer]..sort();
    late String conversationId;

    setUp(() async {
      db = AppDatabase.test(NativeDatabase.memory());
      conversationsDao = ConversationsDao(db);
      messagesDao = DirectMessagesDao(db);
      nostrClient = _MockNostrClient();
      relay = StreamController<Event>();
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
        userPubkey: _owner,
        signer: LocalNostrSigner(_privateKey),
        rumorDecryptor: (_, _) async => null,
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

    /// Persists one own-send row. [legacyShape] reproduces every NIP-17 send
    /// path before `d9846bb5d` (#2654, 2026-04-01), which wrote the gift-wrap
    /// id into BOTH columns; the modern shape writes a distinct rumor id.
    Future<void> persistOwnSend({
      required String content,
      required bool legacyShape,
    }) async {
      const wrapId =
          'ffffffffffffffffffffffffffffffffffffffffffffffffffffffff'
          'ffffffff';
      await conversationsDao.upsertConversation(
        id: conversationId,
        participantPubkeys: participants.join(','),
        isGroup: false,
        createdAt: _baseCreatedAt,
        lastMessageTimestamp: _baseCreatedAt,
        ownerPubkey: _owner,
      );
      await messagesDao.insertMessage(
        id: legacyShape ? wrapId : 'a' * 64,
        conversationId: conversationId,
        senderPubkey: _owner,
        content: content,
        createdAt: _baseCreatedAt,
        giftWrapId: wrapId,
        ownerPubkey: _owner,
      );
    }

    /// Replays the user's own outgoing kind-4 fallback, the way the history
    /// drain's `_recoverOutgoingNip04` does.
    Future<void> replayOwnNip04({required String content}) async {
      relay.add(
        Event.fromJson({
          'id': 'c' * 64,
          'pubkey': _owner,
          'created_at': _baseCreatedAt + 1,
          'kind': EventKind.directMessage,
          'tags': [
            ['p', _peer],
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

    test('does not grow a duplicate when its own kind-4 is replayed', () async {
      await persistOwnSend(content: 'ok', legacyShape: true);
      expect(await storedCount(), 1);

      await replayOwnNip04(content: 'ok');

      expect(
        await storedCount(),
        1,
        reason:
            'the legacy row is the same message, so the replayed kind-4 must '
            'collapse onto it rather than insert a second bubble (#8211)',
      );
    });

    test('collapses the modern-shaped own-send row too', () async {
      // Control: the same replay against a row written after #2654. This
      // already worked, and must keep working — it proves the test above
      // fails for the id shape, not for own-send collapse generally.
      await persistOwnSend(content: 'ok', legacyShape: false);
      expect(await storedCount(), 1);

      await replayOwnNip04(content: 'ok');

      expect(await storedCount(), 1);
    });

    test("still keeps a peer's genuine repeat over NIP-04 (#7324)", () async {
      // The peer path must stay untouched by the own-send exemption: two
      // genuine kind-4 messages carrying the same text both survive.
      await conversationsDao.upsertConversation(
        id: conversationId,
        participantPubkeys: participants.join(','),
        isGroup: false,
        createdAt: _baseCreatedAt,
        lastMessageTimestamp: _baseCreatedAt,
        ownerPubkey: _owner,
      );
      await messagesDao.insertMessage(
        id: 'd' * 64,
        conversationId: conversationId,
        senderPubkey: _peer,
        content: 'ok',
        createdAt: _baseCreatedAt,
        giftWrapId: 'd' * 64,
        ownerPubkey: _owner,
      );

      relay.add(
        Event.fromJson({
          'id': 'e' * 64,
          'pubkey': _peer,
          'created_at': _baseCreatedAt + 2,
          'kind': EventKind.directMessage,
          'tags': [
            ['p', _owner],
          ],
          'content': 'ok',
          'sig': '',
        }),
      );
      await settle();

      expect(
        await storedCount(),
        2,
        reason: 'a genuine second message from the peer must survive (#7324)',
      );
    });
  });
}
