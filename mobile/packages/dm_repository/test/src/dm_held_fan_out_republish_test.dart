// ABOUTME: #10012 — a DM reaction, its removal, or a delete-for-everyone that
// ABOUTME: the fallback pool confirmed on an unreadable inbox keeps that wrap:
// ABOUTME: retries send that recipient nothing while the inbox stays
// ABOUTME: unreadable, settle on it once it reads absent, and wrap it again
// ABOUTME: once the inbox is found; the sender's copy waits for delivery.

import 'dart:convert';

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

/// The real reaction queue, except that recording a held wrap throws.
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
}

/// The real message store, except that recording a held wrap throws.
class _RecordFailingDirectMessagesDao extends DirectMessagesDao {
  _RecordFailingDirectMessagesDao(super.attachedDatabase);

  @override
  Future<bool> recordHeldDeletionWrap(
    String rumorId, {
    required String recipientPubkey,
    required String wrapEventId,
    String? ownerPubkey,
  }) async => throw StateError('database is locked');
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
    late DmSendPolicyDecision policyDecision;
    late bool policyThrows;
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
        sendPolicy: (_) async {
          policyChecks++;
          if (policyThrows) throw StateError('policy unavailable');
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
      policyDecision = DmSendPolicyDecision.allowed;
      policyThrows = false;
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
      // lost, which holds an attempt for a reason other than the inbox.
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
          expect(heldWraps(row.heldReactionWraps), {peerB: poolWrap.id});
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
          expect(heldWraps(row.heldReactionWraps), {peerB: poolWrap.id});
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

        test('sends that member nothing more and publishes no own copy '
            'while their inbox stays unreadable', () async {
          final rumorId = await heldRoomReaction();
          final poolWrap = wrapsTo(peerC).single;

          for (var attempt = 0; attempt < 2; attempt++) {
            final retried = await retry(rumorId);
            expect(retried.success, isFalse);
          }

          expect(wrapsTo(peerC), hasLength(1));
          expect(wrapsTo(owner), isEmpty);
          expect(
            wrapsTo(peerB),
            hasLength(3),
            reason:
                'one row cannot record that B already has it, so B is sent '
                'it again on every attempt, as any partly delivered fan-out is',
          );
          expect(heldWraps((await rowOf(rumorId)).heldReactionWraps), {
            peerC: poolWrap.id,
          });
        });

        test('settles that member on the held wrap once their inbox reads '
            'absent', () async {
          final rumorId = await heldRoomReaction();
          inboxes[peerC] = _Inbox.absent;

          final retried = await retry(rumorId);

          expect(retried.success, isTrue);
          expect(wrapsTo(peerC), hasLength(1));
          expect(wrapsTo(owner), hasLength(1));
          expect((await rowOf(rumorId)).publishStatus, 'sent');
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
          expect(heldWraps(row.heldRemovalWraps), {peerB: poolWrap.id});
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
            peerB: poolWrap.id,
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

        test('sends that member nothing more and publishes no own copy '
            'while their inbox stays unreadable', () async {
          final rumorId = await heldRoomRemoval();
          final poolWrap = removalWrapsTo(peerC).single;

          for (var attempt = 0; attempt < 2; attempt++) {
            expect(
              await retryRemoval(rumorId),
              DmReactionDeletionOutcome.unconfirmed,
            );
          }

          expect(removalWrapsTo(peerC), hasLength(1));
          expect(removalWrapsTo(owner), isEmpty);
          expect(removalWrapsTo(peerB), hasLength(3));
          expect(heldWraps((await rowOf(rumorId)).heldRemovalWraps), {
            peerC: poolWrap.id,
          });
        });

        test('settles that member on the held wrap once their inbox reads '
            'absent', () async {
          final rumorId = await heldRoomRemoval();
          inboxes[peerC] = _Inbox.absent;

          expect(await retryRemoval(rumorId), DmReactionDeletionOutcome.sent);

          expect(removalWrapsTo(peerC), hasLength(1));
          expect(removalWrapsTo(owner), hasLength(1));
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
            peerB: poolWrap.id,
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
          expect(heldWraps(row.heldDeletionWraps), {peerB: poolWrap.id});
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

        test('sends that member nothing more and publishes no own copy '
            'while their inbox stays unreadable', () async {
          await heldRoomRetraction();
          final poolWrap = wrapsTo(peerC).single;

          for (var attempt = 0; attempt < 2; attempt++) {
            expect(
              await retryRetraction(),
              DmMessageDeletionOutcome.unconfirmed,
            );
          }

          expect(wrapsTo(peerC), hasLength(1));
          expect(wrapsTo(owner), isEmpty);
          expect(wrapsTo(peerB), hasLength(3));
          expect(heldWraps((await messageRow()).heldDeletionWraps), {
            peerC: poolWrap.id,
          });
        });

        test('settles that member on the held wrap once their inbox reads '
            'absent, with one own copy per member as before', () async {
          await heldRoomRetraction();
          inboxes[peerC] = _Inbox.absent;

          expect(await retryRetraction(), DmMessageDeletionOutcome.sent);

          expect(wrapsTo(peerC), hasLength(1));
          expect(
            wrapsTo(owner),
            hasLength(2),
            reason: 'a retraction publishes the own copy per member (#10016)',
          );
        });
      });
    });
  });
}
