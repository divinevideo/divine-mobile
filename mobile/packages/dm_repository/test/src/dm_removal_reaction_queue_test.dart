// ABOUTME: Regression coverage for #7857 — removing a conversation must drop
// ABOUTME: its queued DM reactions and pending kind-5 removals, so the retry
// ABOUTME: sweep can never publish a gift wrap into a removed conversation.
// ABOUTME: Also covers rows stranded by a removal on an older build.

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

class _FakeEvent extends Fake implements Event {}

const _owner =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _peer =
    '2222222222222222222222222222222222222222222222222222222222222222';
const _peer2 =
    '3333333333333333333333333333333333333333333333333333333333333333';
const _targetMessageId =
    '4444444444444444444444444444444444444444444444444444444444444444';

void main() {
  setUpAll(() => registerFallbackValue(_FakeEvent()));

  group('removeConversation drops the reaction queue', () {
    late AppDatabase db;
    late DmReactionsDao reactionsDao;
    late ConversationsDao conversationsDao;
    late DirectMessagesDao messagesDao;
    late _MockNip17MessageService messageService;
    late DmReactionsRepository reactions;

    setUp(() {
      db = AppDatabase.test(NativeDatabase.memory());
      reactionsDao = DmReactionsDao(db);
      conversationsDao = ConversationsDao(db);
      messagesDao = DirectMessagesDao(db);
      messageService = _MockNip17MessageService();

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

      when(
        () => messageService.buildDeletionRumor(
          targetEventId: any(named: 'targetEventId'),
          targetKind: any(named: 'targetKind'),
        ),
      ).thenAnswer(
        (invocation) => Event(_owner, EventKind.eventDeletion, [
          ['e', invocation.namedArguments[#targetEventId] as String],
          ['k', '${invocation.namedArguments[#targetKind]}'],
        ], ''),
      );

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

    /// Wire layer that never confirms, so a publish leaves a durable
    /// retryable row behind — the offline case the sweep exists for.
    void stubOfflineWire() {
      when(
        () => messageService.sendRumor(
          rumorEvent: any(named: 'rumorEvent'),
          recipientPubkey: any(named: 'recipientPubkey'),
          targetRelays: any(named: 'targetRelays'),
          awaitRecipientOk: any(named: 'awaitRecipientOk'),
          onSelfWrapDue: any(named: 'onSelfWrapDue'),
          selfWrapOnSoftUnconfirmed: any(named: 'selfWrapOnSoftUnconfirmed'),
          recipientWrapBuildTimeout: any(named: 'recipientWrapBuildTimeout'),
          selfWrapBuildTimeout: any(named: 'selfWrapBuildTimeout'),
        ),
      ).thenAnswer((_) async => const NIP17SendResult.failure('offline'));
    }

    void stubLandingWire() {
      when(
        () => messageService.sendRumor(
          rumorEvent: any(named: 'rumorEvent'),
          recipientPubkey: any(named: 'recipientPubkey'),
          targetRelays: any(named: 'targetRelays'),
          awaitRecipientOk: any(named: 'awaitRecipientOk'),
          onSelfWrapDue: any(named: 'onSelfWrapDue'),
          selfWrapOnSoftUnconfirmed: any(named: 'selfWrapOnSoftUnconfirmed'),
          recipientWrapBuildTimeout: any(named: 'recipientWrapBuildTimeout'),
          selfWrapBuildTimeout: any(named: 'selfWrapBuildTimeout'),
        ),
      ).thenAnswer((invocation) async {
        final rumor = invocation.namedArguments[#rumorEvent] as Event;
        return NIP17SendResult.success(
          rumorEventId: rumor.id,
          messageEventId: 'wrap-${rumor.id}',
          recipientPubkey:
              invocation.namedArguments[#recipientPubkey] as String,
        );
      });
    }

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

    DmRepository buildDmRepository() => DmRepository(
      nostrClient: _MockNostrClient(),
      directMessagesDao: messagesDao,
      conversationsDao: conversationsDao,
      removedConversationsDao: db.removedConversationsDao,
      userPubkey: _owner,
      reactionsRepository: reactions,
    );

    /// Reproduce the on-disk state an older build left behind: the
    /// conversation and its messages are gone and the tombstone is recorded,
    /// but the reaction rows were never touched.
    Future<void> removeTheWayOldBuildsDid(
      String conversationId, {
      Duration ago = Duration.zero,
    }) async {
      final removedAt =
          (DateTime.now().millisecondsSinceEpoch ~/ 1000) - ago.inSeconds;
      await db.removedConversationsDao.record(
        conversationId: conversationId,
        ownerPubkey: _owner,
        removedAt: removedAt,
      );
      await messagesDao.deleteConversationMessages(
        conversationId,
        ownerPubkey: _owner,
      );
      await conversationsDao.deleteConversation(
        conversationId,
        ownerPubkey: _owner,
      );
    }

    test(
      'a reaction stranded by an older build is never swept up again',
      () async {
        stubOfflineWire();
        final conversationId = await seedConversation([_owner, _peer]);
        await reactions.publish(
          conversationId: conversationId,
          targetMessageId: _targetMessageId,
          targetMessageAuthor: _peer,
          emoji: '🔥',
        );
        expect(await reactions.retryableReactions(), hasLength(1));

        await removeTheWayOldBuildsDid(conversationId);

        expect(
          await reactions.retryableReactions(),
          isEmpty,
          reason:
              'the sweep re-derives the recipient from the reaction row, so a '
              'stranded row would publish to the counterparty of a '
              'conversation the user removed',
        );
      },
    );

    test('post-auth maintenance reclaims the stranded rows', () async {
      stubOfflineWire();
      final conversationId = await seedConversation([_owner, _peer]);
      await reactions.publish(
        conversationId: conversationId,
        targetMessageId: _targetMessageId,
        targetMessageAuthor: _peer,
        emoji: '🔥',
      );
      final stranded = (await reactionsDao.getRetryableOwnReactions(
        ownerPubkey: _owner,
      )).single.id;
      await removeTheWayOldBuildsDid(conversationId);
      expect(
        await reactionsDao.getById(id: stranded, ownerPubkey: _owner),
        isNotNull,
        reason: 'the older build left the row on disk',
      );

      final purged = await reactions.purgeStrandedByRemoval(
        ownerPubkey: _owner,
      );

      expect(purged, equals(1));
      expect(
        await reactionsDao.getById(id: stranded, ownerPubkey: _owner),
        isNull,
      );
    });

    test(
      'a reaction in a conversation recreated after removal still sends',
      () async {
        stubOfflineWire();
        final conversationId = await seedConversation([_owner, _peer]);
        // Removed a while back, so the new reaction is unambiguously later —
        // `removed_at` has second granularity and the rule suppresses ties.
        await removeTheWayOldBuildsDid(
          conversationId,
          ago: const Duration(minutes: 1),
        );

        // The counterparty writes again, so the thread comes back.
        await seedConversation([_owner, _peer]);
        await reactions.publish(
          conversationId: conversationId,
          targetMessageId: _targetMessageId,
          targetMessageAuthor: _peer,
          emoji: '🔥',
        );

        expect(
          await reactions.retryableReactions(),
          hasLength(1),
          reason:
              'the tombstone outlives the conversation row on purpose; only '
              'reactions from the removed era are suppressed',
        );
        expect(
          await reactions.purgeStrandedByRemoval(ownerPubkey: _owner),
          isZero,
        );
      },
    );

    test('a queued reaction is not retryable after removal', () async {
      stubOfflineWire();
      final conversationId = await seedConversation([_owner, _peer]);
      final result = await reactions.publish(
        conversationId: conversationId,
        targetMessageId: _targetMessageId,
        targetMessageAuthor: _peer,
        emoji: '🔥',
      );
      expect(result.success, isFalse);
      expect(
        await reactionsDao.getRetryableOwnReactions(ownerPubkey: _owner),
        hasLength(1),
        reason: 'the offline publish must leave a durable retryable row',
      );

      await buildDmRepository().removeConversation(conversationId);

      expect(
        await reactionsDao.getRetryableOwnReactions(ownerPubkey: _owner),
        isEmpty,
        reason:
            'the sweep must find nothing to publish into a removed '
            'conversation',
      );
    });

    test('a pending kind-5 removal is not retryable after removal', () async {
      stubLandingWire();
      final conversationId = await seedConversation([_owner, _peer]);
      final result = await reactions.publish(
        conversationId: conversationId,
        targetMessageId: _targetMessageId,
        targetMessageAuthor: _peer,
        emoji: '🔥',
      );
      expect(result.success, isTrue);

      stubOfflineWire();
      await reactions.removeOwn(
        rumorId: result.rumorId,
        targetMessageAuthor: _peer,
      );
      expect(
        await reactionsDao.getRetryableOwnDeletions(ownerPubkey: _owner),
        hasLength(1),
      );

      await buildDmRepository().removeConversation(conversationId);

      expect(
        await reactionsDao.getRetryableOwnDeletions(ownerPubkey: _owner),
        isEmpty,
      );
    });

    test('removal keeps its owner snapshot when credentials clear', () async {
      stubOfflineWire();
      final conversationId = await seedConversation([_owner, _peer]);
      await reactions.publish(
        conversationId: conversationId,
        targetMessageId: _targetMessageId,
        targetMessageAuthor: _peer,
        emoji: '🔥',
      );
      expect(
        await reactionsDao.getRetryableOwnReactions(ownerPubkey: _owner),
        hasLength(1),
      );

      reactions.clearCredentials();
      await buildDmRepository().removeConversation(conversationId);

      expect(
        await reactionsDao.getRetryableOwnReactions(ownerPubkey: _owner),
        isEmpty,
      );
    });

    test(
      'removal drops received reactions too, not just own queued ones',
      () async {
        stubOfflineWire();
        final conversationId = await seedConversation([_owner, _peer]);
        await reactionsDao.upsertIncoming(
          id: '5' * 64,
          conversationId: conversationId,
          targetMessageId: _targetMessageId,
          targetMessageAuthor: _owner,
          reactorPubkey: _peer,
          emoji: '👍',
          createdAt: 1700000001,
          ownerPubkey: _owner,
          giftWrapId: '6' * 64,
        );

        await buildDmRepository().removeConversation(conversationId);

        expect(
          await reactionsDao.getById(id: '5' * 64, ownerPubkey: _owner),
          isNull,
        );
      },
    );

    test("removal leaves another conversation's queue untouched", () async {
      stubOfflineWire();
      final removed = await seedConversation([_owner, _peer]);
      final kept = await seedConversation([_owner, _peer2]);
      await reactions.publish(
        conversationId: removed,
        targetMessageId: _targetMessageId,
        targetMessageAuthor: _peer,
        emoji: '🔥',
      );
      await reactions.publish(
        conversationId: kept,
        targetMessageId: '7' * 64,
        targetMessageAuthor: _peer2,
        emoji: '🎉',
      );
      expect(
        await reactionsDao.getRetryableOwnReactions(ownerPubkey: _owner),
        hasLength(2),
      );

      await buildDmRepository().removeConversation(removed);

      final survivors = await reactionsDao.getRetryableOwnReactions(
        ownerPubkey: _owner,
      );
      expect(survivors, hasLength(1));
      expect(survivors.single.conversationId, kept);
    });

    test('removeConversations drops the queue for every id', () async {
      stubOfflineWire();
      final first = await seedConversation([_owner, _peer]);
      final second = await seedConversation([_owner, _peer2]);
      await reactions.publish(
        conversationId: first,
        targetMessageId: _targetMessageId,
        targetMessageAuthor: _peer,
        emoji: '🔥',
      );
      await reactions.publish(
        conversationId: second,
        targetMessageId: '7' * 64,
        targetMessageAuthor: _peer2,
        emoji: '🎉',
      );

      await buildDmRepository().removeConversations([first, second]);

      expect(
        await reactionsDao.getRetryableOwnReactions(ownerPubkey: _owner),
        isEmpty,
      );
    });

    test("another account's reactions survive this owner's removal", () async {
      stubOfflineWire();
      final conversationId = await seedConversation([_owner, _peer]);
      await reactionsDao.upsertIncoming(
        id: '8' * 64,
        conversationId: conversationId,
        targetMessageId: _targetMessageId,
        targetMessageAuthor: _peer,
        reactorPubkey: _peer,
        emoji: '👍',
        createdAt: 1700000002,
        ownerPubkey: _peer,
        giftWrapId: '9' * 64,
      );

      await buildDmRepository().removeConversation(conversationId);

      expect(
        await reactionsDao.getById(id: '8' * 64, ownerPubkey: _peer),
        isNotNull,
        reason: 'the delete is owner-scoped',
      );
    });
  });
}
