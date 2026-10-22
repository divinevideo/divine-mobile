// ABOUTME: #8628 — every failed replay the two recovery primitives run is
// ABOUTME: charged to the queue row's retry budget exactly once, whoever
// ABOUTME: called them, so five attempts mean five on every path.

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
import 'package:nostr_sdk/filter.dart' as nostr_filter;
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _FakeEvent extends Fake implements Event {}

/// The real DAO, counting every charge so a double charge cannot hide behind
/// a column that ends at the same value.
class _ChargeCountingDao extends OutgoingDmsDao {
  _ChargeCountingDao(super.attachedDatabase);

  int charges = 0;

  @override
  Future<bool> incrementRetry(String id) {
    charges++;
    return super.incrementRetry(id);
  }
}

// Real curve keys: the real message service encrypts every wrap.
const _ownerKey =
    '5426e5b8b4b0e2a1f5e8d3c7a9b2f4e6d8c0a2b4f6e8d0c2a4b6f8e0d2c4a6b8';
const _peerKey =
    '6a1f2e3d4c5b6a7980f1e2d3c4b5a69788f9e0d1c2b3a4958677f8e9d0c1b2a3';

const _poolRelay = 'wss://relay.divine.video';
const _ownInbox = 'wss://own-inbox.example.com';

/// How the relay answers the recipient's gift wrap.
enum _Recipient {
  confirms,
  rejects,
  neverAnswers,

