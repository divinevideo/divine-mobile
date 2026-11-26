// ABOUTME: #10016 — a group message, a group delete-for-everyone and a group
// ABOUTME: reaction each publish the sender's own copy once, not once per
// ABOUTME: member, and the retry queue replays that copy once per batch.

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
import 'package:nostr_sdk/nip59/gift_wrap_util.dart';
import 'package:nostr_sdk/nostr.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _FakeEvent extends Fake implements Event {}

/// The real queue, with a hook that runs once before the next read of a
/// conversation's rows: the read a group row's batch copy starts with.
class _HookedOutgoingDmsDao extends OutgoingDmsDao {
  _HookedOutgoingDmsDao(super.attachedDatabase);

  void Function()? beforeConversationRead;

  @override
  Future<List<OutgoingDm>> getForConversation({
    required String conversationId,
    required String ownerPubkey,
  }) {
    final hook = beforeConversationRead;
    beforeConversationRead = null;
    hook?.call();
    return super.getForConversation(
      conversationId: conversationId,
      ownerPubkey: ownerPubkey,
    );
  }
}

// Real curve keys: the real message service encrypts every wrap.
const _ownerKey =
    '5426e5b8b4b0e2a1f5e8d3c7a9b2f4e6d8c0a2b4f6e8d0c2a4b6f8e0d2c4a6b8';

/// The account the device switches to mid-copy.
const _nextAccountKey =
    '6a1f2e3d4c5b6a7980f1e2d3c4b5a69788f9e0d1c2b3a4958677f8e9d0c1b2a3';

/// Private keys 1..9 are valid scalars, so their public keys are points.
String _memberKey(int seed) => seed.toRadixString(16).padLeft(64, '0');

const _poolRelay = 'wss://relay.divine.video';
const _advertisedInbox = 'wss://inbox.example.com';

const _reactedMessageId =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _retractedMessageId =
    '2222222222222222222222222222222222222222222222222222222222222222';
