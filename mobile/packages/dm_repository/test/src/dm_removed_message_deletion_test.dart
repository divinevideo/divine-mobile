// ABOUTME: Regression coverage for #8179 — a message or reaction removed with
// ABOUTME: its conversation settles a wrapped kind 5 naming it and is not
// ABOUTME: stored again on replay; a retraction with a target left stays
// ABOUTME: deferred.

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
import 'package:unified_logger/unified_logger.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockNip17MessageService extends Mock implements NIP17MessageService {}

const _owner =
    'a4f5c1b2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8';
const _peer =
    'b1c2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8f9a0';
const _peer2 =
    'c2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8f9a0b1';
const _privateKey =
    '5426e5b8b4b0e2a1f5e8d3c7a9b2f4e6d8c0a2b4f6e8d0c2a4b6f8e0d2c4a6b8';

const _baseCreatedAt = 1700000000;

/// A 64-character hex id made of one repeated digit.
String _id(String digit) => digit * 64;

void main() {
  setUpAll(() {
    // queryEventsDetailed takes a `Duration timeout`, so a stub matching on
    // it needs a fallback (#8212).
    registerFallbackValue(Duration.zero);
  });

  // Real DAOs against a real database: the mock-based deletion suite in
  // dm_repository_test.dart stubs the message lookup per test, so it cannot
  // see what removing a conversation leaves behind.
  group('a wrapped deletion of a removed conversation message', () {
    late AppDatabase db;
    late DirectMessagesDao messagesDao;
    late ConversationsDao conversationsDao;
    late ProcessedGiftWrapsDao processedDao;
    late _MockNostrClient nostrClient;
    late StreamController<Event> relay;
    late DmRepository repository;
    late Map<String, Event> rumorByWrapId;

    final peerConversation = DmRepository.computeConversationId([
      _owner,
      _peer,
    ]);
    final peer2Conversation = DmRepository.computeConversationId([
      _owner,
      _peer2,
    ]);

    setUp(() async {
      db = AppDatabase.test(NativeDatabase.memory());
      messagesDao = DirectMessagesDao(db);
      conversationsDao = ConversationsDao(db);
      processedDao = ProcessedGiftWrapsDao(db);
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

      final reactions =
          DmReactionsRepository(
            reactionsDao: DmReactionsDao(db),
            conversationsDao: conversationsDao,
            directMessagesDao: messagesDao,
          )..setCredentials(
            userPubkey: _owner,
            messageService: _MockNip17MessageService(),
          );

      repository = DmRepository(
        nostrClient: nostrClient,
        directMessagesDao: messagesDao,
        conversationsDao: conversationsDao,
        processedGiftWrapsDao: processedDao,
        removedConversationsDao: db.removedConversationsDao,
        removedMessageIdsDao: db.removedMessageIdsDao,
        reactionsRepository: reactions,
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

    /// Feeds one gift wrap that decrypts to [rumor] and waits for the
    /// serialized ingest to drain.
    Future<void> deliver({
      required String wrapId,
      required Event rumor,
      int? wrapCreatedAt,
    }) async {
      rumorByWrapId[wrapId] = rumor;
      relay.add(
        Event.fromJson({
          'id': wrapId,
          'pubkey': _peer,
          'created_at': wrapCreatedAt ?? rumor.createdAt,
          'kind': EventKind.giftWrap,
          'tags': [
            ['p', _owner],
          ],
          'content': 'wrapped-$wrapId',
          'sig': '',
        }),
      );
      await pumpEventQueue();
    }

    Event message({
      required String id,
      String author = _peer,
      List<List<String>> tags = const [
        ['p', _owner],
      ],
      int createdAt = _baseCreatedAt,
    }) => Event.fromJson({
      'id': id,
      'pubkey': author,
      'created_at': createdAt,
      'kind': EventKind.privateDirectMessage,
      'tags': tags,
      'content': 'message $id',
      'sig': '',
    });

    Event reaction({required String id, required String target}) =>
        Event.fromJson({
          'id': id,
          'pubkey': _peer,
          'created_at': _baseCreatedAt + 1,
          'kind': EventKind.reaction,
          'tags': [
            ['e', target],
            ['p', _peer],
          ],
          'content': '🔥',
          'sig': '',
        });

    /// The sender's retraction: one `p` tag even for a group message.
    Event retraction({
      required String id,
      required List<String> targets,
      String author = _peer,
      String kind = '14',
      int createdAt = _baseCreatedAt + 2,
    }) => Event.fromJson({
      'id': id,
      'pubkey': author,
      'created_at': createdAt,
      'kind': EventKind.eventDeletion,
      'tags': [
        for (final target in targets) ['e', target],
        ['p', _owner],
        ['k', kind],
      ],
      'content': '',
      'sig': '',
    });

    /// Feeds one legacy kind 4 from the peer. The injected decryptor is the
    /// identity, so the stored text is the content below.
    Future<void> deliverNip04({
      required String id,
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
          'content': 'legacy message $id',
          'sig': '',
        }),
      );
      await pumpEventQueue();
    }

    /// The debug lines written for the deferred wrap [wrapId].
    List<String> deferredLinesFor(String wrapId) => LogCaptureService()
        .getRecentLogs()
        .map((entry) => entry.message.toLowerCase())
        .where(
          (line) =>
              line.contains('deferred wrapped deletion') &&
              line.contains(wrapId),
        )
        .toList();

    Future<bool> messageIsDeleted(String id) async {
      final row = await messagesDao.getMessageById(id, ownerPubkey: _owner);
      expect(row, isNotNull, reason: 'the message must still be stored');
      return row!.isDeleted;
    }

    group('removeConversation', () {
      test('records the wrap when its message was removed', () async {
        await deliver(
          wrapId: _id('a'),
          rumor: message(id: _id('1')),
        );
        expect(
          await repository.removeConversation(peerConversation),
          ConversationRemovalOutcome.removed,
        );
        expect(
          await messagesDao.getMessageById(_id('1'), ownerPubkey: _owner),
          isNull,
          reason: 'removal must have deleted the message',
        );

        await deliver(
          wrapId: _id('b'),
          rumor: retraction(id: _id('2'), targets: [_id('1')]),
        );

        expect(
          await processedDao.hasGiftWrap(_id('b')),
          isTrue,
          reason:
              'the message is gone, so the retraction has nothing left to '
              'apply; leaving it deferred re-decrypts it on every launch',
        );
      });

      test('records the wrap when its reaction was removed', () async {
        await deliver(
          wrapId: _id('a'),
          rumor: message(id: _id('1')),
        );
        await deliver(
          wrapId: _id('c'),
          rumor: reaction(id: _id('3'), target: _id('1')),
        );
        expect(
          await db.dmReactionsDao.getById(
            id: _id('3'),
            ownerPubkey: _owner,
          ),
          isNotNull,
          reason: 'the reaction must exist before the conversation goes',
        );
        await repository.removeConversation(peerConversation);

        await deliver(
          wrapId: _id('b'),
          rumor: retraction(
            id: _id('2'),
            targets: [_id('3')],
            kind: '${EventKind.reaction}',
          ),
        );

        expect(await processedDao.hasGiftWrap(_id('b')), isTrue);
      });
    });

    group('removeConversations', () {
      test('records the wrap when its message was removed in bulk', () async {
        await deliver(
          wrapId: _id('a'),
          rumor: message(id: _id('1')),
        );
        await deliver(
          wrapId: _id('d'),
          rumor: message(
            id: _id('4'),
            author: _peer2,
          ),
        );
        final outcome = await repository.removeConversations([
          peerConversation,
          peer2Conversation,
        ]);
        expect(outcome.removed, 2);

        await deliver(
          wrapId: _id('b'),
          rumor: retraction(
            id: _id('2'),
            targets: [_id('4')],
            author: _peer2,
          ),
        );

        expect(await processedDao.hasGiftWrap(_id('b')), isTrue);
      });
    });

    // The ledger is global and has no TTL: a wrap recorded here is lost for
    // every account on the device. Each case below is a retraction that still
    // has something to apply. The last two are the shapes the obvious
    // alternatives, a conversation guess and a tombstone timestamp, settle
    // wrongly.
    group('a retraction that still has something to apply', () {
      test('stays deferred until its message arrives, then applies', () async {
        await deliver(
          wrapId: _id('a'),
          rumor: message(id: _id('1')),
        );
        await repository.removeConversation(peerConversation);

        final early = retraction(
          id: _id('2'),
          targets: [_id('4')],
          author: _peer2,
        );
        await deliver(wrapId: _id('b'), rumor: early);
        expect(
          await processedDao.hasGiftWrap(_id('b')),
          isFalse,
          reason: 'its target has not arrived, so it must stay retryable',
        );

        await deliver(
          wrapId: _id('d'),
          rumor: message(id: _id('4'), author: _peer2),
        );
        await deliver(wrapId: _id('b'), rumor: early);

        expect(await messageIsDeleted(_id('4')), isTrue);
        expect(await processedDao.hasGiftWrap(_id('b')), isTrue);
      });

      test(
        'applies to a group message when only the sender 1:1 was removed',
        () async {
          // A sender builds one retraction with a single `p` tag even for a
          // group message, so resolving its conversation from the tags lands
          // on the 1:1 with the same sender.
          final participants = [_owner, _peer, _peer2]..sort();
          await conversationsDao.upsertConversation(
            id: DmRepository.computeConversationId(participants),
            participantPubkeys: jsonEncode(participants),
            isGroup: true,
            createdAt: _baseCreatedAt,
            ownerPubkey: _owner,
          );
          await deliver(
            wrapId: _id('e'),
            rumor: message(
              id: _id('5'),
              tags: const [
                ['p', _owner],
                ['p', _peer2],
              ],
            ),
          );
          await deliver(
            wrapId: _id('a'),
            rumor: message(id: _id('1')),
          );
          await repository.removeConversation(peerConversation);

          await deliver(
            wrapId: _id('b'),
            rumor: retraction(id: _id('2'), targets: [_id('5')]),
          );

          expect(await messageIsDeleted(_id('5')), isTrue);
          expect(await processedDao.hasGiftWrap(_id('b')), isTrue);
        },
      );

      test('applies to a stored message even if its id was recorded', () async {
        // The id lookup runs only after both stores come up empty. Run first,
        // it would settle a retraction while its target is still on screen.
        await deliver(
          wrapId: _id('a'),
          rumor: message(id: _id('1')),
        );
        await db.removedMessageIdsDao.captureForConversations(
          conversationIds: [peerConversation],
          ownerPubkey: _owner,
          removedAt: _baseCreatedAt + 100,
        );

        await deliver(
          wrapId: _id('b'),
          rumor: retraction(id: _id('2'), targets: [_id('1')]),
        );

        expect(await messageIsDeleted(_id('1')), isTrue);
        expect(await processedDao.hasGiftWrap(_id('b')), isTrue);
      });

      test(
        'applies to a message that reopened the conversation, whatever its '
        'wrap time',
        () async {
          // Gift-wrap created_at is randomized up to two days into the past,
          // so a retraction wrap can predate the removal even though the
          // message it names arrived after it.
          await db.removedConversationsDao.record(
            conversationId: peerConversation,
            ownerPubkey: _owner,
            removedAt: _baseCreatedAt + 100,
          );
          await deliver(
            wrapId: _id('a'),
            rumor: message(id: _id('1'), createdAt: _baseCreatedAt + 200),
          );

          await deliver(
            wrapId: _id('b'),
            rumor: retraction(
              id: _id('2'),
              targets: [_id('1')],
              createdAt: _baseCreatedAt + 300,
            ),
            wrapCreatedAt: _baseCreatedAt + 50,
          );

          expect(await messageIsDeleted(_id('1')), isTrue);
          expect(await processedDao.hasGiftWrap(_id('b')), isTrue);
        },
      );
    });

    // A timestamp cannot keep a removed message out: a rumor is unsigned, so a
    // sender can future-date it, and it is clamped to the receipt time. On a
    // later replay the clamp relaxes and the message clears the removal
    // instant. The id is what says it was already removed. The tombstone is
    // moved back here so the timestamp alone no longer suppresses the replay.
    group('a message whose id was removed with its conversation', () {
      Future<void> removeWithOlderTombstone() async {
        await repository.removeConversation(peerConversation);
        await db.removedConversationsDao.record(
          conversationId: peerConversation,
          ownerPubkey: _owner,
          removedAt: _baseCreatedAt + 100,
        );
      }

      test('is not stored again when its NIP-17 wrap is replayed', () async {
        final original = message(id: _id('1'), createdAt: _baseCreatedAt + 200);
        await deliver(wrapId: _id('a'), rumor: original);
        await removeWithOlderTombstone();
        expect(
          await messagesDao.getMessageById(_id('1'), ownerPubkey: _owner),
          isNull,
          reason: 'removal must have deleted the message',
        );

        await deliver(wrapId: _id('a'), rumor: original);

        expect(
          await messagesDao.getMessageById(_id('1'), ownerPubkey: _owner),
          isNull,
          reason: 'it was removed with its conversation and must stay gone',
        );
        expect(await processedDao.hasGiftWrap(_id('a')), isTrue);
      });

      test('is not stored again when its NIP-04 event is replayed', () async {
        await deliverNip04(id: _id('4'), createdAt: _baseCreatedAt + 200);
        expect(
          await messagesDao.getMessageById(_id('4'), ownerPubkey: _owner),
          isNotNull,
          reason: 'the legacy message must have been stored first',
        );
        await removeWithOlderTombstone();

        await deliverNip04(id: _id('4'), createdAt: _baseCreatedAt + 200);

        expect(
          await messagesDao.getMessageById(_id('4'), ownerPubkey: _owner),
          isNull,
          reason: 'it was removed with its conversation and must stay gone',
        );
      });

      test('does not keep a different message out', () async {
        await deliver(
          wrapId: _id('a'),
          rumor: message(id: _id('1')),
        );
        await removeWithOlderTombstone();

        await deliver(
          wrapId: _id('d'),
          rumor: message(id: _id('5'), createdAt: _baseCreatedAt + 200),
        );

        expect(
          await messagesDao.getMessageById(_id('5'), ownerPubkey: _owner),
          isNotNull,
          reason: 'a new message must still reopen the conversation',
        );
      });
    });

    // Every launch re-routes a deferred wrap, and the capture ring keeps every
    // line whatever the log level, so the line is bounded rather than gated.
    group('a deferred wrapped deletion', () {
      test('logs the id it is waiting for', () async {
        // A wrap id no other test uses: the capture ring is process-wide.
        await deliver(
          wrapId: _id('0'),
          rumor: retraction(id: _id('2'), targets: [_id('9')]),
        );

        final lines = deferredLinesFor(_id('0'));
        expect(lines, hasLength(1));
        expect(
          lines.single,
          contains(_id('9')),
          reason:
              'a deferred wrap re-decrypts on every launch and used to leave '
              'no trace of why',
        );
      });

      test('logs one line however often the wrap is routed again', () async {
        final deletion = retraction(id: _id('2'), targets: [_id('6')]);
        for (var pass = 0; pass < 3; pass++) {
          await deliver(wrapId: _id('7'), rumor: deletion);
        }

        expect(deferredLinesFor(_id('7')), hasLength(1));
      });

      test('does not echo a target that is not an event id', () async {
        await deliver(
          wrapId: _id('8'),
          rumor: retraction(
            id: _id('2'),
            targets: ['not-an-id\nforged log line'],
          ),
        );

        expect(
          deferredLinesFor(_id('8')),
          hasLength(1),
          reason: 'the wrap is still logged, under its own id',
        );
        final forged = LogCaptureService().getRecentLogs().where(
          (entry) => entry.message.contains('forged log line'),
        );
        expect(forged, isEmpty);
      });

      test(
        'stops logging new wraps once the session budget is spent',
        () async {
          String wrapId(int n) => n.toRadixString(16).padLeft(64, '0');
          const budget = DmRepository.maxLoggedDeferredDeletions;
          for (var n = 1; n <= budget + 1; n++) {
            await deliver(
              wrapId: wrapId(n),
              rumor: retraction(
                id: wrapId(n + 1000),
                targets: [wrapId(n + 2000)],
              ),
            );
          }

          expect(deferredLinesFor(wrapId(budget)), hasLength(1));
          expect(
            deferredLinesFor(wrapId(budget + 1)),
            isEmpty,
            reason: 'a flood of deferred wraps must not fill the capture ring',
          );
        },
      );
    });
  });
}
