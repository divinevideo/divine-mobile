// ABOUTME: Regression coverage for #6645 at the repository layer: two accounts
// ABOUTME: on one device each keep their own copy of a message, and a wrap the
// ABOUTME: ledger skipped under the old keys is delivered again after cleanup.

import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/filter.dart' as nostr_filter;
import 'package:nostr_sdk/signer/local_nostr_signer.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockNip17MessageService extends Mock implements NIP17MessageService {}

const _accountA =
    'a4f5c1b2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8';
const _accountB =
    'b1c2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8f9a0';
const _peer =
    'c2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8f9a0b1';
const _privateKey =
    '5426e5b8b4b0e2a1f5e8d3c7a9b2f4e6d8c0a2b4f6e8d0c2a4b6f8e0d2c4a6b8';

const _createdAt = 1700000000;

/// A 64-character hex id made of one repeated digit.
String _id(String digit) => digit * 64;

/// A kind-14 rumor from [author] to [recipient].
Event _rumor({
  required String id,
  required String author,
  required String recipient,
}) => Event.fromJson({
  'id': id,
  'pubkey': author,
  'created_at': _createdAt,
  'kind': EventKind.privateDirectMessage,
  'tags': [
    ['p', recipient],
  ],
  'content': 'message $id',
  'sig': '',
});

/// One listening [DmRepository] for [owner] over a shared database, the way
/// the app builds a fresh one for each signed-in account.
class _Session {
  _Session._(
    this.repository,
    this._relay,
    this._deletionRelays,
    this.owner,
    this.decryptedWrapIds,
  );

  final DmRepository repository;
  final StreamController<Event> _relay;
  final List<StreamController<Event>> _deletionRelays;
  final String owner;

  /// Every wrap that reached the decryptor. A wrap skipped by the dedup
  /// probes before the decrypt never appears here.
  final List<String> decryptedWrapIds;

  static Future<_Session> start({
    required AppDatabase db,
    required String owner,
    required Map<String, Event> rumorByWrapId,
  }) async {
    final messagesDao = DirectMessagesDao(db);
    final conversationsDao = ConversationsDao(db);
    final nostrClient = _MockNostrClient();
    final relay = StreamController<Event>();
    final deletionRelays = <StreamController<Event>>[];
    final decrypted = <String>[];

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
        acceptRelayClosedWhenOthersAnswered: any(
          named: 'acceptRelayClosedWhenOthersAnswered',
        ),
        timeout: any(named: 'timeout'),
        silentRelayTimeout: any(named: 'silentRelayTimeout'),
      ),
    ).thenAnswer(
      (_) async => (events: const <Event>[], timedOut: false, noRelays: false),
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
    ).thenAnswer((invocation) {
      final filters =
          invocation.positionalArguments.first as List<nostr_filter.Filter>;
      final deletionsOnly =
          filters.isNotEmpty &&
          filters.every((filter) {
            final kinds = filter.kinds;
            return kinds != null &&
                kinds.length == 1 &&
                kinds.single == EventKind.eventDeletion;
          });
      // A separate deletion read stays open and quiet; closing it would also
      // end the live message read. Mixed-kind reads still use the relay.
      if (!deletionsOnly) return relay.stream;
      final deletions = StreamController<Event>();
      deletionRelays.add(deletions);
      return deletions.stream;
    });

    final reactions =
        DmReactionsRepository(
          reactionsDao: DmReactionsDao(db),
          conversationsDao: conversationsDao,
          directMessagesDao: messagesDao,
        )..setCredentials(
          userPubkey: owner,
          messageService: _MockNip17MessageService(),
        );

    final repository = DmRepository(
      nostrClient: nostrClient,
      directMessagesDao: messagesDao,
      conversationsDao: conversationsDao,
      processedGiftWrapsDao: ProcessedGiftWrapsDao(db),
      removedConversationsDao: db.removedConversationsDao,
      removedMessageIdsDao: db.removedMessageIdsDao,
      reactionsRepository: reactions,
      userPubkey: owner,
      signer: LocalNostrSigner(_privateKey),
      rumorDecryptor: (_, giftWrap) async {
        decrypted.add(giftWrap.id);
        return rumorByWrapId[giftWrap.id];
      },
      nip04Decryptor: (_, ciphertext) async => ciphertext,
    );
    await repository.startListening();
    final session = _Session._(
      repository,
      relay,
      deletionRelays,
      owner,
      decrypted,
    );
    addTearDown(session.stop);
    return session;
  }

  /// Hands the repository a gift wrap addressed to [owner] and waits for the
  /// message [rumorId] to be stored for it. Returns whether it was: a wrap the
  /// repository skips leaves nothing to wait for, so the wait is bounded.
  Future<bool> deliver({
    required AppDatabase db,
    required String wrapId,
    required String rumorId,
  }) => deliverEvent(
    db: db,
    storedId: rumorId,
    event: Event.fromJson({
      'id': wrapId,
      'pubkey': _peer,
      'created_at': _createdAt,
      'kind': EventKind.giftWrap,
      'tags': [
        ['p', owner],
      ],
      'content': 'wrapped-$wrapId',
      'sig': '',
    }),
  );

  /// Hands the repository [event] and waits for the message [storedId] to be
  /// stored for [owner]. Returns whether it was: an event the repository skips
  /// leaves nothing to wait for, so the wait is bounded.
  Future<bool> deliverEvent({
    required AppDatabase db,
    required Event event,
    required String storedId,
  }) async {
    _relay.add(event);
    for (var attempt = 0; attempt < 100; attempt += 1) {
      await pumpEventQueue();
      if (await DirectMessagesDao(
            db,
          ).getMessageById(storedId, ownerPubkey: owner) !=
          null) {
        return true;
      }
    }
    return false;
  }

  bool _stopped = false;

  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    // stopListening() before closing the stream: onDone would otherwise arm a
    // reconnect timer that outlives this test.
    await repository.stopListening();
    await _relay.close();
    for (final deletions in _deletionRelays) {
      await deletions.close();
    }
  }
}

