// ABOUTME: A kind 4 the account's local key cannot decrypt is dropped for
// ABOUTME: good, since a retry under the same key cannot succeed (#8712).

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
import 'package:nostr_sdk/signer/isolate_decrypt_signer.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNostrClient extends Mock implements NostrClient {}

/// A signer whose key is held on the device, as for a local-key account.
class _LocalKeySigner extends LocalNostrSigner implements IsolateDecryptSigner {
  _LocalKeySigner(this._privateKeyHex) : super(_privateKeyHex);

  final String _privateKeyHex;

  @override
  bool get canDecryptInIsolate => true;

  @override
  T withPrivateKeyHex<T>(T Function(String hex) operation) =>
      operation(_privateKeyHex);
}

/// Holds the dedup probe for [holdId] until [resume] completes.
class _HeldProcessedGiftWrapsDao extends ProcessedGiftWrapsDao {
  _HeldProcessedGiftWrapsDao(super.attachedDatabase);

  String? holdId;
  final started = Completer<void>();
  final resume = Completer<void>();

  @override
  Future<bool> hasGiftWrap(String giftWrapId) async {
    if (giftWrapId == holdId && !started.isCompleted) {
      started.complete();
      await resume.future;
    }
    return super.hasGiftWrap(giftWrapId);
  }
}

// Synthetic keys. The peer encrypted [_payloadForAnotherRecipient] to a third
// key with `nak` 0.20.6, so it is well-formed but the owner cannot read it.
const _ownerPrivateKey =
    '1d2c3b4a59687766554433221100ffeeddccbbaa99887766554433221100ff01';
const _peerPrivateKey =
    '7f4c11a9b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d';
const _nextAccountPrivateKey =
    '2e3d4c5b6a79887766554433221100ffeeddccbbaa99887766554433221100f2';
const _otherRecipientPrivateKey =
    '3f4e5d6c7b8a99887766554433221100ffeeddccbbaa99887766554433221103';
const _payloadForAnotherRecipient =
    'frkb1N4rnki0zNjn4gnQKSbcUEcgY2X8lgN8zk+MT4qUxMB2IIlUH9dURh0H014W'
    '?iv=KR5RbN4CZE7tdq9XxeeLsA==';
const _readableId =
    'c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3';
const _unreadableId =
    'd4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4';
const _sharedId =
    'e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5';
const _sentId =
    'f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6';

void main() {
  group('a kind 4 the local key cannot decrypt', () {
    final ownerPubkey = getPublicKey(_ownerPrivateKey);
    final peerPubkey = getPublicKey(_peerPrivateKey);
    final otherRecipientPubkey = getPublicKey(_otherRecipientPrivateKey);
    final conversationId = DmRepository.computeConversationId(
      [ownerPubkey, peerPubkey]..sort(),
    );

    late AppDatabase db;
    late StreamController<Event> relay;
    late _MockNostrClient nostrClient;
    late _HeldProcessedGiftWrapsDao ledger;
    late DmRepository repository;

    Event kind4(
      String id,
      String content, {
      String? author,
      List<List<String>>? tags,
    }) => Event.fromJson({
      'id': id,
      'pubkey': author ?? peerPubkey,
      'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000 - 60,
      'kind': EventKind.directMessage,
      'tags':
          tags ??
          [
            ['p', ownerPubkey],
          ],
      'content': content,
      'sig': '',
    });

    String readablePayload() => NIP04.encrypt(
      'hello from the peer',
      NIP04.getAgreement(_peerPrivateKey),
      ownerPubkey,
    );

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
      nostrClient = _MockNostrClient();
      ledger = _HeldProcessedGiftWrapsDao(db);
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
        processedGiftWrapsDao: ledger,
        userPubkey: ownerPubkey,
        syncState: DmSyncState(await SharedPreferences.getInstance()),
        signer: _LocalKeySigner(_ownerPrivateKey),
        rumorDecryptor: (_, _) async => null,
      );
      await repository.startListening();
    });

    tearDown(() async {
      await repository.stopListening();
      await relay.close();
      await db.close();
    });

    test(
      'leaves a kind 4 the key can read to be stored with its text',
      () async {
        relay.add(kind4(_readableId, readablePayload()));
        await handled(_readableId);

        expect(
          (await messages()).map((row) => row.content),
          equals(['hello from the peer']),
        );
      },
    );

    test(
      'leaves a kind 4 this account sent to be stored with its text',
      () async {
        relay.add(
          kind4(
            _sentId,
            NIP04.encrypt(
              'hello from this account',
              NIP04.getAgreement(_ownerPrivateKey),
              peerPubkey,
            ),
            author: ownerPubkey,
            tags: [
              ['p', peerPubkey],
            ],
          ),
        );
        await handled(_sentId);

        expect(
          (await messages()).map((row) => row.content),
          equals(['hello from this account']),
        );
      },
    );

    test('is not stored as a message', () async {
      relay.add(kind4(_unreadableId, _payloadForAnotherRecipient));
      await handled(_unreadableId);

      expect(await messages(), isEmpty);
    });

    test('is recorded as processed so a replay skips it', () async {
      relay.add(kind4(_unreadableId, _payloadForAnotherRecipient));
      await handled(_unreadableId);

      expect(await recorded(_unreadableId), isTrue);
    });

    // The ledger is shared by every account on the device, and the account
    // this kind 4 was encrypted to may be one of them.
    for (final (order, tags) in [
      (
        'the other recipient first',
        [
          ['p', otherRecipientPubkey],
          ['p', ownerPubkey],
        ],
      ),
      (
        'this account first',
        [
          ['p', ownerPubkey],
          ['p', otherRecipientPubkey],
        ],
      ),
    ]) {
      test(
        'is not recorded when it also names another recipient, $order',
        () async {
          final forOtherRecipient = NIP04.encrypt(
            'for the other recipient',
            NIP04.getAgreement(_peerPrivateKey),
            otherRecipientPubkey,
          );
          relay
            ..add(kind4(_sharedId, forOtherRecipient, tags: tags))
            // Kind 4s are handled one at a time, so once this one is stored
            // the first has been handled too.
            ..add(kind4(_readableId, readablePayload()));
          await handled(_readableId);

          expect(await recorded(_sharedId), isFalse);
        },
      );
    }

    test(
      'is not recorded for an account that switched away while the event '
      'was checked',
      () async {
        ledger.holdId = _readableId;
        relay.add(kind4(_readableId, readablePayload()));
        await ledger.started.future;

        final nextSigner = _LocalKeySigner(_nextAccountPrivateKey);
        final nextPubkey = getPublicKey(_nextAccountPrivateKey);
        repository.setCredentials(
          userPubkey: nextPubkey,
          signer: nextSigner,
          messageService: NIP17MessageService(
            signer: nextSigner,
            senderPublicKey: nextPubkey,
            nostrService: nostrClient,
          ),
        );
        ledger.resume.complete();
        await pumpEventQueue();

        expect(await recorded(_readableId), isFalse);
      },
    );
  });
}
