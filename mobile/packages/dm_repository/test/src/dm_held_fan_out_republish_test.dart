// ABOUTME: #10012 — retries of a DM reaction, its removal, or a
// ABOUTME: delete-for-everyone send a member an earlier attempt reached nothing
// ABOUTME: again, and keep a wrap the fallback pool confirmed on an unreadable
// ABOUTME: inbox until it reads absent (settle) or is found (wrap again); the
// ABOUTME: sender's copy waits for delivery.

import 'dart:async';
import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/filter.dart' as nostr_filter;
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _FakeEvent extends Fake implements Event {}

/// The real reaction queue, except that recording what relays hold throws.
class _RecordFailingDmReactionsDao extends DmReactionsDao {
  _RecordFailingDmReactionsDao(super.attachedDatabase);

  @override
  Future<bool> recordHeldReactionWrap({
    required String id,
    required String ownerPubkey,
    required String recipientPubkey,
    required String wrapEventId,
  }) async => throw StateError('database is locked');

  @override
  Future<bool> recordHeldRemovalWrap({
    required String id,
    required String ownerPubkey,
    required String recipientPubkey,
    required String wrapEventId,
  }) async => throw StateError('database is locked');

  @override
  Future<bool> recordDeliveredReactionWraps({
    required String id,
    required String ownerPubkey,
    required Map<String, String> wraps,
  }) async => throw StateError('database is locked');

  @override
  Future<bool> recordDeliveredRemovalWraps({
    required String id,
    required String ownerPubkey,
    required Map<String, String> wraps,
  }) async => throw StateError('database is locked');
}

/// The real message store, except that recording what relays hold throws.
class _RecordFailingDirectMessagesDao extends DirectMessagesDao {
  _RecordFailingDirectMessagesDao(super.attachedDatabase);

  @override
  Future<bool> recordHeldDeletionWrap(
    String rumorId, {
    required String recipientPubkey,
    required String wrapEventId,
    String? ownerPubkey,
  }) async => throw StateError('database is locked');

  @override
  Future<bool> recordDeliveredDeletionWraps(
    String rumorId, {
    required Map<String, String> wraps,
    String? ownerPubkey,
  }) async => throw StateError('database is locked');
}

/// The real message store, observed: counts the moves of a retraction back to
/// pending and the warnings written back, and runs [nextStep] once at the
/// next point a retry reads the row or moves it back to pending.
class _ObservedDirectMessagesDao extends DirectMessagesDao {
  _ObservedDirectMessagesDao(super.attachedDatabase);

  Future<void> Function()? nextStep;
  int movesToPending = 0;
  int warningsWritten = 0;

  Future<void> _step() async {
    final step = nextStep;
    nextStep = null;
    await step?.call();
  }

  @override
  Future<DirectMessageRow?> getMessageById(
    String id, {
    String? ownerPubkey,
  }) async {
    final row = await super.getMessageById(id, ownerPubkey: ownerPubkey);
    await _step();
    return row;
  }

  @override
  Future<bool> markUnconfirmedMessageDeletionPending(
    String rumorId, {
    String? ownerPubkey,
  }) async {
    await _step();
    movesToPending++;
    return super.markUnconfirmedMessageDeletionPending(
      rumorId,
      ownerPubkey: ownerPubkey,
    );
  }

