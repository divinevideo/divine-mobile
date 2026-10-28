// ABOUTME: #10012 — once a fallback-pool relay has confirmed a held send's
// ABOUTME: recipient wrap, retries publish no other recipient wrap while the
// ABOUTME: inbox stays unreadable, settle on the held wrap once it reads
// ABOUTME: absent, and republish to the inbox once it is found.

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

/// The real queue, except that recording a held wrap's id throws.
class _RecordFailingOutgoingDmsDao extends OutgoingDmsDao {
  _RecordFailingOutgoingDmsDao(super.attachedDatabase);

  @override
  Future<bool> markRecipientWrapStatus({
    required String id,
    required OutgoingWrapStatus status,
    String? eventId,
    String? lastError,
  }) {
    if (eventId != null && status != OutgoingWrapStatus.sent) {
      throw StateError('database is locked');
    }
    return super.markRecipientWrapStatus(
      id: id,
      status: status,
      eventId: eventId,
      lastError: lastError,
    );
  }
}

// Real curve keys: the real message service encrypts every wrap, so each
// pubkey has to be a point the NIP-44 key agreement accepts.
const _ownerKey =
    '5426e5b8b4b0e2a1f5e8d3c7a9b2f4e6d8c0a2b4f6e8d0c2a4b6f8e0d2c4a6b8';
const _peerBKey =
    '6a1f2e3d4c5b6a7980f1e2d3c4b5a69788f9e0d1c2b3a4958677f8e9d0c1b2a3';
const _peerCKey =
    '7b2e3f4a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8f9a0b1c2d3e4f5a6';

const _poolRelay = 'wss://relay.divine.video';
const _advertisedInbox = 'wss://inbox.example.com';

/// What a recipient's kind-10050 lookup comes back as.
enum _Inbox {
  /// The recipient's list is in hand.
  found,

  /// Every relay answered and none holds a list.
  absent,

