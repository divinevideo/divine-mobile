// ABOUTME: Where a reply that tags someone extra lands must not depend on
// ABOUTME: whether it was stored before or after its parent (#10037).

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
import 'package:nostr_sdk/relay/query_result.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNostrClient extends Mock implements NostrClient {}

/// Fails the next move of messages between conversations once, so a test can
/// roll back the transaction that stores a parent and takes a room apart.
class _ReassignFailingDao extends DirectMessagesDao {
  _ReassignFailingDao(super.attachedDatabase);

  bool failNextReassign = false;
  final Completer<void> reassignFailed = Completer<void>();

  @override
  Future<int> reassignMessages({
    required List<String> messageIds,
    required String toConversationId,
    required String ownerPubkey,
  }) {
    if (failNextReassign) {
      failNextReassign = false;
      reassignFailed.complete();
      throw StateError('disk I/O error');
    }
    return super.reassignMessages(
      messageIds: messageIds,
      toConversationId: toConversationId,
      ownerPubkey: ownerPubkey,
    );
  }
}

final String _ownerSecret = '1' * 64;
final String _aliceSecret = '2' * 64;
final String _bobSecret = '3' * 64;
final String _carolSecret = '4' * 64;
final String _owner = getPublicKey(_ownerSecret);
final String _alice = getPublicKey(_aliceSecret);
final String _bob = getPublicKey(_bobSecret);
final String _carol = getPublicKey(_carolSecret);

final Map<String, String> _names = {
  _owner: 'me',
  _alice: 'alice',
  _bob: 'bob',
  _carol: 'carol',
};

String _id(List<String> members) => DmRepository.computeConversationId(members);

const _sentAt = 1700000000;
const _settleTimeout = Duration(seconds: 20);

