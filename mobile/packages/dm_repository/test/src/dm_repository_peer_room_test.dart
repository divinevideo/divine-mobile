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
import 'package:models/models.dart' show NIP17SendResult;
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/nip59/gift_wrap_util.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _FakeEvent extends Fake implements Event {}

/// Pins the removal to the send's second, moved by [offset] seconds, without
/// relying on wall-clock timing. A negative [offset] puts the leave before the
/// send; a positive one puts it after the send's stamp, as a clock set back
/// between the two does. All storage, signing, and receive behavior remains
/// real.
class _RemovalPinnedToSendDao extends RemovedConversationsDao {
  _RemovalPinnedToSendDao(super.attachedDatabase, {this.offset = 0});

  /// Seconds from the send's stamp to the removal.
  final int offset;

  @override
  Future<bool> markRejoined({
    required String conversationId,
    required String ownerPubkey,
    required int at,
    bool isLocalSend = false,
  }) async {
    await record(
      conversationId: conversationId,
      ownerPubkey: ownerPubkey,
      removedAt: at + offset,
    );
    return super.markRejoined(
      conversationId: conversationId,
      ownerPubkey: ownerPubkey,
      at: at,
      isLocalSend: isLocalSend,
    );
  }
}

/// A send queue that runs [afterFirstEnqueue] once, right after it queues the
/// first member's copy of a send, before the next copy is queued.
class _QueueWithHook extends OutgoingDmsDao {
  _QueueWithHook(super.attachedDatabase);

  Future<void> Function()? afterFirstEnqueue;
  final enqueued = <OutgoingDm>[];

  @override
  Future<void> enqueue(OutgoingDm dm) async {
    await super.enqueue(dm);
    enqueued.add(dm);
    final hook = afterFirstEnqueue;
    afterFirstEnqueue = null;
    await hook?.call();
  }
}

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

/// The relay that confirms the wraps of a send from this device.
const _pool = 'wss://relay.divine.video';