  /// No relay took the REQ: we could not read it.
  unreadable,
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeEvent());
    registerFallbackValue(Duration.zero);
    registerFallbackValue(<nostr_filter.Filter>[]);
  });

  group('#10012 retries of a send held on an unreadable inbox', () {
    final owner = getPublicKey(_ownerKey);
    final peerB = getPublicKey(_peerBKey);
    final peerC = getPublicKey(_peerCKey);

    late AppDatabase db;
    late OutgoingDmsDao outgoingDao;
    late _MockNostrClient nostrClient;
    late Map<String, _Inbox> inboxes;
    late List<Event> published;
    late Map<String, List<String>?> recipientWrapTargets;
    late bool confirmRecipientWraps;
    late DmSendPolicyDecision policyDecision;
    late bool policyThrows;
    late int policyChecks;
    late bool deviceOffline;
    late int connectedRelays;
    late bool selfCopiesPublish;
    late DmRepository repository;

    /// Every gift wrap this device published addressed to [pubkey].
    List<Event> wrapsTo(String pubkey) => [
      for (final event in published)
        if (event.kind == EventKind.giftWrap &&
            event.tags.any(
              (tag) => tag.length >= 2 && tag[0] == 'p' && tag[1] == pubkey,
            ))
          event,
    ];

    /// A repository on the real message service and the [queue] given.
    DmRepository buildRepository({
      required OutgoingDmsDao queue,
      DmRepositoryErrorReporter? errorReporter,
    }) {
      final signer = LocalNostrSigner(_ownerKey);
      return DmRepository(
        nostrClient: nostrClient,
        messageService: NIP17MessageService(
          signer: signer,
          senderPublicKey: owner,
          nostrService: nostrClient,
          sendPolicy: (_) async {
            policyChecks++;
            if (policyThrows) throw StateError('policy unavailable');
            return policyDecision;
          },
          isOffline: () async => deviceOffline,
        ),
        directMessagesDao: DirectMessagesDao(db),
        conversationsDao: ConversationsDao(db),
        outgoingDmsDao: queue,
        userPubkey: owner,
        signer: signer,
        errorReporter: errorReporter,
      );
    }

    ({List<Event> events, bool timedOut, bool noRelays}) answerLookup(
      List<nostr_filter.Filter> filters,
    ) {
      final pubkey = filters.first.authors!.single;
      return switch (inboxes[pubkey] ?? _Inbox.absent) {
        _Inbox.found => (
          events: [
            Event(
              pubkey,
              EventKind.dmRelaysList,
              [
                ['relay', _advertisedInbox],
              ],
              '',
              createdAt: 1700000000,
            ),
          ],
          timedOut: false,
          noRelays: false,
        ),
        _Inbox.absent => (
          events: const <Event>[],
          timedOut: false,
          noRelays: false,
        ),
        _Inbox.unreadable => (
          events: const <Event>[],
          timedOut: false,
          noRelays: true,
        ),
      };
    }

    setUp(() {
      db = AppDatabase.test(NativeDatabase.memory());
      outgoingDao = OutgoingDmsDao(db);
      nostrClient = _MockNostrClient();
      inboxes = {};
      published = [];
      recipientWrapTargets = {};
      confirmRecipientWraps = true;
      policyDecision = DmSendPolicyDecision.allowed;
      policyThrows = false;
      policyChecks = 0;
      deviceOffline = false;
      connectedRelays = 1;
      selfCopiesPublish = true;

      when(
        () => nostrClient.connectedRelayCount,
      ).thenAnswer((_) => connectedRelays);
      when(() => nostrClient.configuredRelayCount).thenReturn(1);
      when(() => nostrClient.configuredRelays).thenReturn(const [_poolRelay]);
      when(() => nostrClient.isRelayAllowed(any())).thenReturn(true);
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
      ).thenAnswer(
        (invocation) async => answerLookup(
          (invocation.positionalArguments.first as List)
              .cast<nostr_filter.Filter>(),
        ),
      );
      // The recipient wrap: the pool confirms it unless a test says the OK
      // was lost, which is a send held for a reason other than the inbox.
      when(
        () => nostrClient.publishEventAwaitOk(
          any(),
          targetRelays: any(named: 'targetRelays'),
          timeout: any(named: 'timeout'),
          diagnosticTag: any(named: 'diagnosticTag'),
        ),
      ).thenAnswer((invocation) async {
        final event = invocation.positionalArguments.first as Event;
        published.add(event);
        recipientWrapTargets[event.id] =
            invocation.namedArguments[#targetRelays] as List<String>?;
        return PublishOutcome(
          eventId: event.id,
          acceptedBy: confirmRecipientWraps ? const [_poolRelay] : const [],
          rejectedBy: const {},
          noResponseFrom: confirmRecipientWraps ? const [] : const [_poolRelay],
        );
      });
      // The sender's own copy.
      when(
        () => nostrClient.publishEvent(
          any(),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).thenAnswer((invocation) async {
        if (!selfCopiesPublish) return const PublishFailed();
        final event = invocation.positionalArguments.first as Event;
        published.add(event);
        return PublishSuccess(event: event);
      });

      repository = buildRepository(queue: outgoingDao);
    });

    tearDown(() async {
      await db.close();
    });

    /// A 1:1 send to peer B that the pool confirmed on an unreadable inbox:
    /// its row id, and the recipient wrap the pool accepted.
    Future<({String rowId, Event poolWrap})> heldSend() async {
      inboxes[peerB] = _Inbox.unreadable;
      final held = await repository.sendMessage(
        recipientPubkey: peerB,
        content: 'held on an unreadable inbox',
      );
      expect(held.retryablePending, isTrue, reason: 'precondition: held');
      return (rowId: held.queuedRumorId!, poolWrap: wrapsTo(peerB).single);
    }

    group('sendMessage', () {
      test('records the wrap the pool accepted on the pending row', () async {
        final (:rowId, :poolWrap) = await heldSend();

        final row = await outgoingDao.getById(rowId);
        expect(row!.recipientWrapStatus, OutgoingWrapStatus.pending);
        expect(row.recipientWrapEventId, equals(poolWrap.id));
        expect(row.retryCount, equals(1));
      });

      test('reports a failed record and still holds the row', () async {
        inboxes[peerB] = _Inbox.unreadable;
        final reported = <String>[];
        final held = await buildRepository(
          queue: _RecordFailingOutgoingDmsDao(db),
          errorReporter: (_, _, {required site}) => reported.add(site),
        ).sendMessage(recipientPubkey: peerB, content: 'record fails');

        expect(held.retryablePending, isTrue);
        expect(reported, [DmRepositoryReportableSites.recordHeldPoolWrap]);
        final row = await outgoingDao.getById(held.queuedRumorId!);
        expect(row!.recipientWrapEventId, isNull);
        expect(row.retryCount, equals(1), reason: 'the attempt is charged');
      });
    });

    group('recoverFullSend while the inbox stays unreadable', () {
      test('leaves a retry uncharged while no relay is connected, then charges '
          'it once one is', () async {
        final (:rowId, :poolWrap) = await heldSend();
        connectedRelays = 0;

        final outage = await repository.recoverFullSend(rumorId: rowId);

        expect(outage.reachedNoRelay, isTrue);
        expect(outage.retryablePending, isFalse);
        final outageRow = await outgoingDao.getById(rowId);
        expect(outageRow!.retryCount, equals(1), reason: 'not charged');
        expect(outageRow.recipientWrapEventId, equals(poolWrap.id));

        connectedRelays = 1;
        final reconnected = await repository.recoverFullSend(rumorId: rowId);

        expect(reconnected.retryablePending, isTrue);
        final row = await outgoingDao.getById(rowId);
        expect(row!.retryCount, equals(2));
        expect(row.recipientWrapEventId, equals(poolWrap.id));
        expect(wrapsTo(peerB), hasLength(1));
      });

      test('publishes no other recipient wrap and still charges each '
          'attempt', () async {
        final (:rowId, :poolWrap) = await heldSend();

        for (var attempt = 0; attempt < 4; attempt++) {
          final retried = await repository.recoverFullSend(rumorId: rowId);
          expect(retried.retryablePending, isTrue);
        }

        expect(
          wrapsTo(peerB),
          hasLength(1),
          reason: 'five attempts, one recipient wrap: the one the pool holds',
        );
        expect(wrapsTo(owner), isEmpty, reason: 'still held, not delivered');
        final row = await outgoingDao.getById(rowId);
        expect(row!.recipientWrapStatus, OutgoingWrapStatus.pending);
        expect(row.recipientWrapEventId, equals(poolWrap.id));
        expect(
          row.retryCount,
          equals(5),
          reason: 'the budget still runs out, so the sweep can give up',
        );
      });

      test('a Resend of the exhausted row publishes no other recipient '
          'wrap', () async {
        final (:rowId, :poolWrap) = await heldSend();
        for (var attempt = 0; attempt < 4; attempt++) {
          final retried = await repository.recoverFullSend(rumorId: rowId);
          expect(retried.retryablePending, isTrue);
        }
        expect(
          (await outgoingDao.getById(rowId))!.retryCount,
          equals(5),
          reason: 'precondition: the budget is spent',
        );
        // What the sweep's exhausted guard does to a pending row whose
        // budget is spent.
        await outgoingDao.markRecipientWrapStatus(
          id: rowId,
          status: OutgoingWrapStatus.failed,
          lastError: 'Exhausted retries without recipient confirmation',
        );
        await outgoingDao.markSelfWrapStatus(
          id: rowId,
          status: OutgoingWrapStatus.failed,
          lastError: 'Exhausted retries without recipient confirmation',
        );

        final resent = await repository.recoverFullSend(
          rumorId: rowId,
          resetRetryBudget: true,
        );

        expect(resent.retryablePending, isTrue);
        expect(wrapsTo(peerB), hasLength(1));
        expect(wrapsTo(owner), isEmpty);
        final row = await outgoingDao.getById(rowId);
        expect(row!.recipientWrapStatus, OutgoingWrapStatus.failed);
        expect(row.recipientWrapEventId, equals(poolWrap.id));
        expect(row.retryCount, equals(1), reason: 'a fresh budget, charged');
      });
    });

    group('recoverFullSend once the inbox reads absent', () {
      test(
        'keeps the row for the self-copy when it fails to publish',
        () async {
          final (:rowId, :poolWrap) = await heldSend();
          inboxes[peerB] = _Inbox.absent;
          selfCopiesPublish = false;

          final retried = await repository.recoverFullSend(rumorId: rowId);

          expect(retried.success, isTrue);
          expect(wrapsTo(peerB), hasLength(1));
          final row = await outgoingDao.getById(rowId);
          expect(row!.recipientWrapStatus, OutgoingWrapStatus.sent);
          expect(row.selfWrapStatus, OutgoingWrapStatus.failed);
          expect(row.recipientWrapEventId, equals(poolWrap.id));
        },
      );

      test('settles on the held wrap and publishes only the withheld '
          'self-copy', () async {
        final (:rowId, :poolWrap) = await heldSend();
        inboxes[peerB] = _Inbox.absent;

        final retried = await repository.recoverFullSend(rumorId: rowId);

        expect(retried.success, isTrue);
        expect(
          wrapsTo(peerB),
          hasLength(1),
          reason: 'they read the pool, which already holds the wrap',
        );
        expect(wrapsTo(owner), hasLength(1));
        final message = await DirectMessagesDao(
          db,
        ).getMessageById(rowId, ownerPubkey: owner);
        expect(message, isNotNull);
        expect(message!.giftWrapId, equals(poolWrap.id));
        expect(await outgoingDao.getById(rowId), isNull);
      });
    });

    group('recoverFullSend once the inbox is found', () {
      test('asks the send policy once, through sendRumor', () async {
        final (:rowId, poolWrap: _) = await heldSend();
        inboxes[peerB] = _Inbox.found;
        policyChecks = 0;

        final retried = await repository.recoverFullSend(rumorId: rowId);

        expect(retried.success, isTrue);
        expect(policyChecks, equals(1));
      });

      test('publishes one new recipient wrap to the inbox and the '
          'self-copy', () async {
        final (:rowId, :poolWrap) = await heldSend();
        inboxes[peerB] = _Inbox.found;

        final retried = await repository.recoverFullSend(rumorId: rowId);

        expect(retried.success, isTrue);
        final recipientWraps = wrapsTo(peerB);
        expect(recipientWraps, hasLength(2));
        final inboxWrap = recipientWraps.last;
        expect(inboxWrap.id, isNot(equals(poolWrap.id)));
        expect(recipientWrapTargets[inboxWrap.id], equals([_advertisedInbox]));
        expect(wrapsTo(owner), hasLength(1));
        final message = await DirectMessagesDao(
          db,
        ).getMessageById(rowId, ownerPubkey: owner);
        expect(message!.giftWrapId, equals(inboxWrap.id));
        expect(await outgoingDao.getById(rowId), isNull);
      });
    });

    group('recoverFullSend makes the checks a publish makes first', () {
      test('discards a held row the send policy now blocks, without '
          'settling on the pool wrap', () async {
        final (:rowId, poolWrap: _) = await heldSend();
        inboxes[peerB] = _Inbox.absent;
        policyDecision = DmSendPolicyDecision.terminallyBlockedDiscard;

        final retried = await repository.recoverFullSend(rumorId: rowId);

        expect(retried.blocked, isTrue);
        expect(wrapsTo(peerB), hasLength(1));
        expect(wrapsTo(owner), isEmpty, reason: 'nothing was settled');
        expect(
          await DirectMessagesDao(
            db,
          ).getMessageById(rowId, ownerPubkey: owner),
          isNull,
        );
        expect(await outgoingDao.getById(rowId), isNull);
      });

      test('charges a held retry the send policy cannot decide yet as a '
          'failed one', () async {
        final (:rowId, :poolWrap) = await heldSend();
        policyDecision = DmSendPolicyDecision.temporarilyBlocked;

        final retried = await repository.recoverFullSend(rumorId: rowId);

        expect(retried.success, isFalse);
        expect(retried.blocked, isFalse);
        expect(retried.retryablePending, isFalse);
        expect(wrapsTo(peerB), hasLength(1));
        final row = await outgoingDao.getById(rowId);
        expect(row!.recipientWrapStatus, OutgoingWrapStatus.failed);
        expect(row.recipientWrapEventId, equals(poolWrap.id));
        expect(row.retryCount, equals(2));
      });

      test('fails a held retry whose send policy throws, as a publish '
          'would', () async {
        final (:rowId, :poolWrap) = await heldSend();
        policyThrows = true;

        final retried = await repository.recoverFullSend(rumorId: rowId);

        expect(retried.success, isFalse);
        expect(retried.retryablePending, isFalse);
        expect(wrapsTo(peerB), hasLength(1));
        final row = await outgoingDao.getById(rowId);
        expect(row!.recipientWrapStatus, OutgoingWrapStatus.failed);
        expect(row.recipientWrapEventId, equals(poolWrap.id));
        expect(row.retryCount, equals(2));
      });

      test(
        'leaves a held retry uncharged while the device is offline',
        () async {
          final (:rowId, :poolWrap) = await heldSend();
          deviceOffline = true;

          final retried = await repository.recoverFullSend(rumorId: rowId);

          expect(retried.reachedNoRelay, isTrue);
          expect(wrapsTo(peerB), hasLength(1));
          final row = await outgoingDao.getById(rowId);
          expect(row!.recipientWrapEventId, equals(poolWrap.id));
          expect(row.retryCount, equals(1), reason: 'an outage is not charged');
        },
      );
    });

    group('a send held for another reason', () {
      test('records no wrap when the recipient OK never arrived, so the '
          'retry republishes', () async {
        inboxes[peerB] = _Inbox.unreadable;
        confirmRecipientWraps = false;
        final held = await repository.sendMessage(
          recipientPubkey: peerB,
          content: 'no OK came back',
        );
        final rowId = held.queuedRumorId!;
        expect(held.retryablePending, isTrue);
        final heldRow = await outgoingDao.getById(rowId);
        expect(heldRow!.recipientWrapEventId, isNull);

        final retried = await repository.recoverFullSend(rumorId: rowId);

        expect(retried.retryablePending, isTrue);
        expect(
          wrapsTo(peerB),
          hasLength(2),
          reason: 'no relay is known to hold the first wrap',
        );
      });

      test('a retry the pool confirms on the unreadable inbox records its '
          'wrap, and the next retry publishes nothing', () async {
        inboxes[peerB] = _Inbox.unreadable;
        confirmRecipientWraps = false;
        final held = await repository.sendMessage(
          recipientPubkey: peerB,
          content: 'no OK came back the first time',
        );
        final rowId = held.queuedRumorId!;
        confirmRecipientWraps = true;
        final confirmed = await repository.recoverFullSend(rumorId: rowId);
        expect(confirmed.retryablePending, isTrue, reason: 'held, recorded');
        final poolWrap = wrapsTo(peerB).last;
        expect(
          wrapsTo(owner),
          isEmpty,
          reason: "a held retry the pool confirms withholds the sender's copy",
        );

        final again = await repository.recoverFullSend(rumorId: rowId);

        expect(again.retryablePending, isTrue);
        expect(wrapsTo(peerB), hasLength(2));
        final row = await outgoingDao.getById(rowId);
        expect(row!.recipientWrapEventId, equals(poolWrap.id));
      });
    });

    group('a group send with one unreadable member', () {
      test('settles that member on the pool wrap without saving the message '
          'twice', () async {
        inboxes[peerB] = _Inbox.found;
        inboxes[peerC] = _Inbox.unreadable;
        final results = await repository.sendGroupMessage(
          recipientPubkeys: [peerB, peerC],
          content: 'saved once, through the readable member',
        );
        expect(results.last.retryablePending, isTrue, reason: 'precondition');
        final heldRowId = results.last.queuedRumorId!;
        expect(await db.select(db.directMessages).get(), hasLength(1));
        inboxes[peerC] = _Inbox.absent;

        final retried = await repository.recoverFullSend(rumorId: heldRowId);

        expect(retried.success, isTrue);
        expect(wrapsTo(peerC), hasLength(1));
        expect(await db.select(db.directMessages).get(), hasLength(1));
        expect(await outgoingDao.getById(heldRowId), isNull);
      });

      test('publishes no other wrap to that member while their inbox stays '
          'unreadable', () async {
        inboxes[peerB] = _Inbox.found;
        inboxes[peerC] = _Inbox.unreadable;
        final results = await repository.sendGroupMessage(
          recipientPubkeys: [peerB, peerC],
          content: 'one readable member, one unreadable',
        );
        expect(results.first.success, isTrue);
        expect(results.last.retryablePending, isTrue);
        final heldRowId = results.last.queuedRumorId!;
        final poolWrap = wrapsTo(peerC).single;

        for (var attempt = 0; attempt < 2; attempt++) {
          final retried = await repository.recoverFullSend(rumorId: heldRowId);
          expect(retried.retryablePending, isTrue);
        }

        expect(wrapsTo(peerC), hasLength(1));
        expect(wrapsTo(peerB), hasLength(1));
        final row = await outgoingDao.getById(heldRowId);
        expect(row!.recipientWrapStatus, OutgoingWrapStatus.pending);
        expect(row.recipientWrapEventId, equals(poolWrap.id));
        expect(row.retryCount, equals(3));
      });
    });
  });
}