const _retractedMessageWrapId =
    '3333333333333333333333333333333333333333333333333333333333333333';

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeEvent());
    registerFallbackValue(Duration.zero);
    registerFallbackValue(<nostr_filter.Filter>[]);
  });

  group("#10016 the sender's own copy in a group", () {
    final owner = getPublicKey(_ownerKey);
    final nextAccount = getPublicKey(_nextAccountKey);
    final members = [for (var i = 1; i <= 9; i++) getPublicKey(_memberKey(i))];

    late AppDatabase db;
    late _MockNostrClient nostrClient;
    late List<Event> published;
    late bool ownCopiesPublish;
    late bool recipientOksArrive;
    late Set<String> unreadableInboxes;
    late Set<String> refusingRecipients;
    late void Function(Event wrap)? onRecipientPublish;
    late _HookedOutgoingDmsDao outgoingDao;
    late DmRepository repository;
    late DmReactionsRepository reactions;

    List<Event> wrapsTo(String pubkey, {int from = 0}) => [
      for (final event in published.skip(from))
        if (event.kind == EventKind.giftWrap &&
            event.tags.any(
              (tag) => tag.length >= 2 && tag[0] == 'p' && tag[1] == pubkey,
            ))
          event,
    ];

    Future<Event?> openAsOwner(Event wrap) => GiftWrapUtil.getRumorEvent(
      Nostr(
        LocalNostrSigner(_ownerKey),
        [],
        (url) => throw UnimplementedError('no relays in this test'),
      ),
      wrap,
    );

    Future<List<OutgoingDm>> queueRows() =>
        OutgoingDmsDao(db).getAllForOwner(owner);

    setUp(() {
      db = AppDatabase.test(NativeDatabase.memory());
      nostrClient = _MockNostrClient();
      published = [];
      ownCopiesPublish = true;
      recipientOksArrive = true;
      unreadableInboxes = {};
      refusingRecipients = {};
      onRecipientPublish = null;
      outgoingDao = _HookedOutgoingDmsDao(db);

      when(() => nostrClient.connectedRelayCount).thenReturn(1);
      when(() => nostrClient.configuredRelayCount).thenReturn(1);
      when(() => nostrClient.configuredRelays).thenReturn(const [_poolRelay]);
      when(() => nostrClient.isRelayAllowed(any())).thenReturn(true);
      // Every member advertises an inbox unless it is unreadable; the owner
      // advertises none.
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
          silentRelayTimeout: any(named: 'silentRelayTimeout'),
        ),
      ).thenAnswer((invocation) async {
        final filters = (invocation.positionalArguments.first as List)
            .cast<nostr_filter.Filter>();
        final pubkey = filters.first.authors!.single;
        if (unreadableInboxes.contains(pubkey)) {
          return (events: const <Event>[], timedOut: false, noRelays: true);
        }
        return (
          events: [
            if (pubkey != owner)
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
        published.add(event);
        onRecipientPublish?.call(event);
        final targets =
            invocation.namedArguments[#targetRelays] as List<String>? ??
            const [_poolRelay];
        final refused = event.tags.any(
          (tag) =>
              tag.length >= 2 &&
              tag[0] == 'p' &&
              refusingRecipients.contains(tag[1]),
        );
        if (refused) {
          return PublishOutcome(
            eventId: event.id,
            acceptedBy: const [],
            rejectedBy: {for (final relay in targets) relay: 'invalid: test'},
            noResponseFrom: const [],
          );
        }
        return PublishOutcome(
          eventId: event.id,
          acceptedBy: recipientOksArrive ? targets : const [],
          rejectedBy: const {},
          noResponseFrom: recipientOksArrive ? const [] : targets,
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

      final signer = LocalNostrSigner(_ownerKey);
      final messageService = NIP17MessageService(
        signer: signer,
        senderPublicKey: owner,
        nostrService: nostrClient,
        sendPolicy: (_) async => DmSendPolicyDecision.allowed,
        isOffline: () async => false,
        isolateGiftWrapBatchBuilder: buildGiftWrapBatch,
      );
      reactions = DmReactionsRepository(
        reactionsDao: DmReactionsDao(db),
        messageService: messageService,
        userPubkey: owner,
        conversationsDao: ConversationsDao(db),
        directMessagesDao: DirectMessagesDao(db),
      );
      // Receiving rooms stays at its default, off: sending to a room the
      // install already holds does not depend on the groupMessages flag.
      repository = DmRepository(
        nostrClient: nostrClient,
        messageService: messageService,
        directMessagesDao: DirectMessagesDao(db),
        conversationsDao: ConversationsDao(db),
        outgoingDmsDao: outgoingDao,
        userPubkey: owner,
        signer: signer,
        reactionsRepository: reactions,
      );
      reactions
        ..setDmInboxRelayResolver(repository.resolveDmInboxRelaysDetailed)
        ..setSelfWrapRelayResolver(repository.resolveSelfWrapTargetRelays);
    });

    tearDown(() async {
      await db.close();
    });

    /// Signs the repository into the next account, as an account switch does:
    /// its message service is replaced.
    void switchAccount() {
      final signer = LocalNostrSigner(_nextAccountKey);
      repository.setCredentials(
        userPubkey: nextAccount,
        signer: signer,
        messageService: NIP17MessageService(
          signer: signer,
          senderPublicKey: nextAccount,
          nostrService: nostrClient,
          sendPolicy: (_) async => DmSendPolicyDecision.allowed,
          isOffline: () async => false,
          isolateGiftWrapBatchBuilder: buildGiftWrapBatch,
        ),
      );
    }

    Future<String> seedRoom(List<String> others) async {
      final participants = [owner, ...others];
      final id = DmRepository.computeConversationId(participants);
      await ConversationsDao(db).upsertConversation(
        id: id,
        participantPubkeys: jsonEncode(participants),
        isGroup: participants.length > 2,
        createdAt: 1700000000,
        ownerPubkey: owner,
      );
      return id;
    }

    Future<List<NIP17SendResult>> sendToRoom(List<String> others) async {
      await seedRoom(others);
      return repository.sendGroupMessage(
        recipientPubkeys: others,
        content: 'hello room',
      );
    }

    group('a message', () {
      for (final size in [2, 3, 4, 10]) {
        test('to $size people publishes one own copy and one wrap per '
            'member', () async {
          final others = members.take(size - 1).toList();

          final results = await sendToRoom(others);

          expect(results, hasLength(others.length));
          expect(results.every((r) => r.success), isTrue);
          for (final member in others) {
            expect(wrapsTo(member), hasLength(1), reason: 'member $member');
          }
          expect(wrapsTo(owner), hasLength(1));
          expect(results.every((r) => r.selfWrapPublished ?? false), isTrue);
          expect(await queueRows(), isEmpty);
        });
      }

      test(
        'to one person through sendMessage publishes one own copy',
        () async {
          final peer = members.first;
          await seedRoom([peer]);

          final result = await repository.sendMessage(
            recipientPubkey: peer,
            content: 'hello',
          );

          expect(result.success, isTrue);
          expect(wrapsTo(peer), hasLength(1));
          expect(wrapsTo(owner), hasLength(1));
        },
      );

      test('publishes as its own copy the rumor the members got', () async {
        final results = await sendToRoom(members.take(3).toList());

        final ownCopy = await openAsOwner(wrapsTo(owner).single);

        expect(ownCopy, isNotNull);
        expect(ownCopy!.id, results.first.rumorEventId);
        expect(ownCopy.content, 'hello room');
      });

      test('publishes one own copy when one member is held on an unreadable '
          "inbox, and records it on that member's row", () async {
        final others = members.take(3).toList();
        unreadableInboxes.add(others.last);

        final results = await sendToRoom(others);

        expect(results.where((r) => r.success), hasLength(2));
        expect(wrapsTo(owner), hasLength(1));
        final held = (await queueRows()).single;
        expect(held.recipientPubkey, others.last);
        expect(held.selfWrapStatus, OutgoingWrapStatus.sent);
      });

      test('records a failed own copy on every delivered member', () async {
        final others = members.take(3).toList();
        ownCopiesPublish = false;

        final results = await sendToRoom(others);

        expect(results.every((r) => r.success), isTrue);
        expect(results.every((r) => r.selfWrapPublished == false), isTrue);
        final rows = await queueRows();
        expect(rows, hasLength(others.length));
        for (final row in rows) {
          expect(row.recipientWrapStatus, OutgoingWrapStatus.sent);
          expect(row.selfWrapStatus, OutgoingWrapStatus.failed);
        }
      });

      test('publishes no own copy when no member is delivered', () async {
        recipientOksArrive = false;

        final results = await sendToRoom(members.take(3).toList());

        expect(results.any((r) => r.success), isFalse);
        expect(wrapsTo(members.first), hasLength(1));
        expect(wrapsTo(owner), isEmpty);
      });
    });

    group('a delete-for-everyone', () {
      for (final size in [2, 3, 4, 10]) {
        test('in a conversation of $size publishes one own copy and one wrap '
            'per member', () async {
          final others = members.take(size - 1).toList();
          final conversationId = await seedRoom(others);
          await DirectMessagesDao(db).insertMessage(
            id: _retractedMessageId,
            conversationId: conversationId,
            senderPubkey: owner,
            content: 'a message to delete for everyone',
            createdAt: 1700000000,
            giftWrapId: _retractedMessageWrapId,
            ownerPubkey: owner,
          );

          await repository.deleteMessageForEveryone(_retractedMessageId);
          for (
            var turn = 0;
            turn < 400 &&
                (others.any((pubkey) => wrapsTo(pubkey).isEmpty) ||
                    wrapsTo(owner).isEmpty);
            turn++
          ) {
            await pumpEventQueue();
          }
          await pumpEventQueue(times: 100);

          for (final member in others) {
            expect(wrapsTo(member), hasLength(1), reason: 'member $member');
          }
          expect(wrapsTo(owner), hasLength(1));
          final ownCopy = await openAsOwner(wrapsTo(owner).single);
          expect(ownCopy?.kind, EventKind.eventDeletion);
        });
      }
    });

    group('a reaction (the shape #8446 shipped)', () {
      for (final size in [2, 3, 4, 10]) {
        test('in a conversation of $size publishes one own copy and one wrap '
            'per member', () async {
          final others = members.take(size - 1).toList();
          final conversationId = await seedRoom(others);

          final result = await reactions.publish(
            conversationId: conversationId,
            targetMessageId: _reactedMessageId,
            targetMessageAuthor: others.first,
            emoji: '🔥',
          );

          expect(result.success, isTrue);
          for (final member in others) {
            expect(wrapsTo(member), hasLength(1), reason: 'member $member');
          }
          expect(wrapsTo(owner), hasLength(1));
        });
      }
    });

    group('the retry queue', () {
      /// Re-drives [rows] the way the retry sweep does: one call per row it
      /// listed. A row gone by its turn is skipped, as the sweep skips the
      /// `ArgumentError` a missing row raises.
      Future<void> sweep(
        List<OutgoingDm> rows,
        Future<NIP17SendResult> Function(String rowId) recover,
      ) async {
        for (final row in rows) {
          if (await OutgoingDmsDao(db).getById(row.id) == null) continue;
          await recover(row.id);
        }
      }

      test('replays a failed own copy once for the whole batch', () async {
        ownCopiesPublish = false;
        await sendToRoom(members.take(3).toList());
        final rows = await queueRows();
        expect(rows, hasLength(3), reason: 'precondition: three partial rows');
        ownCopiesPublish = true;

        await sweep(rows, (id) => repository.recoverSelfWrap(rumorId: id));

        expect(wrapsTo(owner), hasLength(1));
        expect(await queueRows(), isEmpty);
      });

      test('publishes one own copy when members whose OKs were lost are '
          're-driven', () async {
        recipientOksArrive = false;
        final others = members.take(3).toList();
        await sendToRoom(others);
        final rows = await queueRows();
        expect(rows, hasLength(3), reason: 'precondition: nothing confirmed');
        recipientOksArrive = true;

        await sweep(rows, (id) => repository.recoverFullSend(rumorId: id));

        for (final member in others) {
          expect(wrapsTo(member), isNotEmpty, reason: 'member $member');
        }
        expect(wrapsTo(owner), hasLength(1));
        expect(await queueRows(), isEmpty);
      });

      test("keeps the batch's copy on a held member whose next attempt is "
          'refused, so delivering to them later publishes none', () async {
        final others = members.take(3).toList();
        unreadableInboxes.add(others.last);
        await sendToRoom(others);
        expect(wrapsTo(owner), hasLength(1), reason: 'precondition');
        final held = (await queueRows()).single;
        unreadableInboxes.clear();
        refusingRecipients.add(others.last);

        final refused = await repository.recoverFullSend(rumorId: held.id);

        expect(refused.success, isFalse);
        final afterRefusal = await OutgoingDmsDao(db).getById(held.id);
        expect(afterRefusal?.recipientWrapStatus, OutgoingWrapStatus.failed);
        expect(afterRefusal?.selfWrapStatus, OutgoingWrapStatus.sent);
        refusingRecipients.clear();

        final delivered = await repository.recoverFullSend(rumorId: held.id);

        expect(delivered.success, isTrue);
        expect(wrapsTo(owner), hasLength(1));
        expect(await queueRows(), isEmpty);
      });

      test('publishes no second own copy when a held member is delivered '
          'later', () async {
        final others = members.take(3).toList();
        unreadableInboxes.add(others.last);
        await sendToRoom(others);
        expect(wrapsTo(owner), hasLength(1), reason: 'precondition');
        final held = (await queueRows()).single;
        unreadableInboxes.clear();

        final result = await repository.recoverFullSend(rumorId: held.id);

        expect(result.success, isTrue);
        expect(wrapsTo(others.last), hasLength(2), reason: 'pool, then inbox');
        expect(wrapsTo(owner), hasLength(1));
        expect(await queueRows(), isEmpty);
      });
    });

    group('an account switch mid-copy', () {
      test('leaves a group row queued with its budget when the account '
          "changes while its batch's copy is replayed", () async {
        ownCopiesPublish = false;
        await sendToRoom(members.take(3).toList());
        final row = (await queueRows()).first;
        expect(row.selfWrapStatus, OutgoingWrapStatus.failed);
        ownCopiesPublish = true;
        final from = published.length;
        outgoingDao.beforeConversationRead = switchAccount;

        final result = await repository.recoverSelfWrap(rumorId: row.id);

        expect(result.success, isFalse);
        expect(result.queuedRumorId, row.id);
        expect(wrapsTo(nextAccount, from: from), isEmpty);
        expect(wrapsTo(owner, from: from), isEmpty);
        final kept = await outgoingDao.getById(row.id);
        expect(kept?.selfWrapStatus, OutgoingWrapStatus.failed);
        expect(kept?.retryCount, row.retryCount);
      });

      test('publishes no own copy of a retraction whose account changed during '
          'the fan-out', () async {
        final others = members.take(2).toList();
        final conversationId = await seedRoom(others);
        await DirectMessagesDao(db).insertMessage(
          id: _retractedMessageId,
          conversationId: conversationId,
          senderPubkey: owner,
          content: 'a message to delete for everyone',
          createdAt: 1700000000,
          giftWrapId: _retractedMessageWrapId,
          ownerPubkey: owner,
        );
        onRecipientPublish = (wrap) {
          final toLast = wrap.tags.any(
            (tag) => tag.length >= 2 && tag[0] == 'p' && tag[1] == others.last,
          );
          if (!toLast) return;
          onRecipientPublish = null;
          switchAccount();
        };

        await repository.deleteMessageForEveryone(_retractedMessageId);
        for (
          var turn = 0;
          turn < 400 && others.any((pubkey) => wrapsTo(pubkey).isEmpty);
          turn++
        ) {
          await pumpEventQueue();
        }
        await pumpEventQueue(times: 100);

        expect(wrapsTo(others.last), hasLength(1), reason: 'precondition');
        expect(wrapsTo(nextAccount), isEmpty);
        expect(wrapsTo(owner), isEmpty);
      });
    });
  });
}