/// The receive path's room cap, the size above which NIP-17 advises another
/// messaging scheme. Restated rather than read from the repository so a
/// changed production constant fails these tests.
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
    // The production switch is the groupMessages flag. On here, because every
    // group below but one describes receiving a room.
    late bool receivesPeerRooms;

    setUp(() async {
      receivesPeerRooms = true;
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
          onStoredEventsStart: any(named: 'onStoredEventsStart'),
          onStoredEventsEnd: any(named: 'onStoredEventsEnd'),
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
        receivesPeerRooms: () => receivesPeerRooms,
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

    group('while receiving rooms is switched off', () {
      setUp(() => receivesPeerRooms = false);

      test('is the default when no switch is injected', () {
        final unwired = DmRepository(
          nostrClient: nostrClient,
          directMessagesDao: messagesDao,
          conversationsDao: conversationsDao,
          userPubkey: _owner,
        );

        expect(unwired.receivesPeerRooms, isFalse);
        expect(repository.receivesPeerRooms, isFalse);
      });

      test('stays in the one-to-one with its sender', () async {
        final rumor = message(author: _alice, pTags: [_owner, _bob]);

        await deliver(rumor, authorSecret: _aliceSecret);

        await expectOnlyTheOneToOneHolding(_alice, [rumor.id]);
      });

      test('is still stored in a room that already exists', () async {
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

      test('reads the switch for each rumor', () async {
        final before = message(
          author: _alice,
          pTags: [_owner, _bob],
          content: 'before the switch',
        );
        await deliver(before, authorSecret: _aliceSecret);
        await expectOnlyTheOneToOneHolding(_alice, [before.id]);

        receivesPeerRooms = true;
        final after = message(
          author: _bob,
          pTags: [_owner, _alice],
          content: 'after the switch',
        );
        await deliver(after, authorSecret: _bobSecret);

        expect(await messageIdsIn(_roomId), equals([after.id]));
      });
    });

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

      test('stays in the room it mentions a fourth person from', () async {
        final first = message(author: _alice, pTags: [_owner, _bob]);
        await deliver(first, authorSecret: _aliceSecret);
        final mention = message(
          author: _bob,
          pTags: [_owner, _alice, _carol],
          content: 'cc carol',
          createdAt: _sentAt + 1,
          extraTags: [
            ['e', first.id],
          ],
        );

        await deliver(mention, authorSecret: _bobSecret);

        await expectOnlyTheRoomHolding([first.id, mention.id]);
      });

      test('stays out of a one-to-one its sender is not part of', () async {
        final first = message(
          author: _alice,
          pTags: [_owner],
          content: 'just the two of us',
        );
        await deliver(first, authorSecret: _aliceSecret);
        final fromOutside = message(
          author: _bob,
          pTags: [_owner, _alice],
          content: 'answering a thread I am not in',
          createdAt: _sentAt + 1,
          extraTags: [
            ['e', first.id],
          ],
        );

        await deliver(fromOutside, authorSecret: _bobSecret);

        expect(
          await messageIdsIn(
            DmRepository.computeConversationId([_owner, _alice]),
          ),
          equals([first.id]),
          reason: 'only the two people in a one-to-one can write in it',
        );
        expect(
          await messageIdsIn(
            DmRepository.computeConversationId([_owner, _bob]),
          ),
          equals([fromOutside.id]),
        );
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

    group('that names something other than a pubkey', () {
      // A group send validates every recipient, so a room holding a member
      // that is not a key would refuse every reply the user writes in it.
      for (final (description, notAPubkey) in [
        ('a word', 'not-a-pubkey'),
        ('a truncated key', 'a' * 63),
        ('an empty string', ''),
      ]) {
        test(
          'stays in the one-to-one with its sender for $description',
          () async {
            final rumor = message(author: _alice, pTags: [_owner, notAPubkey]);

            await deliver(rumor, authorSecret: _aliceSecret);

            await expectOnlyTheOneToOneHolding(_alice, [rumor.id]);
          },
        );
      }
    });

    group('that spells the user key in other letter case', () {
      test('is filed in the room the lower-case spelling names', () async {
        final upperCase = message(
          author: _alice,
          pTags: [_owner.toUpperCase(), _bob],
        );
        final lowerCase = message(
          author: _bob,
          pTags: [_owner, _alice],
          content: 'the same room, spelled in lower case',
        );

        await deliver(upperCase, authorSecret: _aliceSecret);
        await deliver(lowerCase, authorSecret: _bobSecret);

        await expectOnlyTheRoomHolding([upperCase.id, lowerCase.id]);
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

      // NIP-01 asks for lower-case keys, but another client on the user's key
      // can still write one in upper case.
      test(
        'both land in the room when the user wrote a key in upper case',
        () async {
          final own = message(
            author: _owner,
            pTags: [_alice.toUpperCase(), _bob],
            content: 'written by another client',
          );
          final fromBob = message(author: _bob, pTags: [_owner, _alice]);

          await deliver(own, authorSecret: _ownerSecret);
          await deliver(fromBob, authorSecret: _bobSecret);

          await expectOnlyTheRoomHolding([own.id, fromBob.id]);
        },
      );

      test('both land in the one-to-one when the user wrote its key in upper '
          'case', () async {
        final own = message(
          author: _owner,
          pTags: [_alice.toUpperCase()],
          content: 'written by another client',
        );
        final fromAlice = message(author: _alice, pTags: [_owner]);

        await deliver(own, authorSecret: _ownerSecret);
        await deliver(fromAlice, authorSecret: _aliceSecret);

        await expectOnlyTheOneToOneHolding(_alice, [own.id, fromAlice.id]);
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

    // Leaving a group sticks until the user writes in it again (#10150).
    group('that names a room the user left', () {
      const leftAt = _sentAt + 100;

      // A send from this device publishes through `any()` Event matchers.
      setUpAll(() => registerFallbackValue(_FakeEvent()));

      Future<RemovedConversation?> tombstone() =>
          RemovedConversationsDao(db).tombstoneFor(
            conversationId: _roomId,
            ownerPubkey: _owner,
          );

      /// Moves the removal of the room to [at]. `removeConversation` stamps
      /// the wall clock, and the receive path clamps a rumor stamped after
      /// now to now, so no rumor could otherwise be newer than the removal.
      Future<void> backdateRemoval(int at) => db.customStatement(
        'UPDATE removed_conversations SET removed_at = ? '
        'WHERE conversation_id = ? AND owner_pubkey = ?',
        [at, _roomId, _owner],
      );

      /// Leaves the room, as the inbox's Leave does, at [at].
      Future<void> leave({int at = leftAt}) async {
        expect(
          await repository.removeConversation(_roomId),
          ConversationRemovalOutcome.removed,
        );
        await backdateRemoval(at);
      }

      /// The room as Alice opened it, before the user left.
      Future<void> joinTheRoom() async {
        final first = message(author: _alice, pTags: [_owner, _bob]);
        await deliver(first, authorSecret: _aliceSecret);
        await expectOnlyTheRoomHolding([first.id]);
      }

      Future<bool> ledgered(Event wrap) => processedDao.hasGiftWrapForOwner(
        giftWrapId: wrap.id,
        ownerPubkey: _owner,
      );

      /// Delivers [rumor] like [deliver], for an outcome that writes nothing:
      /// a message kept out of a group the user has not rejoined is neither
      /// stored nor ledgered. Wraps are handled one at a time, so a wrap of an
      /// unsupported kind delivered after it settles only once it has.
      Future<Event> deliverLeavingNoTrace(
        Event rumor, {
        required String authorSecret,
      }) async {
        final wrap = await buildGiftWrapFromHex(
          senderPrivateKeyHex: authorSecret,
          rumorJson: rumor.toJson(),
          receiverPublicKey: _owner,
        );
        relay.add(wrap!);
        await deliver(
          Event(_carol, EventKind.textNote, [
            ['p', _owner],
          ], 'handled after the wrap above'),
          authorSecret: _carolSecret,
        );
        return wrap;
      }

      /// Feeds [wrap] to the live subscription again, as a relay replays it.
      Future<void> replay(Event wrap) async {
        relay.add(wrap);
        await settled(wrap.id);
      }

      // Not ledgered, so a replay after the user rejoins re-evaluates it.
      test('keeps a newer message from a member out without ledgering '
          'it', () async {
        await joinTheRoom();
        await leave();

        final wrap = await deliverLeavingNoTrace(
          message(
            author: _bob,
            pTags: [_owner, _alice],
            content: 'sent after the user left',
            createdAt: leftAt + 100,
          ),
          authorSecret: _bobSecret,
        );

        expect(await conversations(), isEmpty);
        expect(await messageIdsIn(_roomId), isEmpty);
        expect(await ledgered(wrap), isFalse);
      });

      // Gift wraps are backdated up to two days, so a member's reply can
      // arrive before the user's own copy of the message that rejoined.
      test('lets in a member message kept out before the copy of the message '
          'the user wrote arrived, once it is replayed after it', () async {
        await joinTheRoom();
        await leave();
        final reply = message(
          author: _alice,
          pTags: [_owner, _bob],
          content: 'replied after the user came back',
          createdAt: leftAt + 300,
        );
        final wrap = await deliverLeavingNoTrace(
          reply,
          authorSecret: _aliceSecret,
        );
        expect(await conversations(), isEmpty);

        final own = message(
          author: _owner,
          pTags: [_alice, _bob],
          content: 'back again',
          createdAt: leftAt + 200,
        );
        await deliver(own, authorSecret: _ownerSecret);
        await replay(wrap);

        await expectOnlyTheRoomHolding([own.id, reply.id]);
      });

      test('keeps it out after a batch removal, as declining every '
          'request does', () async {
        await joinTheRoom();
        expect(
          await repository.removeConversations([_roomId]),
          (removed: 1, refused: 0),
        );
        await backdateRemoval(leftAt);

        await deliverLeavingNoTrace(
          message(
            author: _bob,
            pTags: [_owner, _alice],
            createdAt: leftAt + 100,
          ),
          authorSecret: _bobSecret,
        );

        expect(await conversations(), isEmpty);
      });

      test('brings the room back when the user writes in it from another '
          'device, and lets later member messages in', () async {
        await joinTheRoom();
        await leave();

        final own = message(
          author: _owner,
          pTags: [_alice, _bob],
          content: 'back again',
          createdAt: leftAt + 200,
        );
        await deliver(own, authorSecret: _ownerSecret);
        await expectOnlyTheRoomHolding([own.id]);

        final later = message(
          author: _alice,
          pTags: [_owner, _bob],
          content: 'welcome back',
          createdAt: leftAt + 300,
        );
        await deliver(later, authorSecret: _aliceSecret);

        await expectOnlyTheRoomHolding([own.id, later.id]);
        expect((await tombstone())!.rejoinedAt, leftAt + 200);
      });

      // Kept out, but not ledgered: an earlier copy of the user's own may
      // still move the rejoin back before it.
      test('keeps out what a member sent while the user was away, even when '
          'it arrives after they rejoined', () async {
        await joinTheRoom();
        await leave();
        final own = message(
          author: _owner,
          pTags: [_alice, _bob],
          content: 'back again',
          createdAt: leftAt + 200,
        );
        await deliver(own, authorSecret: _ownerSecret);
        await expectOnlyTheRoomHolding([own.id]);

        final whileAway = await deliverLeavingNoTrace(
          message(
            author: _bob,
            pTags: [_owner, _alice],
            content: 'sent while the user was away',
            createdAt: leftAt + 100,
          ),
          authorSecret: _bobSecret,
        );

        await expectOnlyTheRoomHolding([own.id]);
        expect(await ledgered(whileAway), isFalse);
      });

      // The user wrote twice after leaving, from another device, and this one
      // receives the later copy first.
      test(
        'lets in a member reply between two messages the user wrote once '
        'the earlier copy arrives, when the later one arrived first',
        () async {
          await joinTheRoom();
          await leave();
          final second = message(
            author: _owner,
            pTags: [_alice, _bob],
            content: 'second',
            createdAt: leftAt + 300,
          );
          await deliver(second, authorSecret: _ownerSecret);
          await expectOnlyTheRoomHolding([second.id]);

          final reply = message(
            author: _alice,
            pTags: [_owner, _bob],
            content: 'answered the first',
            createdAt: leftAt + 200,
          );
          final wrap = await deliverLeavingNoTrace(
            reply,
            authorSecret: _aliceSecret,
          );
          expect(await messageIdsIn(_roomId), equals([second.id]));
          expect(await ledgered(wrap), isFalse);

          final first = message(
            author: _owner,
            pTags: [_alice, _bob],
            content: 'first',
            createdAt: leftAt + 100,
          );
          await deliver(first, authorSecret: _ownerSecret);
          expect((await tombstone())!.rejoinedAt, leftAt + 100);
          await replay(wrap);

          await expectOnlyTheRoomHolding([first.id, reply.id, second.id]);
        },
      );

      test('keeps the room out again after the user leaves a second '
          'time', () async {
        await joinTheRoom();
        await leave();
        final own = message(
          author: _owner,
          pTags: [_alice, _bob],
          content: 'back again',
          createdAt: leftAt + 200,
        );
        await deliver(own, authorSecret: _ownerSecret);
        await expectOnlyTheRoomHolding([own.id]);

        expect(
          await repository.removeConversation(_roomId),
          ConversationRemovalOutcome.removed,
        );
        expect((await tombstone())!.rejoinedAt, isNull);
        await backdateRemoval(leftAt + 300);

        await deliverLeavingNoTrace(
          message(
            author: _alice,
            pTags: [_owner, _bob],
            content: 'sent after the second leave',
            createdAt: leftAt + 400,
          ),
          authorSecret: _aliceSecret,
        );

        expect(await conversations(), isEmpty);
      });

      /// A repository that can send, sharing the receiving fixture's
      /// database. The relays confirm every wrap, or refuse every one when
      /// [relaysRefuse]; [onRecipientWrap] runs before the first answer, while
      /// the send is still in flight. [outgoingDmsDao] queues the send, as the
      /// app does.
      DmRepository sendingRepository({
        Future<void> Function()? onRecipientWrap,
        RemovedConversationsDao? removalDao,
        bool relaysRefuse = false,
        OutgoingDmsDao? outgoingDmsDao,
      }) {
        when(() => nostrClient.configuredRelays).thenReturn(const [_pool]);
        when(() => nostrClient.isRelayAllowed(any())).thenReturn(true);
        var confirms = 0;
        when(
          () => nostrClient.publishEventAwaitOk(
            any(),
            targetRelays: any(named: 'targetRelays'),
            timeout: any(named: 'timeout'),
            diagnosticTag: any(named: 'diagnosticTag'),
          ),
        ).thenAnswer((invocation) async {
          if (confirms++ == 0) await onRecipientWrap?.call();
          final event = invocation.positionalArguments.first as Event;
          return PublishOutcome(
            eventId: event.id,
            acceptedBy: relaysRefuse ? const [] : const [_pool],
            rejectedBy: relaysRefuse
                ? const {_pool: 'error: unavailable'}
                : const {},
            noResponseFrom: const [],
          );
        });
        when(
          () => nostrClient.publishEvent(
            any(),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer(
          (invocation) async => PublishSuccess(
            event: invocation.positionalArguments.first as Event,
          ),
        );
        final signer = LocalNostrSigner(_ownerSecret);
        return DmRepository(
          nostrClient: nostrClient,
          messageService: NIP17MessageService(
            signer: signer,
            senderPublicKey: _owner,
            nostrService: nostrClient,
          ),
          directMessagesDao: messagesDao,
          conversationsDao: conversationsDao,
          removedConversationsDao: removalDao ?? RemovedConversationsDao(db),
          outgoingDmsDao: outgoingDmsDao,
          userPubkey: _owner,
          signer: signer,
        );
      }

      int wallClockSeconds() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

      test('receives newer peer messages after a local send in the removal '
          'second', () async {
        await joinTheRoom();
        await leave();
        final sender = sendingRepository(
          removalDao: _RemovalPinnedToSendDao(db),
        );
        final results = await sender.sendGroupMessage(
          recipientPubkeys: [_alice, _bob],
          content: 'back in the removal second',
        );
        expect(results.every((result) => result.success), isTrue);
        final sent = await messagesDao.getMessageById(
          results.first.rumorEventId!,
          ownerPubkey: _owner,
        );
        expect(sent, isNotNull);
        final removal = (await tombstone())!;
        expect(removal.removedAt, sent!.createdAt);
        expect(removal.rejoinedAt, sent.createdAt);

        // Backdate both boundaries together so a newer peer message is not
        // clamped back onto the removal by the receive path's future guard.
        await db.customStatement(
          'UPDATE removed_conversations '
          'SET removed_at = removed_at - 1, rejoined_at = rejoined_at - 1',
        );
        final reply = message(
          author: _alice,
          pTags: [_owner, _bob],
          content: 'welcome back after same-second send',
          createdAt: sent.createdAt,
        );
        await deliver(reply, authorSecret: _aliceSecret);
        expect(await messageIdsIn(_roomId), contains(reply.id));
      });

      // The control for the same-second case above: a leave the second before
      // the send rejoins from the send's own time, as it always has.
      test('rejoins from the send when the user left the second before '
          'it', () async {
        await joinTheRoom();
        await leave();
        final sender = sendingRepository(
          removalDao: _RemovalPinnedToSendDao(db, offset: -1),
        );
        final results = await sender.sendGroupMessage(
          recipientPubkeys: [_alice, _bob],
          content: 'back the second after leaving',
        );
        expect(results.every((result) => result.success), isTrue);
        final sentId = results.first.rumorEventId!;
        final sent = await messagesDao.getMessageById(
          sentId,
          ownerPubkey: _owner,
        );
        expect(sent, isNotNull);
        final removal = (await tombstone())!;
        expect(removal.removedAt, sent!.createdAt - 1);
        expect(removal.rejoinedAt, sent.createdAt);

        final reply = message(
          author: _alice,
          pTags: [_owner, _bob],
          content: 'welcome back',
          createdAt: sent.createdAt,
        );
        await deliver(reply, authorSecret: _aliceSecret);
        await expectOnlyTheRoomHolding([sentId, reply.id]);
      });

      // The send started after the leave, so it rejoins whatever its stamp
      // says: from the leave, keeping its own copy.
      test('rejoins from the leave when a clock set back since stamps the '
          'send before it', () async {
        await joinTheRoom();
        await leave();
        final sender = sendingRepository(
          removalDao: _RemovalPinnedToSendDao(db, offset: 1),
        );
        final results = await sender.sendGroupMessage(
          recipientPubkeys: [_alice, _bob],
          content: 'back after the clock went back',
        );
        expect(results.every((result) => result.success), isTrue);
        final sentId = results.first.rumorEventId!;
        final sent = await messagesDao.getMessageById(
          sentId,
          ownerPubkey: _owner,
        );
        expect(sent, isNotNull, reason: 'the copy the members got is kept');
        final removal = (await tombstone())!;
        expect(removal.removedAt, sent!.createdAt + 1);
        expect(removal.rejoinedAt, removal.removedAt);

        // Backdate both boundaries together so a newer peer message is not
        // clamped back onto the removal by the receive path's future guard.
        await db.customStatement(
          'UPDATE removed_conversations '
          'SET removed_at = removed_at - 2, rejoined_at = rejoined_at - 2',
        );
        final reply = message(
          author: _alice,
          pTags: [_owner, _bob],
          content: 'welcome back',
          createdAt: sent.createdAt,
        );
        await deliver(reply, authorSecret: _aliceSecret);
        await expectOnlyTheRoomHolding([sentId, reply.id]);
      });

      test('brings the room back from the time of the message the user sends '
          'to it from this device', () async {
        await joinTheRoom();
        await leave();
        int? rejoinedWhilePublishing;
        final sender = sendingRepository(
          onRecipientWrap: () async =>
              rejoinedWhilePublishing = (await tombstone())!.rejoinedAt,
        );

        final results = await sender.sendGroupMessage(
          recipientPubkeys: [_alice, _bob],
          content: 'back again',
        );
        expect(results.every((result) => result.success), isTrue);
        final sent = await messagesDao.getMessageById(
          results.first.rumorEventId!,
          ownerPubkey: _owner,
        );
        expect(sent, isNotNull);
        // Recorded before the first wrap is confirmed, at the message's own
        // created_at rather than at confirm time.
        expect(rejoinedWhilePublishing, sent!.createdAt);
        expect((await tombstone())!.rejoinedAt, sent.createdAt);

        final later = message(
          author: _alice,
          pTags: [_owner, _bob],
          content: 'welcome back',
          createdAt: wallClockSeconds(),
        );
        await deliver(later, authorSecret: _aliceSecret);

        expect(await messageIdsIn(_roomId), contains(later.id));
      });

      test('leaves a one-to-one removal without a rejoin when a group send '
          'names one recipient', () async {
        final oneToOneId = DmRepository.computeConversationId([
          _owner,
          _alice,
        ]);
        await deliver(
          message(author: _alice, pTags: [_owner]),
          authorSecret: _aliceSecret,
        );
        expect(
          await repository.removeConversation(oneToOneId),
          ConversationRemovalOutcome.removed,
        );

        final results = await sendingRepository().sendGroupMessage(
          recipientPubkeys: [_alice],
          content: 'just you',
        );

        expect(results, hasLength(1));
        final removal = await RemovedConversationsDao(db).tombstoneFor(
          conversationId: oneToOneId,
          ownerPubkey: _owner,
        );
        expect(removal, isNotNull);
        expect(removal!.rejoinedAt, isNull);
      });

      // A one-to-one reopens on any newer message, so it needs no rejoin to
      // hear its member, and the failed bubble has to stay reachable.
      test('lists a removed one-to-one again when a group send to its one '
          'member is refused', () async {
        final oneToOneId = DmRepository.computeConversationId([
          _owner,
          _alice,
        ]);
        await deliver(
          message(author: _alice, pTags: [_owner]),
          authorSecret: _aliceSecret,
        );
        expect(
          await repository.removeConversation(oneToOneId),
          ConversationRemovalOutcome.removed,
        );

        final results = await sendingRepository(
          relaysRefuse: true,
          outgoingDmsDao: OutgoingDmsDao(db),
        ).sendGroupMessage(recipientPubkeys: [_alice], content: 'just you');

        expect(results.single.success, isFalse);
        expect(
          (await conversations()).map((conversation) => conversation.id),
          equals([oneToOneId]),
        );
      });

      test('lets in a member reply that lands while the send is still being '
          'confirmed', () async {
        await joinTheRoom();
        await leave();
        late final Event reply;
        final sender = sendingRepository(
          onRecipientWrap: () async {
            reply = message(
              author: _alice,
              pTags: [_owner, _bob],
              content: 'replied before the send confirmed',
              createdAt: wallClockSeconds(),
            );
            await deliver(reply, authorSecret: _aliceSecret);
          },
        );

        final results = await sender.sendGroupMessage(
          recipientPubkeys: [_alice, _bob],
          content: 'back again',
        );

        expect(results.every((result) => result.success), isTrue);
        expect(
          await messageIdsIn(_roomId),
          unorderedEquals([results.first.rumorEventId, reply.id]),
        );
      });

      // A send written before Leave found no removal to rejoin from, so the
      // leave has to win: the group must not come back unable to receive.
      // The leave runs on the sending repository, which owns the queue, as
      // the app's one repository does.
      for (final relaysRefuse in [false, true]) {
        test('keeps the room left when the user leaves it while a message '
            'they wrote before is going out and the relays '
            '${relaysRefuse ? 'refuse' : 'take'} it', () async {
          await joinTheRoom();
          late final DmRepository sender;
          sender = sendingRepository(
            relaysRefuse: relaysRefuse,
            outgoingDmsDao: OutgoingDmsDao(db),
            onRecipientWrap: () async => expect(
              await sender.removeConversation(_roomId),
              ConversationRemovalOutcome.removed,
            ),
          );

          final results = await sender.sendGroupMessage(
            recipientPubkeys: [_alice, _bob],
            content: 'written before leaving',
          );

          expect(results.first.success, !relaysRefuse);
          expect(await conversations(), isEmpty);
          expect((await tombstone())!.rejoinedAt, isNull);
        });
      }

      // The failed bubble has to stay reachable for a retry, and the send
      // rejoined the room, so it can hear its members again.
      test('lists a left room again when the message the user writes in it '
          'is refused', () async {
        await joinTheRoom();
        await leave();

        final results =
            await sendingRepository(
              relaysRefuse: true,
              outgoingDmsDao: OutgoingDmsDao(db),
            ).sendGroupMessage(
              recipientPubkeys: [_alice, _bob],
              content: 'back again',
            );

        expect(results.any((result) => result.success), isFalse);
        expect(
          (await conversations()).map((conversation) => conversation.id),
          equals([_roomId]),
        );
        expect((await tombstone())!.rejoinedAt, isNotNull);
      });

      // Leave can land after the send found nothing to rejoin and before it
      // queued every member's copy, so the leave takes only the copies queued
      // before it. The ones queued after must not bring the group back.
      group('when the user leaves it while a message they wrote before is '
          'being queued', () {
        late _QueueWithHook queue;

        /// The ids of every queued send.
        Future<List<String>> queuedIds() async => [
          for (final row in await db.select(db.outgoingDms).get()) row.id,
        ];

        /// Sends to the room from a repository whose queue leaves the room
        /// right after the first member's copy is queued.
        Future<List<NIP17SendResult>> sendLeavingMidQueue({
          bool relaysRefuse = false,
        }) {
          queue = _QueueWithHook(db);
          late final DmRepository sender;
          sender = sendingRepository(
            relaysRefuse: relaysRefuse,
            outgoingDmsDao: queue,
          );
          queue.afterFirstEnqueue = () async => expect(
            await sender.removeConversation(_roomId),
            ConversationRemovalOutcome.removed,
          );
          return sender.sendGroupMessage(
            recipientPubkeys: [_alice, _bob],
            content: 'written before leaving',
          );
        }

        test(
          'cancels every later copy before publishing after Leave',
          () async {
            await joinTheRoom();

            final results = await sendLeavingMidQueue();

            expect(results.any((result) => result.success), isFalse);
            verifyNever(
              () => nostrClient.publishEventAwaitOk(
                any(),
                targetRelays: any(named: 'targetRelays'),
                timeout: any(named: 'timeout'),
                diagnosticTag: any(named: 'diagnosticTag'),
              ),
            );
            expect(await conversations(), isEmpty);
            expect(await messageIdsIn(_roomId), isEmpty);
            expect(await queuedIds(), isEmpty);
            expect((await tombstone())!.rejoinedAt, isNull);
          },
        );

        test('cancels a legacy escaped queue row before recovery publishes '
            'it', () async {
          await joinTheRoom();
          final results = await sendLeavingMidQueue(relaysRefuse: true);
          expect(results.any((result) => result.success), isFalse);
          expect(await queuedIds(), isEmpty);
          // An older build could leave this later-enqueued copy behind.
          // Restore that exact real row to exercise recovery independently.
          final escaped = queue.enqueued.last;
          await queue.enqueue(escaped);

          final resent = await sendingRepository(
            outgoingDmsDao: queue,
          ).recoverFullSend(rumorId: escaped.id);

          expect(resent.success, isFalse);
          verifyNever(
            () => nostrClient.publishEventAwaitOk(
              any(),
              targetRelays: any(named: 'targetRelays'),
              timeout: any(named: 'timeout'),
              diagnosticTag: any(named: 'diagnosticTag'),
            ),
          );
          expect(await conversations(), isEmpty);
          expect(await messageIdsIn(_roomId), isEmpty);
          expect(await queuedIds(), isEmpty);
          expect((await tombstone())!.rejoinedAt, isNull);
        });
      });

      test('does not carry a member message into the one-to-one while '
          'receiving rooms is switched off', () async {
        receivesPeerRooms = false;
        final own = message(
          author: _owner,
          pTags: [_alice, _bob],
          content: 'the user opened the room',
        );
        await deliver(own, authorSecret: _ownerSecret);
        await expectOnlyTheRoomHolding([own.id]);
        await leave();

        await deliverLeavingNoTrace(
          message(
            author: _alice,
            pTags: [_owner, _bob],
            content: 'sent after the user left',
            createdAt: leftAt + 100,
          ),
          authorSecret: _aliceSecret,
        );

        expect(
          await conversations(),
          isEmpty,
          reason: 'neither the room nor the one-to-one with its sender',
        );
      });

      // A client widening a one-to-one reply names exactly the left room's
      // members (#2740); the reply still belongs in the one-to-one.
      for (final roomsOn in [true, false]) {
        test('files a widened reply to a one-to-one message in the '
            'one-to-one, receiving rooms ${roomsOn ? 'on' : 'off'}', () async {
          receivesPeerRooms = roomsOn;
          final own = message(
            author: _owner,
            pTags: [_alice, _bob],
            content: 'the user opened the room',
          );
          await deliver(own, authorSecret: _ownerSecret);
          await leave();
          final parent = message(
            author: _alice,
            pTags: [_owner],
            content: 'just the two of us',
          );
          await deliver(parent, authorSecret: _aliceSecret);

          final reply = message(
            author: _alice,
            pTags: [_owner, _bob],
            content: 'cc bob',
            createdAt: leftAt + 100,
            extraTags: [
              ['e', parent.id],
            ],
          );
          await deliver(reply, authorSecret: _aliceSecret);

          await expectOnlyTheOneToOneHolding(_alice, [parent.id, reply.id]);
        });
      }

      test('does not carry a member message into the one-to-one when the '
          'room is above the cap', () async {
        final members = [
          _alice,
          for (var i = 0; i < _roomCap - 1; i++)
            getPublicKey((i + 5).toRadixString(16).padLeft(64, '0')),
        ];
        final bigRoomId = DmRepository.computeConversationId([
          _owner,
          ...members,
        ]);
        final own = message(
          author: _owner,
          pTags: members,
          content: 'the user opened the room',
        );
        await deliver(own, authorSecret: _ownerSecret);
        expect(await messageIdsIn(bigRoomId), equals([own.id]));
        expect(
          await repository.removeConversation(bigRoomId),
          ConversationRemovalOutcome.removed,
        );
        await db.customStatement(
          'UPDATE removed_conversations SET removed_at = ? '
          'WHERE conversation_id = ? AND owner_pubkey = ?',
          [leftAt, bigRoomId, _owner],
        );

        await deliverLeavingNoTrace(
          message(
            author: _alice,
            pTags: [_owner, ...members.skip(1)],
            content: 'sent after the user left',
            createdAt: leftAt + 100,
          ),
          authorSecret: _aliceSecret,
        );

        expect(
          await conversations(),
          isEmpty,
          reason: 'neither the room nor the one-to-one with its sender',
        );
      });

      test('leaves a one-to-one reopening on a newer message', () async {
        final oneToOneId = DmRepository.computeConversationId([
          _owner,
          _alice,
        ]);
        await deliver(
          message(author: _alice, pTags: [_owner]),
          authorSecret: _aliceSecret,
        );
        expect(
          await repository.removeConversation(oneToOneId),
          ConversationRemovalOutcome.removed,
        );
        await db.customStatement(
          'UPDATE removed_conversations SET removed_at = ? '
          'WHERE conversation_id = ? AND owner_pubkey = ?',
          [leftAt, oneToOneId, _owner],
        );

        final newer = message(
          author: _alice,
          pTags: [_owner],
          content: 'a newer message',
          createdAt: leftAt + 100,
        );
        await deliver(newer, authorSecret: _aliceSecret);

        await expectOnlyTheOneToOneHolding(_alice, [newer.id]);
      });
    });
  });
}