void main() {
  setUpAll(() {
    // queryEventsDetailed takes a `Duration timeout`, so a stub matching on it
    // needs a fallback.
    registerFallbackValue(Duration.zero);
  });

  group('two accounts on one device', () {
    late AppDatabase db;
    late DirectMessagesDao messagesDao;
    late Map<String, Event> rumorByWrapId;

    final conversationAB = DmRepository.computeConversationId([
      _accountA,
      _accountB,
    ]);
    final conversationAPeer = DmRepository.computeConversationId([
      _accountA,
      _peer,
    ]);

    setUp(() {
      db = AppDatabase.test(NativeDatabase.memory());
      messagesDao = DirectMessagesDao(db);
      rumorByWrapId = <String, Event>{};
    });

    tearDown(() async {
      await db.close();
    });

    group('a message a peer sent to both of them', () {
      test('is kept by the second account when the first holds the same '
          'rumor under a different wrap', () async {
        final rumor = _rumor(
          id: _id('1'),
          author: _peer,
          recipient: _accountB,
        );
        rumorByWrapId[_id('b')] = rumor;
        await messagesDao.insertMessage(
          id: rumor.id,
          conversationId: conversationAPeer,
          senderPubkey: _peer,
          content: rumor.content,
          createdAt: _createdAt,
          giftWrapId: _id('a'),
          ownerPubkey: _accountA,
        );

        final session = await _Session.start(
          db: db,
          owner: _accountB,
          rumorByWrapId: rumorByWrapId,
        );
        final stored = await session.deliver(
          db: db,
          wrapId: _id('b'),
          rumorId: rumor.id,
        );

        expect(
          stored,
          isTrue,
          reason: 'decrypted wraps: ${session.decryptedWrapIds}',
        );
        expect(
          await messagesDao.getMessageById(rumor.id, ownerPubkey: _accountA),
          isNotNull,
          reason: "account A's own copy must be untouched",
        );
      });
    });

    group('a message one of them sent to the other', () {
      test('is kept by the recipient when the sender stored the recipient '
          'wrap id on its outgoing row', () async {
        final rumor = _rumor(
          id: _id('2'),
          author: _accountA,
          recipient: _accountB,
        );
        rumorByWrapId[_id('c')] = rumor;
        // What an account stores for its own send: the RECIPIENT's wrap id.
        await messagesDao.insertMessage(
          id: rumor.id,
          conversationId: conversationAB,
          senderPubkey: _accountA,
          content: rumor.content,
          createdAt: _createdAt,
          giftWrapId: _id('c'),
          ownerPubkey: _accountA,
        );

        final session = await _Session.start(
          db: db,
          owner: _accountB,
          rumorByWrapId: rumorByWrapId,
        );
        final stored = await session.deliver(
          db: db,
          wrapId: _id('c'),
          rumorId: rumor.id,
        );

        expect(
          stored,
          isTrue,
          reason: 'decrypted wraps: ${session.decryptedWrapIds}',
        );
      });
    });

    group('a kind-4 message between them', () {
      // One signed event, one id: the sender's row and the recipient's row
      // carry the same `id` and `gift_wrap_id`.
      Event kind4({required String id}) => Event.fromJson({
        'id': id,
        'pubkey': _accountA,
        'created_at': _createdAt,
        'kind': EventKind.directMessage,
        'tags': [
          ['p', _accountB],
        ],
        'content': 'plain text',
        'sig': '',
      });

      test('is kept by the recipient when the sender stored the shared event '
          'id', () async {
        final eventId = _id('4');
        await messagesDao.insertMessage(
          id: eventId,
          conversationId: conversationAB,
          senderPubkey: _accountA,
          content: 'plain text',
          createdAt: _createdAt,
          giftWrapId: eventId,
          messageKind: EventKind.directMessage,
          ownerPubkey: _accountA,
        );

        final session = await _Session.start(
          db: db,
          owner: _accountB,
          rumorByWrapId: rumorByWrapId,
        );
        final stored = await session.deliverEvent(
          db: db,
          event: kind4(id: eventId),
          storedId: eventId,
        );

        expect(stored, isTrue);
      });

      test('is handled by the recipient when only the sender ledgered the '
          'shared event id', () async {
        final eventId = _id('5');
        await ProcessedGiftWrapsDao(
          db,
        ).record(giftWrapId: eventId, ownerPubkey: _accountA);

        final session = await _Session.start(
          db: db,
          owner: _accountB,
          rumorByWrapId: rumorByWrapId,
        );
        final stored = await session.deliverEvent(
          db: db,
          event: kind4(id: eventId),
          storedId: eventId,
        );

        expect(stored, isTrue);
      });
    });

    group('a message the sender dual-sent as NIP-17 and kind 4', () {
      test('is stored once for the recipient across a relaunch when the '
          'sender ledgered the kind-4 copy', () async {
        final kind4Id = _id('4');
        final rumor = Event.fromJson({
          'id': _id('2'),
          'pubkey': _accountA,
          'created_at': _createdAt,
          'kind': EventKind.privateDirectMessage,
          'tags': [
            ['p', _accountB],
          ],
          'content': 'plain text',
          'sig': '',
        });
        final kind4 = Event.fromJson({
          'id': kind4Id,
          'pubkey': _accountA,
          'created_at': _createdAt,
          'kind': EventKind.directMessage,
          'tags': [
            ['p', _accountB],
          ],
          'content': 'plain text',
          'sig': '',
        });
        rumorByWrapId[_id('c')] = rumor;
        // The sender's own send row holds the recipient's wrap id, and its
        // outgoing NIP-04 recovery ledgered the kind-4 copy when it saw its
        // own echo.
        await messagesDao.insertMessage(
          id: rumor.id,
          conversationId: conversationAB,
          senderPubkey: _accountA,
          content: rumor.content,
          createdAt: _createdAt,
          giftWrapId: _id('c'),
          ownerPubkey: _accountA,
        );
        await ProcessedGiftWrapsDao(
          db,
        ).record(giftWrapId: kind4Id, ownerPubkey: _accountA);

        final first = await _Session.start(
          db: db,
          owner: _accountB,
          rumorByWrapId: rumorByWrapId,
        );
        expect(
          await first.deliver(db: db, wrapId: _id('c'), rumorId: rumor.id),
          isTrue,
          reason: 'precondition: the recipient stores the NIP-17 copy',
        );
        await first.deliverEvent(db: db, event: kind4, storedId: kind4Id);
        await first.stop();

        // The next launch replays the kind 4 inside the two-day overlap.
        final relaunch = await _Session.start(
          db: db,
          owner: _accountB,
          rumorByWrapId: rumorByWrapId,
        );
        await relaunch.deliverEvent(db: db, event: kind4, storedId: kind4Id);

        expect(
          await messagesDao.getMessagesForConversation(
            conversationAB,
            ownerPubkey: _accountB,
          ),
          hasLength(1),
        );
      });
    });

    group('a wrap the ledger recorded under the old keys', () {
      test('is stored once the account switch has cleared the ledger and its '
          'rows', () async {
        final rumor = _rumor(
          id: _id('3'),
          author: _peer,
          recipient: _accountB,
        );
        rumorByWrapId[_id('d')] = rumor;
        await messagesDao.insertMessage(
          id: rumor.id,
          conversationId: conversationAPeer,
          senderPubkey: _peer,
          content: rumor.content,
          createdAt: _createdAt,
          giftWrapId: _id('a'),
          ownerPubkey: _accountA,
        );
        // The state the old global key left behind: B's wrap was ledgered as
        // handled although no message row of B's exists.
        await ProcessedGiftWrapsDao(
          db,
        ).record(giftWrapId: _id('d'), ownerPubkey: _accountB);

        final stranded = await _Session.start(
          db: db,
          owner: _accountB,
          rumorByWrapId: rumorByWrapId,
        );
        final skipped = await stranded.deliver(
          db: db,
          wrapId: _id('d'),
          rumorId: rumor.id,
        );
        await stranded.stop();
        expect(
          skipped,
          isFalse,
          reason:
              'precondition: the ledger entry makes the repository skip the '
              'wrap before it decrypts it (${stranded.decryptedWrapIds})',
        );

        // What the app does when account B is switched away from: it deletes
        // the leaving account's messages and its ledger rows.
        await messagesDao.clearForAccountSwitch(_accountB);
        await ProcessedGiftWrapsDao(db).clearForAccountSwitch(_accountB);

        final relogin = await _Session.start(
          db: db,
          owner: _accountB,
          rumorByWrapId: rumorByWrapId,
        );
        final recovered = await relogin.deliver(
          db: db,
          wrapId: _id('d'),
          rumorId: rumor.id,
        );

        expect(
          recovered,
          isTrue,
          reason: 'decrypted wraps: ${relogin.decryptedWrapIds}',
        );
        expect(
          await messagesDao.getMessageById(rumor.id, ownerPubkey: _accountA),
          isNotNull,
          reason: "account A's copy must survive account B's cleanup",
        );
      });
    });
  });
}
