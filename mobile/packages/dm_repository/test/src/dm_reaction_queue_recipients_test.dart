// ABOUTME: Regression coverage for #7880 — a queued DM reaction, or a queued
// ABOUTME: kind-5 removal, is sent to the people it was queued for. An account
// ABOUTME: switch deletes the conversation rows a retry used to read them
// ABOUTME: from, which narrowed a group reaction to the message's author.

import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';

class _MockNip17MessageService extends Mock implements NIP17MessageService {}

class _MockNostrClient extends Mock implements NostrClient {}

class _MockReactionsRepository extends Mock implements DmReactionsRepository {}

class _FakeEvent extends Fake implements Event {}

const _owner =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _peer =
    '2222222222222222222222222222222222222222222222222222222222222222';
const _peer2 =
    '3333333333333333333333333333333333333333333333333333333333333333';
const _peer3 =
    '9999999999999999999999999999999999999999999999999999999999999999';
const _peerMessageId =
    '4444444444444444444444444444444444444444444444444444444444444444';
const _ownMessageId =
    '5555555555555555555555555555555555555555555555555555555555555555';

void main() {
  setUpAll(() => registerFallbackValue(_FakeEvent()));

  group('DM reaction queue recipients', () {
    late AppDatabase db;
    late DmReactionsDao reactionsDao;
    late ConversationsDao conversationsDao;
    late DirectMessagesDao messagesDao;
    late _MockNip17MessageService messageService;
    late DmReactionsRepository reactions;

    /// Every gift wrap handed to the wire, in order.
    late List<({int kind, String recipient, List<String>? relays})> wire;

    setUp(() {
      db = AppDatabase.test(NativeDatabase.memory());
      reactionsDao = DmReactionsDao(db);
      conversationsDao = ConversationsDao(db);
      messagesDao = DirectMessagesDao(db);
      messageService = _MockNip17MessageService();
      wire = [];

      when(
        () => messageService.buildRumor(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          eventKind: any(named: 'eventKind'),
          additionalTags: any(named: 'additionalTags'),
          createdAt: any(named: 'createdAt'),
        ),
      ).thenAnswer((invocation) {
        final tags = <List<String>>[
          ['p', invocation.namedArguments[#recipientPubkey] as String],
          ...invocation.namedArguments[#additionalTags] as List<List<String>>,
        ];
        return Event(
          _owner,
          invocation.namedArguments[#eventKind] as int,
          tags,
          invocation.namedArguments[#content] as String,
        );
      });

      reactions =
          DmReactionsRepository(
            reactionsDao: reactionsDao,
            conversationsDao: conversationsDao,
            directMessagesDao: messagesDao,
          )..setCredentials(
            userPubkey: _owner,
            messageService: messageService,
          );
    });

    tearDown(() => db.close());

    /// Records every wrap, and either confirms it or reports the relay down.
    void stubWire({required bool lands}) {
      when(
        () => messageService.sendRumor(
          rumorEvent: any(named: 'rumorEvent'),
          recipientPubkey: any(named: 'recipientPubkey'),
          targetRelays: any(named: 'targetRelays'),
          awaitRecipientOk: any(named: 'awaitRecipientOk'),
          selfWrapOnSoftUnconfirmed: any(named: 'selfWrapOnSoftUnconfirmed'),
          recipientWrapBuildTimeout: any(named: 'recipientWrapBuildTimeout'),
          selfWrapBuildTimeout: any(named: 'selfWrapBuildTimeout'),
        ),
      ).thenAnswer((invocation) async {
        final rumor = invocation.namedArguments[#rumorEvent] as Event;
        final recipient = invocation.namedArguments[#recipientPubkey] as String;
        wire.add((
          kind: rumor.kind,
          recipient: recipient,
          relays: invocation.namedArguments[#targetRelays] as List<String>?,
        ));
        if (!lands) return const NIP17SendResult.failure('offline');
        return NIP17SendResult.success(
          rumorEventId: rumor.id,
          messageEventId: 'wrap-${rumor.id}-$recipient',
          recipientPubkey: recipient,
        );
      });
    }

    List<String> recipientsOf(int kind) => [
      for (final wrap in wire)
        if (wrap.kind == kind) wrap.recipient,
    ];

    Future<String> seedConversation(List<String> participants) async {
      final conversationId = DmRepository.computeConversationId(participants);
      await conversationsDao.upsertConversation(
        id: conversationId,
        participantPubkeys: '["${participants.join('","')}"]',
        isGroup: participants.length > 2,
        createdAt: 1700000000,
        ownerPubkey: _owner,
      );
      return conversationId;
    }

    /// The cleanup the incoming account runs for the one that left
    /// (`social_providers.dart`): its messages and conversations go, and so
    /// does every reaction row except the ones still waiting to be sent.
    Future<void> switchAccountAwayAndBack() async {
      await db.transaction(() async {
        await messagesDao.clearForAccountSwitch(_owner);
        await conversationsDao.clearForAccountSwitch(_owner);
      });
      await reactionsDao.deleteNonRetryableForOwner(_owner);
    }

    /// The state a build without stored recipients left behind: the queue row
    /// is intact and says nothing about who it was for.
    Future<void> forgetStoredRecipients() => db.customStatement(
      'UPDATE dm_message_reactions SET recipient_pubkeys = NULL',
    );

    /// Queues a reaction while the relay is down, then brings the relay back.
    Future<String> queueReactionOffline({
      required String conversationId,
      required String targetMessageId,
      required String targetMessageAuthor,
    }) async {
      stubWire(lands: false);
      final published = await reactions.publish(
        conversationId: conversationId,
        targetMessageId: targetMessageId,
        targetMessageAuthor: targetMessageAuthor,
        emoji: '🔥',
      );
      expect(
        await reactions.retryableReactions(),
        hasLength(1),
        reason: 'precondition: the offline publish left a queued reaction',
      );
      wire.clear();
      stubWire(lands: true);
      return published.rumorId;
    }

    /// Delivers a reaction, then queues its removal while the relay is down,
    /// and brings the relay back.
    Future<String> queueRemovalOffline({
      required String conversationId,
      required String targetMessageId,
      required String targetMessageAuthor,
    }) async {
      stubWire(lands: true);
      final published = await reactions.publish(
        conversationId: conversationId,
        targetMessageId: targetMessageId,
        targetMessageAuthor: targetMessageAuthor,
        emoji: '🔥',
      );
      expect(published.success, isTrue, reason: 'precondition: delivered');
      stubWire(lands: false);
      await reactions.removeOwn(
        rumorId: published.rumorId,
        targetMessageAuthor: targetMessageAuthor,
      );
      await pumpEventQueue();
      expect(
        await reactions.retryableDeletions(),
        hasLength(1),
        reason: 'precondition: the offline removal left a queued kind-5',
      );
      wire.clear();
      stubWire(lands: true);
      return published.rumorId;
    }

    /// What the reaction's own self-wrap echo writes when the reacted message
    /// is now filed under [conversationId], such as the 1:1 with its author.
    Future<void> echoFilesReactionUnder(
      String conversationId, {
      required String rumorId,
    }) async {
      final row = await reactionsDao.getById(id: rumorId, ownerPubkey: _owner);
      await reactionsDao.upsertIncoming(
        id: rumorId,
        conversationId: conversationId,
        targetMessageId: row!.targetMessageId,
        targetMessageAuthor: row.targetMessageAuthor,
        reactorPubkey: _owner,
        emoji: row.emoji,
        createdAt: row.createdAt,
        giftWrapId: '6' * 64,
        ownerPubkey: _owner,
      );
    }

    group('after an account switch', () {
      test('a queued group reaction is sent to every member', () async {
        final group = await seedConversation([_owner, _peer, _peer2]);
        final rumorId = await queueReactionOffline(
          conversationId: group,
          targetMessageId: _peerMessageId,
          targetMessageAuthor: _peer,
        );

        await switchAccountAwayAndBack();
        final result = await reactions.retry(
          rumorId: rumorId,
          targetMessageAuthor: _peer,
        );

        expect(
          recipientsOf(EventKind.reaction),
          unorderedEquals([_peer, _peer2]),
        );
        expect(result.success, isTrue);
        expect(await reactions.retryableReactions(), isEmpty);
      });

      test(
        'a queued group reaction to your own message is sent to every member',
        () async {
          final group = await seedConversation([_owner, _peer, _peer2]);
          final rumorId = await queueReactionOffline(
            conversationId: group,
            targetMessageId: _ownMessageId,
            targetMessageAuthor: _owner,
          );

          await switchAccountAwayAndBack();
          final result = await reactions.retry(
            rumorId: rumorId,
            targetMessageAuthor: _owner,
          );

          expect(
            recipientsOf(EventKind.reaction),
            unorderedEquals([_peer, _peer2]),
          );
          expect(result.success, isTrue);
        },
      );

      test(
        'a queued 1:1 reaction to your own message is sent to the other person',
        () async {
          final direct = await seedConversation([_owner, _peer]);
          final rumorId = await queueReactionOffline(
            conversationId: direct,
            targetMessageId: _ownMessageId,
            targetMessageAuthor: _owner,
          );

          await switchAccountAwayAndBack();
          final result = await reactions.retry(
            rumorId: rumorId,
            targetMessageAuthor: _owner,
          );

          expect(recipientsOf(EventKind.reaction), equals([_peer]));
          expect(result.success, isTrue);
        },
      );

      test(
        'a queued removal of a group reaction is sent to every member',
        () async {
          final group = await seedConversation([_owner, _peer, _peer2]);
          final rumorId = await queueRemovalOffline(
            conversationId: group,
            targetMessageId: _peerMessageId,
            targetMessageAuthor: _peer,
          );

          await switchAccountAwayAndBack();
          final outcome = await reactions.retryDeletion(
            rumorId: rumorId,
            targetMessageAuthor: _peer,
          );

          expect(
            recipientsOf(EventKind.eventDeletion),
            unorderedEquals([_peer, _peer2]),
          );
          expect(outcome, equals(DmReactionDeletionOutcome.sent));
          expect(await reactions.retryableDeletions(), isEmpty);
        },
      );
    });

    group('once the message is shown in another conversation', () {
      test('removing a reaction reaches everyone it was sent to', () async {
        final group = await seedConversation([_owner, _peer, _peer2]);
        final direct = await seedConversation([_owner, _peer]);
        stubWire(lands: true);
        final published = await reactions.publish(
          conversationId: group,
          targetMessageId: _peerMessageId,
          targetMessageAuthor: _peer,
          emoji: '🔥',
        );
        expect(
          recipientsOf(EventKind.reaction),
          unorderedEquals([_peer, _peer2]),
          reason: 'precondition: both members received the reaction',
        );
        await echoFilesReactionUnder(direct, rumorId: published.rumorId);

        await reactions.removeOwn(
          rumorId: published.rumorId,
          targetMessageAuthor: _peer,
        );
        await pumpEventQueue();

        expect(
          recipientsOf(EventKind.eventDeletion),
          unorderedEquals([_peer, _peer2]),
        );
      });

      test(
        'changing the emoji removes the old one for everyone who received it',
        () async {
          final group = await seedConversation([_owner, _peer, _peer2]);
          final direct = await seedConversation([_owner, _peer]);
          stubWire(lands: true);
          await reactions.publish(
            conversationId: group,
            targetMessageId: _peerMessageId,
            targetMessageAuthor: _peer,
            emoji: '🔥',
          );
          expect(
            recipientsOf(EventKind.reaction),
            unorderedEquals([_peer, _peer2]),
            reason: 'precondition: both members received the first emoji',
          );

          await reactions.publish(
            conversationId: direct,
            targetMessageId: _peerMessageId,
            targetMessageAuthor: _peer,
            emoji: '👍',
          );
          await pumpEventQueue();

          expect(
            recipientsOf(EventKind.eventDeletion),
            unorderedEquals([_peer, _peer2]),
          );
        },
      );

      test(
        'changing the emoji does not send the removal of the old one to '
        'people it never reached',
        () async {
          final direct = await seedConversation([_owner, _peer]);
          final group = await seedConversation([_owner, _peer, _peer2]);
          stubWire(lands: true);
          await reactions.publish(
            conversationId: direct,
            targetMessageId: _peerMessageId,
            targetMessageAuthor: _peer,
            emoji: '🔥',
          );
          expect(
            recipientsOf(EventKind.reaction),
            equals([_peer]),
            reason: 'precondition: only the 1:1 received the first emoji',
          );

          await reactions.publish(
            conversationId: group,
            targetMessageId: _peerMessageId,
            targetMessageAuthor: _peer,
            emoji: '👍',
          );
          await pumpEventQueue();

          expect(recipientsOf(EventKind.eventDeletion), equals([_peer]));
        },
      );

      test(
        'changing the emoji reads the inbox of everyone either emoji goes to',
        () async {
          final group = await seedConversation([_owner, _peer, _peer2]);
          final direct = await seedConversation([_owner, _peer]);
          final lookups = <String>[];
          reactions.setDmInboxRelayResolver((pubkey) async {
            lookups.add(pubkey);
            return (
              relays: ['wss://inbox.example/$pubkey'],
              state: DmInboxResolution.found,
            );
          });
          stubWire(lands: true);
          await reactions.publish(
            conversationId: group,
            targetMessageId: _peerMessageId,
            targetMessageAuthor: _peer,
            emoji: '🔥',
          );
          wire.clear();
          lookups.clear();

          await reactions.publish(
            conversationId: direct,
            targetMessageId: _peerMessageId,
            targetMessageAuthor: _peer,
            emoji: '👍',
          );
          await pumpEventQueue();

          final removalToPeer2 = wire.singleWhere(
            (wrap) =>
                wrap.kind == EventKind.eventDeletion &&
                wrap.recipient == _peer2,
          );
          expect(
            removalToPeer2.relays,
            equals(['wss://inbox.example/$_peer2']),
          );
          expect(lookups, unorderedEquals([_peer, _peer2]));
        },
      );

      test(
        'changing an emoji whose recipients were only inferred also removes it '
        'for the recipients of the new one',
        () async {
          // An own reaction received by self-wrap before its message was
          // stored: it is filed under the 1:1 with the author and has no
          // stored set.
          final direct = await seedConversation([_owner, _peer]);
          final group = await seedConversation([_owner, _peer, _peer2]);
          await reactionsDao.upsertIncoming(
            id: '7' * 64,
            conversationId: direct,
            targetMessageId: _peerMessageId,
            targetMessageAuthor: _peer,
            reactorPubkey: _owner,
            emoji: '🔥',
            createdAt: 1700000000,
            giftWrapId: '6' * 64,
            ownerPubkey: _owner,
          );
          stubWire(lands: true);

          await reactions.publish(
            conversationId: group,
            targetMessageId: _peerMessageId,
            targetMessageAuthor: _peer,
            emoji: '👍',
          );
          await pumpEventQueue();

          expect(
            recipientsOf(EventKind.eventDeletion),
            unorderedEquals([_peer, _peer2]),
          );
        },
      );

      test(
        'changing an emoji from the 1:1 removes one inferred from its group '
        'for the whole group',
        () async {
          // An own reaction received by self-wrap and filed under the group,
          // with no stored set: the group is all that says who has it.
          final group = await seedConversation([_owner, _peer, _peer2]);
          final direct = await seedConversation([_owner, _peer]);
          final priorId = '7' * 64;
          await reactionsDao.upsertIncoming(
            id: priorId,
            conversationId: group,
            targetMessageId: _peerMessageId,
            targetMessageAuthor: _peer,
            reactorPubkey: _owner,
            emoji: '🔥',
            createdAt: 1700000000,
            giftWrapId: '6' * 64,
            ownerPubkey: _owner,
          );
          stubWire(lands: true);

          await reactions.publish(
            conversationId: direct,
            targetMessageId: _peerMessageId,
            targetMessageAuthor: _peer,
            emoji: '👍',
          );
          await pumpEventQueue();

          final prior = await reactionsDao.getById(
            id: priorId,
            ownerPubkey: _owner,
          );
          expect(
            recipientsOf(EventKind.eventDeletion),
            unorderedEquals([_peer, _peer2]),
          );
          expect(
            jsonDecode(prior!.recipientPubkeys!),
            unorderedEquals([_peer, _peer2]),
          );
        },
      );
    });

    group('after group recovery moves the message into its group', () {
      test('a queued reaction is sent to every member of that group', () async {
        // The state #8407 repairs: a group message filed under the 1:1 with
        // its author, so a reaction queued there only names the author.
        final direct = await seedConversation([_owner, _peer]);
        final group = await seedConversation([_owner, _peer, _peer2]);
        final rumorId = await queueReactionOffline(
          conversationId: direct,
          targetMessageId: _peerMessageId,
          targetMessageAuthor: _peer,
        );

        await reactions.reassignForMovedMessages(
          targetMessageIds: [_peerMessageId],
          toConversationId: group,
          ownerPubkey: _owner,
        );
        final result = await reactions.retry(
          rumorId: rumorId,
          targetMessageAuthor: _peer,
        );

        expect(
          recipientsOf(EventKind.reaction),
          unorderedEquals([_peer, _peer2]),
        );
        expect(result.success, isTrue);
      });
    });

    group('when the row has no usable recipient set', () {
      test(
        'a group reaction is held instead of going to the author alone',
        () async {
          final group = await seedConversation([_owner, _peer, _peer2]);
          final rumorId = await queueReactionOffline(
            conversationId: group,
            targetMessageId: _peerMessageId,
            targetMessageAuthor: _peer,
          );
          await forgetStoredRecipients();

          await switchAccountAwayAndBack();
          final result = await reactions.retry(
            rumorId: rumorId,
            targetMessageAuthor: _peer,
          );

          final row = await reactionsDao.getById(
            id: rumorId,
            ownerPubkey: _owner,
          );
          expect(wire, isEmpty);
          expect(result.success, isFalse);
          expect(row!.publishStatus, equals('failed'));
          expect(row.rumorEventJson, isNotNull);
        },
      );

      test(
        'a group removal is held instead of going to the author alone',
        () async {
          final group = await seedConversation([_owner, _peer, _peer2]);
          final rumorId = await queueRemovalOffline(
            conversationId: group,
            targetMessageId: _peerMessageId,
            targetMessageAuthor: _peer,
          );
          await forgetStoredRecipients();

          await switchAccountAwayAndBack();
          final outcome = await reactions.retryDeletion(
            rumorId: rumorId,
            targetMessageAuthor: _peer,
          );

          expect(wire, isEmpty);
          expect(outcome, equals(DmReactionDeletionOutcome.unconfirmed));
          expect(
            await reactions.retryableDeletions(),
            hasLength(1),
            reason: 'the removal stays queued with its kind-5',
          );
        },
      );

      test(
        'a reaction in a conversation that is not stored is held, then reaches '
        'every member once it is',
        () async {
          final group = DmRepository.computeConversationId([
            _owner,
            _peer,
            _peer2,
          ]);
          stubWire(lands: true);

          final held = await reactions.publish(
            conversationId: group,
            targetMessageId: _peerMessageId,
            targetMessageAuthor: _peer,
            emoji: '🔥',
          );
          final heldRow = await reactionsDao.getById(
            id: held.rumorId,
            ownerPubkey: _owner,
          );
          expect(wire, isEmpty);
          expect(held.success, isFalse);
          expect(heldRow!.publishStatus, equals('failed'));
          expect(await reactions.retryableReactions(), hasLength(1));

          await seedConversation([_owner, _peer, _peer2]);
          final result = await reactions.retry(
            rumorId: held.rumorId,
            targetMessageAuthor: _peer,
          );

          expect(
            recipientsOf(EventKind.reaction),
            unorderedEquals([_peer, _peer2]),
          );
          expect(result.success, isTrue);
          expect(await reactions.retryableReactions(), isEmpty);
        },
      );

      test(
        'removing a reaction is recorded, then sent to every member once they '
        'are known',
        () async {
          final group = await seedConversation([_owner, _peer, _peer2]);
          stubWire(lands: true);
          final published = await reactions.publish(
            conversationId: group,
            targetMessageId: _peerMessageId,
            targetMessageAuthor: _peer,
            emoji: '🔥',
          );
          expect(published.success, isTrue, reason: 'precondition: delivered');
          await forgetStoredRecipients();
          await conversationsDao.clearForAccountSwitch(_owner);
          wire.clear();

          await reactions.removeOwn(
            rumorId: published.rumorId,
            targetMessageAuthor: _peer,
          );
          await pumpEventQueue();

          final removed = await reactionsDao.getById(
            id: published.rumorId,
            ownerPubkey: _owner,
          );
          expect(wire, isEmpty);
          expect(removed!.isDeleted, isTrue);
          expect(await reactions.retryableDeletions(), hasLength(1));

          await seedConversation([_owner, _peer, _peer2]);
          final outcome = await reactions.retryDeletion(
            rumorId: published.rumorId,
            targetMessageAuthor: _peer,
          );

          expect(
            recipientsOf(EventKind.eventDeletion),
            unorderedEquals([_peer, _peer2]),
          );
          expect(outcome, equals(DmReactionDeletionOutcome.sent));
        },
      );

      test(
        'changing the emoji still queues the removal of the old one',
        () async {
          final group = await seedConversation([_owner, _peer, _peer2]);
          stubWire(lands: true);
          final first = await reactions.publish(
            conversationId: group,
            targetMessageId: _peerMessageId,
            targetMessageAuthor: _peer,
            emoji: '🔥',
          );
          expect(first.success, isTrue, reason: 'precondition: delivered');
          await forgetStoredRecipients();
          await conversationsDao.clearForAccountSwitch(_owner);
          wire.clear();

          await reactions.publish(
            conversationId: group,
            targetMessageId: _peerMessageId,
            targetMessageAuthor: _peer,
            emoji: '👍',
          );
          await pumpEventQueue();

          final queued = await reactions.retryableDeletions();
          final prior = await reactionsDao.getById(
            id: first.rumorId,
            ownerPubkey: _owner,
          );
          expect(wire, isEmpty);
          expect(
            queued.map((target) => target.rumorId),
            equals([first.rumorId]),
          );
          expect(prior!.recipientPubkeys, isNull);

          await seedConversation([_owner, _peer, _peer2]);
          final outcome = await reactions.retryDeletion(
            rumorId: first.rumorId,
            targetMessageAuthor: _peer,
          );

          expect(
            recipientsOf(EventKind.eventDeletion),
            unorderedEquals([_peer, _peer2]),
          );
          expect(outcome, equals(DmReactionDeletionOutcome.sent));
        },
      );

      test(
        'the removal of an old emoji keeps going to the recipients its first '
        'attempt was sent to',
        () async {
          // A reaction queued by an older build whose group is gone, replaced
          // from the 1:1 its message is now shown in.
          final group = await seedConversation([_owner, _peer, _peer2]);
          final rumorId = await queueReactionOffline(
            conversationId: group,
            targetMessageId: _peerMessageId,
            targetMessageAuthor: _peer,
          );
          await forgetStoredRecipients();
          await switchAccountAwayAndBack();
          final direct = await seedConversation([_owner, _peer]);
          stubWire(lands: false);
          await reactions.publish(
            conversationId: direct,
            targetMessageId: _peerMessageId,
            targetMessageAuthor: _peer,
            emoji: '👍',
          );
          await pumpEventQueue();
          expect(
            recipientsOf(EventKind.eventDeletion),
            equals([_peer]),
            reason: 'precondition: the first attempt went out and failed',
          );
          wire.clear();
          stubWire(lands: true);

          final outcome = await reactions.retryDeletion(
            rumorId: rumorId,
            targetMessageAuthor: _peer,
          );

          expect(recipientsOf(EventKind.eventDeletion), equals([_peer]));
          expect(outcome, equals(DmReactionDeletionOutcome.sent));
        },
      );

      group('and the reacted message is stored again', () {
        /// An install that synced a group message before #7338 was fixed
        /// still holds it under the 1:1 with its sender; the rumor's `p` tags
        /// still name the rest of the room.
        Future<void> syncBackPeerMessage({required List<String> pTags}) async {
          final direct = await seedConversation([_owner, _peer]);
          await messagesDao.insertMessage(
            id: _peerMessageId,
            conversationId: direct,
            senderPubkey: _peer,
            content: 'hello',
            createdAt: 1700000001,
            giftWrapId: '8' * 64,
            ownerPubkey: _owner,
            tagsJson: jsonEncode([
              for (final pubkey in pTags) ['p', pubkey],
            ]),
          );
        }

        test(
          'a group reaction is sent to the room that message names, when it is '
          'the room the reaction was queued in',
          () async {
            final group = await seedConversation([_owner, _peer, _peer2]);
            final rumorId = await queueReactionOffline(
              conversationId: group,
              targetMessageId: _peerMessageId,
              targetMessageAuthor: _peer,
            );
            await forgetStoredRecipients();
            await switchAccountAwayAndBack();
            await syncBackPeerMessage(pTags: [_owner, _peer2]);

            final result = await reactions.retry(
              rumorId: rumorId,
              targetMessageAuthor: _peer,
            );

            expect(
              recipientsOf(EventKind.reaction),
              unorderedEquals([_peer, _peer2]),
            );
            expect(result.success, isTrue);
          },
        );

        test(
          'a group reaction is not narrowed to the author by its own echo',
          () async {
            final group = await seedConversation([_owner, _peer, _peer2]);
            final rumorId = await queueReactionOffline(
              conversationId: group,
              targetMessageId: _peerMessageId,
              targetMessageAuthor: _peer,
            );
            await forgetStoredRecipients();
            await switchAccountAwayAndBack();
            await syncBackPeerMessage(pTags: [_owner, _peer2]);
            final queued = await reactionsDao.getById(
              id: rumorId,
              ownerPubkey: _owner,
            );
            final echo = Event.fromJson(
              jsonDecode(queued!.rumorEventJson!) as Map<String, dynamic>,
            );
            expect(
              await reactions.persistIncoming(
                rumorEvent: echo,
                giftWrapId: '6' * 64,
              ),
              equals(DmWrapOutcome.processed),
              reason: 'precondition: the history sync re-reads the echo',
            );

            final result = await reactions.retry(
              rumorId: rumorId,
              targetMessageAuthor: _peer,
            );

            expect(
              recipientsOf(EventKind.reaction),
              unorderedEquals([_peer, _peer2]),
            );
            expect(result.success, isTrue);
          },
        );

        test(
          'a group removal is not narrowed to the author by the echo of the '
          'reaction it removes',
          () async {
            final group = await seedConversation([_owner, _peer, _peer2]);
            final rumorId = await queueRemovalOffline(
              conversationId: group,
              targetMessageId: _peerMessageId,
              targetMessageAuthor: _peer,
            );
            await forgetStoredRecipients();
            await switchAccountAwayAndBack();
            final direct = DmRepository.computeConversationId([
              _owner,
              _peer,
            ]);
            await echoFilesReactionUnder(direct, rumorId: rumorId);

            final held = await reactions.retryDeletion(
              rumorId: rumorId,
              targetMessageAuthor: _peer,
            );
            expect(wire, isEmpty);
            expect(held, equals(DmReactionDeletionOutcome.unconfirmed));

            await syncBackPeerMessage(pTags: [_owner, _peer2]);
            final outcome = await reactions.retryDeletion(
              rumorId: rumorId,
              targetMessageAuthor: _peer,
            );

            expect(
              recipientsOf(EventKind.eventDeletion),
              unorderedEquals([_peer, _peer2]),
            );
            expect(outcome, equals(DmReactionDeletionOutcome.sent));
          },
        );

        test(
          'a group reaction stays held when that message names another room',
          () async {
            final group = await seedConversation([_owner, _peer, _peer2]);
            final rumorId = await queueReactionOffline(
              conversationId: group,
              targetMessageId: _peerMessageId,
              targetMessageAuthor: _peer,
            );
            await forgetStoredRecipients();
            await switchAccountAwayAndBack();
            await syncBackPeerMessage(pTags: [_owner]);

            final result = await reactions.retry(
              rumorId: rumorId,
              targetMessageAuthor: _peer,
            );

            expect(wire, isEmpty);
            expect(result.success, isFalse);
            expect(await reactions.retryableReactions(), hasLength(1));
          },
        );
      });

      test('a 1:1 reaction to their message is still sent to them', () async {
        final direct = await seedConversation([_owner, _peer]);
        final rumorId = await queueReactionOffline(
          conversationId: direct,
          targetMessageId: _peerMessageId,
          targetMessageAuthor: _peer,
        );
        await forgetStoredRecipients();

        await switchAccountAwayAndBack();
        final result = await reactions.retry(
          rumorId: rumorId,
          targetMessageAuthor: _peer,
        );

        expect(recipientsOf(EventKind.reaction), equals([_peer]));
        expect(result.success, isTrue);
      });

      test(
        'a 1:1 reaction to your own message waits for the conversation, then '
        'is sent to the other person',
        () async {
          final direct = await seedConversation([_owner, _peer]);
          final rumorId = await queueReactionOffline(
            conversationId: direct,
            targetMessageId: _ownMessageId,
            targetMessageAuthor: _owner,
          );
          await forgetStoredRecipients();
          await switchAccountAwayAndBack();

          final held = await reactions.retry(
            rumorId: rumorId,
            targetMessageAuthor: _owner,
          );
          expect(wire, isEmpty);
          expect(held.success, isFalse);

          // The history drain brings the 1:1 back.
          await seedConversation([_owner, _peer]);
          final result = await reactions.retry(
            rumorId: rumorId,
            targetMessageAuthor: _owner,
          );

          expect(recipientsOf(EventKind.reaction), equals([_peer]));
          expect(result.success, isTrue);
        },
      );

      test(
        'a retry records the recipients it resolved, so the next one survives '
        'an account switch',
        () async {
          final group = await seedConversation([_owner, _peer, _peer2]);
          final rumorId = await queueReactionOffline(
            conversationId: group,
            targetMessageId: _peerMessageId,
            targetMessageAuthor: _peer,
          );
          await forgetStoredRecipients();
          stubWire(lands: false);
          await reactions.retry(rumorId: rumorId, targetMessageAuthor: _peer);
          wire.clear();
          stubWire(lands: true);

          await switchAccountAwayAndBack();
          final result = await reactions.retry(
            rumorId: rumorId,
            targetMessageAuthor: _peer,
          );

          expect(
            recipientsOf(EventKind.reaction),
            unorderedEquals([_peer, _peer2]),
          );
          expect(result.success, isTrue);
        },
      );

      for (final unusable in ['not json', '[]', '{}', '["$_peer", 1]']) {
        test(
          'a stored set of $unusable is ignored in favour of the conversation',
          () async {
            final group = await seedConversation([_owner, _peer, _peer2]);
            final rumorId = await queueReactionOffline(
              conversationId: group,
              targetMessageId: _peerMessageId,
              targetMessageAuthor: _peer,
            );
            await db.customStatement(
              'UPDATE dm_message_reactions SET recipient_pubkeys = ?',
              [unusable],
            );

            final result = await reactions.retry(
              rumorId: rumorId,
              targetMessageAuthor: _peer,
            );

            expect(
              recipientsOf(EventKind.reaction),
              unorderedEquals([_peer, _peer2]),
            );
            expect(result.success, isTrue);
          },
        );
      }
    });

    group('when a recipient list holds something other than pubkeys', () {
      /// A member of the four-person room can write a `p` tag joining two
      /// other members with the separator conversation ids are hashed with.
      const crafted = '$_peer2:$_peer3';

      test(
        'a message naming the room that way does not prove its recipients',
        () async {
          final group = await seedConversation([
            _owner,
            _peer,
            _peer2,
            _peer3,
          ]);
          final rumorId = await queueReactionOffline(
            conversationId: group,
            targetMessageId: _peerMessageId,
            targetMessageAuthor: _peer,
          );
          await forgetStoredRecipients();
          await switchAccountAwayAndBack();
          await messagesDao.insertMessage(
            id: _peerMessageId,
            conversationId: await seedConversation([_owner, _peer]),
            senderPubkey: _peer,
            content: 'hello',
            createdAt: 1700000001,
            giftWrapId: '8' * 64,
            ownerPubkey: _owner,
            tagsJson: jsonEncode([
              ['p', _owner],
              ['p', crafted],
            ]),
          );

          final filled = await reactions.backfillQueuedRecipients(
            ownerPubkey: _owner,
          );
          await reactions.retry(rumorId: rumorId, targetMessageAuthor: _peer);

          final row = await reactionsDao.getById(
            id: rumorId,
            ownerPubkey: _owner,
          );
          expect(filled, isZero);
          expect(row!.recipientPubkeys, isNull);
          expect(wire, isEmpty);
        },
      );

      test('a conversation listing a member that way is not used', () async {
        final group = DmRepository.computeConversationId([
          _owner,
          _peer,
          _peer2,
          _peer3,
        ]);
        await conversationsDao.upsertConversation(
          id: group,
          participantPubkeys: jsonEncode([_peer, _owner, crafted]),
          isGroup: true,
          createdAt: 1700000000,
          ownerPubkey: _owner,
        );
        stubWire(lands: true);

        final held = await reactions.publish(
          conversationId: group,
          targetMessageId: _peerMessageId,
          targetMessageAuthor: _peer,
          emoji: '🔥',
        );

        final row = await reactionsDao.getById(
          id: held.rumorId,
          ownerPubkey: _owner,
        );
        expect(wire, isEmpty);
        expect(held.success, isFalse);
        expect(row!.recipientPubkeys, isNull);
      });
    });

    group('backfillQueuedRecipients', () {
      test('does not guess once the conversation is gone', () async {
        final group = await seedConversation([_owner, _peer, _peer2]);
        final rumorId = await queueReactionOffline(
          conversationId: group,
          targetMessageId: _peerMessageId,
          targetMessageAuthor: _peer,
        );
        await forgetStoredRecipients();
        await switchAccountAwayAndBack();

        expect(
          await reactions.retryableReactions(),
          hasLength(1),
          reason: 'precondition: the queued reaction survived the switch',
        );

        final filled = await reactions.backfillQueuedRecipients(
          ownerPubkey: _owner,
        );
        await reactions.retry(rumorId: rumorId, targetMessageAuthor: _peer);

        expect(filled, isZero);
        expect(wire, isEmpty);
      });

      test('works for the owner it is given after sign-out', () async {
        final group = await seedConversation([_owner, _peer, _peer2]);
        final rumorId = await queueReactionOffline(
          conversationId: group,
          targetMessageId: _peerMessageId,
          targetMessageAuthor: _peer,
        );
        await forgetStoredRecipients();

        reactions.clearCredentials();
        final filled = await reactions.backfillQueuedRecipients(
          ownerPubkey: _owner,
        );
        reactions.setCredentials(
          userPubkey: _owner,
          messageService: messageService,
        );
        await switchAccountAwayAndBack();
        await reactions.retry(rumorId: rumorId, targetMessageAuthor: _peer);

        expect(filled, equals(1));
        expect(
          recipientsOf(EventKind.reaction),
          unorderedEquals([_peer, _peer2]),
        );
      });

      test(
        'works for the owner it is given after sign-out, from a 1:1 with the '
        'author',
        () async {
          final direct = await seedConversation([_owner, _peer]);
          final rumorId = await queueReactionOffline(
            conversationId: direct,
            targetMessageId: _peerMessageId,
            targetMessageAuthor: _peer,
          );
          await forgetStoredRecipients();
          await switchAccountAwayAndBack();

          reactions.clearCredentials();
          final filled = await reactions.backfillQueuedRecipients(
            ownerPubkey: _owner,
          );
          final row = await reactionsDao.getById(
            id: rumorId,
            ownerPubkey: _owner,
          );

          expect(filled, equals(1));
          expect(row!.recipientPubkeys, equals(jsonEncode([_peer])));
        },
      );

      test(
        'works for the owner it is given after sign-out, from the message the '
        'reaction is on',
        () async {
          final group = await seedConversation([_owner, _peer, _peer2]);
          final rumorId = await queueReactionOffline(
            conversationId: group,
            targetMessageId: _peerMessageId,
            targetMessageAuthor: _peer,
          );
          await forgetStoredRecipients();
          await switchAccountAwayAndBack();
          final direct = await seedConversation([_owner, _peer]);
          await messagesDao.insertMessage(
            id: _peerMessageId,
            conversationId: direct,
            senderPubkey: _peer,
            content: 'hello',
            createdAt: 1700000001,
            giftWrapId: '8' * 64,
            ownerPubkey: _owner,
            tagsJson: jsonEncode([
              ['p', _owner],
              ['p', _peer2],
            ]),
          );

          reactions.clearCredentials();
          final filled = await reactions.backfillQueuedRecipients(
            ownerPubkey: _owner,
          );
          final row = await reactionsDao.getById(
            id: rumorId,
            ownerPubkey: _owner,
          );

          expect(filled, equals(1));
          expect(
            jsonDecode(row!.recipientPubkeys!) as List<dynamic>,
            unorderedEquals([_peer, _peer2]),
          );
        },
      );

      test(
        'post-auth maintenance completes when the backfill throws',
        () async {
          final direct = await seedConversation([_owner, _peer]);
          final failing = _MockReactionsRepository();
          when(
            () => failing.purgeStrandedByRemoval(ownerPubkey: _owner),
          ).thenAnswer((_) async => 0);
          when(
            () => failing.backfillQueuedRecipients(ownerPubkey: _owner),
          ).thenThrow(StateError('database is locked'));

          // getConversations waits for post-auth maintenance.
          final conversations = await DmRepository(
            nostrClient: _MockNostrClient(),
            directMessagesDao: messagesDao,
            conversationsDao: conversationsDao,
            removedConversationsDao: db.removedConversationsDao,
            userPubkey: _owner,
            reactionsRepository: failing,
          ).getConversations();

          expect(conversations.map((c) => c.id), equals([direct]));
          verify(
            () => failing.backfillQueuedRecipients(ownerPubkey: _owner),
          ).called(1);
        },
      );

      test('runs as part of post-auth maintenance', () async {
        final group = await seedConversation([_owner, _peer, _peer2]);
        final rumorId = await queueReactionOffline(
          conversationId: group,
          targetMessageId: _peerMessageId,
          targetMessageAuthor: _peer,
        );
        await forgetStoredRecipients();

        // getConversations waits for post-auth maintenance.
        await DmRepository(
          nostrClient: _MockNostrClient(),
          directMessagesDao: messagesDao,
          conversationsDao: conversationsDao,
          removedConversationsDao: db.removedConversationsDao,
          userPubkey: _owner,
          reactionsRepository: reactions,
        ).getConversations();
        await switchAccountAwayAndBack();
        await reactions.retry(rumorId: rumorId, targetMessageAuthor: _peer);

        expect(
          recipientsOf(EventKind.reaction),
          unorderedEquals([_peer, _peer2]),
        );
      });
    });
  });
}
