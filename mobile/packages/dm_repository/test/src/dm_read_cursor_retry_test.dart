// ABOUTME: Regression coverage for the #4977 cross-device read-cursor retry —
// ABOUTME: a marker arriving before its conversation row must be re-applied.

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
import 'package:shared_preferences/shared_preferences.dart';

class _MockNostrClient extends Mock implements NostrClient {}

const _owner =
    'a4f5c1b2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8';
const _peer =
    'b1c2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8f9a0';
const _privateKey =
    '5426e5b8b4b0e2a1f5e8d3c7a9b2f4e6d8c0a2b4f6e8d0c2a4b6f8e0d2c4a6b8';

const _readMarkerDTag = 'divine/dm-read/v1';
const _baseCreatedAt = 1700000000;

void main() {
  setUpAll(() {
    registerFallbackValue(Duration.zero);
  });

  // Drives the real ConversationsDao against a real database. The mock suite
  // in dm_repository_test.dart stubs applyReadCursor to a constant `true` in
  // its top-level setUp, so the `!applied` retry branch never executes there
  // and _pendingReadCursors is always empty — a test written there would pass
  // whether or not the retry works (#8170).
  group(
    'read-cursor retry for a marker that arrives before its conversation',
    () {
      late AppDatabase db;
      late ConversationsDao conversationsDao;
      late DirectMessagesDao messagesDao;
      late _MockNostrClient nostrClient;
      late StreamController<Event> relay;
      late DmRepository repository;
      late Map<String, Event> rumorByWrapId;
      late DmSyncState syncState;

      /// The conversation the marker names — deliberately not created yet.
      final participants = [_owner, _peer]..sort();
      late String conversationId;

      setUp(() async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        syncState = DmSyncState(await SharedPreferences.getInstance());
        db = AppDatabase.test(NativeDatabase.memory());
        conversationsDao = ConversationsDao(db);
        messagesDao = DirectMessagesDao(db);
        nostrClient = _MockNostrClient();
        relay = StreamController<Event>();
        rumorByWrapId = <String, Event>{};
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
          syncState: syncState,
          signer: LocalNostrSigner(_privateKey),
          rumorDecryptor: (_, giftWrap) async => rumorByWrapId[giftWrap.id],
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

      /// Feeds the owner's own kind-30078 read marker, naming [conversationId]
      /// via its participant tuple and carrying [readAt] as the cursor.
      Future<void> deliverReadMarker({
        required String wrapId,
        required String rumorId,
        required int readAt,
      }) async {
        rumorByWrapId[wrapId] = Event.fromJson({
          'id': rumorId,
          'pubkey': _owner,
          'created_at': _baseCreatedAt,
          'kind': EventKind.appSpecificData,
          'tags': [
            ['d', _readMarkerDTag],
            ['p', _owner],
          ],
          'content': jsonEncode({
            'v': 1,
            'read': {participants.join(','): readAt},
          }),
          'sig': '',
        });
        relay.add(
          Event.fromJson({
            'id': wrapId,
            'pubkey': _owner,
            'created_at': _baseCreatedAt,
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

      /// Creates the conversation the marker named, with one unread inbound
      /// message at [messageAt] — the row the marker was racing.
      Future<void> ingestConversation({required int messageAt}) async {
        final wrapId = 'e' * 64;
        final rumorId = 'f' * 64;
        rumorByWrapId[wrapId] = Event.fromJson({
          'id': rumorId,
          'pubkey': _peer,
          'created_at': messageAt,
          'kind': EventKind.privateDirectMessage,
          'tags': [
            ['p', _owner],
          ],
          'content': 'hello',
          'sig': '',
        });
        relay.add(
          Event.fromJson({
            'id': wrapId,
            'pubkey': _peer,
            'created_at': messageAt,
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

      Future<ConversationRow?> conversation() async {
        final rows = await conversationsDao.getAllConversations(
          ownerPubkey: _owner,
        );
        return rows.where((r) => r.id == conversationId).firstOrNull;
      }

      test(
        'a marker landing before its conversation is retried after the drain',
        () async {
          // The marker names a conversation that does not exist yet, so
          // applyReadCursor matches no row and returns false.
          await deliverReadMarker(
            wrapId: 'a' * 64,
            rumorId: 'b' * 64,
            readAt: _baseCreatedAt + 100,
          );
          expect(
            await conversation(),
            isNull,
            reason:
                'precondition: the marker must arrive before its row exists',
          );

          // The drain then ingests the conversation it was racing.
          await ingestConversation(messageAt: _baseCreatedAt + 50);
          final beforeRetry = await conversation();
          expect(beforeRetry, isNotNull);
          expect(
            beforeRetry!.isRead,
            isFalse,
            reason: 'the dropped cursor has not been re-applied yet',
          );

          // backfillHistoryIfNeeded flushes the queued cursors (#4977).
          await repository.backfillHistoryIfNeeded();
          await settle();

          final afterRetry = await conversation();
          expect(
            afterRetry!.lastReadTimestamp,
            _baseCreatedAt + 100,
            reason: 'the queued cursor must be re-applied, not discarded',
          );
          expect(
            afterRetry.isRead,
            isTrue,
            reason: 'the cursor covers the latest message, so it reads as read',
          );
        },
      );

      test(
        'a marker for an already-ingested conversation applies directly',
        () async {
          // Control: when the row exists, applyReadCursor returns true and
          // the retry queue is never involved. Keeps the test above honest —
          // it must fail for the retry, not because markers never work.
          await ingestConversation(messageAt: _baseCreatedAt + 50);
          expect(await conversation(), isNotNull);

          await deliverReadMarker(
            wrapId: 'c' * 64,
            rumorId: 'd' * 64,
            readAt: _baseCreatedAt + 100,
          );

          final row = await conversation();
          expect(row!.lastReadTimestamp, _baseCreatedAt + 100);
          expect(row.isRead, isTrue);
        },
      );
    },
  );
}
