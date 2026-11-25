// ABOUTME: Exercises video share retries across a real SQLite close/reopen.
// ABOUTME: Encrypted video shares retain their rumor and protocol on reconnect.

import 'dart:convert';
import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart' as nostr_filter;
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:openvine/services/outgoing_dm_retry_service.dart';

class _Client extends Mock implements NostrClient {}

class _FakeEvent extends Fake implements Event {}

final String _senderKey = '01' * 32;

class _Signer extends LocalNostrSigner {
  _Signer() : super(_senderKey);

  int legacyEncryptions = 0;

  @override
  Future<String?> encrypt(String pubkey, String plaintext) {
    legacyEncryptions++;
    return super.encrypt(pubkey, plaintext);
  }
}

void main() {
  const relay = 'wss://relay.example';
  final owner = getPublicKey(_senderKey);
  final recipient = getPublicKey('02' * 32);
  final otherOwner = getPublicKey('03' * 32);

  setUpAll(() {
    registerFallbackValue(_FakeEvent());
    registerFallbackValue(Duration.zero);
    registerFallbackValue(<nostr_filter.Filter>[]);
  });

  test(
    'reconnect after restart replays only the owner’s original rumor',
    () async {
      final dir = await Directory.systemTemp.createTemp('dm_share_retry_');
      final file = File('${dir.path}/app.db');
      var db = AppDatabase.test(NativeDatabase(file));
      final client = _Client();
      final published = <Event>[];
      var offline = true;
      when(() => client.connectedRelayCount).thenReturn(1);
      when(() => client.configuredRelayCount).thenReturn(1);
      when(() => client.configuredRelays).thenReturn([relay]);
      when(() => client.isRelayAllowed(any())).thenReturn(true);
      when(
        () => client.queryEventsDetailed(
          any(),
          subscriptionId: any(named: 'subscriptionId'),
          tempRelays: any(named: 'tempRelays'),
          relayTypes: any(named: 'relayTypes'),
          sendAfterAuth: any(named: 'sendAfterAuth'),
          useCache: any(named: 'useCache'),
          useQueryPool: any(named: 'useQueryPool'),
          timeout: any(named: 'timeout'),
          requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          acceptRelayClosedWhenOthersAnswered: any(
            named: 'acceptRelayClosedWhenOthersAnswered',
          ),
          silentRelayTimeout: any(named: 'silentRelayTimeout'),
        ),
      ).thenAnswer(
        (_) async => (events: <Event>[], timedOut: false, noRelays: false),
      );
      when(
        () => client.publishEventAwaitOk(
          any(),
          targetRelays: any(named: 'targetRelays'),
          timeout: any(named: 'timeout'),
          diagnosticTag: any(named: 'diagnosticTag'),
        ),
      ).thenAnswer((call) async {
        final event = call.positionalArguments.first as Event;
        published.add(event);
        return PublishOutcome(
          eventId: event.id,
          acceptedBy: [relay],
          rejectedBy: const {},
          noResponseFrom: const [],
        );
      });
      when(
        () => client.publishEvent(
          any(),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).thenAnswer((call) async {
        final event = call.positionalArguments.first as Event;
        published.add(event);
        return PublishSuccess(event: event);
      });

      final signer = _Signer();
      DmRepository buildRepository() {
        return DmRepository(
          nostrClient: client,
          messageService: NIP17MessageService(
            signer: signer,
            senderPublicKey: owner,
            nostrService: client,
            isOffline: () async => offline,
          ),
          directMessagesDao: db.directMessagesDao,
          conversationsDao: db.conversationsDao,
          outgoingDmsDao: db.outgoingDmsDao,
          signer: signer,
          userPubkey: owner,
          environment: 'staging',
        );
      }

      var repo = buildRepository();
      addTearDown(() async {
        await repo.stopListening();
        await db.close();
        await dir.delete(recursive: true);
      });

      // A legacy thread and an incomplete citation leave a plain-text-shaped
      // rumor. Replay must retain the original share's explicit kind-4 opt-out.
      final conversationId = DmRepository.computeConversationId([
        owner,
        recipient,
      ]);
      await db.conversationsDao.upsertConversation(
        id: conversationId,
        participantPubkeys: jsonEncode([owner, recipient]),
        isGroup: false,
        createdAt: 1700000000,
        dmProtocol: 'nip04',
        ownerPubkey: owner,
      );
      final results = await repo.enqueueSharedVideoBatch(
        recipientPubkeys: [recipient],
        baseContent: 'https://divine.video/video',
        videoKind: 22,
        videoAuthorPubkey: '',
      );
      final queued = results[recipient]! as ShareEnqueueQueued;
      expect(
        (await repo.recoverFullSend(rumorId: queued.rumorId)).success,
        isFalse,
      );
      expect(published, isEmpty);

      await repo.stopListening();
      await db.close();
      db = AppDatabase.test(NativeDatabase(file));
      repo = buildRepository();
      final row = await db.outgoingDmsDao.getById(queued.rumorId);
      expect(row!.skipNip04Fallback, isTrue);
      expect(row.content, 'https://divine.video/video');
      offline = false;
      Future<void> sweep(String activeOwner) async {
        final retry = OutgoingDmRetryService(
          dmRepository: repo,
          outgoingDmsDao: db.outgoingDmsDao,
          userPubkey: activeOwner,
          appForegroundStream: const Stream.empty(),
          environment: 'staging',
          now: () => DateTime.now().add(const Duration(days: 1)),
        );
        try {
          await retry.sweep();
        } finally {
          await retry.dispose();
        }
      }

      await sweep(otherOwner);
      expect(published, isEmpty);
      await sweep(owner);
      expect(signer.legacyEncryptions, 0);
      expect(published, isNotEmpty);
      expect(published.map((event) => event.kind), everyElement(1059));
      expect(await db.outgoingDmsDao.getById(queued.rumorId), isNull);
      expect(
        (await repo.getMessages(conversationId)).single.id,
        queued.rumorId,
      );
    },
  );
}
