// ABOUTME: Regression coverage for #7338 — a NIP-17 rumor a peer authored that
// ABOUTME: names three or more participants is filed as the room its pubkey +
// ABOUTME: p tags name, unless it is a mention reply or does not name the user.

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
final String _carolSecret = '4' * 64;
final String _owner = getPublicKey(_ownerSecret);
final String _alice = getPublicKey(_aliceSecret);
final String _bob = getPublicKey(_bobSecret);
final String _carol = getPublicKey(_carolSecret);

final String _roomId = DmRepository.computeConversationId([
  _owner,
  _alice,
  _bob,
]);

const _sentAt = 1700000000;

/// NIP-17's bound on a chat room (17.md:106), restated rather than read from
/// the repository so a changed production constant fails these tests.
const _roomCap = 10;

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
  // decrypt: the participant resolver reads the conversations and messages
  // tables, so a mocked DAO would answer whatever the test told it to.
  group('a NIP-17 rumor authored by a peer', () {
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
        removedConversationsDao: RemovedConversationsDao(db),
        reactionsRepository: DmReactionsRepository(
          reactionsDao: DmReactionsDao(db),
          conversationsDao: conversationsDao,
          directMessagesDao: messagesDao,
          userPubkey: _owner,
        ),
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

    /// A kind-14 rumor by [author] with one `p` tag per entry of [pTags],
    /// followed by [extraTags], as another member or another client writes it.
    Event message({
      required String author,
      required List<String> pTags,
      String content = 'a room message',
      List<List<String>> extraTags = const [],
      int createdAt = _sentAt,
    }) => Event(
      author,
      EventKind.privateDirectMessage,
      [
        for (final pubkey in pTags) ['p', pubkey],
        ...extraTags,
      ],
      content,
      createdAt: createdAt,
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
    Future<void> deliver(Event rumor, {required String authorSecret}) async {
      final wrap = await buildGiftWrapFromHex(
        senderPrivateKeyHex: authorSecret,
        rumorJson: rumor.toJson(),
        receiverPublicKey: _owner,
      );
      relay.add(wrap!);
      await settled(wrap.id);
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

    List<String> participantsOf(ConversationRow conversation) =>
        (jsonDecode(conversation.participantPubkeys) as List).cast<String>();

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
        participantsOf(stored.single),
        unorderedEquals([_owner, _alice, _bob]),
      );
      expect(await messageIdsIn(_roomId), unorderedEquals(messageIds));
    }

    /// The 1:1 with [peer] is the only conversation, holds exactly
    /// [messageIds], and is not a group.
    Future<void> expectOnlyTheOneToOneHolding(
      String peer,
      List<String> messageIds,
    ) async {
      final oneToOneId = DmRepository.computeConversationId([_owner, peer]);
      final stored = await conversations();
      expect(
        stored.map((conversation) => conversation.id),
        equals([oneToOneId]),
      );
      expect(stored.single.isGroup, isFalse);
      expect(participantsOf(stored.single), unorderedEquals([_owner, peer]));
      expect(await messageIdsIn(oneToOneId), unorderedEquals(messageIds));
    }

    group('that names the user and a third member', () {
      test('is filed as a room when no conversation exists yet', () async {
        final rumor = message(author: _alice, pTags: [_owner, _bob]);

        await deliver(rumor, authorSecret: _aliceSecret);

        await expectOnlyTheRoomHolding([rumor.id]);
      });

      for (final (first, second) in [
        ('alice', 'bob'),
        ('bob', 'alice'),
      ]) {
        test('files both messages in one room when $first speaks '
            'before $second', () async {
          final secrets = {'alice': _aliceSecret, 'bob': _bobSecret};
          final pubkeys = {'alice': _alice, 'bob': _bob};
          final other = {'alice': _bob, 'bob': _alice};
          final firstRumor = message(
            author: pubkeys[first]!,
            pTags: [_owner, other[first]!],
            content: 'from $first',
          );
          final secondRumor = message(
            author: pubkeys[second]!,
            pTags: [_owner, other[second]!],
            content: 'from $second',
          );

          await deliver(firstRumor, authorSecret: secrets[first]!);
          await deliver(secondRumor, authorSecret: secrets[second]!);

          await expectOnlyTheRoomHolding([firstRumor.id, secondRumor.id]);
        });
      }

      test('is stored in a room that already exists', () async {
        await conversationsDao.upsertConversation(
          id: _roomId,
          participantPubkeys: jsonEncode([_owner, _alice, _bob]..sort()),
          isGroup: true,
          createdAt: _sentAt - 10,
          ownerPubkey: _owner,
          dmProtocol: 'nip17',
        );
        final rumor = message(author: _alice, pTags: [_owner, _bob]);

        await deliver(rumor, authorSecret: _aliceSecret);

        await expectOnlyTheRoomHolding([rumor.id]);
      });

      test('keeps the subject its first message carries', () async {
        final rumor = message(
          author: _alice,
          pTags: [_owner, _bob],
          extraTags: [
            ['subject', 'Weekend trip'],
          ],
        );

        await deliver(rumor, authorSecret: _aliceSecret);

        final room = await conversationsDao.getConversation(
          _roomId,
          ownerPubkey: _owner,
        );
        expect(room, isNotNull);
        expect(room!.subject, equals('Weekend trip'));
      });

      test('is filed as a room when it replies to a message this install '
          'does not hold', () async {
        final rumor = message(
          author: _alice,
          pTags: [_owner, _bob],
          extraTags: [
            ['e', 'f' * 64],
          ],
        );

        await deliver(rumor, authorSecret: _aliceSecret);

        await expectOnlyTheRoomHolding([rumor.id]);
      });

      test(
        'is filed as a room when it replies to a message in a one-to-one '
        'that the room does not contain',
        () async {
          final aboutCarol = message(
            author: _carol,
            pTags: [_owner],
            content: 'a different thread',
          );
          await deliver(aboutCarol, authorSecret: _carolSecret);
          final rumor = message(
            author: _alice,
            pTags: [_owner, _bob],
            extraTags: [
              ['e', aboutCarol.id],
            ],
          );

          await deliver(rumor, authorSecret: _aliceSecret);

          expect(await messageIdsIn(_roomId), equals([rumor.id]));
          expect(
            await messageIdsIn(
              DmRepository.computeConversationId([_owner, _carol]),
            ),
            equals([aboutCarol.id]),
          );
        },
      );
    });

    group('that replies into a smaller conversation', () {
      test('stays in the one-to-one it mentions a third member from', () async {
        final first = message(
          author: _alice,
          pTags: [_owner],
          content: 'just the two of us',
        );
        await deliver(first, authorSecret: _aliceSecret);
        final mention = message(
          author: _alice,
          pTags: [_owner, _bob],
          content: 'cc bob',
          createdAt: _sentAt + 1,
          extraTags: [
            ['e', first.id],
          ],
        );

        await deliver(mention, authorSecret: _aliceSecret);

        await expectOnlyTheOneToOneHolding(_alice, [first.id, mention.id]);
      });
    });

    group('that replies to a message in a conversation it cannot read', () {
      /// Stores a message by Alice in [conversationId] without making a
      /// conversation row for it, and returns the message.
      Future<String> storeParentIn(String conversationId) async {
        const parentId = 'e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0';
        await messagesDao.insertMessage(
          id: parentId,
          conversationId: conversationId,
          senderPubkey: _alice,
          content: 'an older message',
          createdAt: _sentAt - 10,
          giftWrapId: 'wrap-$parentId',
          ownerPubkey: _owner,
        );
        return parentId;
      }

      Future<void> deliverReplyToAndExpectRoom(String parentId) async {
        final rumor = message(
          author: _alice,
          pTags: [_owner, _bob],
          extraTags: [
            ['e', parentId],
          ],
        );

        await deliver(rumor, authorSecret: _aliceSecret);

        expect(await messageIdsIn(_roomId), equals([rumor.id]));
      }

      for (final (description, participantPubkeys) in [
        ('is not JSON', '{not json'),
        ('is not a list', '{"a": 1}'),
        ('holds something other than pubkeys', '[1, 2]'),
      ]) {
        test(
          'is filed as a room when the participant list $description',
          () async {
            await conversationsDao.upsertConversation(
              id: 'unreadable',
              participantPubkeys: participantPubkeys,
              isGroup: false,
              createdAt: _sentAt - 10,
              ownerPubkey: _owner,
            );
            final parentId = await storeParentIn('unreadable');

            await deliverReplyToAndExpectRoom(parentId);
          },
        );
      }

      test('is filed as a room when that conversation is gone', () async {
        final parentId = await storeParentIn('gone');

        await deliverReplyToAndExpectRoom(parentId);
      });
    });

    group('that names as many people as the room cap allows', () {
      /// [count] distinct pubkeys that are neither the user nor Alice.
      List<String> others(int count) => [
        for (var i = 0; i < count; i++)
          getPublicKey((i + 5).toRadixString(16).padLeft(64, '0')),
      ];

      /// The room of [others] plus the user and Alice, so [others] is the
      /// number of participants minus two.
      String roomOf(List<String> others) =>
          DmRepository.computeConversationId([_owner, _alice, ...others]);

      test('is filed as a room at exactly the cap', () async {
        final members = others(_roomCap - 2);
        final rumor = message(author: _alice, pTags: [_owner, ...members]);

        await deliver(rumor, authorSecret: _aliceSecret);

        final stored = await conversations();
        expect(stored.map((conversation) => conversation.id), [
          roomOf(members),
        ]);
        expect(stored.single.isGroup, isTrue);
        expect(
          participantsOf(stored.single),
          hasLength(_roomCap),
        );
        expect(await messageIdsIn(roomOf(members)), equals([rumor.id]));
      });

      test('stays in the one-to-one with its sender above the cap', () async {
        final members = others(_roomCap - 1);
        final rumor = message(author: _alice, pTags: [_owner, ...members]);

        await deliver(rumor, authorSecret: _aliceSecret);

        await expectOnlyTheOneToOneHolding(_alice, [rumor.id]);
      });

      test('is stored in an existing room above the cap', () async {
        final members = others(_roomCap - 1);
        final roomId = roomOf(members);
        await conversationsDao.upsertConversation(
          id: roomId,
          participantPubkeys: jsonEncode([_owner, _alice, ...members]..sort()),
          isGroup: true,
          createdAt: _sentAt - 10,
          ownerPubkey: _owner,
          dmProtocol: 'nip17',
        );
        final rumor = message(author: _alice, pTags: [_owner, ...members]);

        await deliver(rumor, authorSecret: _aliceSecret);

        expect(await messageIdsIn(roomId), equals([rumor.id]));
        expect(await conversations(), hasLength(1));
      });

      test('is filed as a room above the cap when the user wrote it', () async {
        final members = [
          _alice,
          ...others(_roomCap - 1),
        ];
        final rumor = message(author: _owner, pTags: members);
        final roomId = DmRepository.computeConversationId([_owner, ...members]);

        await deliver(rumor, authorSecret: _ownerSecret);

        final stored = await conversations();
        expect(stored.map((conversation) => conversation.id), [roomId]);
        expect(stored.single.isGroup, isTrue);
        expect(await messageIdsIn(roomId), equals([rumor.id]));
      });
    });

    group('that does not name the user', () {
      test('is filed under the one-to-one with its sender', () async {
        final rumor = message(author: _alice, pTags: [_bob, _carol]);

        await deliver(rumor, authorSecret: _aliceSecret);

        await expectOnlyTheOneToOneHolding(_alice, [rumor.id]);
      });
    });

    group('that spells the user key in other letter case', () {
      test('is filed as a room, since the key is the same', () async {
        final rumor = message(
          author: _alice,
          pTags: [_owner.toUpperCase(), _bob],
        );

        await deliver(rumor, authorSecret: _aliceSecret);

        final stored = await conversations();
        expect(stored, hasLength(1));
        expect(stored.single.isGroup, isTrue);
        expect(await messageIdsIn(stored.single.id), equals([rumor.id]));
      });
    });

    group('that names only the user', () {
      test('is filed under the one-to-one with its sender', () async {
        final rumor = message(author: _alice, pTags: [_owner]);

        await deliver(rumor, authorSecret: _aliceSecret);

        await expectOnlyTheOneToOneHolding(_alice, [rumor.id]);
      });
    });

    group('next to a rumor the user authored', () {
      test('both land in the room', () async {
        final own =
            NIP17MessageService(
              signer: LocalNostrSigner(_ownerSecret),
              senderPublicKey: _owner,
              nostrService: nostrClient,
            ).buildGroupRumor(
              recipientPubkeys: [_alice, _bob],
              content: 'hello room',
              createdAt: _sentAt,
            );
        final fromAlice = message(author: _alice, pTags: [_owner, _bob]);

        await deliver(own, authorSecret: _ownerSecret);
        await deliver(fromAlice, authorSecret: _aliceSecret);

        await expectOnlyTheRoomHolding([own.id, fromAlice.id]);
      });
    });

    group('that names a room the user removed', () {
      test('is suppressed when the history replays, not refiled as a '
          'one-to-one', () async {
        final before = message(author: _alice, pTags: [_owner, _bob]);
        await deliver(before, authorSecret: _aliceSecret);
        await expectOnlyTheRoomHolding([before.id]);
        expect(
          await repository.removeConversation(_roomId),
          ConversationRemovalOutcome.removed,
        );

        final replayed = message(
          author: _bob,
          pTags: [_owner, _alice],
          content: 'an older message of the same room',
        );
        await deliver(replayed, authorSecret: _bobSecret);

        expect(
          await conversations(),
          isEmpty,
          reason: 'the removal is keyed by the room id the message resolves to',
        );
        expect(await messageIdsIn(_roomId), isEmpty);
      });
    });
  });
}