void main() {
  setUpAll(() {
    registerFallbackValue(Duration.zero);
  });

  late AppDatabase db;
  late ConversationsDao conversationsDao;
  late _ReassignFailingDao messagesDao;
  late _MockNostrClient nostrClient;
  late StreamController<Event> relay;
  late DmRepository repository;
  late bool receivesPeerRooms;

  /// What the history drain is handed for its first page, in this order.
  late List<Event> historyPage;

  DmRepository buildRepository({DmSyncState? syncState}) => DmRepository(
    nostrClient: nostrClient,
    directMessagesDao: messagesDao,
    conversationsDao: conversationsDao,
    processedGiftWrapsDao: ProcessedGiftWrapsDao(db),
    removedConversationsDao: RemovedConversationsDao(db),
    outgoingDmsDao: OutgoingDmsDao(db),
    reactionsRepository: DmReactionsRepository(
      reactionsDao: DmReactionsDao(db),
      conversationsDao: conversationsDao,
      directMessagesDao: messagesDao,
      userPubkey: _owner,
    ),
    syncState: syncState,
    userPubkey: _owner,
    signer: LocalNostrSigner(_ownerSecret),
    receivesPeerRooms: () => receivesPeerRooms,
  );

  setUp(() async {
    receivesPeerRooms = true;
    historyPage = const [];
    db = AppDatabase.test(NativeDatabase.memory());
    conversationsDao = ConversationsDao(db);
    messagesDao = _ReassignFailingDao(db);
    nostrClient = _MockNostrClient();
    relay = StreamController<Event>.broadcast();

    when(() => nostrClient.connectedRelayCount).thenReturn(1);
    when(() => nostrClient.configuredRelayCount).thenReturn(1);
    when(() => nostrClient.configuredRelays).thenReturn(const ['wss://r']);
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
        acceptRelayClosedWhenOthersAnswered: any(
          named: 'acceptRelayClosedWhenOthersAnswered',
        ),
        timeout: any(named: 'timeout'),
      ),
    ).thenAnswer((invocation) async {
      final subscriptionId =
          invocation.namedArguments[#subscriptionId] as String?;
      // Only the first page of the NIP-17 history drain carries events; every
      // other query is answered and empty.
      final isFirstDrainPage =
          subscriptionId == dmHistoryDrainSubscriptionId(_owner, 0);
      return (
        events: isFirstDrainPage ? historyPage : const <Event>[],
        timedOut: false,
        noRelays: false,
      );
    });
    when(() => nostrClient.unsubscribe(any())).thenAnswer((_) async {});
    when(
      () => nostrClient.subscribe(
        any(),
        subscriptionId: any(named: 'subscriptionId'),
        tempRelays: any(named: 'tempRelays'),
        targetRelays: any(named: 'targetRelays'),
      ),
    ).thenAnswer((_) => relay.stream);

    repository = buildRepository();
    await repository.startListening();
  });

  tearDown(() async {
    await repository.stopListening();
    await relay.close();
    await db.close();
  });

  Event message({
    required String author,
    required List<String> pTags,
    required String content,
    String? replyTo,
    int createdAt = _sentAt,
  }) => Event(
    author,
    EventKind.privateDirectMessage,
    [
      for (final pubkey in pTags) ['p', pubkey],
      if (replyTo != null) ['e', replyTo],
    ],
    content,
    createdAt: createdAt,
  );

  Future<void> settled(String giftWrapId) => db
      .customSelect(
        '''
        SELECT EXISTS (
          SELECT 1 FROM direct_messages WHERE gift_wrap_id = ?1
        ) OR EXISTS (
          SELECT 1 FROM processed_gift_wraps WHERE gift_wrap_id = ?1
        ) AS settled
        ''',
        variables: [Variable.withString(giftWrapId)],
        readsFrom: {db.directMessages, db.processedGiftWraps},
      )
      .watchSingle()
      .firstWhere((row) => row.read<bool>('settled'))
      .timeout(
        _settleTimeout,
        onTimeout: () => fail('gift wrap $giftWrapId was never settled'),
      );

  Future<Event> wrap(Event rumor, {required String authorSecret}) async =>
      (await buildGiftWrapFromHex(
        senderPrivateKeyHex: authorSecret,
        rumorJson: rumor.toJson(),
        receiverPublicKey: _owner,
      ))!;

  Future<void> deliver(Event rumor, {required String authorSecret}) async {
    final giftWrap = await wrap(rumor, authorSecret: authorSecret);
    relay.add(giftWrap);
    await settled(giftWrap.id);
  }

  /// Every conversation with its messages, as
  /// `1:1(alice,me)=[hello] | room(alice,bob,me)=[cc bob]`.
  Future<String> conversations() async {
    final rows = await conversationsDao.getAllConversations(
      ownerPubkey: _owner,
    );
    final parts = <String>[];
    for (final row in rows) {
      final members =
          (jsonDecode(row.participantPubkeys) as List)
              .cast<String>()
              .map((pubkey) => _names[pubkey] ?? pubkey)
              .toList()
            ..sort();
      final messages = await messagesDao.getMessagesForConversation(
        row.id,
        ownerPubkey: _owner,
      );
      final contents = [for (final m in messages) m.content]..sort();
      parts.add(
        '${row.isGroup ? 'room' : '1:1'}(${members.join(',')})'
        '=[${contents.join('; ')}]',
      );
    }
    parts.sort();
    return parts.join(' | ');
  }

  final oneToOneId = _id([_owner, _alice]);
  final wideRoomId = _id([_owner, _alice, _bob]);

  Event hello() => message(author: _alice, pTags: [_owner], content: 'hello');

  /// Alice answering [parent] in the one-to-one while also tagging Bob.
  Event ccBob(Event parent, {String content = 'cc bob', int after = 1}) =>
      message(
        author: _alice,
        pTags: [_owner, _bob],
        content: content,
        replyTo: parent.id,
        createdAt: parent.createdAt + after,
      );

  group('a reply that tags someone extra, stored before the message it '
      'answers', () {
    test('joins the one-to-one once that message arrives', () async {
      final parent = hello();
      await deliver(ccBob(parent), authorSecret: _aliceSecret);
      expect(
        await conversations(),
        equals('room(alice,bob,me)=[cc bob]'),
        reason: 'until its parent is known the reply can only be a room',
      );

      await deliver(parent, authorSecret: _aliceSecret);

      expect(await conversations(), equals('1:1(alice,me)=[cc bob; hello]'));
    });

    test('joins the room once that message arrives', () async {
      final parent = message(
        author: _alice,
        pTags: [_owner, _bob],
        content: 'room hello',
      );
      final ccCarol = message(
        author: _alice,
        pTags: [_owner, _bob, _carol],
        content: 'cc carol',
        replyTo: parent.id,
        createdAt: _sentAt + 1,
      );

      await deliver(ccCarol, authorSecret: _aliceSecret);
      await deliver(parent, authorSecret: _aliceSecret);

      expect(
        await conversations(),
        equals('room(alice,bob,me)=[cc carol; room hello]'),
      );
    });

    test('takes along a later reply that had joined the same room', () async {
      final parent = hello();
      final other = message(
        author: _alice,
        pTags: [_owner],
        content: 'another',
        createdAt: _sentAt + 10,
      );
      await deliver(other, authorSecret: _aliceSecret);
      await deliver(ccBob(parent), authorSecret: _aliceSecret);
      await deliver(
        ccBob(other, content: 'cc bob again'),
        authorSecret: _aliceSecret,
      );

      await deliver(parent, authorSecret: _aliceSecret);

      expect(
        await conversations(),
        equals('1:1(alice,me)=[another; cc bob; cc bob again; hello]'),
      );
    });

    test("files the tagged person's own answer with them, as it would "
        'have in order', () async {
      final parent = hello();
      final reply = ccBob(parent);
      final bobAnswers = message(
        author: _bob,
        pTags: [_owner, _alice],
        content: 'bob here',
        replyTo: reply.id,
        createdAt: reply.createdAt + 1,
      );

      await deliver(bobAnswers, authorSecret: _bobSecret);
      await deliver(reply, authorSecret: _aliceSecret);
      await deliver(parent, authorSecret: _aliceSecret);

      expect(
        await conversations(),
        equals('1:1(alice,me)=[cc bob; hello] | 1:1(bob,me)=[bob here]'),
      );
    });

    test('joins the one-to-one when its parent arrives on a later '
        'launch', () async {
      final parent = hello();
      await deliver(ccBob(parent), authorSecret: _aliceSecret);

      await repository.stopListening();
      repository = buildRepository();
      await repository.startListening();
      await deliver(parent, authorSecret: _aliceSecret);

      expect(await conversations(), equals('1:1(alice,me)=[cc bob; hello]'));
    });

    test('joins the one-to-one when a reply to it shares its second and '
        'sorts first', () async {
      final parent = hello();
      final reply = ccBob(parent);
      // Ids are hashes: pick a follow-up that sorts before the reply it
      // answers, in the same second, so time order cannot place it.
      final followUp = [
        for (var i = 0; i < 64; i++)
          message(
            author: _alice,
            pTags: [_owner, _bob],
            content: 'cc bob more $i',
            replyTo: reply.id,
            createdAt: reply.createdAt,
          ),
      ].firstWhere((event) => event.id.compareTo(reply.id) < 0);

      await deliver(followUp, authorSecret: _aliceSecret);
      await deliver(reply, authorSecret: _aliceSecret);
      await deliver(parent, authorSecret: _aliceSecret);

      expect(
        await conversations(),
        equals('1:1(alice,me)=[cc bob; ${followUp.content}; hello]'),
      );
    });

    test('joins the one-to-one when storing its parent is rolled back and '
        'retried', () async {
      final parent = hello();
      await deliver(ccBob(parent), authorSecret: _aliceSecret);
      final parentWrap = await wrap(parent, authorSecret: _aliceSecret);

      messagesDao.failNextReassign = true;
      relay.add(parentWrap);
      await messagesDao.reassignFailed.future.timeout(_settleTimeout);
      expect(
        await messagesDao.getMessageById(parent.id, ownerPubkey: _owner),
        isNull,
        reason: 'the failed move rolls the parent back too',
      );

      relay.add(parentWrap);
      await settled(parentWrap.id);

      expect(await conversations(), equals('1:1(alice,me)=[cc bob; hello]'));
    });

    test('shows as the unread preview of the one-to-one', () async {
      final parent = hello();
      await deliver(ccBob(parent), authorSecret: _aliceSecret);
      await deliver(parent, authorSecret: _aliceSecret);

      final oneToOne = await conversationsDao.getConversation(
        oneToOneId,
        ownerPubkey: _owner,
      );
      expect(oneToOne?.lastMessageContent, equals('cc bob'));
      expect(oneToOne?.lastMessageTimestamp, equals(_sentAt + 1));
      expect(oneToOne?.isRead, isFalse);
    });

    test('brings the reactions on it along', () async {
      final parent = hello();
      final reply = ccBob(parent);
      await deliver(reply, authorSecret: _aliceSecret);
      final reactionsDao = DmReactionsDao(db);
      await reactionsDao.upsertIncoming(
        id: 'a' * 64,
        conversationId: wideRoomId,
        targetMessageId: reply.id,
        targetMessageAuthor: _alice,
        reactorPubkey: _bob,
        emoji: '+',
        createdAt: _sentAt + 2,
        giftWrapId: 'b' * 64,
        ownerPubkey: _owner,
      );

      await deliver(parent, authorSecret: _aliceSecret);

      final reaction = await reactionsDao.getById(
        id: 'a' * 64,
        ownerPubkey: _owner,
      );
      expect(reaction?.conversationId, equals(oneToOneId));
    });
  });

  group('the wider room stays', () {
    test('when the user has answered in it', () async {
      final parent = hello();
      final reply = ccBob(parent);
      await deliver(reply, authorSecret: _aliceSecret);
      await deliver(
        message(
          author: _owner,
          pTags: [_alice, _bob],
          content: 'hi both',
          replyTo: reply.id,
          createdAt: _sentAt + 2,
        ),
        authorSecret: _ownerSecret,
      );

      await deliver(parent, authorSecret: _aliceSecret);

      expect(
        await conversations(),
        equals('1:1(alice,me)=[hello] | room(alice,bob,me)=[cc bob; hi both]'),
      );
    });

    test('when the user has a message queued for it', () async {
      final parent = hello();
      await deliver(ccBob(parent), authorSecret: _aliceSecret);
      await OutgoingDmsDao(db).enqueue(
        OutgoingDm(
          id: 'c' * 64,
          conversationId: wideRoomId,
          recipientPubkey: _bob,
          content: 'on its way',
          createdAt: _sentAt + 2,
          rumorEventJson: '{}',
          recipientWrapStatus: OutgoingWrapStatus.pending,
          selfWrapStatus: OutgoingWrapStatus.pending,
          queuedAt: DateTime.fromMillisecondsSinceEpoch((_sentAt + 2) * 1000),
          ownerPubkey: _owner,
        ),
      );

      await deliver(parent, authorSecret: _aliceSecret);

      expect(
        await conversations(),
        equals('1:1(alice,me)=[hello] | room(alice,bob,me)=[cc bob]'),
      );
    });

    test('when someone has spoken in it without answering anything', () async {
      final parent = hello();
      await deliver(ccBob(parent), authorSecret: _aliceSecret);
      await deliver(
        message(
          author: _bob,
          pTags: [_owner, _alice],
          content: 'bob starts talking',
          createdAt: _sentAt + 2,
        ),
        authorSecret: _bobSecret,
      );

      await deliver(parent, authorSecret: _aliceSecret);

      expect(
        await conversations(),
        equals(
          '1:1(alice,me)=[hello] | '
          'room(alice,bob,me)=[bob starts talking; cc bob]',
        ),
      );
    });

    test('when the reply is stamped at or before the removal of the '
        'conversation it answers', () async {
      final parent = message(
        author: _alice,
        pTags: [_owner],
        content: 'hello',
        createdAt: _sentAt + 5,
      );
      await deliver(ccBob(parent, after: -6), authorSecret: _aliceSecret);
      await RemovedConversationsDao(db).record(
        conversationId: oneToOneId,
        ownerPubkey: _owner,
        removedAt: _sentAt,
      );

      await deliver(parent, authorSecret: _aliceSecret);

      expect(
        await conversations(),
        equals('1:1(alice,me)=[hello] | room(alice,bob,me)=[cc bob]'),
      );
    });
  });

  group('with receiving rooms switched off', () {
    test('a room a reply opened earlier is left as it is', () async {
      final parent = hello();
      await deliver(ccBob(parent), authorSecret: _aliceSecret);
      receivesPeerRooms = false;

      await deliver(parent, authorSecret: _aliceSecret);

      expect(
        await conversations(),
        equals('1:1(alice,me)=[hello] | room(alice,bob,me)=[cc bob]'),
      );
    });
  });

  group('one page of history', () {
    /// Hands [page] to the history drain as the single page it will read, on a
    /// repository that has not drained yet.
    Future<void> drain(List<Event> page) async {
      await repository.stopListening();
      historyPage = page;
      // What the drain reads once the page is stored: the account's own
      // outgoing NIP-04, answered and empty, and the relay statuses.
      when(
        () => nostrClient.readEvents(
          any(),
          subscriptionId: any(named: 'subscriptionId'),
          useCache: any(named: 'useCache'),
          requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
        ),
      ).thenAnswer(
        (_) async => const QueryResult(
          events: [],
          endedBy: QueryEnd.complete,
          answeredNetworkRelayCount: 1,
        ),
      );
      when(() => nostrClient.relayStatuses).thenReturn(const {});
      SharedPreferences.setMockInitialValues(<String, Object>{});
      repository = buildRepository(
        syncState: DmSyncState(await SharedPreferences.getInstance()),
      );
      await repository.startListening();
      await repository.backfillHistoryIfNeeded();
      for (final event in page) {
        await settled(event.id);
      }
    }

    Future<List<String>> contentsInStoredOrder() async {
      final rows = await db
          .customSelect('SELECT content FROM direct_messages ORDER BY rowid')
          .get();
      return [for (final row in rows) row.read<String>('content')];
    }

    test('is stored oldest message first, whatever order the relay '
        'returned', () async {
      final first = message(author: _alice, pTags: [_owner], content: 'one');
      final second = message(
        author: _alice,
        pTags: [_owner],
        content: 'two',
        createdAt: _sentAt + 1,
      );
      final third = message(
        author: _alice,
        pTags: [_owner],
        content: 'three',
        createdAt: _sentAt + 2,
      );

      await drain([
        await wrap(third, authorSecret: _aliceSecret),
        await wrap(first, authorSecret: _aliceSecret),
        await wrap(second, authorSecret: _aliceSecret),
      ]);

      expect(await contentsInStoredOrder(), equals(['one', 'two', 'three']));
    });

    test('is stored in the order the relay returned with receiving rooms '
        'switched off', () async {
      receivesPeerRooms = false;
      final first = message(author: _alice, pTags: [_owner], content: 'one');
      final second = message(
        author: _alice,
        pTags: [_owner],
        content: 'two',
        createdAt: _sentAt + 1,
      );

      await drain([
        await wrap(second, authorSecret: _aliceSecret),
        await wrap(first, authorSecret: _aliceSecret),
      ]);

      expect(await contentsInStoredOrder(), equals(['two', 'one']));
    });

    test('never opens the wider room for a reply listed before its '
        'parent', () async {
      final parent = hello();
      final seen = <String>[];
      final subscription = conversationsDao
          .watchAllConversations(ownerPubkey: _owner)
          .listen((rows) => seen.addAll([for (final row in rows) row.id]));
      addTearDown(subscription.cancel);

      await drain([
        await wrap(ccBob(parent), authorSecret: _aliceSecret),
        await wrap(parent, authorSecret: _aliceSecret),
      ]);
      await pumpEventQueue();

      expect(await conversations(), equals('1:1(alice,me)=[cc bob; hello]'));
      expect(seen, contains(oneToOneId));
      expect(seen, isNot(contains(wideRoomId)));
    });
  });
}
