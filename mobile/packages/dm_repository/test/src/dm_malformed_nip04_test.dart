// ABOUTME: A kind 4 whose content is not a NIP-04 payload is dropped for good
// ABOUTME: before any signer is asked, instead of being stored as "" (#8712).

import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/nip04/nip04.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNostrClient extends Mock implements NostrClient {}

/// The owner's real NIP-04 crypto, counting every decrypt the repository
/// asks for.
class _CountingSigner extends LocalNostrSigner {
  _CountingSigner() : super(_ownerPrivateKey);

  int decrypts = 0;

  @override
  Future<String?> decrypt(String pubkey, String ciphertext) {
    decrypts++;
    return super.decrypt(pubkey, ciphertext);
  }
}

// Synthetic keys.
const _ownerPrivateKey =
    '1d2c3b4a59687766554433221100ffeeddccbbaa99887766554433221100ff01';
const _peerPrivateKey =
    '7f4c11a9b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d';
const _wellFormedId =
    'a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1';
const _malformedId =
    'b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2';

void main() {
  group('a kind 4 whose content is not a NIP-04 payload', () {
    final ownerPubkey = getPublicKey(_ownerPrivateKey);
    final peerPubkey = getPublicKey(_peerPrivateKey);
    final conversationId = DmRepository.computeConversationId(
      [ownerPubkey, peerPubkey]..sort(),
    );

    late AppDatabase db;
    late StreamController<Event> relay;
    late _CountingSigner signer;
    late DmRepository repository;

    Event kind4(String id, String content) => Event.fromJson({
      'id': id,
      'pubkey': peerPubkey,
      'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000 - 60,
      'kind': EventKind.directMessage,
      'tags': [
        ['p', ownerPubkey],
      ],
      'content': content,
      'sig': '',
    });

    Future<List<DirectMessageRow>> messages() => DirectMessagesDao(
      db,
    ).getMessagesForConversation(conversationId, ownerPubkey: ownerPubkey);

    Future<bool> recorded(String id) => ProcessedGiftWrapsDao(
      db,
    ).hasGiftWrapForOwner(giftWrapId: id, ownerPubkey: ownerPubkey);

    /// Pumps until [id] has an outcome, a stored message or a ledger row, so
    /// an assertion that something did not happen cannot pass because the
    /// event was never handled at all.
    Future<void> handled(String id) async {
      for (var i = 0; i < 50; i++) {
        if (await recorded(id) || (await messages()).isNotEmpty) return;
        await pumpEventQueue();
      }
      fail('Event $id was never handled');
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      db = AppDatabase.test(NativeDatabase.memory());
      relay = StreamController<Event>();
      signer = _CountingSigner();
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
        processedGiftWrapsDao: ProcessedGiftWrapsDao(db),
        userPubkey: ownerPubkey,
        syncState: DmSyncState(await SharedPreferences.getInstance()),
        signer: signer,
        rumorDecryptor: (_, _) async => null,
      );
      await repository.startListening();
    });

    tearDown(() async {
      await repository.stopListening();
      await relay.close();
      await db.close();
    });

    test('leaves a well-formed kind 4 to be stored with its text', () async {
      relay.add(
        kind4(
          _wellFormedId,
          NIP04.encrypt(
            'hello from the peer',
            NIP04.getAgreement(_peerPrivateKey),
            ownerPubkey,
          ),
        ),
      );
      await handled(_wellFormedId);

      expect(
        (await messages()).map((row) => row.content),
        equals(['hello from the peer']),
      );
    });

    test('is not stored as a message', () async {
      relay.add(kind4(_malformedId, 'garbage!!!'));
      await handled(_malformedId);

      expect(await messages(), isEmpty);
    });

    test('is never handed to the signer', () async {
      relay.add(kind4(_malformedId, 'garbage!!!'));
      await handled(_malformedId);

      expect(signer.decrypts, isZero);
    });

    test('is recorded as processed so a replay skips it', () async {
      relay.add(kind4(_malformedId, 'garbage!!!'));
      await handled(_malformedId);

      expect(await recorded(_malformedId), isTrue);
    });
  });
}