  /// No relay took the frame: accepted, rejected and silent are all empty.
  unreached,
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeEvent());
    registerFallbackValue(Duration.zero);
    registerFallbackValue(<nostr_filter.Filter>[]);
  });

  group('#8628 recovery charges each failed replay once', () {
    final owner = getPublicKey(_ownerKey);
    final peer = getPublicKey(_peerKey);

    late AppDatabase db;
    late _ChargeCountingDao dao;
    late _MockNostrClient nostrClient;
    late DmRepository repository;
    late _Recipient recipient;
    late PublishResult Function(Event) selfCopy;
    late int recipientPublishes;
    late int selfCopyPublishes;
    late int connectedRelays;
    late bool ownInboxAdvertised;

    setUp(() {
      db = AppDatabase.test(NativeDatabase.memory());
      dao = _ChargeCountingDao(db);
      nostrClient = _MockNostrClient();
      recipient = _Recipient.confirms;
      selfCopy = (event) => PublishSuccess(event: event);
      recipientPublishes = 0;
      selfCopyPublishes = 0;
      connectedRelays = 1;
      ownInboxAdvertised = false;

      when(
        () => nostrClient.connectedRelayCount,
      ).thenAnswer((_) => connectedRelays);
      when(() => nostrClient.configuredRelayCount).thenReturn(1);
      when(() => nostrClient.configuredRelays).thenReturn(const [_poolRelay]);
      when(() => nostrClient.isRelayAllowed(any())).thenReturn(true);
      // Every relay answers. Only the sender's own kind-10050 list can exist,
      // when a test advertises it; otherwise both copies go to the pool.
      when(
        () => nostrClient.queryEventsDetailed(
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
        ),
      ).thenAnswer((invocation) async {
        final filters = (invocation.positionalArguments.first as List)
            .cast<nostr_filter.Filter>();
        final asksForOwnInbox = filters.first.authors?.contains(owner) ?? false;
        return (
          events: [
            if (ownInboxAdvertised && asksForOwnInbox)
              Event(
                owner,
                EventKind.dmRelaysList,
                [
                  ['relay', _ownInbox],
                ],
                '',
                createdAt: 1700000000,
              ),
          ],
          timedOut: false,
          noRelays: false,
        );
      });
      when(
        () => nostrClient.publishEventAwaitOk(
          any(),
          targetRelays: any(named: 'targetRelays'),
          timeout: any(named: 'timeout'),
          diagnosticTag: any(named: 'diagnosticTag'),
        ),
      ).thenAnswer((invocation) async {
        final event = invocation.positionalArguments.first as Event;
        recipientPublishes++;
        return PublishOutcome(
          eventId: event.id,
          acceptedBy: [if (recipient == _Recipient.confirms) _poolRelay],
          rejectedBy: {
            if (recipient == _Recipient.rejects) _poolRelay: 'blocked: test',
          },
          noResponseFrom: [
            if (recipient == _Recipient.neverAnswers) _poolRelay,
          ],
        );
      });
      when(
        () => nostrClient.publishEvent(
          any(),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).thenAnswer((invocation) async {
        selfCopyPublishes++;
        return selfCopy(invocation.positionalArguments.first as Event);
      });

      final signer = LocalNostrSigner(_ownerKey);
      repository = DmRepository(
        nostrClient: nostrClient,
        messageService: NIP17MessageService(
          signer: signer,
          senderPublicKey: owner,
          nostrService: nostrClient,
        ),
        directMessagesDao: DirectMessagesDao(db),
        conversationsDao: ConversationsDao(db),
        outgoingDmsDao: dao,
        userPubkey: owner,
        signer: signer,
      );
    });

    tearDown(() async {
      await db.close();
    });

    /// A send the recipient received whose self-copy failed: the row the
    /// sentPartial Retry and the sweep's self-wrap arm replay.
    Future<String> deliveredWithoutSelfCopy() async {
      selfCopy = (_) => const PublishFailed();
      final sent = await repository.sendMessage(
        recipientPubkey: peer,
        content: 'delivered, not copied',
      );
      // A delivered send hands back its rumor id, not a queue handle.
      final row = await dao.getById(sent.rumorEventId!);
      expect(row!.recipientWrapStatus, OutgoingWrapStatus.sent);
      expect(row.selfWrapStatus, OutgoingWrapStatus.failed);
      expect(row.retryCount, 0);
      dao.charges = 0;
      return row.id;
    }

    /// A send the relay rejected outright.
    Future<String> rejectedSend() async {
      recipient = _Recipient.rejects;
      final sent = await repository.sendMessage(
        recipientPubkey: peer,
        content: 'rejected',
      );
      final row = await dao.getById(sent.queuedRumorId!);
      expect(row!.recipientWrapStatus, OutgoingWrapStatus.failed);
      expect(row.retryCount, 0);
      dao.charges = 0;
      return row.id;
    }

    Future<void> corruptRumor(String id) => db.customStatement(
      "UPDATE outgoing_dms SET rumor_event_json = 'not json' WHERE id = ?",
      [id],
    );

    Future<int> retryCount(String id) async =>
        (await dao.getById(id))!.retryCount;

    group('recoverFullSend', () {
      test('charges a self-copy replay that fails once, without '
          'republishing to the recipient', () async {
        final id = await deliveredWithoutSelfCopy();

        final result = await repository.recoverFullSend(
          rumorId: id,
          resetRetryBudget: true,
        );

        expect(result.success, isFalse);
        expect(selfCopyPublishes, 2, reason: 'one self-copy replay ran');
        expect(recipientPublishes, 1);
        expect(dao.charges, 1);
        expect(await retryCount(id), 1);
      });

      test('charges a replay the relay rejects once', () async {
        final id = await rejectedSend();

        final result = await repository.recoverFullSend(
          rumorId: id,
          resetRetryBudget: true,
        );

        expect(result.success, isFalse);
        expect(result.retryablePending, isFalse);
        expect(recipientPublishes, 2, reason: 'one replay ran');
        expect(dao.charges, 1);
        expect(await retryCount(id), 1);
      });

      test('charges a replay nobody answered once', () async {
        final id = await rejectedSend();
        recipient = _Recipient.neverAnswers;

        final result = await repository.recoverFullSend(rumorId: id);

        expect(result.retryablePending, isTrue);
        expect(dao.charges, 1);
        expect(await retryCount(id), 1);
      });

      test('charges a stored rumor it cannot parse once', () async {
        final id = await rejectedSend();
        await corruptRumor(id);

        final result = await repository.recoverFullSend(rumorId: id);

        expect(result.success, isFalse);
        expect(recipientPublishes, 1, reason: 'nothing was republished');
        expect(dao.charges, 1);
        expect(await retryCount(id), 1);
      });

      test('charges two callers that join one failing replay once', () async {
        final id = await rejectedSend();

        final results = await Future.wait([
          repository.recoverFullSend(rumorId: id),
          repository.recoverFullSend(rumorId: id),
        ]);

        expect(results.every((result) => !result.success), isTrue);
        expect(recipientPublishes, 2, reason: 'the two calls shared one');
        expect(dao.charges, 1);
        expect(await retryCount(id), 1);
      });

      test('deletes the row of a delivered replay without charging', () async {
        final id = await rejectedSend();
        recipient = _Recipient.confirms;

        final result = await repository.recoverFullSend(rumorId: id);

        expect(result.success, isTrue);
        expect(await dao.getById(id), isNull);
        expect(dao.charges, 0);
      });

      test('does not charge a replay that reached no relay', () async {
        final id = await rejectedSend();
        recipient = _Recipient.unreached;

        final result = await repository.recoverFullSend(rumorId: id);

        expect(result.reachedNoRelay, isTrue);
        expect(recipientPublishes, 2, reason: 'the replay was attempted');
        expect(dao.charges, 0, reason: 'an outage is not an attempt (#8516)');
        expect(await retryCount(id), 0);
      });
    });

    group('recoverSelfWrap', () {
      test('charges a self-copy replay that fails once', () async {
        final id = await deliveredWithoutSelfCopy();

        final result = await repository.recoverSelfWrap(rumorId: id);

        expect(result.success, isFalse);
        expect(selfCopyPublishes, 2, reason: 'one self-copy replay ran');
        expect(dao.charges, 1);
        expect(await retryCount(id), 1);
      });

      test('charges two callers that join one failing self-copy replay '
          'once', () async {
        final id = await deliveredWithoutSelfCopy();

        final results = await Future.wait([
          repository.recoverSelfWrap(rumorId: id),
          repository.recoverSelfWrap(rumorId: id),
        ]);

        expect(results.every((result) => !result.success), isTrue);
        expect(selfCopyPublishes, 2, reason: 'the two calls shared one');
        expect(dao.charges, 1);
        expect(await retryCount(id), 1);
      });

      test(
        'does not charge a self-copy replay that reached no relay',
        () async {
          final id = await deliveredWithoutSelfCopy();
          selfCopy = (_) => const PublishNoRelays();

          final result = await repository.recoverSelfWrap(rumorId: id);

          expect(result.success, isFalse);
          expect(result.reachedNoRelay, isTrue);
          expect(selfCopyPublishes, 2, reason: 'the replay was attempted');
          expect(dao.charges, 0);
          expect(await retryCount(id), 0);
        },
      );

      test('with resetRetryBudget, hands an exhausted row back with a fresh '
          'budget before charging the replay', () async {
        final id = await deliveredWithoutSelfCopy();
        for (var i = 0; i < 5; i++) {
          await dao.incrementRetry(id);
        }
        expect(await retryCount(id), 5, reason: 'the sweep has given up');
        dao.charges = 0;

        final result = await repository.recoverSelfWrap(
          rumorId: id,
          resetRetryBudget: true,
        );

        expect(result.success, isFalse);
        expect(dao.charges, 1);
        expect(await retryCount(id), 1);
      });

      test('does not charge a replay abandoned before publishing because the '
          'session ended', () async {
        final id = await deliveredWithoutSelfCopy();

        final pending = repository.recoverSelfWrap(rumorId: id);
        // Ends the session while the replay is between its row read and its
        // publish, the window the account-switch guard covers.
        unawaited(repository.stopListening());
        final result = await pending;

        expect(result.retryablePending, isTrue);
        expect(selfCopyPublishes, 1, reason: 'nothing was republished');
        expect(dao.charges, 0);
        expect(await retryCount(id), 0);
      });

      test('does not charge a self-copy to an advertised inbox while no relay '
          'is connected', () async {
        ownInboxAdvertised = true;
        final id = await deliveredWithoutSelfCopy();
        connectedRelays = 0;

        final result = await repository.recoverSelfWrap(rumorId: id);

        expect(result.reachedNoRelay, isTrue);
        expect(selfCopyPublishes, 2, reason: 'the replay was attempted');
        expect(dao.charges, 0);
        expect(await retryCount(id), 0);
      });

      test('does not wake the sweep for a self-copy replay that reached no '
          'relay', () async {
        final id = await deliveredWithoutSelfCopy();
        selfCopy = (_) => const PublishNoRelays();
        final nudges = <void>[];
        final subscription = repository.retryableOutgoingWork.listen(
          nudges.add,
        );
        addTearDown(subscription.cancel);

        final _ = await repository.recoverSelfWrap(rumorId: id);
        await pumpEventQueue();

        expect(
          nudges,
          isEmpty,
          reason: 'a relay connecting wakes the sweep for it (#8516)',
        );
      });

      test('charges a stored rumor it cannot parse once', () async {
        final id = await deliveredWithoutSelfCopy();
        await corruptRumor(id);

        final result = await repository.recoverSelfWrap(rumorId: id);

        expect(result.success, isFalse);
        expect(selfCopyPublishes, 1, reason: 'nothing was republished');
        expect(dao.charges, 1);
        expect(await retryCount(id), 1);
      });

      test('deletes the row of a delivered replay without charging', () async {
        final id = await deliveredWithoutSelfCopy();
        selfCopy = (event) => PublishSuccess(event: event);

        final result = await repository.recoverSelfWrap(rumorId: id);

        expect(result.success, isTrue);
        expect(await dao.getById(id), isNull);
        expect(dao.charges, 0);
      });
    });
  });
}