  @override
  Future<bool> markMessageDeletionUnconfirmed(
    String rumorId, {
    String? ownerPubkey,
  }) {
    warningsWritten++;
    return super.markMessageDeletionUnconfirmed(
      rumorId,
      ownerPubkey: ownerPubkey,
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

const _reactedMessageId =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _retractedMessageId =
    '2222222222222222222222222222222222222222222222222222222222222222';
const _retractedMessageWrapId =
    '3333333333333333333333333333333333333333333333333333333333333333';

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

  group('#10012 retries of a reaction or retraction held on an unreadable '
      'inbox', () {
    final owner = getPublicKey(_ownerKey);
    final peerB = getPublicKey(_peerBKey);
    final peerC = getPublicKey(_peerCKey);
    final oneToOne = DmRepository.computeConversationId([owner, peerB]);
    final room = DmRepository.computeConversationId([owner, peerB, peerC]);

    late AppDatabase db;
    late _MockNostrClient nostrClient;
    late Map<String, _Inbox> inboxes;
    late List<Event> published;
    late Map<String, List<String>?> recipientWrapTargets;
    late bool confirmRecipientWraps;
    late Set<String> okLostFor;
    late DmSendPolicyDecision policyDecision;
    late bool policyThrows;
    late Set<String> policyThrowsFor;
    late int policyChecks;
    late bool deviceOffline;
    late int connectedRelays;
    late bool ownCopiesPublish;
    late DmRepository repository;
    late DmReactionsRepository reactions;

    /// Every gift wrap this device published addressed to [pubkey], from the
    /// [from]th publish on.
    List<Event> wrapsTo(String pubkey, {int from = 0}) => [
      for (final event in published.skip(from))
        if (event.kind == EventKind.giftWrap &&
            event.tags.any(
              (tag) => tag.length >= 2 && tag[0] == 'p' && tag[1] == pubkey,
            ))
          event,
    ];

    /// The wraps a held-wrap column records, keyed by recipient.
    Map<String, dynamic>? heldWraps(String? json) =>
        json == null ? null : jsonDecode(json) as Map<String, dynamic>;

    /// A held-wrap record's entry for a recipient the fallback pool holds
    /// [wrapId] for while their inbox cannot be read.
    Map<String, Object> heldEntry(String wrapId) => {
      'wrap': wrapId,
      'delivered': false,
    };

    /// A held-wrap record's entry for a recipient who has the rumor through
    /// [wrapId].
    Map<String, Object> deliveredEntry(String wrapId) => {
      'wrap': wrapId,
      'delivered': true,
    };

    /// A repository and a reactions repository on the real message service,
    /// wired to each other as `repository_providers.dart` wires them.
    void buildStack({
      DmReactionsDao? reactionsDao,
      DirectMessagesDao? messagesDao,
      List<String>? reportedSites,
    }) {
      final signer = LocalNostrSigner(_ownerKey);
      final messageService = NIP17MessageService(
        signer: signer,
        senderPublicKey: owner,
        nostrService: nostrClient,
        sendPolicy: (recipient) async {
          policyChecks++;
          if (policyThrows || policyThrowsFor.contains(recipient)) {
            throw StateError('policy unavailable');
          }
          return policyDecision;
        },
        isOffline: () async => deviceOffline,
        // On this isolate, so the unawaited first attempt of a removal or a
        // retraction runs to its end within the test's event loop.
        isolateGiftWrapBatchBuilder: buildGiftWrapBatch,
      );
      reactions = DmReactionsRepository(
        reactionsDao: reactionsDao ?? DmReactionsDao(db),
        messageService: messageService,
        userPubkey: owner,
        conversationsDao: ConversationsDao(db),
        directMessagesDao: messagesDao ?? DirectMessagesDao(db),
        errorReporter: reportedSites == null
            ? null
            : (_, _, {required site}) => reportedSites.add(site),
      );
      repository = DmRepository(
        nostrClient: nostrClient,
        messageService: messageService,
        directMessagesDao: messagesDao ?? DirectMessagesDao(db),
        conversationsDao: ConversationsDao(db),
        outgoingDmsDao: OutgoingDmsDao(db),
        userPubkey: owner,
        signer: signer,
        reactionsRepository: reactions,
        errorReporter: reportedSites == null
            ? null
            : (_, _, {required site}) => reportedSites.add(site),
      );
      reactions
        ..setDmInboxRelayResolver(repository.resolveDmInboxRelaysDetailed)
        ..setSelfWrapRelayResolver(repository.resolveSelfWrapTargetRelays);
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
      nostrClient = _MockNostrClient();
      inboxes = {};
      published = [];
      recipientWrapTargets = {};
      confirmRecipientWraps = true;
      okLostFor = {};
      policyDecision = DmSendPolicyDecision.allowed;
      policyThrows = false;
      policyThrowsFor = {};
      policyChecks = 0;
      deviceOffline = false;
      connectedRelays = 1;
      ownCopiesPublish = true;

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
      // A recipient wrap: the pool confirms it unless a test says the OK was
      // lost, for every recipient or for those in okLostFor, which holds an
      // attempt for a reason other than the inbox.
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
        final confirmed =
            confirmRecipientWraps &&
            !event.tags.any(
              (tag) =>
                  tag.length >= 2 &&
                  tag[0] == 'p' &&
                  okLostFor.contains(tag[1]),
            );
        return PublishOutcome(
          eventId: event.id,
          acceptedBy: confirmed ? const [_poolRelay] : const [],
          rejectedBy: const {},
          noResponseFrom: confirmed ? const [] : const [_poolRelay],
        );
      });
      // The sender's own copy.
      when(
        () => nostrClient.publishEvent(
          any(),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).thenAnswer((invocation) async {
        if (!ownCopiesPublish) return const PublishFailed();
        final event = invocation.positionalArguments.first as Event;
        published.add(event);
        return PublishSuccess(event: event);
      });

      buildStack();
    });

    tearDown(() async {
      await db.close();
    });

    Future<void> seedConversation(String id, List<String> participants) =>
        ConversationsDao(db).upsertConversation(
          id: id,
          participantPubkeys: jsonEncode(participants),
          isGroup: participants.length > 2,
          createdAt: 1700000000,
          ownerPubkey: owner,
        );

    /// The settle branch checks, each with what a check that refuses leaves.
    /// A retry that skipped them would settle on the held wrap instead.
    final settleChecks =
        <({String refusal, void Function() arrange, bool noRelay})>[
          (
            refusal: 'the send policy now refuses',
            arrange: () =>
                policyDecision = DmSendPolicyDecision.terminallyBlockedDiscard,
            noRelay: false,
          ),
          (
            refusal: 'the send policy cannot decide yet',
            arrange: () =>
                policyDecision = DmSendPolicyDecision.temporarilyBlocked,
            noRelay: false,
          ),
          (
            refusal: 'the send policy throws',
            arrange: () => policyThrows = true,
            noRelay: false,
          ),
          (
            refusal: 'the device is offline',
            arrange: () => deviceOffline = true,
            noRelay: true,
          ),
          (
            refusal: 'no relay is connected',
            arrange: () => connectedRelays = 0,
            noRelay: true,
          ),
        ];

    group('a reaction', () {
      Future<DmReactionPublishResult> react({String? conversationId}) =>
          reactions.publish(
            conversationId: conversationId ?? oneToOne,
            targetMessageId: _reactedMessageId,
            targetMessageAuthor: peerB,
            emoji: '🔥',
          );

      Future<DmReactionPublishResult> retry(String rumorId) =>
          reactions.retry(rumorId: rumorId, targetMessageAuthor: peerB);

      Future<DmReactionRow> rowOf(String rumorId) async =>
          (await DmReactionsDao(db).getById(id: rumorId, ownerPubkey: owner))!;

      /// A reaction to peer B that the pool confirmed on an unreadable inbox.
      Future<String> heldReaction() async {
        await seedConversation(oneToOne, [owner, peerB]);
        inboxes[peerB] = _Inbox.unreadable;
        final held = await react();
        expect(held.success, isFalse, reason: 'precondition: held');
        return held.rumorId;
      }

      group('publish', () {
        test('records the wrap the pool accepted and publishes no own '
            'copy', () async {
          final rumorId = await heldReaction();

          final poolWrap = wrapsTo(peerB).single;
          expect(
            wrapsTo(owner),
            isEmpty,
            reason: 'held, not delivered, so the own copy waits',
          );
          final row = await rowOf(rumorId);
          expect(row.publishStatus, 'pending');
          expect(heldWraps(row.heldReactionWraps), {
            peerB: heldEntry(poolWrap.id),
          });
        });

        test('reports a failed record and still holds the reaction', () async {
          final reported = <String>[];
          buildStack(
            reactionsDao: _RecordFailingDmReactionsDao(db),
            reportedSites: reported,
          );

          final rumorId = await heldReaction();

          expect(reported, [
            DmReactionsRepositoryReportableSites.recordHeldPoolWrap,
          ]);
          final row = await rowOf(rumorId);
          expect(row.publishStatus, 'pending');
          expect(row.heldReactionWraps, isNull);
        });
      });

      group('retry while the inbox stays unreadable', () {
        test('publishes no other recipient wrap and counts every '
            'attempt', () async {
          final rumorId = await heldReaction();
          final poolWrap = wrapsTo(peerB).single;

          for (var attempt = 0; attempt < 4; attempt++) {
            final retried = await retry(rumorId);
            expect(retried.success, isFalse);
            expect(
              retried.reachedNoRelay,
              isFalse,
              reason: 'an attempt the retry sweep counts',
            );
          }

          expect(
            wrapsTo(peerB),
            hasLength(1),
            reason: 'five attempts, one wrap: the one the pool holds',
          );
          expect(wrapsTo(owner), isEmpty);
          final row = await rowOf(rumorId);
          expect(row.publishStatus, 'pending');
          expect(heldWraps(row.heldReactionWraps), {
            peerB: heldEntry(poolWrap.id),
          });
        });

        test('counts no attempt while no relay is connected, then counts '
            'the next one', () async {
          final rumorId = await heldReaction();
          connectedRelays = 0;

          final outage = await retry(rumorId);

          expect(outage.reachedNoRelay, isTrue);
          connectedRelays = 1;
          final reconnected = await retry(rumorId);
          expect(reconnected.success, isFalse);
          expect(reconnected.reachedNoRelay, isFalse);
          expect(wrapsTo(peerB), hasLength(1));
          expect((await rowOf(rumorId)).publishStatus, 'pending');
        });
      });

      group('retry once the inbox reads absent', () {
        test('settles on the held wrap and publishes the own copy '
            'once', () async {
          final rumorId = await heldReaction();
          inboxes[peerB] = _Inbox.absent;

          final retried = await retry(rumorId);

          expect(retried.success, isTrue);
          expect(
            wrapsTo(peerB),
            hasLength(1),
            reason: 'they read the pool, which already holds the wrap',
          );
          expect(wrapsTo(owner), hasLength(1));
          final row = await rowOf(rumorId);
          expect(row.publishStatus, 'sent');
          expect(row.rumorEventJson, isNull);
          expect(row.heldReactionWraps, isNull);
        });
      });

      group('retry once the inbox is found', () {
        test('publishes one new wrap to the inbox and the own copy '
            'once', () async {
          final rumorId = await heldReaction();
          final poolWrap = wrapsTo(peerB).single;
          inboxes[peerB] = _Inbox.found;

          final retried = await retry(rumorId);

          expect(retried.success, isTrue);
          final recipientWraps = wrapsTo(peerB);
          expect(recipientWraps, hasLength(2));
          final inboxWrap = recipientWraps.last;
          expect(inboxWrap.id, isNot(equals(poolWrap.id)));
          expect(
            recipientWrapTargets[inboxWrap.id],
            equals([_advertisedInbox]),
          );
          expect(wrapsTo(owner), hasLength(1));
          expect((await rowOf(rumorId)).publishStatus, 'sent');
        });

        test('asks the send policy once, through sendRumor', () async {
          final rumorId = await heldReaction();
          inboxes[peerB] = _Inbox.found;
          policyChecks = 0;

          final retried = await retry(rumorId);

          expect(retried.success, isTrue);
          expect(policyChecks, equals(1));
        });
      });

      group('retry makes the checks a publish makes first', () {
        for (final check in settleChecks) {
          test('does not settle on the held wrap when '
              '${check.refusal}', () async {
            final rumorId = await heldReaction();
            inboxes[peerB] = _Inbox.absent;
            check.arrange();

            final retried = await retry(rumorId);

            expect(retried.success, isFalse);
            expect(retried.reachedNoRelay, check.noRelay);
            expect(wrapsTo(peerB), hasLength(1));
            expect((await rowOf(rumorId)).publishStatus, isNot('sent'));
          });
        }
      });

      group('a reaction held for another reason', () {
        test('records no wrap when the OK never came back, so the retry '
            'publishes again', () async {
          confirmRecipientWraps = false;
          final rumorId = await heldReaction();
          expect((await rowOf(rumorId)).heldReactionWraps, isNull);

          await retry(rumorId);

          expect(
            wrapsTo(peerB),
            hasLength(2),
            reason: 'no relay is known to hold the first wrap',
          );
          expect(
            wrapsTo(owner),
            isEmpty,
            reason: 'their inbox is unreadable, so no attempt is delivery',
          );
        });

        test("records the members it reached when another member's OK never "
            'came back, and sends them nothing again', () async {
          await seedConversation(room, [owner, peerB, peerC]);
          inboxes[peerB] = _Inbox.found;
          inboxes[peerC] = _Inbox.found;
          okLostFor = {peerC};
          final held = await react(conversationId: room);
          expect(held.success, isFalse, reason: 'precondition: C unconfirmed');
          final delivery = wrapsTo(peerB).single;
          expect(heldWraps((await rowOf(held.rumorId)).heldReactionWraps), {
            peerB: deliveredEntry(delivery.id),
          });
          okLostFor = {};

          final retried = await retry(held.rumorId);

          expect(retried.success, isTrue);
          expect(wrapsTo(peerB), hasLength(1), reason: 'B has it already');
          expect(wrapsTo(peerC), hasLength(2));
        });
      });

      group('in a group with one unreadable member', () {
        /// A room reaction delivered to B's inbox and held for C.
        Future<String> heldRoomReaction() async {
          await seedConversation(room, [owner, peerB, peerC]);
          inboxes[peerB] = _Inbox.found;
          inboxes[peerC] = _Inbox.unreadable;
          final held = await react(conversationId: room);
          expect(held.success, isFalse, reason: 'precondition: held for C');
          return held.rumorId;
        }

        test('sends that member nothing more, the member who has it nothing '
            'again, and publishes no own copy while their inbox stays '
            'unreadable', () async {
          final rumorId = await heldRoomReaction();
          final poolWrap = wrapsTo(peerC).single;
          final delivery = wrapsTo(peerB).single;

          for (var attempt = 0; attempt < 2; attempt++) {
            final retried = await retry(rumorId);
            expect(retried.success, isFalse);
          }

          expect(wrapsTo(peerC), hasLength(1));
          expect(wrapsTo(owner), isEmpty);
          expect(
            wrapsTo(peerB),
            hasLength(1),
            reason: 'B has it from the first attempt',
          );
          expect(heldWraps((await rowOf(rumorId)).heldReactionWraps), {
            peerB: deliveredEntry(delivery.id),
            peerC: heldEntry(poolWrap.id),
          });
        });

        test('settles that member on the held wrap once their inbox reads '
            'absent, sending the member who has it nothing', () async {
          final rumorId = await heldRoomReaction();
          inboxes[peerC] = _Inbox.absent;

          final retried = await retry(rumorId);

          expect(retried.success, isTrue);
          expect(wrapsTo(peerC), hasLength(1));
          expect(wrapsTo(peerB), hasLength(1));
          expect(wrapsTo(owner), hasLength(1));
          expect((await rowOf(rumorId)).publishStatus, 'sent');
        });

        test('publishes the own copy when only an already-delivered member '
            'has an unreadable inbox after a restart', () async {
          final rumorId = await heldRoomReaction();
          expect(heldWraps((await rowOf(rumorId)).heldReactionWraps), {
            peerB: deliveredEntry(wrapsTo(peerB).single.id),
            peerC: heldEntry(wrapsTo(peerC).single.id),
          });
          expect(wrapsTo(owner), isEmpty);
          buildStack();
          inboxes[peerB] = _Inbox.unreadable;
          inboxes[peerC] = _Inbox.absent;

          final retried = await retry(rumorId);

          expect(retried.success, isTrue);
          expect(wrapsTo(peerB), hasLength(1));
          expect(wrapsTo(peerC), hasLength(1));
          expect((await rowOf(rumorId)).publishStatus, 'sent');
          expect(wrapsTo(owner), hasLength(1));
        });

        test('reads who has it from the row, so a restart sends them nothing '
            'again', () async {
          final rumorId = await heldRoomReaction();
          buildStack();
          inboxes[peerC] = _Inbox.absent;

          final retried = await retry(rumorId);

          expect(retried.success, isTrue);
          expect(wrapsTo(peerB), hasLength(1));
        });

        test('reports a failed record of who has it and still holds the '
            'reaction', () async {
          final reported = <String>[];
          buildStack(
            reactionsDao: _RecordFailingDmReactionsDao(db),
            reportedSites: reported,
          );

          final rumorId = await heldRoomReaction();

          expect(reported, [
            DmReactionsRepositoryReportableSites.recordHeldPoolWrap,
            DmReactionsRepositoryReportableSites.recordHeldPoolWrap,
          ]);
          final row = await rowOf(rumorId);
          expect(row.publishStatus, 'pending');
          expect(row.heldReactionWraps, isNull);
        });

        test('counts no attempt made while the device is offline, though a '
            'member has it from before', () async {
          final rumorId = await heldRoomReaction();
          deviceOffline = true;

          final outage = await retry(rumorId);

          expect(outage.success, isFalse);
          expect(
            outage.reachedNoRelay,
            isTrue,
            reason: 'B was reached by an earlier attempt, not this one',
          );
        });

        test('counts a member who has it as delivered without asking the '
            'send policy again', () async {
          final rumorId = await heldRoomReaction();
          inboxes[peerC] = _Inbox.absent;
          policyThrowsFor = {peerB};

          final retried = await retry(rumorId);

          expect(retried.success, isTrue);
          expect(wrapsTo(peerB), hasLength(1));
        });

        test('publishes no own copy for a member settled on the held wrap '
            'while another member stays unreadable', () async {
          await seedConversation(room, [owner, peerB, peerC]);
          inboxes[peerB] = _Inbox.unreadable;
          inboxes[peerC] = _Inbox.unreadable;
          final held = await react(conversationId: room);
          expect(held.success, isFalse, reason: 'precondition: held for both');
          inboxes[peerC] = _Inbox.absent;

          final retried = await retry(held.rumorId);

          expect(retried.success, isFalse);
          expect(wrapsTo(peerB), hasLength(1));
          expect(wrapsTo(peerC), hasLength(1));
          expect(
            wrapsTo(owner),
            isEmpty,
            reason: 'B is still held, so the attempt is not delivery',
          );
        });

        test('still wraps the other members when the send policy throws '
            'for the held one', () async {
          // C first, so a throw that escaped C's check would stop B's send,
          // and B's first OK lost, so the retry has a send for B to make.
          await seedConversation(room, [owner, peerC, peerB]);
          inboxes[peerB] = _Inbox.found;
          inboxes[peerC] = _Inbox.unreadable;
          okLostFor = {peerB};
          final held = await react(conversationId: room);
          expect(held.success, isFalse, reason: 'precondition: held for C');
          okLostFor = {};
          inboxes[peerC] = _Inbox.absent;
          policyThrowsFor = {peerC};

          final retried = await retry(held.rumorId);

          expect(retried.success, isFalse);
          expect(wrapsTo(peerC), hasLength(1));
          expect(
            wrapsTo(peerB),
            hasLength(2),
            reason: 'it fails C alone, as it would inside a send',
          );
        });
      });
    });

    group('a reaction removal', () {
      late int removalStart;

      Future<DmReactionDeletionOutcome> retryRemoval(String rumorId) =>
          reactions.retryDeletion(rumorId: rumorId, targetMessageAuthor: peerB);

      Future<DmReactionRow> rowOf(String rumorId) async =>
          (await DmReactionsDao(db).getById(id: rumorId, ownerPubkey: owner))!;

      List<Event> removalWrapsTo(String pubkey) =>
          wrapsTo(pubkey, from: removalStart);

      /// Removes a delivered reaction while [heldFor]'s inbox cannot be read,
      /// and returns its rumor id once the removal's first attempt is held.
      /// With [okLost] no relay answers the removal's wraps.
      Future<String> heldRemoval({
        List<String>? participants,
        Map<String, _Inbox> deliveredTo = const {},
        List<String> heldFor = const [],
        bool okLost = false,
      }) async {
        final members = participants ?? [owner, peerB];
        final conversationId = DmRepository.computeConversationId(members);
        await seedConversation(conversationId, members);
        for (final recipient in members.skip(1)) {
          inboxes[recipient] = _Inbox.absent;
        }
        final sent = await reactions.publish(
          conversationId: conversationId,
          targetMessageId: _reactedMessageId,
          targetMessageAuthor: peerB,
          emoji: '🔥',
        );
        expect(sent.success, isTrue, reason: 'precondition: delivered');
        removalStart = published.length;
        confirmRecipientWraps = !okLost;
        inboxes
          ..addAll(deliveredTo)
          ..addAll({
            for (final recipient in heldFor.isEmpty ? [peerB] : heldFor)
              recipient: _Inbox.unreadable,
          });

        await reactions.removeOwn(
          rumorId: sent.rumorId,
          targetMessageAuthor: peerB,
        );
        // Joins the removal's first attempt, which removeOwn left running.
        final first = await retryRemoval(sent.rumorId);
        expect(
          first,
          DmReactionDeletionOutcome.unconfirmed,
          reason: 'precondition: held',
        );
        return sent.rumorId;
      }

      group('removeOwn', () {
        test('records the wrap the pool accepted and publishes no own '
            'copy', () async {
          final rumorId = await heldRemoval();

          final poolWrap = removalWrapsTo(peerB).single;
          expect(removalWrapsTo(owner), isEmpty);
          final row = await rowOf(rumorId);
          expect(row.publishStatus, 'deletion_pending');
          expect(heldWraps(row.heldRemovalWraps), {
            peerB: heldEntry(poolWrap.id),
          });
        });

        test('reports a failed record and still holds the removal', () async {
          final reported = <String>[];
          buildStack(
            reactionsDao: _RecordFailingDmReactionsDao(db),
            reportedSites: reported,
          );

          final rumorId = await heldRemoval();

          expect(reported, [
            DmReactionsRepositoryReportableSites.recordHeldPoolWrap,
          ]);
          final row = await rowOf(rumorId);
          expect(row.publishStatus, 'deletion_pending');
          expect(row.heldRemovalWraps, isNull);
        });
      });

      group('retryDeletion while the inbox stays unreadable', () {
        test('publishes no other recipient wrap and counts every '
            'attempt', () async {
          final rumorId = await heldRemoval();
          final poolWrap = removalWrapsTo(peerB).single;

          for (var attempt = 0; attempt < 4; attempt++) {
            expect(
              await retryRemoval(rumorId),
              DmReactionDeletionOutcome.unconfirmed,
              reason: 'an attempt the retry sweep counts',
            );
          }

          expect(removalWrapsTo(peerB), hasLength(1));
          expect(removalWrapsTo(owner), isEmpty);
          expect(heldWraps((await rowOf(rumorId)).heldRemovalWraps), {
            peerB: heldEntry(poolWrap.id),
          });
        });

        test('counts no attempt while no relay is connected, then counts '
            'the next one', () async {
          final rumorId = await heldRemoval();
          connectedRelays = 0;

          expect(
            await retryRemoval(rumorId),
            DmReactionDeletionOutcome.notSent,
          );
          connectedRelays = 1;
          expect(
            await retryRemoval(rumorId),
            DmReactionDeletionOutcome.unconfirmed,
          );
          expect(removalWrapsTo(peerB), hasLength(1));
        });
      });

      group('retryDeletion once the inbox reads absent', () {
        test('settles on the held wrap and publishes the own copy '
            'once', () async {
          final rumorId = await heldRemoval();
          inboxes[peerB] = _Inbox.absent;

          expect(await retryRemoval(rumorId), DmReactionDeletionOutcome.sent);

          expect(removalWrapsTo(peerB), hasLength(1));
          expect(removalWrapsTo(owner), hasLength(1));
          final row = await rowOf(rumorId);
          expect(row.publishStatus, 'deletion_sent');
          expect(row.heldRemovalWraps, isNull);
        });
      });

      group('retryDeletion once the inbox is found', () {
        test('publishes one new wrap to the inbox and the own copy '
            'once', () async {
          final rumorId = await heldRemoval();
          final poolWrap = removalWrapsTo(peerB).single;
          inboxes[peerB] = _Inbox.found;

          expect(await retryRemoval(rumorId), DmReactionDeletionOutcome.sent);

          final recipientWraps = removalWrapsTo(peerB);
          expect(recipientWraps, hasLength(2));
          expect(recipientWraps.last.id, isNot(equals(poolWrap.id)));
          expect(
            recipientWrapTargets[recipientWraps.last.id],
            equals([_advertisedInbox]),
          );
          expect(removalWrapsTo(owner), hasLength(1));
        });
      });

      group('retryDeletion makes the checks a publish makes first', () {
        for (final check in settleChecks) {
          test('does not settle on the held wrap when '
              '${check.refusal}', () async {
            final rumorId = await heldRemoval();
            inboxes[peerB] = _Inbox.absent;
            check.arrange();

            final outcome = await retryRemoval(rumorId);

            expect(outcome, isNot(DmReactionDeletionOutcome.sent));
            expect(
              outcome == DmReactionDeletionOutcome.notSent,
              check.noRelay,
            );
            expect(removalWrapsTo(peerB), hasLength(1));
            expect(
              (await rowOf(rumorId)).publishStatus,
              isNot('deletion_sent'),
            );
          });
        }
      });

      group('a removal held for another reason', () {
        test('records no wrap when the OK never came back, so the retry '
            'publishes again', () async {
          final rumorId = await heldRemoval(okLost: true);
          expect((await rowOf(rumorId)).heldRemovalWraps, isNull);

          await retryRemoval(rumorId);

          expect(
            removalWrapsTo(peerB),
            hasLength(2),
            reason: 'no relay is known to hold the first wrap',
          );
          expect(removalWrapsTo(owner), isEmpty);
        });
      });

      group('in a group with one unreadable member', () {
        Future<String> heldRoomRemoval() => heldRemoval(
          participants: [owner, peerB, peerC],
          deliveredTo: {peerB: _Inbox.found},
          heldFor: [peerC],
        );

        test('sends that member nothing more, the member who has it nothing '
            'again, and publishes no own copy while their inbox stays '
            'unreadable', () async {
          final rumorId = await heldRoomRemoval();
          final poolWrap = removalWrapsTo(peerC).single;
          final delivery = removalWrapsTo(peerB).single;

          for (var attempt = 0; attempt < 2; attempt++) {
            expect(
              await retryRemoval(rumorId),
              DmReactionDeletionOutcome.unconfirmed,
            );
          }

          expect(removalWrapsTo(peerC), hasLength(1));
          expect(removalWrapsTo(owner), isEmpty);
          expect(
            removalWrapsTo(peerB),
            hasLength(1),
            reason: 'B has it from the first attempt',
          );
          expect(heldWraps((await rowOf(rumorId)).heldRemovalWraps), {
            peerB: deliveredEntry(delivery.id),
            peerC: heldEntry(poolWrap.id),
          });
        });

        test('settles that member on the held wrap once their inbox reads '
            'absent, sending the member who has it nothing', () async {
          final rumorId = await heldRoomRemoval();
          inboxes[peerC] = _Inbox.absent;

          expect(await retryRemoval(rumorId), DmReactionDeletionOutcome.sent);

          expect(removalWrapsTo(peerC), hasLength(1));
          expect(removalWrapsTo(peerB), hasLength(1));
          expect(removalWrapsTo(owner), hasLength(1));
        });

        test('publishes the own copy when only an already-delivered member '
            'has an unreadable inbox after a restart', () async {
          final rumorId = await heldRoomRemoval();
          expect(heldWraps((await rowOf(rumorId)).heldRemovalWraps), {
            peerB: deliveredEntry(removalWrapsTo(peerB).single.id),
            peerC: heldEntry(removalWrapsTo(peerC).single.id),
          });
          expect(removalWrapsTo(owner), isEmpty);
          buildStack();
          inboxes[peerB] = _Inbox.unreadable;
          inboxes[peerC] = _Inbox.absent;

          expect(await retryRemoval(rumorId), DmReactionDeletionOutcome.sent);

          expect(removalWrapsTo(peerB), hasLength(1));
          expect(removalWrapsTo(peerC), hasLength(1));
          expect((await rowOf(rumorId)).publishStatus, 'deletion_sent');
          expect(removalWrapsTo(owner), hasLength(1));
        });

        test('reads who has it from the row, so a restart sends them nothing '
            'again', () async {
          final rumorId = await heldRoomRemoval();
          buildStack();
          inboxes[peerC] = _Inbox.absent;

          expect(await retryRemoval(rumorId), DmReactionDeletionOutcome.sent);

          expect(removalWrapsTo(peerB), hasLength(1));
        });

        test('counts no attempt made while the device is offline, though a '
            'member has it from before', () async {
          final rumorId = await heldRoomRemoval();
          deviceOffline = true;

          expect(
            await retryRemoval(rumorId),
            DmReactionDeletionOutcome.notSent,
            reason: 'B was reached by an earlier attempt, not this one',
          );
        });
      });
    });

    group('a delete-for-everyone', () {
      Future<DmMessageDeletionOutcome> retryRetraction() =>
          repository.retryMessageDeletion(rumorId: _retractedMessageId);

      Future<DirectMessageRow> messageRow() async => (await DirectMessagesDao(
        db,
      ).getMessageById(_retractedMessageId, ownerPubkey: owner))!;

      /// Lets the first attempt [DmRepository.deleteMessageForEveryone] leaves
      /// running publish to every one of [recipients], then finish.
      Future<void> firstAttemptEnds(List<String> recipients) async {
        for (
          var turn = 0;
          turn < 200 && recipients.any((pubkey) => wrapsTo(pubkey).isEmpty);
          turn++
        ) {
          await pumpEventQueue();
        }
        await pumpEventQueue(times: 100);
      }

      /// Deletes an own message for everyone while [heldFor]'s inbox cannot be
      /// read, and returns once the first attempt is held.
      Future<void> heldRetraction({
        List<String>? participants,
        Map<String, _Inbox> deliveredTo = const {},
        List<String> heldFor = const [],
      }) async {
        final members = participants ?? [owner, peerB];
        final conversationId = DmRepository.computeConversationId(members);
        await seedConversation(conversationId, members);
        await DirectMessagesDao(db).insertMessage(
          id: _retractedMessageId,
          conversationId: conversationId,
          senderPubkey: owner,
          content: 'a message to delete for everyone',
          createdAt: 1700000000,
          giftWrapId: _retractedMessageWrapId,
          ownerPubkey: owner,
        );
        inboxes
          ..addAll(deliveredTo)
          ..addAll({
            for (final recipient in heldFor.isEmpty ? [peerB] : heldFor)
              recipient: _Inbox.unreadable,
          });

        await repository.deleteMessageForEveryone(_retractedMessageId);
        await firstAttemptEnds(members.skip(1).toList());

        expect(
          (await messageRow()).deletionPublishStatus,
          DirectMessagesDao.deletionPending,
          reason: 'precondition: held',
        );
      }

      group('deleteMessageForEveryone', () {
        test('records the wrap the pool accepted and publishes no own '
            'copy', () async {
          await heldRetraction();

          final poolWrap = wrapsTo(peerB).single;
          expect(wrapsTo(owner), isEmpty);
          expect(heldWraps((await messageRow()).heldDeletionWraps), {
            peerB: heldEntry(poolWrap.id),
          });
        });

        test(
          'reports a failed record and still holds the retraction',
          () async {
            final reported = <String>[];
            buildStack(
              messagesDao: _RecordFailingDirectMessagesDao(db),
              reportedSites: reported,
            );

            await heldRetraction();

            expect(reported, [DmRepositoryReportableSites.recordHeldPoolWrap]);
            expect((await messageRow()).heldDeletionWraps, isNull);
          },
        );
      });

      group('retryMessageDeletion while the inbox stays unreadable', () {
        test('publishes no other recipient wrap on any attempt', () async {
          await heldRetraction();
          final poolWrap = wrapsTo(peerB).single;

          for (var attempt = 0; attempt < 4; attempt++) {
            expect(
              await retryRetraction(),
              DmMessageDeletionOutcome.unconfirmed,
            );
          }

          expect(wrapsTo(peerB), hasLength(1));
          expect(wrapsTo(owner), isEmpty);
          final row = await messageRow();
          expect(row.deletionPublishStatus, DirectMessagesDao.deletionPending);
          expect(heldWraps(row.heldDeletionWraps), {
            peerB: heldEntry(poolWrap.id),
          });
        });

        test('publishes nothing while no relay is connected', () async {
          await heldRetraction();
          connectedRelays = 0;

          expect(
            await retryRetraction(),
            DmMessageDeletionOutcome.unconfirmed,
          );

          expect(wrapsTo(peerB), hasLength(1));
          expect(wrapsTo(owner), isEmpty);
        });
      });

      group('retryMessageDeletion once the inbox reads absent', () {
        test('settles on the held wrap and publishes the own copy '
            'once', () async {
          await heldRetraction();
          inboxes[peerB] = _Inbox.absent;

          expect(await retryRetraction(), DmMessageDeletionOutcome.sent);

          expect(wrapsTo(peerB), hasLength(1));
          expect(wrapsTo(owner), hasLength(1));
          final row = await messageRow();
          expect(row.deletionPublishStatus, 'deletion_sent');
          expect(row.deletionRumorJson, isNull);
          expect(row.heldDeletionWraps, isNull);
        });

        test('settles even when the own copy fails to publish', () async {
          await heldRetraction();
          inboxes[peerB] = _Inbox.absent;
          ownCopiesPublish = false;

          expect(await retryRetraction(), DmMessageDeletionOutcome.sent);

          expect(wrapsTo(peerB), hasLength(1));
          expect(
            (await messageRow()).deletionPublishStatus,
            'deletion_sent',
            reason: 'the recipient has it; the own copy is not delivery',
          );
        });
      });

      group('retryMessageDeletion once the inbox is found', () {
        test('publishes one new wrap to the inbox and the own copy '
            'once', () async {
          await heldRetraction();
          final poolWrap = wrapsTo(peerB).single;
          inboxes[peerB] = _Inbox.found;

          expect(await retryRetraction(), DmMessageDeletionOutcome.sent);

          final recipientWraps = wrapsTo(peerB);
          expect(recipientWraps, hasLength(2));
          expect(recipientWraps.last.id, isNot(equals(poolWrap.id)));
          expect(
            recipientWrapTargets[recipientWraps.last.id],
            equals([_advertisedInbox]),
          );
          expect(wrapsTo(owner), hasLength(1));
        });
      });

      group('once its automatic retries ran out', () {
        Future<DmMessage> bubble() async {
          final row = await messageRow();
          final messages = await repository
              .watchMessages(row.conversationId)
              .first;
          return messages.singleWhere((m) => m.id == _retractedMessageId);
        }

        Future<DmMessageDeletionRetryTarget> worklistEntry() async =>
            (await repository.retryableMessageDeletions()).singleWhere(
              (t) => t.rumorId == _retractedMessageId,
            );

        test('shows the warning and stays on the worklist for a later '
            'launch', () async {
          await heldRetraction();
          expect(
            (await bubble()).retractionStatus,
            DmRetractionStatus.pending,
          );
          expect((await worklistEntry()).retriesRanOut, isFalse);

          await repository.markMessageDeletionUnconfirmed(
            rumorId: _retractedMessageId,
          );

          expect((await bubble()).retractionStatus, DmRetractionStatus.failed);
          expect((await worklistEntry()).retriesRanOut, isTrue);
        });

        test('Try again sends a held member nothing more and keeps the held '
            'wraps', () async {
          await heldRetraction();
          final heldBefore = (await messageRow()).heldDeletionWraps;
          await repository.markMessageDeletionUnconfirmed(
            rumorId: _retractedMessageId,
          );

          expect(await retryRetraction(), DmMessageDeletionOutcome.unconfirmed);

          expect((await messageRow()).heldDeletionWraps, equals(heldBefore));
          expect(wrapsTo(peerB), hasLength(1));
          expect(wrapsTo(owner), isEmpty);
        });

        test('a Try again that nothing confirms reads failed again as soon '
            'as it returns', () async {
          await heldRetraction();
          await repository.markMessageDeletionUnconfirmed(
            rumorId: _retractedMessageId,
          );

          expect(await retryRetraction(), DmMessageDeletionOutcome.unconfirmed);

          expect(
            (await messageRow()).deletionPublishStatus,
            DirectMessagesDao.deletionUnconfirmed,
          );
          expect((await bubble()).retractionStatus, DmRetractionStatus.failed);
        });

        test('a Try again reads pending while it runs, then failed, with no '
            'sweep in between', () async {
          await heldRetraction();
          await repository.markMessageDeletionUnconfirmed(
            rumorId: _retractedMessageId,
          );
          final seen = <DmRetractionStatus>[];
          final subscription = repository
              .watchMessages((await messageRow()).conversationId)
              .listen((messages) {
                final status = messages
                    .singleWhere((m) => m.id == _retractedMessageId)
                    .retractionStatus;
                if (seen.isEmpty || seen.last != status) seen.add(status);
              });
          addTearDown(subscription.cancel);
          await pumpEventQueue();
          expect(seen, [DmRetractionStatus.failed], reason: 'precondition');

          await retryRetraction();
          await pumpEventQueue();

          expect(seen, [
            DmRetractionStatus.failed,
            DmRetractionStatus.pending,
            DmRetractionStatus.failed,
          ]);
        });

        test('Try again records a member it reaches, so the next retry sends '
            'them nothing again', () async {
          await heldRetraction(
            participants: [owner, peerB, peerC],
            heldFor: [peerB, peerC],
          );
          await repository.markMessageDeletionUnconfirmed(
            rumorId: _retractedMessageId,
          );
          inboxes[peerB] = _Inbox.found;

          expect(await retryRetraction(), DmMessageDeletionOutcome.unconfirmed);
          final delivery = wrapsTo(peerB).last;
          expect(heldWraps((await messageRow()).heldDeletionWraps), {
            peerB: deliveredEntry(delivery.id),
            peerC: heldEntry(wrapsTo(peerC).single.id),
          });

          expect(await retryRetraction(), DmMessageDeletionOutcome.unconfirmed);

          expect(
            wrapsTo(peerB),
            hasLength(2),
            reason: 'the pool wrap, then one wrap to the inbox it found',
          );
        });

        group('an automatic retry', () {
          Future<DmMessageDeletionOutcome> automaticRetry() =>
              repository.retryMessageDeletion(
                rumorId: _retractedMessageId,
                automatic: true,
              );

          /// The retraction status each change of the thread shows, from now;
          /// null once the message has left the thread.
          Future<List<DmRetractionStatus?>> watchStatuses() async {
            final seen = <DmRetractionStatus?>[];
            final subscription = repository
                .watchMessages((await messageRow()).conversationId)
                .listen((messages) {
                  final shown = messages.where(
                    (m) => m.id == _retractedMessageId,
                  );
                  final status = shown.isEmpty
                      ? null
                      : shown.single.retractionStatus;
                  if (seen.isEmpty || seen.last != status) seen.add(status);
                });
            addTearDown(subscription.cancel);
            await pumpEventQueue();
            return seen;
          }

          /// Holds every inbox lookup until [gate] completes.
          void holdLookups(Completer<void> gate) {
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
              await gate.future;
              return answerLookup(
                (invocation.positionalArguments.first as List)
                    .cast<nostr_filter.Filter>(),
              );
            });
          }

          /// A retraction whose retries ran out, on a store this test observes.
          Future<_ObservedDirectMessagesDao> observedRanOutRetraction() async {
            final observed = _ObservedDirectMessagesDao(db);
            buildStack(messagesDao: observed);
            await heldRetraction();
            await repository.markMessageDeletionUnconfirmed(
              rumorId: _retractedMessageId,
            );
            observed
              ..movesToPending = 0
              ..warningsWritten = 0;
            return observed;
          }

          test('keeps the warning for the whole attempt', () async {
            await heldRetraction();
            await repository.markMessageDeletionUnconfirmed(
              rumorId: _retractedMessageId,
            );
            final seen = await watchStatuses();

            expect(
              await automaticRetry(),
              DmMessageDeletionOutcome.unconfirmed,
            );
            await pumpEventQueue();

            expect(seen, [DmRetractionStatus.failed]);
            expect(
              (await messageRow()).deletionPublishStatus,
              DirectMessagesDao.deletionUnconfirmed,
            );
          });

          test('records a member it reaches, so the next one sends them '
              'nothing again', () async {
            await heldRetraction(
              participants: [owner, peerB, peerC],
              heldFor: [peerB, peerC],
            );
            await repository.markMessageDeletionUnconfirmed(
              rumorId: _retractedMessageId,
            );
            inboxes[peerB] = _Inbox.found;

            expect(
              await automaticRetry(),
              DmMessageDeletionOutcome.unconfirmed,
            );
            expect(heldWraps((await messageRow()).heldDeletionWraps), {
              peerB: deliveredEntry(wrapsTo(peerB).last.id),
              peerC: heldEntry(wrapsTo(peerC).single.id),
            });
            expect(
              await automaticRetry(),
              DmMessageDeletionOutcome.unconfirmed,
            );

            expect(wrapsTo(peerB), hasLength(2));
            expect(
              (await messageRow()).deletionPublishStatus,
              DirectMessagesDao.deletionUnconfirmed,
            );
          });

          test('settles a retraction it delivers', () async {
            await heldRetraction();
            await repository.markMessageDeletionUnconfirmed(
              rumorId: _retractedMessageId,
            );
            inboxes[peerB] = _Inbox.absent;

            expect(await automaticRetry(), DmMessageDeletionOutcome.sent);

            expect((await messageRow()).deletionPublishStatus, 'deletion_sent');
          });

          test(
            'a Try again that joins it shows progress, then the warning',
            () async {
              await heldRetraction();
              await repository.markMessageDeletionUnconfirmed(
                rumorId: _retractedMessageId,
              );
              final seen = await watchStatuses();
              final lookupGate = Completer<void>();
              holdLookups(lookupGate);
              final automatic = automaticRetry();
              await pumpEventQueue();

              final tryAgain = retryRetraction();
              await pumpEventQueue();
              expect(
                (await messageRow()).deletionPublishStatus,
                DirectMessagesDao.deletionPending,
                reason: 'the spinner shows while the running attempt finishes',
              );
              lookupGate.complete();

              expect(await tryAgain, DmMessageDeletionOutcome.unconfirmed);
              expect(await automatic, DmMessageDeletionOutcome.unconfirmed);
              await pumpEventQueue();
              expect(seen, [
                DmRetractionStatus.failed,
                DmRetractionStatus.pending,
                DmRetractionStatus.failed,
              ]);
              expect(wrapsTo(peerB), hasLength(1));
            },
          );

          for (final settle in [
            (
              as: DmMessageDeletionOutcome.sent,
              status: 'deletion_sent',
              arrange: () => inboxes[peerB] = _Inbox.absent,
            ),
            (
              as: DmMessageDeletionOutcome.blocked,
              status: DirectMessagesDao.deletionBlocked,
              arrange: () {
                inboxes[peerB] = _Inbox.absent;
                policyDecision = DmSendPolicyDecision.terminallyBlockedDiscard;
              },
            ),
          ]) {
            test('a Try again that joins it after it settled as '
                '${settle.as.name} leaves it settled', () async {
              final observed = await observedRanOutRetraction();
              final seen = await watchStatuses();
              final lookupGate = Completer<void>();
              holdLookups(lookupGate);
              final automatic = automaticRetry();
              await pumpEventQueue();
              // The running attempt settles just before the Try again moves
              // the row back to pending.
              observed.nextStep = () async {
                settle.arrange();
                lookupGate.complete();
                expect(await automatic, settle.as, reason: 'precondition');
              };

              expect(await retryRetraction(), settle.as);
              await pumpEventQueue();

              expect(
                (await messageRow()).deletionPublishStatus,
                settle.status,
              );
              expect(seen, isNot(contains(DmRetractionStatus.pending)));
            });
          }

          test('a Try again that joins it shows the warning again when it '
              'had nothing to send', () async {
            final observed = await observedRanOutRetraction();
            final conversationId = (await messageRow()).conversationId;
            final readGate = Completer<void>();
            // The running attempt waits after its read of the row.
            observed.nextStep = () => readGate.future;
            final automatic = automaticRetry();
            await pumpEventQueue();
            final tryAgain = retryRetraction();
            await pumpEventQueue();
            expect(
              (await messageRow()).deletionPublishStatus,
              DirectMessagesDao.deletionPending,
              reason: 'precondition: the spinner shows',
            );
            // Nobody is left to send it to.
            await ConversationsDao(
              db,
            ).deleteConversation(conversationId, ownerPubkey: owner);
            readGate.complete();

            expect(await automatic, DmMessageDeletionOutcome.unavailable);
            expect(await tryAgain, DmMessageDeletionOutcome.unavailable);

            expect(
              (await messageRow()).deletionPublishStatus,
              DirectMessagesDao.deletionUnconfirmed,
            );
          });

          test('joins a running Try again without touching the status '
              'itself', () async {
            final observed = await observedRanOutRetraction();
            final seen = await watchStatuses();
            final lookupGate = Completer<void>();
            holdLookups(lookupGate);
            final tryAgain = retryRetraction();
            await pumpEventQueue();
            final automatic = automaticRetry();
            await pumpEventQueue();
            lookupGate.complete();

            expect(await automatic, DmMessageDeletionOutcome.unconfirmed);
            expect(await tryAgain, DmMessageDeletionOutcome.unconfirmed);
            await pumpEventQueue();

            expect(observed.movesToPending, 1, reason: 'the Try again only');
            expect(observed.warningsWritten, 1, reason: 'the Try again only');
            expect(
              (await messageRow()).deletionPublishStatus,
              DirectMessagesDao.deletionUnconfirmed,
            );
            expect(seen, [
              DmRetractionStatus.failed,
              DmRetractionStatus.pending,
              DmRetractionStatus.failed,
            ]);
          });
        });
      });

      group('retryMessageDeletion makes the checks a publish makes '
          'first', () {
        for (final check in settleChecks) {
          test('does not settle on the held wrap when '
              '${check.refusal}', () async {
            await heldRetraction();
            inboxes[peerB] = _Inbox.absent;
            check.arrange();

            final outcome = await retryRetraction();

            expect(outcome, isNot(DmMessageDeletionOutcome.sent));
            expect(wrapsTo(peerB), hasLength(1));
            expect(
              (await messageRow()).deletionPublishStatus,
              isNot('deletion_sent'),
            );
          });
        }
      });

      group('a retraction held for another reason', () {
        test('records no wrap when the OK never came back, so the retry '
            'publishes again', () async {
          confirmRecipientWraps = false;
          await heldRetraction();
          expect((await messageRow()).heldDeletionWraps, isNull);

          await retryRetraction();

          expect(
            wrapsTo(peerB),
            hasLength(2),
            reason: 'no relay is known to hold the first wrap',
          );
          expect(wrapsTo(owner), isEmpty);
        });
      });

      group('in a group with one unreadable member', () {
        Future<void> heldRoomRetraction() => heldRetraction(
          participants: [owner, peerB, peerC],
          deliveredTo: {peerB: _Inbox.found},
          heldFor: [peerC],
        );

        test('sends that member nothing more, the member who has it nothing '
            'again, and publishes no own copy while their inbox stays '
            'unreadable', () async {
          await heldRoomRetraction();
          final poolWrap = wrapsTo(peerC).single;
          final delivery = wrapsTo(peerB).single;

          for (var attempt = 0; attempt < 2; attempt++) {
            expect(
              await retryRetraction(),
              DmMessageDeletionOutcome.unconfirmed,
            );
          }

          expect(wrapsTo(peerC), hasLength(1));
          expect(wrapsTo(owner), isEmpty);
          expect(
            wrapsTo(peerB),
            hasLength(1),
            reason: 'B has it from the first attempt',
          );
          expect(heldWraps((await messageRow()).heldDeletionWraps), {
            peerB: deliveredEntry(delivery.id),
            peerC: heldEntry(poolWrap.id),
          });
        });

        test('settles that member on the held wrap once their inbox reads '
            'absent, sending the member who has it nothing, with one own '
            'copy per member as before', () async {
          await heldRoomRetraction();
          inboxes[peerC] = _Inbox.absent;

          expect(await retryRetraction(), DmMessageDeletionOutcome.sent);

          expect(wrapsTo(peerC), hasLength(1));
          expect(wrapsTo(peerB), hasLength(1));
          expect(
            wrapsTo(owner),
            hasLength(2),
            reason: 'a retraction publishes the own copy per member (#10016)',
          );
        });

        test('publishes the own copies when only an already-delivered member '
            'has an unreadable inbox after a restart', () async {
          await heldRoomRetraction();
          expect(heldWraps((await messageRow()).heldDeletionWraps), {
            peerB: deliveredEntry(wrapsTo(peerB).single.id),
            peerC: heldEntry(wrapsTo(peerC).single.id),
          });
          expect(wrapsTo(owner), isEmpty);
          buildStack();
          inboxes[peerB] = _Inbox.unreadable;
          inboxes[peerC] = _Inbox.absent;

          expect(await retryRetraction(), DmMessageDeletionOutcome.sent);

          expect(wrapsTo(peerB), hasLength(1));
          expect(wrapsTo(peerC), hasLength(1));
          expect((await messageRow()).deletionPublishStatus, 'deletion_sent');
          expect(wrapsTo(owner), hasLength(2));
        });

        test('reads who has it from the row, so a restart sends them nothing '
            'again', () async {
          await heldRoomRetraction();
          buildStack();
          inboxes[peerC] = _Inbox.absent;

          expect(await retryRetraction(), DmMessageDeletionOutcome.sent);

          expect(wrapsTo(peerB), hasLength(1));
        });

        test('reports a failed record of who has it and still holds the '
            'retraction', () async {
          final reported = <String>[];
          buildStack(
            messagesDao: _RecordFailingDirectMessagesDao(db),
            reportedSites: reported,
          );

          await heldRoomRetraction();

          expect(reported, [
            DmRepositoryReportableSites.recordHeldPoolWrap,
            DmRepositoryReportableSites.recordHeldPoolWrap,
          ]);
          expect((await messageRow()).heldDeletionWraps, isNull);
        });

        test('publishes no own copy for a member settled on the held wrap '
            'while another member stays unreadable', () async {
          await heldRetraction(
            participants: [owner, peerB, peerC],
            heldFor: [peerB, peerC],
          );
          inboxes[peerC] = _Inbox.absent;

          expect(
            await retryRetraction(),
            DmMessageDeletionOutcome.unconfirmed,
          );

          expect(wrapsTo(peerB), hasLength(1));
          expect(wrapsTo(peerC), hasLength(1));
          expect(
            wrapsTo(owner),
            isEmpty,
            reason: 'B is still held, so the attempt is not delivery',
          );
        });

        test('still wraps the other members when the send policy throws '
            'for the held one', () async {
          // C first, so a throw that escaped C's check would stop B's send,
          // and B's first OK lost, so the retry has a send for B to make.
          okLostFor = {peerB};
          await heldRetraction(
            participants: [owner, peerC, peerB],
            deliveredTo: {peerB: _Inbox.found},
            heldFor: [peerC],
          );
          okLostFor = {};
          inboxes[peerC] = _Inbox.absent;
          policyThrowsFor = {peerC};

          expect(
            await retryRetraction(),
            DmMessageDeletionOutcome.unconfirmed,
          );

          expect(wrapsTo(peerC), hasLength(1));
          expect(
            wrapsTo(peerB),
            hasLength(2),
            reason: 'it fails C alone, as it would inside a send',
          );
        });
      });
    });
  });
}
