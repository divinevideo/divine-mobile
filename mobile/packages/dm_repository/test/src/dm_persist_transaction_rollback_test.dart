// ABOUTME: Regression coverage for #8408 — the receive path's persist writes
// ABOUTME: must run inside one transaction, and roll back when one throws.

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

/// A real [ConversationsDao] that records whether each write ran inside a
/// transaction, and can be told to throw from `upsertConversation` — the call
/// the receive path makes *after* it has already inserted the message row and
/// while the transaction is still open.
///
/// `runInTransaction` delegates to `super`, so drift's real transaction is what
/// runs; the override only brackets it with a flag so membership is
/// observable. Presence of a transaction and membership *in* it are different
/// properties: a write can be moved out of a still-present transaction without
/// changing any call count or call order (#8408).
class _InstrumentedConversationsDao extends ConversationsDao {
  _InstrumentedConversationsDao(super.attachedDatabase);

  bool failUpsert = false;

  /// Write name -> whether a transaction was open when it ran.
  final membership = <String, bool>{};

  bool _open = false;

  @override
  Future<T> runInTransaction<T>(Future<T> Function() action) {
    return super.runInTransaction(() async {
      _open = true;
      try {
        return await action();
      } finally {
        _open = false;
      }
    });
  }

  @override
  Future<void> upsertConversation({
    required String id,
    required String participantPubkeys,
    required bool isGroup,
    required int createdAt,
    String? lastMessageContent,
    int? lastMessageTimestamp,
    String? lastMessageSenderPubkey,
    String? subject,
    bool isRead = true,
    bool currentUserHasSent = false,
    String? ownerPubkey,
    String? dmProtocol,
    bool forceUpdateLastMessage = false,
  }) {
    membership['upsertConversation'] = _open;
    if (failUpsert) {
      throw StateError('injected mid-transaction failure');
    }
    return super.upsertConversation(
      id: id,
      participantPubkeys: participantPubkeys,
      isGroup: isGroup,
      createdAt: createdAt,
      lastMessageContent: lastMessageContent,
      lastMessageTimestamp: lastMessageTimestamp,
      lastMessageSenderPubkey: lastMessageSenderPubkey,
      subject: subject,
      isRead: isRead,
      currentUserHasSent: currentUserHasSent,
      ownerPubkey: ownerPubkey,
      dmProtocol: dmProtocol,
      forceUpdateLastMessage: forceUpdateLastMessage,
    );
  }
}

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

  // Drives the real DAOs against a real database. The mock suite stubs
  // runInTransaction to run its callback inline, which is indistinguishable
  // from having no transaction at all, so a test written there cannot observe
  // a rollback (#8408).
  group('the receive path persist transaction', () {
    late AppDatabase db;
    late _InstrumentedConversationsDao conversationsDao;
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
      conversationsDao = _InstrumentedConversationsDao(db);
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
      await pumpEventQueue();
    }

    Future<void> deliverNip17({
      required String wrapId,
      required String rumorId,
      required String content,
    }) async {
      rumors[wrapId] = Event.fromJson({
        'id': rumorId,
        'pubkey': _peer,
        'created_at': _baseCreatedAt,
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

    Future<List<DirectMessageRow>> storedMessages() => messagesDao
        .getMessagesForConversation(conversationId, ownerPubkey: _owner);

    const wrapId =
        'c1c2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8f9a1';
    const rumorId =
        'd1c2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8f9a2';

    group('membership', () {
      test(
        'runs the conversation upsert inside it, not merely after it',
        () async {
          await deliverNip17(
            wrapId: wrapId,
            rumorId: rumorId,
            content: 'hello',
          );

          // The rollback tests prove the transaction wraps *something*. This
          // proves it wraps this particular write: moving the upsert out of a
          // still-present transaction changes no call count and no call order,
          // so nothing else in the package would notice. That is the shape of
          // the unenforced `_upsertSentConversationAndMarkRead` contract.
          expect(
            conversationsDao.membership['upsertConversation'],
            isTrue,
            reason:
                'upsertConversation ran outside the transaction that carries '
                'the message insert, so the two are no longer atomic',
          );
        },
      );
    });

    group('rollback', () {
      test('rolls the message insert back instead of orphaning it', () async {
        conversationsDao.failUpsert = true;

        await deliverNip17(wrapId: wrapId, rumorId: rumorId, content: 'hello');

        expect(conversationsDao.membership['upsertConversation'], isTrue);

        // Without the transaction the insert commits and the upsert throws
        // into the receive path's `on Object catch`, leaving a
        // direct_messages row whose conversation never existed: invisible in
        // the UI, and silent.
        expect(await storedMessages(), isEmpty);
      });

      test(
        'leaves the wrap replayable rather than permanently swallowed',
        () async {
          conversationsDao.failUpsert = true;
          await deliverNip17(
            wrapId: wrapId,
            rumorId: rumorId,
            content: 'hello',
          );

          expect(conversationsDao.membership['upsertConversation'], isTrue);

          // The rolled-back insert must take the gift-wrap marker with it. If
          // the row survived, hasGiftWrap() would short-circuit the TOCTOU
          // re-check on every replay and the message could never be recovered.
          expect(await messagesDao.hasGiftWrap(wrapId), isFalse);

          conversationsDao.failUpsert = false;
          await deliverNip17(
            wrapId: wrapId,
            rumorId: rumorId,
            content: 'hello',
          );

          final recovered = await storedMessages();
          expect(recovered, hasLength(1));
          expect(recovered.single.id, rumorId);
          expect(recovered.single.content, 'hello');
        },
      );
    });
  });
}
