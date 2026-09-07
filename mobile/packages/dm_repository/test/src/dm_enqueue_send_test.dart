// ABOUTME: #8053 — enqueueSend parks a durable DM row without publishing, so a
// ABOUTME: caller (the optimistic report flow) can await only the local write.

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

class _MockMessageService extends Mock implements NIP17MessageService {}

class _FakeEvent extends Fake implements Event {}

const _owner =
    'a4f5c1b2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8';
const _peer =
    'b1c2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8f9a0';
const _privateKey =
    '5426e5b8b4b0e2a1f5e8d3c7a9b2f4e6d8c0a2b4f6e8d0c2a4b6f8e0d2c4a6b8';
const _rumorId =
    '2222222222222222222222222222222222222222222222222222222222222222';

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeEvent());
    registerFallbackValue(Duration.zero);
  });

  group('enqueueSend (#8053)', () {
    late AppDatabase db;
    late OutgoingDmsDao outgoingDao;
    late _MockNostrClient nostrClient;
    late _MockMessageService messageService;
    late DmRepository repository;

    Event fakeRumor(String id) => Event.fromJson({
      'id': id,
      'pubkey': _owner,
      'created_at': 1700000000,
      'kind': EventKind.privateDirectMessage,
      'tags': [
        ['p', _peer],
      ],
      'content': 'report dm',
      'sig': '',
    });

    void stubBuildRumor(Event rumor) {
      when(
        () => messageService.buildRumor(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          additionalTags: any(named: 'additionalTags'),
        ),
      ).thenReturn(rumor);
    }

    setUp(() async {
      db = AppDatabase.test(NativeDatabase.memory());
      outgoingDao = OutgoingDmsDao(db);
      nostrClient = _MockNostrClient();
      messageService = _MockMessageService();

      when(() => nostrClient.connectedRelayCount).thenReturn(1);
      when(() => nostrClient.configuredRelayCount).thenReturn(1);
      when(() => messageService.canSendTo(any())).thenAnswer((_) async => true);

      repository = DmRepository(
        nostrClient: nostrClient,
        messageService: messageService,
        directMessagesDao: DirectMessagesDao(db),
        conversationsDao: ConversationsDao(db),
        outgoingDmsDao: outgoingDao,
        userPubkey: _owner,
        signer: LocalNostrSigner(_privateKey),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'parks a pending row and returns its rumor id without publishing',
      () async {
        stubBuildRumor(fakeRumor(_rumorId));

        final result = await repository.enqueueSend(
          recipientPubkey: _peer,
          content: 'report dm',
        );

        expect(result.accepted, isTrue);
        expect(result.queuedRumorId, _rumorId);

        final row = await outgoingDao.getById(_rumorId);
        expect(row, isNotNull);
        expect(row!.recipientWrapStatus, OutgoingWrapStatus.pending);
        expect(row.selfWrapStatus, OutgoingWrapStatus.pending);

        // The whole point: no network publish happened.
        verifyNever(
          () => messageService.sendRumor(
            rumorEvent: any(named: 'rumorEvent'),
            recipientPubkey: any(named: 'recipientPubkey'),
            targetRelays: any(named: 'targetRelays'),
            selfWrapTargetRelays: any(named: 'selfWrapTargetRelays'),
            awaitRecipientOk: any(named: 'awaitRecipientOk'),
            selfWrapOnSoftUnconfirmed: any(named: 'selfWrapOnSoftUnconfirmed'),
            recipientWrapBuildTimeout: any(named: 'recipientWrapBuildTimeout'),
            selfWrapBuildTimeout: any(named: 'selfWrapBuildTimeout'),
          ),
        );
      },
    );

    test('refuses a self-addressed send and enqueues nothing', () async {
      final result = await repository.enqueueSend(
        recipientPubkey: _owner,
        content: 'to myself',
      );

      expect(result.refused, isTrue);
      expect(result.accepted, isFalse);
      verifyNever(
        () => messageService.buildRumor(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          additionalTags: any(named: 'additionalTags'),
        ),
      );
    });

    test('reports a policy block and enqueues nothing', () async {
      when(
        () => messageService.canSendTo(any()),
      ).thenAnswer((_) async => false);

      final result = await repository.enqueueSend(
        recipientPubkey: _peer,
        content: 'blocked',
      );

      expect(result.blocked, isTrue);
      expect(result.accepted, isFalse);
      expect(await outgoingDao.getById(_rumorId), isNull);
    });
  });
}
