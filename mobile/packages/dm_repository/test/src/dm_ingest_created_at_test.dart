// ABOUTME: Ingest stores the clock-bounded preview stamp and the rumor's own
// ABOUTME: created_at, which the account-boundary cursor pin needs (#10276).

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
import 'package:shared_preferences/shared_preferences.dart';

class _MockNostrClient extends Mock implements NostrClient {}

const _owner =
    'a4f5c1b2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8';
const _peer =
    'b1c2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8f9a0';

void main() {
  group('ingest of a message from a sender whose clock runs ahead', () {
    late AppDatabase db;
    late StreamController<Event> relay;
    late DmRepository repository;
    late Map<String, Event> rumorByWrapId;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      db = AppDatabase.test(NativeDatabase.memory());
      relay = StreamController<Event>();
      rumorByWrapId = {};
      final nostrClient = _MockNostrClient();
      when(() => nostrClient.connectedRelayCount).thenReturn(1);
      when(() => nostrClient.configuredRelayCount).thenReturn(1);
      when(
        () => nostrClient.queryEvents(
          any(),
          subscriptionId: any(named: 'subscriptionId'),
          useCache: any(named: 'useCache'),
        ),
      ).thenAnswer((_) async => const <Event>[]);
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
        directMessagesDao: DirectMessagesDao(db),
        conversationsDao: ConversationsDao(db),
        userPubkey: _owner,
        syncState: DmSyncState(await SharedPreferences.getInstance()),
        signer: LocalNostrSigner('5' * 64),
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

    test('keeps the rumor created_at beside the bounded stamp', () async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final ahead = now + 3600;
      const wrapId =
          'c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0';
      rumorByWrapId[wrapId] = Event.fromJson({
        'id': 'd0' * 32,
        'pubkey': _peer,
        'created_at': ahead,
        'kind': EventKind.privateDirectMessage,
        'tags': [
          ['p', _owner],
        ],
        'content': 'from the future',
        'sig': '',
      });
      relay.add(
        Event.fromJson({
          'id': wrapId,
          'pubkey': _peer,
          'created_at': now,
          'kind': EventKind.giftWrap,
          'tags': [
            ['p', _owner],
          ],
          'content': 'wrapped',
          'sig': '',
        }),
      );
      ConversationRow? row;
      for (var i = 0; i < 50 && row == null; i++) {
        await pumpEventQueue();
        final rows = await ConversationsDao(
          db,
        ).getAllConversations(ownerPubkey: _owner);
        row = rows.isEmpty ? null : rows.single;
      }

      expect(row, isNotNull);
      expect(row!.lastMessageTimestamp, lessThan(ahead));
      expect(row.lastMessageCreatedAt, ahead);
    });
  });
}
