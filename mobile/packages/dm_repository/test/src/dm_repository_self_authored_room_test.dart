// ABOUTME: Regression coverage for #8271 — a NIP-17 rumor the signed-in user
// ABOUTME: authored is stored in the room its pubkey + p tags name, even on an
// ABOUTME: install that holds no conversation row for that room yet.

import 'dart:async';
import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/nip59/gift_wrap_util.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';

class _MockNostrClient extends Mock implements NostrClient {}

// Real key pairs: every gift wrap below is sealed, signed and decrypted for
// real, so each pubkey has to belong to its secret.
final String _ownerSecret = '1' * 64;
final String _aliceSecret = '2' * 64;
final String _bobSecret = '3' * 64;
final String _owner = getPublicKey(_ownerSecret);
final String _alice = getPublicKey(_aliceSecret);
final String _bob = getPublicKey(_bobSecret);

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
    // queryEventsDetailed takes a `Duration timeout`, so a stub matching on
    // it needs a fallback (#8212).
    registerFallbackValue(Duration.zero);
  });

  // Real DAOs over a real database, and real gift wraps through the real
  // decrypt: the participant resolver reads the conversations table, so a
  // mocked DAO would answer whatever the test told it to.
  group('a NIP-17 rumor arriving on an install with no conversations', () {
    late AppDatabase db;
    late ConversationsDao conversationsDao;
    late DirectMessagesDao messagesDao;
    late ProcessedGiftWrapsDao processedDao;
    late _MockNostrClient nostrClient;
    late StreamController<Event> relay;
    late DmRepository repository;

    setUp(() async {
      db = AppDatabase.test(NativeDatabase.memory());
      conversationsDao = ConversationsDao(db);
      messagesDao = DirectMessagesDao(db);
      processedDao = ProcessedGiftWrapsDao(db);
      nostrClient = _MockNostrClient();
      relay = StreamController<Event>();

      when(() => nostrClient.connectedRelayCount).thenReturn(1);
      when(() => nostrClient.configuredRelayCount).thenReturn(1);
      // The own kind-10050 resolve. Answered and empty: the live subscription
      // reads the default pool.
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
        (_) async => (
          events: const <Event>[],
          timedOut: false,
          noRelays: false,
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
        signer: LocalNostrSigner(_ownerSecret),
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

    /// The rumor Divine's own group send builds for the room: the production
    /// builder's tags (one `p` per recipient, the sender left out) plus the
    /// `batch` token `sendGroupMessage` adds.
    Event ownGroupSend() =>
        NIP17MessageService(
          signer: LocalNostrSigner(_ownerSecret),
          senderPublicKey: _owner,
          nostrService: nostrClient,
        ).buildGroupRumor(
          recipientPubkeys: [_alice, _bob],
          content: 'hello room',
          additionalTags: [
            ['batch', 'd' * 64],
          ],
          createdAt: _sentAt,
        );

    /// A kind-14 rumor by [author] with one `p` tag per entry of [pTags], as
    /// another member or another client writes it.
    Event roomMessage({
      required String author,
      required List<String> pTags,
    }) => Event(
      author,
      EventKind.privateDirectMessage,
      [
        for (final pubkey in pTags) ['p', pubkey],
      ],
      'a room message',
      createdAt: _sentAt,
    );

    /// Completes once the receive path has settled the gift wrap [id]: stored
    /// as a message, or written to the processed ledger. Those are the two
    /// places the pre-decrypt dedup reads, so every terminal outcome reaches
    /// one of them.
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

    /// Seals [rumor] with [authorSecret] and gift-wraps it to the owner, the
    /// way the author's client publishes the owner's copy, then feeds it to
    /// the live subscription and waits for it to settle.
    Future<Event> deliver(Event rumor, {required String authorSecret}) async {
      final wrap = await buildGiftWrapFromHex(
        senderPrivateKeyHex: authorSecret,
        rumorJson: rumor.toJson(),
        receiverPublicKey: _owner,
      );
      relay.add(wrap!);
      await settled(wrap.id);
      return wrap;
    }

    Future<List<ConversationRow>> conversations() =>
        conversationsDao.getAllConversations(ownerPubkey: _owner);

    Future<List<String>> messageIdsIn(String conversationId) async {
      final rows = await messagesDao.getMessagesForConversation(
        conversationId,
        ownerPubkey: _owner,
      );
      return [for (final row in rows) row.id];
    }

    /// The room is the only conversation, names all three members, and holds
    /// exactly [messageIds].
    Future<void> expectOnlyTheRoomHolding(List<String> messageIds) async {
      final stored = await conversations();
      expect(
        stored.map((conversation) => conversation.id),
        equals([_roomId]),
        reason: 'the message belongs to the room its pubkey + p tags name',
      );
      expect(stored.single.isGroup, isTrue);
      expect(
        jsonDecode(stored.single.participantPubkeys),
        unorderedEquals([_owner, _alice, _bob]),
      );
      expect(await messageIdsIn(_roomId), unorderedEquals(messageIds));
    }

    group('authored by the signed-in user', () {
      test('is stored in the room when built by a Divine group send', () async {
        final rumor = ownGroupSend();

        final wrap = await deliver(rumor, authorSecret: _ownerSecret);

        await expectOnlyTheRoomHolding([rumor.id]);
        expect(
          await processedDao.hasGiftWrap(wrap.id),
          isFalse,
          reason:
              'a ledgered wrap is skipped before decryption on every later '
              'launch, so writing the message off there loses it for good',
        );
      });

      test('is stored in the room when built by another client', () async {
        // No batch token, and the sender listed among its own p tags.
        final rumor = roomMessage(
          author: _owner,
          pTags: [_owner, _alice, _bob],
        );

        final wrap = await deliver(rumor, authorSecret: _ownerSecret);

        await expectOnlyTheRoomHolding([rumor.id]);
        expect(await processedDao.hasGiftWrap(wrap.id), isFalse);
      });

      test('is stored once when both of its self-copies arrive', () async {
        // One group send wraps its one rumor to the sender once per
        // recipient: the same rumor id under two gift-wrap ids.
        final rumor = ownGroupSend();

        final first = await deliver(rumor, authorSecret: _ownerSecret);
        final second = await deliver(rumor, authorSecret: _ownerSecret);

        expect(second.id, isNot(equals(first.id)));
        await expectOnlyTheRoomHolding([rumor.id]);
      });

      test("is joined in the room by a member's later message", () async {
        final own = ownGroupSend();
        final fromAlice = roomMessage(author: _alice, pTags: [_owner, _bob]);

        await deliver(own, authorSecret: _ownerSecret);
        await deliver(fromAlice, authorSecret: _aliceSecret);

        await expectOnlyTheRoomHolding([own.id, fromAlice.id]);
      });

      test('is discarded when its p tag only respells its sender', () async {
        // Upper-case hex is the same key, so this is a room of one: a
        // self-addressed conversation, which Divine does not keep (#8351).
        final rumor = roomMessage(
          author: _owner,
          pTags: [_owner.toUpperCase()],
        );

        final wrap = await deliver(rumor, authorSecret: _ownerSecret);

        expect(await conversations(), isEmpty);
        expect(await processedDao.hasGiftWrap(wrap.id), isTrue);
      });
    });

    group('authored by a peer', () {
      test('is still filed under the 1:1 with that peer', () async {
        // The phantom-group guard: an extra p tag on a peer's rumor does not
        // open a group this install has never seen (#2740).
        final rumor = roomMessage(author: _alice, pTags: [_owner, _bob]);
        final oneToOne = DmRepository.computeConversationId([_owner, _alice]);

        await deliver(rumor, authorSecret: _aliceSecret);

        final stored = await conversations();
        expect(
          stored.map((conversation) => conversation.id),
          equals([oneToOne]),
        );
        expect(stored.single.isGroup, isFalse);
        expect(
          jsonDecode(stored.single.participantPubkeys),
          unorderedEquals([_owner, _alice]),
        );
        expect(await messageIdsIn(oneToOne), equals([rumor.id]));
      });
    });
  });
}
