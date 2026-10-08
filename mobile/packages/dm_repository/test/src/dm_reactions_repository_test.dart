// ABOUTME: Unit tests for DmReactionsRepository.
// ABOUTME: Covers publish/retry/remove/receive flows plus wrapped kind-5
// ABOUTME: deletion handling and account-scoped watch behaviour.

import 'dart:async';
import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';

class _MockDmReactionsDao extends Mock implements DmReactionsDao {}

class _MockConversationsDao extends Mock implements ConversationsDao {}

class _MockDirectMessagesDao extends Mock implements DirectMessagesDao {}

class _MockNip17MessageService extends Mock implements NIP17MessageService {}

class _FakeEvent extends Fake implements Event {}

const _ownerPubkey =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
const _otherPubkey =
    'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';

/// The 1:1 between the owner and the other account. A real conversation id,
/// because with no conversation row to read the repository only accepts
/// recipients it can prove from one.
final String _conversationId = DmRepository.computeConversationId([
  _ownerPubkey,
  _otherPubkey,
]);
const _targetMessageId =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _reactionRumorId =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const _giftWrapId =
    'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';

/// A thread-root `e` tag a peer client may place AHEAD of the target,
/// and a mentioned `p` tag ahead of the target's author. NIP-25 puts the
/// real target last in each family, so these two exist to be ignored.
const _threadRootId =
    'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
const _mentionedPubkey =
    '1111111111111111111111111111111111111111111111111111111111111111';

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeEvent());
  });

  group(DmReactionsRepository, () {
    late _MockDmReactionsDao mockDao;
    late _MockNip17MessageService mockMessageService;
    late List<String> reporterSites;

    DmReactionsRepository createRepository({
      bool initialized = true,
      ConversationsDao? conversationsDao,
      DirectMessagesDao? directMessagesDao,
    }) {
      final repository = DmReactionsRepository(
        reactionsDao: mockDao,
        conversationsDao: conversationsDao,
        directMessagesDao: directMessagesDao,
        errorReporter: (_, _, {required site}) {
          reporterSites.add(site);
        },
      );
      if (initialized) {
        repository.setCredentials(
          userPubkey: _ownerPubkey,
          messageService: mockMessageService,
        );
      }
      return repository;
    }

    Event reactionRumor({
      String id = _reactionRumorId,
      String reactorPubkey = _ownerPubkey,
      String content = '🔥',
      List<List<String>>? tags,
      int createdAt = 1_700_000_000,
      int kind = EventKind.reaction,
    }) {
      return Event.fromJson({
        'id': id,
        'pubkey': reactorPubkey,
        'created_at': createdAt,
        'kind': kind,
        'tags':
            tags ??
            [
              ['e', _targetMessageId],
              ['p', _otherPubkey],
              ['k', EventKind.privateDirectMessage.toString()],
            ],
        'content': content,
        'sig': '',
      });
    }

    DmReactionRow makeRow({
      String id = _reactionRumorId,
      String? conversationId,
      String reactorPubkey = _ownerPubkey,
      String emoji = '🔥',
      String? giftWrapId,
      bool isDeleted = false,
      String? rumorEventJson,
      String? publishStatus,
      String targetAuthor = _otherPubkey,
      String targetMessageId = _targetMessageId,
      int createdAt = 1_700_000_000,
      String? recipientPubkeys,
    }) {
      return DmReactionRow(
        id: id,
        conversationId: conversationId ?? _conversationId,
        targetMessageId: targetMessageId,
        targetMessageAuthor: targetAuthor,
        reactorPubkey: reactorPubkey,
        emoji: emoji,
        createdAt: createdAt,
        giftWrapId: giftWrapId,
        ownerPubkey: _ownerPubkey,
        isDeleted: isDeleted,
        rumorEventJson: rumorEventJson,
        publishStatus: publishStatus,
        recipientPubkeys: recipientPubkeys,
      );
    }

    /// Stubs the queue row a retry or removal acts on: an own reaction sent to
    /// the other account.
    void stubQueuedRow({String? rumorEventJson, String? publishStatus}) {
      when(
        () => mockDao.getById(id: _reactionRumorId, ownerPubkey: _ownerPubkey),
      ).thenAnswer(
        (_) async => makeRow(
          rumorEventJson: rumorEventJson,
          publishStatus: publishStatus,
          recipientPubkeys: jsonEncode([_otherPubkey]),
        ),
      );
    }

    setUp(() {
      mockDao = _MockDmReactionsDao();
      mockMessageService = _MockNip17MessageService();
      reporterSites = <String>[];

      // Default: no row for getById. Tests that retry or remove a reaction
      // stub the row they act on.
      when(
        () => mockDao.getById(
          id: any(named: 'id'),
          ownerPubkey: any(named: 'ownerPubkey'),
        ),
      ).thenAnswer((_) async => null);
    });

    test('watchForConversation returns empty when uninitialized', () async {
      final repository = createRepository(initialized: false);

      await expectLater(
        repository.watchForConversation(_conversationId),
        emits(const <DmReaction>[]),
      );
    });

    test('clearCredentials resets initialization state', () {
      final repository = createRepository();

      expect(repository.isInitialized, isTrue);
      repository.clearCredentials();
      expect(repository.isInitialized, isFalse);
    });

    test('hasOutstandingOwnDeletion is false when uninitialized', () async {
      final repository = createRepository(initialized: false);

      expect(
        await repository.hasOutstandingOwnDeletion(
          targetMessageId: _targetMessageId,
        ),
        isFalse,
      );
      verifyNever(
        () => mockDao.hasOutstandingOwnDeletion(
          targetMessageId: any(named: 'targetMessageId'),
          ownerPubkey: any(named: 'ownerPubkey'),
        ),
      );
    });

    test(
      'hasOutstandingOwnDeletion delegates with the current owner',
      () async {
        when(
          () => mockDao.hasOutstandingOwnDeletion(
            targetMessageId: _targetMessageId,
            ownerPubkey: _ownerPubkey,
          ),
        ).thenAnswer((_) async => true);
        final repository = createRepository();

        expect(
          await repository.hasOutstandingOwnDeletion(
            targetMessageId: _targetMessageId,
          ),
          isTrue,
        );
      },
    );

    test('watchForConversation maps dao rows to models', () async {
      when(
        () => mockDao.watchForConversation(
          conversationId: _conversationId,
          ownerPubkey: _ownerPubkey,
        ),
      ).thenAnswer(
        (_) => Stream.value([
          makeRow(
            reactorPubkey: _otherPubkey,
            emoji: '😂',
            giftWrapId: _giftWrapId,
          ),
        ]),
      );

      final repository = createRepository();
      final reactions = await repository
          .watchForConversation(_conversationId)
          .first;

      expect(reactions, hasLength(1));
      expect(reactions.single.id, _reactionRumorId);
      expect(reactions.single.publishStatus, DmReactionPublishStatus.received);
    });

    test(
      'watchForConversation collapses duplicate live rows for one reactor, '
      'keeping the most recent',
      () async {
        // Cap-at-one violated in storage: the same reactor has three live
        // rows (a superseding kind-5 deletion never landed). The read layer
        // must collapse to the latest so the pill shows one avatar/emoji.
        when(
          () => mockDao.watchForConversation(
            conversationId: _conversationId,
            ownerPubkey: _ownerPubkey,
          ),
        ).thenAnswer(
          // All three are the owner (makeRow's default reactor).
          (_) => Stream.value([
            makeRow(id: 'a' * 64, createdAt: 1_700_000_001),
            makeRow(id: 'b' * 64, emoji: '😮', createdAt: 1_700_000_010),
            makeRow(id: 'c' * 64, emoji: '😂', createdAt: 1_700_000_020),
          ]),
        );

        final repository = createRepository();
        final reactions = await repository
            .watchForConversation(_conversationId)
            .first;

        expect(reactions, hasLength(1));
        expect(reactions.single.id, 'c' * 64);
        expect(reactions.single.emoji, '😂');
      },
    );

    test(
      'watchForConversation keeps distinct reactors and distinct messages '
      'separate',
      () async {
        const otherMessageId =
            'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
        when(
          () => mockDao.watchForConversation(
            conversationId: _conversationId,
            ownerPubkey: _ownerPubkey,
          ),
        ).thenAnswer(
          (_) => Stream.value([
            // Owner + the other participant on the same message → both kept.
            makeRow(id: 'a' * 64, createdAt: 1_700_000_001),
            makeRow(
              id: 'b' * 64,
              reactorPubkey: _otherPubkey,
              emoji: '😂',
              createdAt: 1_700_000_005,
            ),
            // Owner again, but a different message → kept (collapse is keyed
            // per message, not per reactor alone).
            makeRow(
              id: 'd' * 64,
              emoji: '😮',
              targetMessageId: otherMessageId,
              createdAt: 1_700_000_010,
            ),
          ]),
        );

        final repository = createRepository();
        final reactions = await repository
            .watchForConversation(_conversationId)
            .first;

        expect(reactions, hasLength(3));
        // Ascending createdAt order preserved for the pill's reversed render.
        expect(
          reactions.map((r) => r.id).toList(),
          ['a' * 64, 'b' * 64, 'd' * 64],
        );
      },
    );

    test('publish returns failure when repository is uninitialized', () async {
      final repository = createRepository(initialized: false);

      final result = await repository.publish(
        conversationId: _conversationId,
        targetMessageId: _targetMessageId,
        targetMessageAuthor: _otherPubkey,
        emoji: '🔥',
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('not initialized'));
    });

    test(
      'publish inserts optimistic row and swaps to sent on success',
      () async {
        final rumor = reactionRumor();
        when(
          () => mockMessageService.buildRumor(
            recipientPubkey: _otherPubkey,
            content: '🔥',
            eventKind: EventKind.reaction,
            additionalTags: any(named: 'additionalTags'),
          ),
        ).thenReturn(rumor);
        when(
          () => mockDao.insertOwnReactionSuperseding(
            placeholderId: rumor.id,
            conversationId: _conversationId,
            targetMessageId: _targetMessageId,
            targetMessageAuthor: _otherPubkey,
            reactorPubkey: _ownerPubkey,
            emoji: '🔥',
            createdAt: rumor.createdAt,
            ownerPubkey: _ownerPubkey,
            rumorEventJson: jsonEncode(rumor.toJson()),
            recipientPubkeys: jsonEncode([_otherPubkey]),
          ),
        ).thenAnswer((_) async => <String>[]);
        when(
          () => mockMessageService.sendRumor(
            rumorEvent: rumor,
            recipientPubkey: _otherPubkey,
            awaitRecipientOk: any(named: 'awaitRecipientOk'),
          ),
        ).thenAnswer(
          (_) async => NIP17SendResult.success(
            rumorEventId: rumor.id,
            messageEventId: _giftWrapId,
            recipientPubkey: _otherPubkey,
          ),
        );
        when(
          () => mockDao.swapPlaceholderId(
            placeholderId: rumor.id,
            realRumorId: rumor.id,
            ownerPubkey: _ownerPubkey,
          ),
        ).thenAnswer((_) async {});

        final repository = createRepository();
        final result = await repository.publish(
          conversationId: _conversationId,
          targetMessageId: _targetMessageId,
          targetMessageAuthor: _otherPubkey,
          emoji: '🔥',
        );

        expect(result.success, isTrue);
        verify(
          () => mockDao.insertOwnReactionSuperseding(
            placeholderId: rumor.id,
            conversationId: _conversationId,
            targetMessageId: _targetMessageId,
            targetMessageAuthor: _otherPubkey,
            reactorPubkey: _ownerPubkey,
            emoji: '🔥',
            createdAt: rumor.createdAt,
            ownerPubkey: _ownerPubkey,
            rumorEventJson: jsonEncode(rumor.toJson()),
            recipientPubkeys: jsonEncode([_otherPubkey]),
          ),
        ).called(1);
        verify(
          () => mockDao.swapPlaceholderId(
            placeholderId: rumor.id,
            realRumorId: rumor.id,
            ownerPubkey: _ownerPubkey,
          ),
        ).called(1);
        // The reaction send opts into NIP-20 OK-confirmation so a flaky
        // relay's frame-accept false positive can't mark it delivered.
        verify(
          () => mockMessageService.sendRumor(
            rumorEvent: rumor,
            recipientPubkey: _otherPubkey,
            awaitRecipientOk: true,
          ),
        ).called(1);
      },
    );

    test(
      'publish supersedes a prior reaction DURABLY: records a '
      'deletion_pending row for it and OK-confirms the kind-5, so a '
      'flaky/offline relay can no longer strand the old emoji',
      () async {
        const priorReactionId =
            '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
        final rumor = reactionRumor();
        final deletionRumor = reactionRumor(
          id: _giftWrapId,
          content: '',
          kind: EventKind.eventDeletion,
          tags: [
            ['e', priorReactionId],
            ['k', EventKind.reaction.toString()],
          ],
        );
        when(
          () => mockMessageService.buildRumor(
            recipientPubkey: any(named: 'recipientPubkey'),
            content: '🔥',
            eventKind: EventKind.reaction,
            additionalTags: any(named: 'additionalTags'),
          ),
        ).thenReturn(rumor);
        when(
          () => mockDao.insertOwnReactionSuperseding(
            placeholderId: any(named: 'placeholderId'),
            conversationId: any(named: 'conversationId'),
            targetMessageId: any(named: 'targetMessageId'),
            targetMessageAuthor: any(named: 'targetMessageAuthor'),
            reactorPubkey: any(named: 'reactorPubkey'),
            emoji: any(named: 'emoji'),
            createdAt: any(named: 'createdAt'),
            ownerPubkey: any(named: 'ownerPubkey'),
            rumorEventJson: any(named: 'rumorEventJson'),
            recipientPubkeys: any(named: 'recipientPubkeys'),
          ),
        ).thenAnswer((_) async => <String>[priorReactionId]);
        when(
          () => mockMessageService.buildRumor(
            recipientPubkey: any(named: 'recipientPubkey'),
            content: '',
            eventKind: EventKind.eventDeletion,
            additionalTags: any(named: 'additionalTags'),
          ),
        ).thenReturn(deletionRumor);
        when(
          () => mockDao.markOwnDeletionPending(
            id: any(named: 'id'),
            ownerPubkey: any(named: 'ownerPubkey'),
            deletionRumorJson: any(named: 'deletionRumorJson'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockDao.markDeletionSent(
            id: any(named: 'id'),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockMessageService.sendRumor(
            rumorEvent: any(named: 'rumorEvent'),
            recipientPubkey: any(named: 'recipientPubkey'),
            awaitRecipientOk: any(named: 'awaitRecipientOk'),
          ),
        ).thenAnswer(
          (_) async => NIP17SendResult.success(
            rumorEventId: rumor.id,
            messageEventId: _giftWrapId,
            recipientPubkey: _otherPubkey,
          ),
        );
        when(
          () => mockDao.swapPlaceholderId(
            placeholderId: any(named: 'placeholderId'),
            realRumorId: any(named: 'realRumorId'),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer((_) async {});

        final repository = createRepository();
        final result = await repository.publish(
          conversationId: _conversationId,
          targetMessageId: _targetMessageId,
          targetMessageAuthor: _otherPubkey,
          emoji: '🔥',
        );
        // The kind-5 drive fires via unawaited; let it run.
        await Future<void>.delayed(Duration.zero);

        expect(result.success, isTrue);
        // The superseded emoji's removal is recorded as a durable
        // deletion_pending row (the retry sweep's recovery hook), storing the
        // exact kind-5 rumor keyed by the prior reaction id.
        verify(
          () => mockDao.markOwnDeletionPending(
            id: priorReactionId,
            ownerPubkey: _ownerPubkey,
            deletionRumorJson: jsonEncode(deletionRumor.toJson()),
          ),
        ).called(1);
        // The kind-5 now OK-confirms (durable path), not best-effort
        // frame-accept.
        verify(
          () => mockMessageService.sendRumor(
            rumorEvent: deletionRumor,
            recipientPubkey: any(named: 'recipientPubkey'),
            awaitRecipientOk: true,
          ),
        ).called(1);
        // Confirmed delivery clears the pending marker to terminal.
        verify(
          () => mockDao.markDeletionSent(
            id: priorReactionId,
            ownerPubkey: _ownerPubkey,
          ),
        ).called(1);
      },
    );

    group('publish superseding a prior reaction it cannot fully read or '
        'record', () {
      const priorReactionId =
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
      late Event rumor;
      late Event deletionRumor;

      setUp(() {
        rumor = reactionRumor();
        deletionRumor = reactionRumor(
          id: _giftWrapId,
          content: '',
          kind: EventKind.eventDeletion,
          tags: [
            ['e', priorReactionId],
            ['k', EventKind.reaction.toString()],
          ],
        );
      });

      /// Stubs an emoji swap whose new reaction reaches the other account and
      /// supersedes [priorReactionId].
      void stubSwap() {
        when(
          () => mockMessageService.buildRumor(
            recipientPubkey: _otherPubkey,
            content: '🔥',
            eventKind: EventKind.reaction,
            additionalTags: any(named: 'additionalTags'),
          ),
        ).thenReturn(rumor);
        when(
          () => mockDao.insertOwnReactionSuperseding(
            placeholderId: any(named: 'placeholderId'),
            conversationId: any(named: 'conversationId'),
            targetMessageId: any(named: 'targetMessageId'),
            targetMessageAuthor: any(named: 'targetMessageAuthor'),
            reactorPubkey: any(named: 'reactorPubkey'),
            emoji: any(named: 'emoji'),
            createdAt: any(named: 'createdAt'),
            ownerPubkey: any(named: 'ownerPubkey'),
            rumorEventJson: any(named: 'rumorEventJson'),
            recipientPubkeys: any(named: 'recipientPubkeys'),
          ),
        ).thenAnswer((_) async => <String>[priorReactionId]);
        when(
          () => mockMessageService.buildRumor(
            recipientPubkey: any(named: 'recipientPubkey'),
            content: '',
            eventKind: EventKind.eventDeletion,
            additionalTags: any(named: 'additionalTags'),
          ),
        ).thenReturn(deletionRumor);
        when(
          () => mockDao.markOwnDeletionPending(
            id: priorReactionId,
            ownerPubkey: _ownerPubkey,
            deletionRumorJson: any(named: 'deletionRumorJson'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockMessageService.sendRumor(
            rumorEvent: any(named: 'rumorEvent'),
            recipientPubkey: _otherPubkey,
            awaitRecipientOk: any(named: 'awaitRecipientOk'),
          ),
        ).thenAnswer(
          (_) async => NIP17SendResult.success(
            rumorEventId: rumor.id,
            messageEventId: _giftWrapId,
            recipientPubkey: _otherPubkey,
          ),
        );
        when(
          () => mockDao.swapPlaceholderId(
            placeholderId: any(named: 'placeholderId'),
            realRumorId: any(named: 'realRumorId'),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer((_) async {});
      }

      Future<DmReactionPublishResult> swap(DmReactionsRepository repository) {
        return repository.publish(
          conversationId: _conversationId,
          targetMessageId: _targetMessageId,
          targetMessageAuthor: _otherPubkey,
          emoji: '🔥',
        );
      }

      /// The prior's removal is recorded for the retry sweep, and not sent.
      void verifyRemovalHeld() {
        verify(
          () => mockDao.markOwnDeletionPending(
            id: priorReactionId,
            ownerPubkey: _ownerPubkey,
            deletionRumorJson: any(named: 'deletionRumorJson'),
          ),
        ).called(1);
        verifyNever(
          () => mockMessageService.sendRumor(
            rumorEvent: deletionRumor,
            recipientPubkey: any(named: 'recipientPubkey'),
            awaitRecipientOk: any(named: 'awaitRecipientOk'),
          ),
        );
      }

      test(
        'holds its removal, and reports, when its row fails to read',
        () async {
          stubSwap();
          when(
            () =>
                mockDao.getById(id: priorReactionId, ownerPubkey: _ownerPubkey),
          ).thenThrow(StateError('database is locked'));

          final result = await swap(createRepository());
          await pumpEventQueue();

          expect(result.success, isTrue);
          expect(
            reporterSites,
            equals([
              DmReactionsRepositoryReportableSites.publishSupersedeRecipients,
            ]),
          );
          verifyRemovalHeld();
        },
      );

      test(
        'holds its removal, and records no recipients for it, when the '
        'conversation it came from fails to read',
        () async {
          final priorConversationId = '9' * 64;
          stubSwap();
          when(
            () =>
                mockDao.getById(id: priorReactionId, ownerPubkey: _ownerPubkey),
          ).thenAnswer(
            (_) async => makeRow(
              id: priorReactionId,
              conversationId: priorConversationId,
              publishStatus: 'sent',
            ),
          );
          final mockConversationsDao = _MockConversationsDao();
          when(
            () => mockConversationsDao.getConversation(
              _conversationId,
              ownerPubkey: _ownerPubkey,
            ),
          ).thenAnswer((_) async => null);
          when(
            () => mockConversationsDao.getConversation(
              priorConversationId,
              ownerPubkey: _ownerPubkey,
            ),
          ).thenThrow(StateError('database is locked'));

          final result = await swap(
            createRepository(conversationsDao: mockConversationsDao),
          );
          await pumpEventQueue();

          expect(result.success, isTrue);
          expect(
            reporterSites,
            equals([
              DmReactionsRepositoryReportableSites
                  .wrapRecipientsConversationRead,
            ]),
          );
          verifyRemovalHeld();
          verifyNever(
            () => mockDao.setRecipientPubkeysIfMissing(
              id: any(named: 'id'),
              ownerPubkey: any(named: 'ownerPubkey'),
              conversationId: any(named: 'conversationId'),
              recipientPubkeys: any(named: 'recipientPubkeys'),
            ),
          );
        },
      );

      test(
        'holds its removal, and records no recipients for it, when the message '
        'it reacts to fails to read',
        () async {
          final priorConversationId = '9' * 64;
          stubSwap();
          when(
            () =>
                mockDao.getById(id: priorReactionId, ownerPubkey: _ownerPubkey),
          ).thenAnswer(
            (_) async => makeRow(
              id: priorReactionId,
              conversationId: priorConversationId,
              publishStatus: 'sent',
            ),
          );
          final mockConversationsDao = _MockConversationsDao();
          when(
            () => mockConversationsDao.getConversation(
              any(),
              ownerPubkey: _ownerPubkey,
            ),
          ).thenAnswer((_) async => null);
          final mockMessagesDao = _MockDirectMessagesDao();
          when(
            () => mockMessagesDao.getMessageById(
              _targetMessageId,
              ownerPubkey: _ownerPubkey,
            ),
          ).thenThrow(StateError('database is locked'));

          final result = await swap(
            createRepository(
              conversationsDao: mockConversationsDao,
              directMessagesDao: mockMessagesDao,
            ),
          );
          await pumpEventQueue();

          expect(result.success, isTrue);
          expect(
            reporterSites,
            equals([
              DmReactionsRepositoryReportableSites
                  .wrapRecipientsTargetMessageRead,
            ]),
          );
          verifyRemovalHeld();
          verifyNever(
            () => mockDao.setRecipientPubkeysIfMissing(
              id: any(named: 'id'),
              ownerPubkey: any(named: 'ownerPubkey'),
              conversationId: any(named: 'conversationId'),
              recipientPubkeys: any(named: 'recipientPubkeys'),
            ),
          );
        },
      );

      test(
        'sends its removal to everyone it may have reached, and records them, '
        'when its conversation fails to read but its 1:1 can still be proven',
        () async {
          final thirdPubkey = '3' * 64;
          final groupConversationId = DmRepository.computeConversationId([
            _ownerPubkey,
            _otherPubkey,
            thirdPubkey,
          ]);
          stubSwap();
          when(
            () => mockMessageService.sendRumor(
              rumorEvent: any(named: 'rumorEvent'),
              recipientPubkey: thirdPubkey,
              awaitRecipientOk: any(named: 'awaitRecipientOk'),
            ),
          ).thenAnswer(
            (_) async => NIP17SendResult.success(
              rumorEventId: rumor.id,
              messageEventId: _giftWrapId,
              recipientPubkey: thirdPubkey,
            ),
          );
          when(
            () => mockDao.markDeletionSent(
              id: priorReactionId,
              ownerPubkey: _ownerPubkey,
            ),
          ).thenAnswer((_) async {});
          when(
            () =>
                mockDao.getById(id: priorReactionId, ownerPubkey: _ownerPubkey),
          ).thenAnswer(
            (_) async => makeRow(id: priorReactionId, publishStatus: 'sent'),
          );
          when(
            () => mockDao.setRecipientPubkeysIfMissing(
              id: any(named: 'id'),
              ownerPubkey: any(named: 'ownerPubkey'),
              conversationId: any(named: 'conversationId'),
              recipientPubkeys: any(named: 'recipientPubkeys'),
            ),
          ).thenAnswer((_) async => 1);
          final mockConversationsDao = _MockConversationsDao();
          when(
            () => mockConversationsDao.getConversation(
              groupConversationId,
              ownerPubkey: _ownerPubkey,
            ),
          ).thenAnswer(
            (_) async => ConversationRow(
              id: groupConversationId,
              participantPubkeys: jsonEncode([
                _ownerPubkey,
                _otherPubkey,
                thirdPubkey,
              ]),
              isGroup: true,
              isRead: true,
              currentUserHasSent: true,
              createdAt: 1700000000,
              ownerPubkey: _ownerPubkey,
            ),
          );
          when(
            () => mockConversationsDao.getConversation(
              _conversationId,
              ownerPubkey: _ownerPubkey,
            ),
          ).thenThrow(StateError('database is locked'));

          final result =
              await createRepository(
                conversationsDao: mockConversationsDao,
              ).publish(
                conversationId: groupConversationId,
                targetMessageId: _targetMessageId,
                targetMessageAuthor: _otherPubkey,
                emoji: '🔥',
              );
          await pumpEventQueue();

          expect(result.success, isTrue);
          final removalRecipients = verify(
            () => mockMessageService.sendRumor(
              rumorEvent: deletionRumor,
              recipientPubkey: captureAny(named: 'recipientPubkey'),
              awaitRecipientOk: any(named: 'awaitRecipientOk'),
            ),
          ).captured;
          expect(
            removalRecipients,
            unorderedEquals([_otherPubkey, thirdPubkey]),
          );
          final recorded = verify(
            () => mockDao.setRecipientPubkeysIfMissing(
              id: priorReactionId,
              ownerPubkey: _ownerPubkey,
              conversationId: _conversationId,
              recipientPubkeys: captureAny(named: 'recipientPubkeys'),
            ),
          ).captured;
          expect(
            jsonDecode(recorded.single as String) as List<dynamic>,
            unorderedEquals([_otherPubkey, thirdPubkey]),
          );
        },
      );

      test(
        'still sends the new reaction, and reports once, when recording its '
        'removal fails',
        () async {
          stubSwap();
          when(
            () =>
                mockDao.getById(id: priorReactionId, ownerPubkey: _ownerPubkey),
          ).thenAnswer(
            (_) async => makeRow(
              id: priorReactionId,
              publishStatus: 'sent',
              recipientPubkeys: jsonEncode([_otherPubkey]),
            ),
          );
          when(
            () => mockDao.markOwnDeletionPending(
              id: priorReactionId,
              ownerPubkey: _ownerPubkey,
              deletionRumorJson: any(named: 'deletionRumorJson'),
            ),
          ).thenThrow(Exception('disk I/O error'));

          final result = await swap(createRepository());
          await pumpEventQueue();

          expect(result.success, isTrue);
          expect(
            reporterSites,
            equals([
              DmReactionsRepositoryReportableSites.publishSupersedeDeletion,
            ]),
          );
          verify(
            () => mockMessageService.sendRumor(
              rumorEvent: rumor,
              recipientPubkey: _otherPubkey,
              awaitRecipientOk: any(named: 'awaitRecipientOk'),
            ),
          ).called(1);
          verifyNever(
            () => mockMessageService.sendRumor(
              rumorEvent: deletionRumor,
              recipientPubkey: any(named: 'recipientPubkey'),
              awaitRecipientOk: any(named: 'awaitRecipientOk'),
            ),
          );
        },
      );
    });

    test(
      'publish still sends a reaction it can prove is a 1:1, and reports, when '
      'the conversation fails to read',
      () async {
        final mockConversationsDao = _MockConversationsDao();
        when(
          () => mockConversationsDao.getConversation(
            _conversationId,
            ownerPubkey: _ownerPubkey,
          ),
        ).thenThrow(StateError('database is locked'));
        final rumor = reactionRumor();
        when(
          () => mockMessageService.buildRumor(
            recipientPubkey: _otherPubkey,
            content: '🔥',
            eventKind: EventKind.reaction,
            additionalTags: any(named: 'additionalTags'),
          ),
        ).thenReturn(rumor);
        when(
          () => mockDao.insertOwnReactionSuperseding(
            placeholderId: any(named: 'placeholderId'),
            conversationId: any(named: 'conversationId'),
            targetMessageId: any(named: 'targetMessageId'),
            targetMessageAuthor: any(named: 'targetMessageAuthor'),
            reactorPubkey: any(named: 'reactorPubkey'),
            emoji: any(named: 'emoji'),
            createdAt: any(named: 'createdAt'),
            ownerPubkey: any(named: 'ownerPubkey'),
            rumorEventJson: any(named: 'rumorEventJson'),
            recipientPubkeys: any(named: 'recipientPubkeys'),
          ),
        ).thenAnswer((_) async => <String>[]);
        when(
          () => mockMessageService.sendRumor(
            rumorEvent: rumor,
            recipientPubkey: _otherPubkey,
            awaitRecipientOk: any(named: 'awaitRecipientOk'),
          ),
        ).thenAnswer(
          (_) async => NIP17SendResult.success(
            rumorEventId: rumor.id,
            messageEventId: _giftWrapId,
            recipientPubkey: _otherPubkey,
          ),
        );
        when(
          () => mockDao.swapPlaceholderId(
            placeholderId: any(named: 'placeholderId'),
            realRumorId: any(named: 'realRumorId'),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer((_) async {});

        final result =
            await createRepository(
              conversationsDao: mockConversationsDao,
            ).publish(
              conversationId: _conversationId,
              targetMessageId: _targetMessageId,
              targetMessageAuthor: _otherPubkey,
              emoji: '🔥',
            );

        expect(result.success, isTrue);
        expect(
          reporterSites,
          equals([
            DmReactionsRepositoryReportableSites.wrapRecipientsConversationRead,
          ]),
        );
        verify(
          () => mockMessageService.sendRumor(
            rumorEvent: rumor,
            recipientPubkey: _otherPubkey,
            awaitRecipientOk: true,
          ),
        ).called(1);
      },
    );

    test(
      'publish queues the reaction for the account that started it when the '
      'session changes while its recipients are worked out',
      () async {
        const nextAccount =
            '2222222222222222222222222222222222222222222222222222222222222222';
        final mockConversationsDao = _MockConversationsDao();
        late final DmReactionsRepository repository;
        when(
          () => mockConversationsDao.getConversation(
            _conversationId,
            ownerPubkey: _ownerPubkey,
          ),
        ).thenAnswer((_) async {
          repository.setCredentials(
            userPubkey: nextAccount,
            messageService: mockMessageService,
          );
          return null;
        });
        final rumor = reactionRumor();
        when(
          () => mockMessageService.buildRumor(
            recipientPubkey: _otherPubkey,
            content: '🔥',
            eventKind: EventKind.reaction,
            additionalTags: any(named: 'additionalTags'),
          ),
        ).thenReturn(rumor);
        when(
          () => mockDao.insertOwnReactionSuperseding(
            placeholderId: any(named: 'placeholderId'),
            conversationId: any(named: 'conversationId'),
            targetMessageId: any(named: 'targetMessageId'),
            targetMessageAuthor: any(named: 'targetMessageAuthor'),
            reactorPubkey: any(named: 'reactorPubkey'),
            emoji: any(named: 'emoji'),
            createdAt: any(named: 'createdAt'),
            ownerPubkey: any(named: 'ownerPubkey'),
            rumorEventJson: any(named: 'rumorEventJson'),
            recipientPubkeys: any(named: 'recipientPubkeys'),
          ),
        ).thenAnswer((_) async => <String>[]);
        when(
          () => mockMessageService.sendRumor(
            rumorEvent: rumor,
            recipientPubkey: _otherPubkey,
            awaitRecipientOk: any(named: 'awaitRecipientOk'),
          ),
        ).thenAnswer((_) async => const NIP17SendResult.failure('offline'));
        when(
          () => mockDao.markFailed(
            placeholderId: any(named: 'placeholderId'),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer((_) async {});

        repository = createRepository(conversationsDao: mockConversationsDao);
        await repository.publish(
          conversationId: _conversationId,
          targetMessageId: _targetMessageId,
          targetMessageAuthor: _otherPubkey,
          emoji: '🔥',
        );

        verify(
          () => mockDao.insertOwnReactionSuperseding(
            placeholderId: rumor.id,
            conversationId: _conversationId,
            targetMessageId: _targetMessageId,
            targetMessageAuthor: _otherPubkey,
            reactorPubkey: _ownerPubkey,
            emoji: '🔥',
            createdAt: rumor.createdAt,
            ownerPubkey: _ownerPubkey,
            rumorEventJson: any(named: 'rumorEventJson'),
            recipientPubkeys: jsonEncode([_otherPubkey]),
          ),
        ).called(1);
        verify(
          () => mockDao.markFailed(
            placeholderId: rumor.id,
            ownerPubkey: _ownerPubkey,
          ),
        ).called(1);
      },
    );

    /// Stubs every write a send outcome can make on the queue row.
    void stubSettleWrites() {
      when(
        () => mockDao.swapPlaceholderId(
          placeholderId: any(named: 'placeholderId'),
          realRumorId: any(named: 'realRumorId'),
          ownerPubkey: any(named: 'ownerPubkey'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => mockDao.markBlocked(
          id: any(named: 'id'),
          ownerPubkey: any(named: 'ownerPubkey'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => mockDao.markPending(
          id: any(named: 'id'),
          ownerPubkey: any(named: 'ownerPubkey'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => mockDao.markFailed(
          placeholderId: any(named: 'placeholderId'),
          ownerPubkey: any(named: 'ownerPubkey'),
        ),
      ).thenAnswer((_) async {});
    }

    NIP17SendResult confirmedSend(Event rumor) => NIP17SendResult.success(
      rumorEventId: rumor.id,
      messageEventId: _giftWrapId,
      recipientPubkey: _otherPubkey,
    );

    void verifySent(Event rumor) => verify(
      () => mockDao.swapPlaceholderId(
        placeholderId: rumor.id,
        realRumorId: rumor.id,
        ownerPubkey: _ownerPubkey,
      ),
    ).called(1);

    void verifyBlocked(Event rumor) => verify(
      () => mockDao.markBlocked(id: rumor.id, ownerPubkey: _ownerPubkey),
    ).called(1);

    for (final (outcome, sendResult, verifyWrite)
        in <(String, NIP17SendResult Function(Event), void Function(Event))>[
          ('a confirmed send', confirmedSend, verifySent),
          (
            'a refused send',
            (_) => const NIP17SendResult.blocked('policy refused'),
            verifyBlocked,
          ),
          (
            'an unconfirmed send',
            (_) => const NIP17SendResult.failure(
              'no relay confirmed it',
              retryablePending: true,
            ),
            (rumor) => verify(
              () =>
                  mockDao.markPending(id: rumor.id, ownerPubkey: _ownerPubkey),
            ).called(1),
          ),
        ]) {
      test(
        'publish settles the row of the account that started it after '
        '$outcome, when the session changes while its recipients are worked '
        'out',
        () async {
          final nextAccount = '2' * 64;
          final mockConversationsDao = _MockConversationsDao();
          late final DmReactionsRepository repository;
          when(
            () => mockConversationsDao.getConversation(
              _conversationId,
              ownerPubkey: _ownerPubkey,
            ),
          ).thenAnswer((_) async {
            repository.setCredentials(
              userPubkey: nextAccount,
              messageService: mockMessageService,
            );
            return null;
          });
          final rumor = reactionRumor();
          when(
            () => mockMessageService.buildRumor(
              recipientPubkey: _otherPubkey,
              content: '🔥',
              eventKind: EventKind.reaction,
              additionalTags: any(named: 'additionalTags'),
            ),
          ).thenReturn(rumor);
          when(
            () => mockDao.insertOwnReactionSuperseding(
              placeholderId: any(named: 'placeholderId'),
              conversationId: any(named: 'conversationId'),
              targetMessageId: any(named: 'targetMessageId'),
              targetMessageAuthor: any(named: 'targetMessageAuthor'),
              reactorPubkey: any(named: 'reactorPubkey'),
              emoji: any(named: 'emoji'),
              createdAt: any(named: 'createdAt'),
              ownerPubkey: any(named: 'ownerPubkey'),
              rumorEventJson: any(named: 'rumorEventJson'),
              recipientPubkeys: any(named: 'recipientPubkeys'),
            ),
          ).thenAnswer((_) async => <String>[]);
          when(
            () => mockMessageService.sendRumor(
              rumorEvent: rumor,
              recipientPubkey: _otherPubkey,
              awaitRecipientOk: any(named: 'awaitRecipientOk'),
            ),
          ).thenAnswer((_) async => sendResult(rumor));
          stubSettleWrites();

          repository = createRepository(conversationsDao: mockConversationsDao);
          await repository.publish(
            conversationId: _conversationId,
            targetMessageId: _targetMessageId,
            targetMessageAuthor: _otherPubkey,
            emoji: '🔥',
          );

          verifyWrite(rumor);
        },
      );
    }

    test('publish marks failed when send returns failure', () async {
      final rumor = reactionRumor();
      when(
        () => mockMessageService.buildRumor(
          recipientPubkey: _otherPubkey,
          content: '🔥',
          eventKind: EventKind.reaction,
          additionalTags: any(named: 'additionalTags'),
        ),
      ).thenReturn(rumor);
      when(
        () => mockDao.insertOwnReactionSuperseding(
          placeholderId: rumor.id,
          conversationId: _conversationId,
          targetMessageId: _targetMessageId,
          targetMessageAuthor: _otherPubkey,
          reactorPubkey: _ownerPubkey,
          emoji: '🔥',
          createdAt: rumor.createdAt,
          ownerPubkey: _ownerPubkey,
          rumorEventJson: jsonEncode(rumor.toJson()),
          recipientPubkeys: jsonEncode([_otherPubkey]),
        ),
      ).thenAnswer((_) async => <String>[]);
      when(
        () => mockMessageService.sendRumor(
          rumorEvent: rumor,
          recipientPubkey: _otherPubkey,
          awaitRecipientOk: any(named: 'awaitRecipientOk'),
        ),
      ).thenAnswer((_) async => const NIP17SendResult.failure('relay down'));
      when(
        () => mockDao.markFailed(
          placeholderId: rumor.id,
          ownerPubkey: _ownerPubkey,
        ),
      ).thenAnswer((_) async {});

      final repository = createRepository();
      final result = await repository.publish(
        conversationId: _conversationId,
        targetMessageId: _targetMessageId,
        targetMessageAuthor: _otherPubkey,
        emoji: '🔥',
      );

      expect(result.success, isFalse);
      verify(
        () => mockDao.markFailed(
          placeholderId: rumor.id,
          ownerPubkey: _ownerPubkey,
        ),
      ).called(1);
    });

    test(
      'publish marks BLOCKED (terminal, non-retryable) when the send policy '
      'refuses the recipient — never failed/pending, so the retry sweep and '
      'a chip re-tap both leave it alone',
      () async {
        final rumor = reactionRumor();
        when(
          () => mockMessageService.buildRumor(
            recipientPubkey: _otherPubkey,
            content: '🔥',
            eventKind: EventKind.reaction,
            additionalTags: any(named: 'additionalTags'),
          ),
        ).thenReturn(rumor);
        when(
          () => mockDao.insertOwnReactionSuperseding(
            placeholderId: rumor.id,
            conversationId: _conversationId,
            targetMessageId: _targetMessageId,
            targetMessageAuthor: _otherPubkey,
            reactorPubkey: _ownerPubkey,
            emoji: '🔥',
            createdAt: rumor.createdAt,
            ownerPubkey: _ownerPubkey,
            rumorEventJson: jsonEncode(rumor.toJson()),
            recipientPubkeys: jsonEncode([_otherPubkey]),
          ),
        ).thenAnswer((_) async => <String>[]);
        when(
          () => mockMessageService.sendRumor(
            rumorEvent: rumor,
            recipientPubkey: _otherPubkey,
            awaitRecipientOk: any(named: 'awaitRecipientOk'),
          ),
        ).thenAnswer(
          (_) async => const NIP17SendResult.blocked('policy refused'),
        );
        when(
          () => mockDao.markBlocked(id: rumor.id, ownerPubkey: _ownerPubkey),
        ).thenAnswer((_) async {});

        final repository = createRepository();
        final result = await repository.publish(
          conversationId: _conversationId,
          targetMessageId: _targetMessageId,
          targetMessageAuthor: _otherPubkey,
          emoji: '🔥',
        );

        expect(result.success, isFalse);
        verify(
          () => mockDao.markBlocked(id: rumor.id, ownerPubkey: _ownerPubkey),
        ).called(1);
        verifyNever(
          () => mockDao.markFailed(
            placeholderId: any(named: 'placeholderId'),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        );
        verifyNever(
          () => mockDao.markPending(
            id: any(named: 'id'),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        );
      },
    );

    test(
      'publish contains a thrown send: marks failed and surfaces the error '
      'instead of leaking the exception',
      () async {
        final rumor = reactionRumor();
        when(
          () => mockMessageService.buildRumor(
            recipientPubkey: _otherPubkey,
            content: '🔥',
            eventKind: EventKind.reaction,
            additionalTags: any(named: 'additionalTags'),
          ),
        ).thenReturn(rumor);
        when(
          () => mockDao.insertOwnReactionSuperseding(
            placeholderId: rumor.id,
            conversationId: _conversationId,
            targetMessageId: _targetMessageId,
            targetMessageAuthor: _otherPubkey,
            reactorPubkey: _ownerPubkey,
            emoji: '🔥',
            createdAt: rumor.createdAt,
            ownerPubkey: _ownerPubkey,
            rumorEventJson: jsonEncode(rumor.toJson()),
            recipientPubkeys: jsonEncode([_otherPubkey]),
          ),
        ).thenAnswer((_) async => <String>[]);
        // A thrown send (not a returned NIP17SendFailure) must still flip the
        // chip to 'failed' and surface the error — the outer catch must never
        // let the exception escape to the caller.
        when(
          () => mockMessageService.sendRumor(
            rumorEvent: rumor,
            recipientPubkey: _otherPubkey,
            awaitRecipientOk: any(named: 'awaitRecipientOk'),
          ),
        ).thenThrow(StateError('socket boom'));
        when(
          () => mockDao.markFailed(
            placeholderId: rumor.id,
            ownerPubkey: _ownerPubkey,
          ),
        ).thenAnswer((_) async {});

        final repository = createRepository();
        final result = await repository.publish(
          conversationId: _conversationId,
          targetMessageId: _targetMessageId,
          targetMessageAuthor: _otherPubkey,
          emoji: '🔥',
        );

        expect(result.success, isFalse);
        expect(result.errorMessage, contains('socket boom'));
        verify(
          () => mockDao.markFailed(
            placeholderId: rumor.id,
            ownerPubkey: _ownerPubkey,
          ),
        ).called(1);
      },
    );

    test(
      'publish keeps the row pending (not failed) on an unconfirmed send',
      () async {
        final rumor = reactionRumor();
        when(
          () => mockMessageService.buildRumor(
            recipientPubkey: _otherPubkey,
            content: '🔥',
            eventKind: EventKind.reaction,
            additionalTags: any(named: 'additionalTags'),
          ),
        ).thenReturn(rumor);
        when(
          () => mockDao.insertOwnReactionSuperseding(
            placeholderId: rumor.id,
            conversationId: _conversationId,
            targetMessageId: _targetMessageId,
            targetMessageAuthor: _otherPubkey,
            reactorPubkey: _ownerPubkey,
            emoji: '🔥',
            createdAt: rumor.createdAt,
            ownerPubkey: _ownerPubkey,
            rumorEventJson: jsonEncode(rumor.toJson()),
            recipientPubkeys: jsonEncode([_otherPubkey]),
          ),
        ).thenAnswer((_) async => <String>[]);
        // Frame written, no relay OK within the window (no explicit rejection).
        when(
          () => mockMessageService.sendRumor(
            rumorEvent: rumor,
            recipientPubkey: _otherPubkey,
            awaitRecipientOk: any(named: 'awaitRecipientOk'),
          ),
        ).thenAnswer(
          (_) async => const NIP17SendResult.failure(
            'unconfirmed',
            retryablePending: true,
          ),
        );
        when(
          () => mockDao.markPending(id: rumor.id, ownerPubkey: _ownerPubkey),
        ).thenAnswer((_) async {});

        final repository = createRepository();
        final result = await repository.publish(
          conversationId: _conversationId,
          targetMessageId: _targetMessageId,
          targetMessageAuthor: _otherPubkey,
          emoji: '🔥',
        );

        expect(result.success, isFalse);
        // A durable row exists, so the cubit keeps the chip; and an unconfirmed
        // send is not proof of loss, so keep it pending+retryable — never the
        // red 'failed' state a re-tap could delete.
        expect(result.optimisticInsertSucceeded, isTrue);
        verify(
          () => mockDao.markPending(id: rumor.id, ownerPubkey: _ownerPubkey),
        ).called(1);
        verifyNever(
          () => mockDao.markFailed(
            placeholderId: any(named: 'placeholderId'),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        );
      },
    );

    test('publish reports optimistic insert failures', () async {
      final rumor = reactionRumor();
      when(
        () => mockMessageService.buildRumor(
          recipientPubkey: _otherPubkey,
          content: '🔥',
          eventKind: EventKind.reaction,
          additionalTags: any(named: 'additionalTags'),
        ),
      ).thenReturn(rumor);
      when(
        () => mockDao.insertOwnReactionSuperseding(
          placeholderId: any(named: 'placeholderId'),
          conversationId: any(named: 'conversationId'),
          targetMessageId: any(named: 'targetMessageId'),
          targetMessageAuthor: any(named: 'targetMessageAuthor'),
          reactorPubkey: any(named: 'reactorPubkey'),
          emoji: any(named: 'emoji'),
          createdAt: any(named: 'createdAt'),
          ownerPubkey: any(named: 'ownerPubkey'),
          rumorEventJson: any(named: 'rumorEventJson'),
          recipientPubkeys: any(named: 'recipientPubkeys'),
        ),
      ).thenThrow(StateError('insert failed'));

      final repository = createRepository();
      final result = await repository.publish(
        conversationId: _conversationId,
        targetMessageId: _targetMessageId,
        targetMessageAuthor: _otherPubkey,
        emoji: '🔥',
      );

      expect(result.success, isFalse);
      expect(
        reporterSites,
        contains(DmReactionsRepositoryReportableSites.publishOptimisticInsert),
      );
    });

    test('retry replays stored rumor and clears failure on success', () async {
      final rumor = reactionRumor();
      stubQueuedRow(
        rumorEventJson: jsonEncode(rumor.toJson()),
        publishStatus: 'failed',
      );
      when(
        () => mockDao.markPending(id: rumor.id, ownerPubkey: _ownerPubkey),
      ).thenAnswer((_) async {});
      when(
        () => mockMessageService.sendRumor(
          rumorEvent: any(named: 'rumorEvent'),
          recipientPubkey: _otherPubkey,
          awaitRecipientOk: any(named: 'awaitRecipientOk'),
        ),
      ).thenAnswer(
        (_) async => NIP17SendResult.success(
          rumorEventId: rumor.id,
          messageEventId: _giftWrapId,
          recipientPubkey: _otherPubkey,
        ),
      );
      when(
        () => mockDao.swapPlaceholderId(
          placeholderId: rumor.id,
          realRumorId: rumor.id,
          ownerPubkey: _ownerPubkey,
        ),
      ).thenAnswer((_) async {});

      final repository = createRepository();
      final result = await repository.retry(
        rumorId: rumor.id,
        targetMessageAuthor: _otherPubkey,
      );

      expect(result.success, isTrue);
      verify(
        () => mockDao.markPending(id: rumor.id, ownerPubkey: _ownerPubkey),
      ).called(1);
      verify(
        () => mockDao.swapPlaceholderId(
          placeholderId: rumor.id,
          realRumorId: rumor.id,
          ownerPubkey: _ownerPubkey,
        ),
      ).called(1);
    });

    test('retry sends nothing when its row holds no rumor', () async {
      stubQueuedRow(publishStatus: 'sent');

      final repository = createRepository();
      final result = await repository.retry(
        rumorId: _reactionRumorId,
        targetMessageAuthor: _otherPubkey,
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('No stored rumor'));
      verifyNever(
        () => mockDao.markPending(
          id: any(named: 'id'),
          ownerPubkey: any(named: 'ownerPubkey'),
        ),
      );
      verifyNever(
        () => mockMessageService.sendRumor(
          rumorEvent: any(named: 'rumorEvent'),
          recipientPubkey: any(named: 'recipientPubkey'),
          awaitRecipientOk: any(named: 'awaitRecipientOk'),
        ),
      );
    });

    test(
      'retry settles the row of the account that started it when the session '
      'changes during the send',
      () async {
        const nextAccount =
            '2222222222222222222222222222222222222222222222222222222222222222';
        final rumor = reactionRumor();
        stubQueuedRow(
          rumorEventJson: jsonEncode(rumor.toJson()),
          publishStatus: 'failed',
        );
        when(
          () => mockDao.markPending(
            id: any(named: 'id'),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockDao.markFailed(
            placeholderId: any(named: 'placeholderId'),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer((_) async {});
        final repository = createRepository();
        when(
          () => mockMessageService.sendRumor(
            rumorEvent: any(named: 'rumorEvent'),
            recipientPubkey: _otherPubkey,
            awaitRecipientOk: any(named: 'awaitRecipientOk'),
          ),
        ).thenAnswer((_) async {
          repository.setCredentials(
            userPubkey: nextAccount,
            messageService: mockMessageService,
          );
          return const NIP17SendResult.failure('relay down');
        });

        await repository.retry(
          rumorId: rumor.id,
          targetMessageAuthor: _otherPubkey,
        );

        verify(
          () => mockDao.markFailed(
            placeholderId: rumor.id,
            ownerPubkey: _ownerPubkey,
          ),
        ).called(1);
      },
    );

    for (final (outcome, sendResult, verifyWrite)
        in <(String, NIP17SendResult Function(Event), void Function(Event))>[
          ('a confirmed send', confirmedSend, verifySent),
          (
            'a refused send',
            (_) => const NIP17SendResult.blocked('policy refused'),
            verifyBlocked,
          ),
          (
            'a rejected send',
            (_) => const NIP17SendResult.failure('relay down'),
            (rumor) => verify(
              () => mockDao.markFailed(
                placeholderId: rumor.id,
                ownerPubkey: _ownerPubkey,
              ),
            ).called(1),
          ),
        ]) {
      test(
        'retry settles the row of the account that started it after '
        '$outcome, when the session changes while its row is read',
        () async {
          final nextAccount = '2' * 64;
          final rumor = reactionRumor();
          final repository = createRepository();
          when(
            () => mockDao.getById(id: rumor.id, ownerPubkey: _ownerPubkey),
          ).thenAnswer((_) async {
            repository.setCredentials(
              userPubkey: nextAccount,
              messageService: mockMessageService,
            );
            return makeRow(
              publishStatus: 'failed',
              rumorEventJson: jsonEncode(rumor.toJson()),
              recipientPubkeys: jsonEncode([_otherPubkey]),
            );
          });
          when(
            () => mockMessageService.sendRumor(
              rumorEvent: any(named: 'rumorEvent'),
              recipientPubkey: _otherPubkey,
              awaitRecipientOk: any(named: 'awaitRecipientOk'),
            ),
          ).thenAnswer((_) async => sendResult(rumor));
          stubSettleWrites();

          await repository.retry(
            rumorId: rumor.id,
            targetMessageAuthor: _otherPubkey,
          );

          verify(
            () => mockDao.markPending(id: rumor.id, ownerPubkey: _ownerPubkey),
          ).called(1);
          verifyWrite(rumor);
        },
      );
    }

    test(
      'removeOwn records the removal for the account that started it when the '
      'session changes while its row is read',
      () async {
        const nextAccount =
            '2222222222222222222222222222222222222222222222222222222222222222';
        final deletionRumor = reactionRumor(
          id: _giftWrapId,
          content: '',
          kind: EventKind.eventDeletion,
          tags: [
            ['e', _reactionRumorId],
            ['k', EventKind.reaction.toString()],
          ],
        );
        final repository = createRepository();
        when(
          () =>
              mockDao.getById(id: _reactionRumorId, ownerPubkey: _ownerPubkey),
        ).thenAnswer((_) async {
          repository.setCredentials(
            userPubkey: nextAccount,
            messageService: mockMessageService,
          );
          return makeRow(
            publishStatus: 'sent',
            recipientPubkeys: jsonEncode([_otherPubkey]),
          );
        });
        when(
          () => mockMessageService.buildRumor(
            recipientPubkey: _otherPubkey,
            content: '',
            eventKind: EventKind.eventDeletion,
            additionalTags: any(named: 'additionalTags'),
          ),
        ).thenReturn(deletionRumor);
        when(
          () => mockDao.markOwnDeletionPending(
            id: any(named: 'id'),
            ownerPubkey: any(named: 'ownerPubkey'),
            deletionRumorJson: any(named: 'deletionRumorJson'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockMessageService.sendRumor(
            rumorEvent: deletionRumor,
            recipientPubkey: _otherPubkey,
            awaitRecipientOk: any(named: 'awaitRecipientOk'),
          ),
        ).thenAnswer((_) async => const NIP17SendResult.failure('offline'));

        await repository.removeOwn(
          rumorId: _reactionRumorId,
          targetMessageAuthor: _otherPubkey,
        );
        await pumpEventQueue();

        verify(
          () => mockDao.markOwnDeletionPending(
            id: _reactionRumorId,
            ownerPubkey: _ownerPubkey,
            deletionRumorJson: any(named: 'deletionRumorJson'),
          ),
        ).called(1);
      },
    );

    test(
      'retryDeletion settles the row of the account that started it when the '
      'session changes during the send',
      () async {
        const nextAccount =
            '2222222222222222222222222222222222222222222222222222222222222222';
        final deletionRumor = reactionRumor(
          id: _giftWrapId,
          content: '',
          kind: EventKind.eventDeletion,
          tags: [
            ['e', _reactionRumorId],
            ['k', EventKind.reaction.toString()],
          ],
        );
        when(
          () =>
              mockDao.getById(id: _reactionRumorId, ownerPubkey: _ownerPubkey),
        ).thenAnswer(
          (_) async => makeRow(
            isDeleted: true,
            publishStatus: 'deletion_pending',
            rumorEventJson: jsonEncode(deletionRumor.toJson()),
            recipientPubkeys: jsonEncode([_otherPubkey]),
          ),
        );
        when(
          () => mockDao.markDeletionSent(
            id: any(named: 'id'),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer((_) async {});
        final repository = createRepository();
        when(
          () => mockMessageService.sendRumor(
            rumorEvent: any(named: 'rumorEvent'),
            recipientPubkey: _otherPubkey,
            awaitRecipientOk: any(named: 'awaitRecipientOk'),
          ),
        ).thenAnswer((_) async {
          repository.setCredentials(
            userPubkey: nextAccount,
            messageService: mockMessageService,
          );
          return NIP17SendResult.success(
            rumorEventId: deletionRumor.id,
            messageEventId: _giftWrapId,
            recipientPubkey: _otherPubkey,
          );
        });

        final outcome = await repository.retryDeletion(
          rumorId: _reactionRumorId,
          targetMessageAuthor: _otherPubkey,
        );

        expect(outcome, equals(DmReactionDeletionOutcome.sent));
        verify(
          () => mockDao.markDeletionSent(
            id: _reactionRumorId,
            ownerPubkey: _ownerPubkey,
          ),
        ).called(1);
      },
    );

    test('retry sends nothing when the queue row is gone', () async {
      final rumor = reactionRumor();

      final result = await createRepository().retry(
        rumorId: rumor.id,
        targetMessageAuthor: _otherPubkey,
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('No stored rumor'));
      verifyNever(
        () => mockDao.markPending(
          id: any(named: 'id'),
          ownerPubkey: any(named: 'ownerPubkey'),
        ),
      );
      verifyNever(
        () => mockMessageService.sendRumor(
          rumorEvent: any(named: 'rumorEvent'),
          recipientPubkey: any(named: 'recipientPubkey'),
          awaitRecipientOk: any(named: 'awaitRecipientOk'),
        ),
      );
    });

    test(
      'retry still sends, and reports, when recording the resolved recipients '
      'fails',
      () async {
        final rumor = reactionRumor();
        final rumorJson = jsonEncode(rumor.toJson());
        when(
          () => mockDao.getById(id: rumor.id, ownerPubkey: _ownerPubkey),
        ).thenAnswer(
          (_) async =>
              makeRow(publishStatus: 'failed', rumorEventJson: rumorJson),
        );
        when(
          () => mockDao.setRecipientPubkeysIfMissing(
            id: any(named: 'id'),
            ownerPubkey: any(named: 'ownerPubkey'),
            conversationId: any(named: 'conversationId'),
            recipientPubkeys: any(named: 'recipientPubkeys'),
          ),
        ).thenThrow(StateError('write failed'));
        when(
          () => mockDao.markPending(id: rumor.id, ownerPubkey: _ownerPubkey),
        ).thenAnswer((_) async {});
        when(
          () => mockMessageService.sendRumor(
            rumorEvent: any(named: 'rumorEvent'),
            recipientPubkey: _otherPubkey,
            awaitRecipientOk: any(named: 'awaitRecipientOk'),
          ),
        ).thenAnswer(
          (_) async => NIP17SendResult.success(
            rumorEventId: rumor.id,
            messageEventId: _giftWrapId,
            recipientPubkey: _otherPubkey,
          ),
        );
        when(
          () => mockDao.swapPlaceholderId(
            placeholderId: rumor.id,
            realRumorId: rumor.id,
            ownerPubkey: _ownerPubkey,
          ),
        ).thenAnswer((_) async {});

        final result = await createRepository().retry(
          rumorId: rumor.id,
          targetMessageAuthor: _otherPubkey,
        );

        expect(result.success, isTrue);
        expect(
          reporterSites,
          equals([DmReactionsRepositoryReportableSites.wrapRecipientsStore]),
        );
      },
    );

    test('retry marks failed when send returns failure', () async {
      final rumor = reactionRumor();
      stubQueuedRow(
        rumorEventJson: jsonEncode(rumor.toJson()),
        publishStatus: 'failed',
      );
      when(
        () => mockDao.markPending(id: rumor.id, ownerPubkey: _ownerPubkey),
      ).thenAnswer((_) async {});
      when(
        () => mockMessageService.sendRumor(
          rumorEvent: any(named: 'rumorEvent'),
          recipientPubkey: _otherPubkey,
          awaitRecipientOk: any(named: 'awaitRecipientOk'),
        ),
      ).thenAnswer((_) async => const NIP17SendResult.failure('relay down'));
      when(
        () => mockDao.markFailed(
          placeholderId: rumor.id,
          ownerPubkey: _ownerPubkey,
        ),
      ).thenAnswer((_) async {});

      final repository = createRepository();
      final result = await repository.retry(
        rumorId: rumor.id,
        targetMessageAuthor: _otherPubkey,
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, 'relay down');
      verify(
        () => mockDao.markFailed(
          placeholderId: rumor.id,
          ownerPubkey: _ownerPubkey,
        ),
      ).called(1);
    });

    test(
      'retry leaves the row pending (does not mark failed) on an unconfirmed '
      'send',
      () async {
        final rumor = reactionRumor();
        stubQueuedRow(
          rumorEventJson: jsonEncode(rumor.toJson()),
          publishStatus: 'failed',
        );
        when(
          () => mockDao.markPending(id: rumor.id, ownerPubkey: _ownerPubkey),
        ).thenAnswer((_) async {});
        when(
          () => mockMessageService.sendRumor(
            rumorEvent: any(named: 'rumorEvent'),
            recipientPubkey: _otherPubkey,
            awaitRecipientOk: any(named: 'awaitRecipientOk'),
          ),
        ).thenAnswer(
          (_) async => const NIP17SendResult.failure(
            'unconfirmed',
            retryablePending: true,
          ),
        );

        final repository = createRepository();
        final result = await repository.retry(
          rumorId: rumor.id,
          targetMessageAuthor: _otherPubkey,
        );

        // The pre-send markPending stands; an unconfirmed retry must not flip
        // the row to 'failed' (the sweep keeps re-driving it).
        expect(result.success, isFalse);
        verify(
          () => mockMessageService.sendRumor(
            rumorEvent: any(named: 'rumorEvent'),
            recipientPubkey: _otherPubkey,
            awaitRecipientOk: true,
          ),
        ).called(1);
        verifyNever(
          () => mockDao.markFailed(
            placeholderId: any(named: 'placeholderId'),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        );
      },
    );

    test(
      'retryableReactions projects failed and pending own reactions from '
      'the dao',
      () async {
        when(
          () => mockDao.getRetryableOwnReactions(ownerPubkey: _ownerPubkey),
        ).thenAnswer(
          (_) async => [
            makeRow(
              publishStatus: 'failed',
              rumorEventJson: '{}',
              createdAt: 1_700_000_100,
            ),
            makeRow(
              id: _giftWrapId,
              publishStatus: 'pending',
              rumorEventJson: '{}',
              createdAt: 1_700_000_200,
            ),
          ],
        );

        final repository = createRepository();
        final targets = await repository.retryableReactions();

        expect(targets, hasLength(2));
        expect(targets.first.rumorId, _reactionRumorId);
        expect(targets.first.targetMessageAuthor, _otherPubkey);
        expect(targets.first.publishStatus, 'failed');
        expect(targets.first.createdAt, 1_700_000_100);
        expect(targets.last.publishStatus, 'pending');
      },
    );

    test('retryableReactions returns empty when uninitialized', () async {
      final repository = createRepository(initialized: false);

      final targets = await repository.retryableReactions();

      expect(targets, isEmpty);
      verifyNever(
        () => mockDao.getRetryableOwnReactions(
          ownerPubkey: any(named: 'ownerPubkey'),
        ),
      );
    });

    test('removeOwn does nothing when there is no row to remove', () async {
      await createRepository().removeOwn(
        rumorId: _reactionRumorId,
        targetMessageAuthor: _otherPubkey,
      );
      await pumpEventQueue();

      verifyNever(
        () => mockDao.markOwnDeletionPending(
          id: any(named: 'id'),
          ownerPubkey: any(named: 'ownerPubkey'),
          deletionRumorJson: any(named: 'deletionRumorJson'),
        ),
      );
      verifyNever(
        () => mockMessageService.sendRumor(
          rumorEvent: any(named: 'rumorEvent'),
          recipientPubkey: any(named: 'recipientPubkey'),
          awaitRecipientOk: any(named: 'awaitRecipientOk'),
        ),
      );
      expect(reporterSites, isEmpty);
    });

    test(
      'removeOwn durably records the kind-5 deletion and publishes it',
      () async {
        final deletionRumor = reactionRumor(
          id: _giftWrapId,
          content: '',
          kind: EventKind.eventDeletion,
          tags: [
            ['e', _reactionRumorId],
            ['k', EventKind.reaction.toString()],
          ],
        );
        stubQueuedRow(publishStatus: 'sent');
        when(
          () => mockDao.markOwnDeletionPending(
            id: _reactionRumorId,
            ownerPubkey: _ownerPubkey,
            deletionRumorJson: any(named: 'deletionRumorJson'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockMessageService.buildRumor(
            recipientPubkey: _otherPubkey,
            content: '',
            eventKind: EventKind.eventDeletion,
            additionalTags: any(named: 'additionalTags'),
          ),
        ).thenReturn(deletionRumor);
        // Publish fails (e.g. offline) — the durable row stays pending for the
        // sweep, so markDeletionSent must NOT be called.
        when(
          () => mockMessageService.sendRumor(
            rumorEvent: deletionRumor,
            recipientPubkey: _otherPubkey,
            awaitRecipientOk: any(named: 'awaitRecipientOk'),
          ),
        ).thenAnswer((_) async => const NIP17SendResult.failure('offline'));

        final repository = createRepository();
        await repository.removeOwn(
          rumorId: _reactionRumorId,
          targetMessageAuthor: _otherPubkey,
        );
        // _driveDeletion fires via unawaited; let it run.
        await Future<void>.delayed(Duration.zero);

        verify(
          () => mockDao.markOwnDeletionPending(
            id: _reactionRumorId,
            ownerPubkey: _ownerPubkey,
            deletionRumorJson: any(named: 'deletionRumorJson'),
          ),
        ).called(1);
        verify(
          () => mockMessageService.sendRumor(
            rumorEvent: deletionRumor,
            recipientPubkey: _otherPubkey,
            awaitRecipientOk: any(named: 'awaitRecipientOk'),
          ),
        ).called(1);
        verifyNever(
          () => mockDao.markDeletionSent(
            id: any(named: 'id'),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        );
      },
    );

    test(
      'removeOwn throws, reports, and sends nothing when the deletion '
      'cannot be recorded',
      () async {
        final deletionRumor = reactionRumor(
          id: _giftWrapId,
          content: '',
          kind: EventKind.eventDeletion,
          tags: [
            ['e', _reactionRumorId],
            ['k', EventKind.reaction.toString()],
          ],
        );
        final failure = Exception('disk I/O error');
        stubQueuedRow(publishStatus: 'sent');
        when(
          () => mockMessageService.buildRumor(
            recipientPubkey: _otherPubkey,
            content: '',
            eventKind: EventKind.eventDeletion,
            additionalTags: any(named: 'additionalTags'),
          ),
        ).thenReturn(deletionRumor);
        when(
          () => mockDao.markOwnDeletionPending(
            id: _reactionRumorId,
            ownerPubkey: _ownerPubkey,
            deletionRumorJson: any(named: 'deletionRumorJson'),
          ),
        ).thenThrow(failure);

        await expectLater(
          createRepository().removeOwn(
            rumorId: _reactionRumorId,
            targetMessageAuthor: _otherPubkey,
          ),
          throwsA(same(failure)),
        );
        await pumpEventQueue();

        expect(
          reporterSites,
          equals([DmReactionsRepositoryReportableSites.removeOwnSoftDelete]),
        );
        verifyNever(
          () => mockMessageService.sendRumor(
            rumorEvent: any(named: 'rumorEvent'),
            recipientPubkey: any(named: 'recipientPubkey'),
            awaitRecipientOk: any(named: 'awaitRecipientOk'),
          ),
        );
      },
    );

    test('removeOwn records a blocked first attempt as refused', () async {
      final deletionRumor = reactionRumor(
        id: _giftWrapId,
        content: '',
        kind: EventKind.eventDeletion,
        tags: [
          ['e', _reactionRumorId],
          ['k', EventKind.reaction.toString()],
        ],
      );
      stubQueuedRow(publishStatus: 'sent');
      when(
        () => mockDao.markOwnDeletionPending(
          id: _reactionRumorId,
          ownerPubkey: _ownerPubkey,
          deletionRumorJson: any(named: 'deletionRumorJson'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => mockMessageService.buildRumor(
          recipientPubkey: _otherPubkey,
          content: '',
          eventKind: EventKind.eventDeletion,
          additionalTags: any(named: 'additionalTags'),
        ),
      ).thenReturn(deletionRumor);
      when(
        () => mockMessageService.sendRumor(
          rumorEvent: deletionRumor,
          recipientPubkey: _otherPubkey,
          awaitRecipientOk: any(named: 'awaitRecipientOk'),
        ),
      ).thenAnswer(
        (_) async => const NIP17SendResult.blocked('policy refused'),
      );
      when(
        () => mockDao.markDeletionRefused(
          id: _reactionRumorId,
          ownerPubkey: _ownerPubkey,
        ),
      ).thenAnswer((_) async {});

      await createRepository().removeOwn(
        rumorId: _reactionRumorId,
        targetMessageAuthor: _otherPubkey,
      );
      await Future<void>.delayed(Duration.zero);

      verify(
        () => mockDao.markDeletionRefused(
          id: _reactionRumorId,
          ownerPubkey: _ownerPubkey,
        ),
      ).called(1);
      verifyNever(
        () => mockDao.markDeletionSent(
          id: any(named: 'id'),
          ownerPubkey: any(named: 'ownerPubkey'),
        ),
      );
    });

    test(
      'the initial deletion and a concurrent retry share one fan-out',
      () async {
        final deletionRumor = reactionRumor(
          id: _giftWrapId,
          content: '',
          kind: EventKind.eventDeletion,
          tags: [
            ['e', _reactionRumorId],
            ['k', EventKind.reaction.toString()],
          ],
        );
        final send = Completer<NIP17SendResult>();
        when(
          () => mockDao.getById(
            id: _reactionRumorId,
            ownerPubkey: _ownerPubkey,
          ),
        ).thenAnswer(
          (_) async => makeRow(
            isDeleted: true,
            publishStatus: 'deletion_pending',
            rumorEventJson: jsonEncode(deletionRumor.toJson()),
            recipientPubkeys: jsonEncode([_otherPubkey]),
          ),
        );
        when(
          () => mockDao.markOwnDeletionPending(
            id: _reactionRumorId,
            ownerPubkey: _ownerPubkey,
            deletionRumorJson: any(named: 'deletionRumorJson'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockMessageService.buildRumor(
            recipientPubkey: _otherPubkey,
            content: '',
            eventKind: EventKind.eventDeletion,
            additionalTags: any(named: 'additionalTags'),
          ),
        ).thenReturn(deletionRumor);
        when(
          () => mockMessageService.sendRumor(
            rumorEvent: deletionRumor,
            recipientPubkey: _otherPubkey,
            awaitRecipientOk: any(named: 'awaitRecipientOk'),
          ),
        ).thenAnswer((_) => send.future);
        when(
          () => mockDao.markDeletionSent(
            id: _reactionRumorId,
            ownerPubkey: _ownerPubkey,
          ),
        ).thenAnswer((_) async {});

        final repository = createRepository();
        await repository.removeOwn(
          rumorId: _reactionRumorId,
          targetMessageAuthor: _otherPubkey,
        );
        await Future<void>.delayed(Duration.zero);
        final retry = repository.retryDeletion(
          rumorId: _reactionRumorId,
          targetMessageAuthor: _otherPubkey,
        );
        send.complete(
          NIP17SendResult.success(
            rumorEventId: deletionRumor.id,
            messageEventId: _giftWrapId,
            recipientPubkey: _otherPubkey,
          ),
        );

        expect(await retry, DmReactionDeletionOutcome.sent);
        verify(
          () => mockMessageService.sendRumor(
            rumorEvent: deletionRumor,
            recipientPubkey: _otherPubkey,
            awaitRecipientOk: any(named: 'awaitRecipientOk'),
          ),
        ).called(1);
      },
    );

    test(
      'retryableDeletions projects pending own deletions from the dao',
      () async {
        when(
          () => mockDao.getRetryableOwnDeletions(ownerPubkey: _ownerPubkey),
        ).thenAnswer(
          (_) async => [
            makeRow(
              isDeleted: true,
              publishStatus: 'deletion_pending',
              rumorEventJson: '{}',
            ),
          ],
        );

        final repository = createRepository();
        final targets = await repository.retryableDeletions();

        expect(targets, hasLength(1));
        expect(targets.first.rumorId, _reactionRumorId);
        expect(targets.first.targetMessageAuthor, _otherPubkey);
      },
    );

    test(
      'concurrent retryDeletion calls share one stored-rumor publish',
      () async {
        final send = Completer<NIP17SendResult>();
        final deletionRumor = reactionRumor(
          id: _giftWrapId,
          content: '',
          kind: EventKind.eventDeletion,
          tags: [
            ['e', _reactionRumorId],
            ['k', EventKind.reaction.toString()],
          ],
        );
        when(
          () => mockDao.getById(
            id: _reactionRumorId,
            ownerPubkey: _ownerPubkey,
          ),
        ).thenAnswer(
          (_) async => makeRow(
            isDeleted: true,
            publishStatus: 'deletion_refused',
            rumorEventJson: jsonEncode(deletionRumor.toJson()),
            recipientPubkeys: jsonEncode([_otherPubkey]),
          ),
        );
        when(
          () => mockMessageService.sendRumor(
            rumorEvent: deletionRumor,
            recipientPubkey: _otherPubkey,
            awaitRecipientOk: true,
          ),
        ).thenAnswer((_) => send.future);
        when(
          () => mockDao.markDeletionSent(
            id: _reactionRumorId,
            ownerPubkey: _ownerPubkey,
          ),
        ).thenAnswer((_) async {});

        final repository = createRepository();
        final first = repository.retryDeletion(
          rumorId: _reactionRumorId,
          targetMessageAuthor: _otherPubkey,
        );
        final second = repository.retryDeletion(
          rumorId: _reactionRumorId,
          targetMessageAuthor: _otherPubkey,
        );
        send.complete(
          NIP17SendResult.success(
            rumorEventId: deletionRumor.id,
            messageEventId: _giftWrapId,
            recipientPubkey: _otherPubkey,
          ),
        );

        expect(
          await Future.wait([first, second]),
          everyElement(DmReactionDeletionOutcome.sent),
        );
        verify(
          () => mockMessageService.sendRumor(
            rumorEvent: deletionRumor,
            recipientPubkey: _otherPubkey,
            awaitRecipientOk: true,
          ),
        ).called(1);
      },
    );

    test(
      'retryDeletion replays the stored kind-5 and marks it sent on success',
      () async {
        final deletionRumor = reactionRumor(
          id: _giftWrapId,
          content: '',
          kind: EventKind.eventDeletion,
          tags: [
            ['e', _reactionRumorId],
            ['k', EventKind.reaction.toString()],
          ],
        );
        when(
          () =>
              mockDao.getById(id: _reactionRumorId, ownerPubkey: _ownerPubkey),
        ).thenAnswer(
          (_) async => makeRow(
            isDeleted: true,
            publishStatus: 'deletion_pending',
            rumorEventJson: jsonEncode(deletionRumor.toJson()),
            recipientPubkeys: jsonEncode([_otherPubkey]),
          ),
        );
        when(
          () => mockMessageService.sendRumor(
            rumorEvent: any(named: 'rumorEvent'),
            recipientPubkey: _otherPubkey,
            awaitRecipientOk: any(named: 'awaitRecipientOk'),
          ),
        ).thenAnswer(
          (_) async => NIP17SendResult.success(
            rumorEventId: deletionRumor.id,
            messageEventId: _giftWrapId,
            recipientPubkey: _otherPubkey,
          ),
        );
        when(
          () => mockDao.markDeletionSent(
            id: _reactionRumorId,
            ownerPubkey: _ownerPubkey,
          ),
        ).thenAnswer((_) async {});

        final repository = createRepository();
        final result = await repository.retryDeletion(
          rumorId: _reactionRumorId,
          targetMessageAuthor: _otherPubkey,
        );

        expect(result, DmReactionDeletionOutcome.sent);
        verify(
          () => mockDao.markDeletionSent(
            id: _reactionRumorId,
            ownerPubkey: _ownerPubkey,
          ),
        ).called(1);
        final sentRumor =
            verify(
                  () => mockMessageService.sendRumor(
                    rumorEvent: captureAny(named: 'rumorEvent'),
                    recipientPubkey: _otherPubkey,
                    awaitRecipientOk: true,
                  ),
                ).captured.single
                as Event;
        expect(sentRumor.toJson(), equals(deletionRumor.toJson()));
      },
    );

    test(
      'retryDeletion preserves a policy-refused removal for manual retry',
      () async {
        final deletionRumor = reactionRumor(
          id: _giftWrapId,
          content: '',
          kind: EventKind.eventDeletion,
          tags: [
            ['e', _reactionRumorId],
            ['k', EventKind.reaction.toString()],
          ],
        );
        when(
          () =>
              mockDao.getById(id: _reactionRumorId, ownerPubkey: _ownerPubkey),
        ).thenAnswer(
          (_) async => makeRow(
            isDeleted: true,
            publishStatus: 'deletion_pending',
            rumorEventJson: jsonEncode(deletionRumor.toJson()),
            recipientPubkeys: jsonEncode([_otherPubkey]),
          ),
        );
        when(
          () => mockMessageService.sendRumor(
            rumorEvent: any(named: 'rumorEvent'),
            recipientPubkey: _otherPubkey,
            awaitRecipientOk: any(named: 'awaitRecipientOk'),
          ),
        ).thenAnswer(
          (_) async => const NIP17SendResult.blocked('policy refused'),
        );
        when(
          () => mockDao.markDeletionRefused(
            id: _reactionRumorId,
            ownerPubkey: _ownerPubkey,
          ),
        ).thenAnswer((_) async {});

        final repository = createRepository();
        final result = await repository.retryDeletion(
          rumorId: _reactionRumorId,
          targetMessageAuthor: _otherPubkey,
        );

        expect(result, DmReactionDeletionOutcome.refused);
        verify(
          () => mockDao.markDeletionRefused(
            id: _reactionRumorId,
            ownerPubkey: _ownerPubkey,
          ),
        ).called(1);
      },
    );

    test('retryDeletion fails when no stored deletion exists', () async {
      // getById default stub returns null → nothing to replay.
      final repository = createRepository();
      final result = await repository.retryDeletion(
        rumorId: _reactionRumorId,
        targetMessageAuthor: _otherPubkey,
      );

      expect(result, DmReactionDeletionOutcome.unavailable);
    });

    test('persistIncoming validates event shape before upsert', () async {
      final repository = createRepository();

      // Malformed content / missing e-tag are permanent drops — terminal, so
      // the wrap is recorded (processed) and not re-decrypted. #5452.
      final emptyContentOutcome = await repository.persistIncoming(
        rumorEvent: reactionRumor(content: ''),
        giftWrapId: _giftWrapId,
      );
      final missingTagOutcome = await repository.persistIncoming(
        rumorEvent: reactionRumor(
          tags: [
            ['p', _otherPubkey],
          ],
        ),
        giftWrapId: _giftWrapId,
      );

      expect(emptyContentOutcome, DmWrapOutcome.processed);
      expect(missingTagOutcome, DmWrapOutcome.processed);

      verifyNever(
        () => mockDao.upsertIncoming(
          id: any(named: 'id'),
          conversationId: any(named: 'conversationId'),
          targetMessageId: any(named: 'targetMessageId'),
          targetMessageAuthor: any(named: 'targetMessageAuthor'),
          reactorPubkey: any(named: 'reactorPubkey'),
          emoji: any(named: 'emoji'),
          createdAt: any(named: 'createdAt'),
          giftWrapId: any(named: 'giftWrapId'),
          ownerPubkey: any(named: 'ownerPubkey'),
        ),
      );
    });

    test('persistIncoming upserts valid reaction rumors', () async {
      when(
        () => mockDao.upsertIncoming(
          id: _reactionRumorId,
          conversationId: any(named: 'conversationId'),
          targetMessageId: _targetMessageId,
          targetMessageAuthor: _otherPubkey,
          reactorPubkey: _ownerPubkey,
          emoji: '🔥',
          createdAt: 1_700_000_000,
          giftWrapId: _giftWrapId,
          ownerPubkey: _ownerPubkey,
        ),
      ).thenAnswer((_) async {});

      final repository = createRepository();
      final outcome = await repository.persistIncoming(
        rumorEvent: reactionRumor(),
        giftWrapId: _giftWrapId,
      );

      expect(outcome, DmWrapOutcome.processed);
      verify(
        () => mockDao.upsertIncoming(
          id: _reactionRumorId,
          conversationId: any(named: 'conversationId'),
          targetMessageId: _targetMessageId,
          targetMessageAuthor: _otherPubkey,
          reactorPubkey: _ownerPubkey,
          emoji: '🔥',
          createdAt: 1_700_000_000,
          giftWrapId: _giftWrapId,
          ownerPubkey: _ownerPubkey,
        ),
      ).called(1);
    });

    test('persistIncoming binds the LAST e and p tag per NIP-25', () async {
      // NIP-25: "If a client decides to include other `e`, which not
      // recommended, the target event `id` should be last of the `e` tags",
      // and likewise the target pubkey "should be last the `p` tags". A peer
      // that threads its reaction puts the root first, so first-wins binds
      // the reaction to the wrong message — painted on the wrong bubble, or
      // written against no bubble at all and then cemented in the dedup
      // ledger as `processed`, which no later launch re-derives. #7333.
      when(
        () => mockDao.upsertIncoming(
          id: any(named: 'id'),
          conversationId: any(named: 'conversationId'),
          targetMessageId: any(named: 'targetMessageId'),
          targetMessageAuthor: any(named: 'targetMessageAuthor'),
          reactorPubkey: any(named: 'reactorPubkey'),
          emoji: any(named: 'emoji'),
          createdAt: any(named: 'createdAt'),
          giftWrapId: any(named: 'giftWrapId'),
          ownerPubkey: any(named: 'ownerPubkey'),
        ),
      ).thenAnswer((_) async {});

      final repository = createRepository();
      final outcome = await repository.persistIncoming(
        rumorEvent: reactionRumor(
          tags: [
            ['e', _threadRootId],
            ['e', _targetMessageId],
            ['p', _mentionedPubkey],
            ['p', _otherPubkey],
            ['k', EventKind.privateDirectMessage.toString()],
          ],
        ),
        giftWrapId: _giftWrapId,
      );

      expect(outcome, DmWrapOutcome.processed);
      verify(
        () => mockDao.upsertIncoming(
          id: _reactionRumorId,
          conversationId: any(named: 'conversationId'),
          targetMessageId: _targetMessageId,
          targetMessageAuthor: _otherPubkey,
          reactorPubkey: _ownerPubkey,
          emoji: '🔥',
          createdAt: 1_700_000_000,
          giftWrapId: _giftWrapId,
          ownerPubkey: _ownerPubkey,
        ),
      ).called(1);
    });

    test('persistIncoming reports dao upsert failures', () async {
      when(
        () => mockDao.upsertIncoming(
          id: _reactionRumorId,
          conversationId: any(named: 'conversationId'),
          targetMessageId: _targetMessageId,
          targetMessageAuthor: _otherPubkey,
          reactorPubkey: _ownerPubkey,
          emoji: '🔥',
          createdAt: 1_700_000_000,
          giftWrapId: _giftWrapId,
          ownerPubkey: _ownerPubkey,
        ),
      ).thenThrow(StateError('boom'));

      final repository = createRepository();
      final outcome = await repository.persistIncoming(
        rumorEvent: reactionRumor(),
        giftWrapId: _giftWrapId,
      );

      // A transient DAO failure must NOT cement a skip — leave it deferred so
      // the wrap retries on a later launch. #5452.
      expect(outcome, DmWrapOutcome.deferred);
      expect(
        reporterSites,
        contains(
          DmReactionsRepositoryReportableSites.persistIncomingDaoUpsert,
        ),
      );
    });

    test(
      'persistIncoming returns deferred when the conversation cannot be '
      'resolved (target not synced)',
      () async {
        // A third-party reaction (neither reactor nor target author is us) with
        // no synced target message: the conversation cannot be inferred, so the
        // wrap is left undecided to re-decrypt and land later. #5452.
        const thirdPubkey =
            '1111111111111111111111111111111111111111111111111111111111111111';
        final repository = createRepository();

        final outcome = await repository.persistIncoming(
          rumorEvent: reactionRumor(
            reactorPubkey: _otherPubkey,
            tags: [
              ['e', _targetMessageId],
              ['p', thirdPubkey],
            ],
          ),
          giftWrapId: _giftWrapId,
        );

        expect(outcome, DmWrapOutcome.deferred);
        verifyNever(
          () => mockDao.upsertIncoming(
            id: any(named: 'id'),
            conversationId: any(named: 'conversationId'),
            targetMessageId: any(named: 'targetMessageId'),
            targetMessageAuthor: any(named: 'targetMessageAuthor'),
            reactorPubkey: any(named: 'reactorPubkey'),
            emoji: any(named: 'emoji'),
            createdAt: any(named: 'createdAt'),
            giftWrapId: any(named: 'giftWrapId'),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        );
      },
    );

    test(
      'applyDeletion soft-deletes the matching reaction row',
      () async {
        when(
          () =>
              mockDao.getById(id: _reactionRumorId, ownerPubkey: _ownerPubkey),
        ).thenAnswer((_) async => makeRow());
        when(
          () => mockDao.softDelete(
            id: _reactionRumorId,
            ownerPubkey: _ownerPubkey,
          ),
        ).thenAnswer((_) async => 1);

        final repository = createRepository();
        final outcome = await repository.applyDeletion(
          rumorId: _reactionRumorId,
          deleterPubkey: _ownerPubkey,
          giftWrapId: _giftWrapId,
        );

        // Terminal: the deletion wrap is recorded so it is not re-decrypted on
        // every launch. #5452.
        expect(outcome, DmWrapOutcome.processed);
        verify(
          () => mockDao.softDelete(
            id: _reactionRumorId,
            ownerPubkey: _ownerPubkey,
          ),
        ).called(1);
      },
    );

    test(
      'applyDeletion keeps a refused removal retryable when its own '
      'self-wrap arrives',
      () async {
        when(
          () => mockDao.getById(
            id: _reactionRumorId,
            ownerPubkey: _ownerPubkey,
          ),
        ).thenAnswer(
          (_) async => makeRow(
            isDeleted: true,
            publishStatus: DmReactionsDao.deletionRefused,
            rumorEventJson: '{}',
          ),
        );

        final outcome = await createRepository().applyDeletion(
          rumorId: _reactionRumorId,
          deleterPubkey: _ownerPubkey,
          giftWrapId: _giftWrapId,
        );

        expect(outcome, DmWrapOutcome.processed);
        verifyNever(
          () => mockDao.markDeletionSent(
            id: any(named: 'id'),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        );
        verifyNever(
          () => mockDao.softDelete(
            id: any(named: 'id'),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        );
      },
    );

    test('applyDeletion ignores author mismatches', () async {
      when(
        () => mockDao.getById(id: _reactionRumorId, ownerPubkey: _ownerPubkey),
      ).thenAnswer((_) async => makeRow(reactorPubkey: _otherPubkey));

      final repository = createRepository();
      final outcome = await repository.applyDeletion(
        rumorId: _reactionRumorId,
        deleterPubkey: _ownerPubkey,
        giftWrapId: _giftWrapId,
      );

      // An invalid deletion (author mismatch) will never apply — it is
      // terminal, so the wrap is recorded and not re-decrypted. #5452.
      expect(outcome, DmWrapOutcome.processed);
      verifyNever(
        () => mockDao.softDelete(
          id: any(named: 'id'),
          ownerPubkey: any(named: 'ownerPubkey'),
        ),
      );
    });

    test(
      'applyDeletion returns null when the target reaction has not synced',
      () async {
        // `null` means "no reaction with that id here", which lets
        // DmRepository's classifier try the message store before giving up.
        // Only when neither store holds the target does the wrap defer — and
        // it must, because NIP-59 randomizes gift-wrap created_at, so a
        // deletion can drain before the reaction it removes. Recording it as
        // terminal would let the reaction insert live later and never be
        // soft-deleted. #5452, #7809.
        when(
          () =>
              mockDao.getById(id: _reactionRumorId, ownerPubkey: _ownerPubkey),
        ).thenAnswer((_) async => null);

        final repository = createRepository();
        final outcome = await repository.applyDeletion(
          rumorId: _reactionRumorId,
          deleterPubkey: _ownerPubkey,
          giftWrapId: _giftWrapId,
        );

        expect(outcome, isNull);
        verifyNever(
          () => mockDao.softDelete(
            id: any(named: 'id'),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        );
      },
    );

    test(
      'applyDeletion defers and reports on a soft-delete failure',
      () async {
        when(
          () =>
              mockDao.getById(id: _reactionRumorId, ownerPubkey: _ownerPubkey),
        ).thenAnswer((_) async => makeRow());
        when(
          () => mockDao.softDelete(
            id: _reactionRumorId,
            ownerPubkey: _ownerPubkey,
          ),
        ).thenThrow(StateError('boom'));

        final repository = createRepository();
        final outcome = await repository.applyDeletion(
          rumorId: _reactionRumorId,
          deleterPubkey: _ownerPubkey,
          giftWrapId: _giftWrapId,
        );

        // A transient DAO failure must NOT cement a skip — leave it deferred so
        // the wrap retries on a later launch. #5452.
        expect(outcome, DmWrapOutcome.deferred);
        expect(
          reporterSites,
          contains(
            DmReactionsRepositoryReportableSites
                .handleIncomingDeletionSoftDelete,
          ),
        );
      },
    );

    test(
      'publish addresses the wrap to the counterparty (not self) when '
      'reacting to your OWN message in a 1:1',
      () async {
        const oneToOneConversationId =
            'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
        final mockConversationsDao = _MockConversationsDao();
        when(
          () => mockConversationsDao.getConversation(
            oneToOneConversationId,
            ownerPubkey: _ownerPubkey,
          ),
        ).thenAnswer(
          (_) async => ConversationRow(
            id: oneToOneConversationId,
            participantPubkeys: jsonEncode([_ownerPubkey, _otherPubkey]),
            isGroup: false,
            isRead: true,
            currentUserHasSent: true,
            createdAt: 1700000000,
            ownerPubkey: _ownerPubkey,
          ),
        );
        // Reacting to our OWN sent message: the target author is us.
        final rumor = reactionRumor();
        when(
          () => mockMessageService.buildRumor(
            recipientPubkey: _ownerPubkey,
            content: '🔥',
            eventKind: EventKind.reaction,
            additionalTags: any(named: 'additionalTags'),
          ),
        ).thenReturn(rumor);
        when(
          () => mockDao.insertOwnReactionSuperseding(
            placeholderId: any(named: 'placeholderId'),
            conversationId: any(named: 'conversationId'),
            targetMessageId: any(named: 'targetMessageId'),
            targetMessageAuthor: any(named: 'targetMessageAuthor'),
            reactorPubkey: any(named: 'reactorPubkey'),
            emoji: any(named: 'emoji'),
            createdAt: any(named: 'createdAt'),
            ownerPubkey: any(named: 'ownerPubkey'),
            rumorEventJson: any(named: 'rumorEventJson'),
            recipientPubkeys: any(named: 'recipientPubkeys'),
          ),
        ).thenAnswer((_) async => <String>[]);
        when(
          () => mockMessageService.sendRumor(
            rumorEvent: any(named: 'rumorEvent'),
            recipientPubkey: any(named: 'recipientPubkey'),
            awaitRecipientOk: any(named: 'awaitRecipientOk'),
          ),
        ).thenAnswer(
          (_) async => NIP17SendResult.success(
            rumorEventId: rumor.id,
            messageEventId: _giftWrapId,
            recipientPubkey: _otherPubkey,
          ),
        );
        when(
          () => mockDao.swapPlaceholderId(
            placeholderId: any(named: 'placeholderId'),
            realRumorId: any(named: 'realRumorId'),
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer((_) async {});

        final repository = createRepository(
          conversationsDao: mockConversationsDao,
        );
        final result = await repository.publish(
          conversationId: oneToOneConversationId,
          targetMessageId: _targetMessageId,
          targetMessageAuthor: _ownerPubkey, // our own message
          emoji: '🔥',
        );

        expect(result.success, isTrue);
        // The reaction wrap must reach the OTHER participant, never only self
        // — otherwise a reaction on a message the reactor authored is never
        // delivered to the counterparty.
        verify(
          () => mockMessageService.sendRumor(
            rumorEvent: any(named: 'rumorEvent'),
            recipientPubkey: _otherPubkey,
            awaitRecipientOk: any(named: 'awaitRecipientOk'),
          ),
        ).called(1);
        verifyNever(
          () => mockMessageService.sendRumor(
            rumorEvent: any(named: 'rumorEvent'),
            recipientPubkey: _ownerPubkey,
            awaitRecipientOk: any(named: 'awaitRecipientOk'),
          ),
        );
      },
    );

    group('group reactions', () {
      const thirdPubkey =
          '1111111111111111111111111111111111111111111111111111111111111111';
      const groupConversationId = 'group-convo-id';

      test(
        'a mixed confirmed and policy-blocked deletion is recorded refused',
        () async {
          final deletionRumor = reactionRumor(
            id: _giftWrapId,
            content: '',
            kind: EventKind.eventDeletion,
            tags: [
              ['e', _reactionRumorId],
              ['k', EventKind.reaction.toString()],
            ],
          );
          when(
            () => mockDao.getById(
              id: _reactionRumorId,
              ownerPubkey: _ownerPubkey,
            ),
          ).thenAnswer(
            (_) async => makeRow(
              conversationId: groupConversationId,
              isDeleted: true,
              publishStatus: 'deletion_pending',
              rumorEventJson: jsonEncode(deletionRumor.toJson()),
              recipientPubkeys: jsonEncode([_otherPubkey, thirdPubkey]),
            ),
          );
          when(
            () => mockMessageService.sendRumor(
              rumorEvent: deletionRumor,
              recipientPubkey: _otherPubkey,
              awaitRecipientOk: any(named: 'awaitRecipientOk'),
            ),
          ).thenAnswer(
            (_) async => NIP17SendResult.success(
              rumorEventId: deletionRumor.id,
              messageEventId: _giftWrapId,
              recipientPubkey: _otherPubkey,
            ),
          );
          when(
            () => mockMessageService.sendRumor(
              rumorEvent: deletionRumor,
              recipientPubkey: thirdPubkey,
              awaitRecipientOk: any(named: 'awaitRecipientOk'),
            ),
          ).thenAnswer(
            (_) async => const NIP17SendResult.blocked('policy refused'),
          );
          when(
            () => mockDao.markDeletionRefused(
              id: _reactionRumorId,
              ownerPubkey: _ownerPubkey,
            ),
          ).thenAnswer((_) async {});

          final outcome = await createRepository().retryDeletion(
            rumorId: _reactionRumorId,
            targetMessageAuthor: _otherPubkey,
          );

          expect(outcome, DmReactionDeletionOutcome.refused);
          verify(
            () => mockDao.markDeletionRefused(
              id: _reactionRumorId,
              ownerPubkey: _ownerPubkey,
            ),
          ).called(1);
        },
      );

      test(
        'publish fans the reaction wrap out to every group member',
        () async {
          final mockConversationsDao = _MockConversationsDao();
          when(
            () => mockConversationsDao.getConversation(
              groupConversationId,
              ownerPubkey: _ownerPubkey,
            ),
          ).thenAnswer(
            (_) async => ConversationRow(
              id: groupConversationId,
              participantPubkeys: jsonEncode([
                _ownerPubkey,
                _otherPubkey,
                thirdPubkey,
              ]),
              isGroup: true,
              isRead: true,
              currentUserHasSent: true,
              createdAt: 1700000000,
              ownerPubkey: _ownerPubkey,
            ),
          );
          final rumor = reactionRumor();
          when(
            () => mockMessageService.buildRumor(
              recipientPubkey: _otherPubkey,
              content: '🔥',
              eventKind: EventKind.reaction,
              additionalTags: any(named: 'additionalTags'),
            ),
          ).thenReturn(rumor);
          when(
            () => mockDao.insertOwnReactionSuperseding(
              placeholderId: any(named: 'placeholderId'),
              conversationId: any(named: 'conversationId'),
              targetMessageId: any(named: 'targetMessageId'),
              targetMessageAuthor: any(named: 'targetMessageAuthor'),
              reactorPubkey: any(named: 'reactorPubkey'),
              emoji: any(named: 'emoji'),
              createdAt: any(named: 'createdAt'),
              ownerPubkey: any(named: 'ownerPubkey'),
              rumorEventJson: any(named: 'rumorEventJson'),
              recipientPubkeys: any(named: 'recipientPubkeys'),
            ),
          ).thenAnswer((_) async => <String>[]);
          when(
            () => mockMessageService.sendRumor(
              rumorEvent: any(named: 'rumorEvent'),
              recipientPubkey: any(named: 'recipientPubkey'),
              awaitRecipientOk: any(named: 'awaitRecipientOk'),
            ),
          ).thenAnswer(
            (_) async => NIP17SendResult.success(
              rumorEventId: rumor.id,
              messageEventId: _giftWrapId,
              recipientPubkey: _otherPubkey,
            ),
          );
          when(
            () => mockDao.swapPlaceholderId(
              placeholderId: any(named: 'placeholderId'),
              realRumorId: any(named: 'realRumorId'),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer((_) async {});

          final repository = createRepository(
            conversationsDao: mockConversationsDao,
          );
          final result = await repository.publish(
            conversationId: groupConversationId,
            targetMessageId: _targetMessageId,
            targetMessageAuthor: _otherPubkey,
            emoji: '🔥',
          );

          expect(result.success, isTrue);
          // Wrapped to BOTH non-self members (fan-out), not just the author.
          verify(
            () => mockMessageService.sendRumor(
              rumorEvent: any(named: 'rumorEvent'),
              recipientPubkey: _otherPubkey,
              awaitRecipientOk: any(named: 'awaitRecipientOk'),
            ),
          ).called(1);
          verify(
            () => mockMessageService.sendRumor(
              rumorEvent: any(named: 'rumorEvent'),
              recipientPubkey: thirdPubkey,
              awaitRecipientOk: any(named: 'awaitRecipientOk'),
            ),
          ).called(1);
        },
      );

      test(
        'publish holds a group reaction, and reports the failure, when the '
        'conversation fails to read',
        () async {
          final mockConversationsDao = _MockConversationsDao();
          when(
            () => mockConversationsDao.getConversation(
              groupConversationId,
              ownerPubkey: _ownerPubkey,
            ),
          ).thenThrow(StateError('database is locked'));
          final rumor = reactionRumor();
          when(
            () => mockMessageService.buildRumor(
              recipientPubkey: _otherPubkey,
              content: '🔥',
              eventKind: EventKind.reaction,
              additionalTags: any(named: 'additionalTags'),
            ),
          ).thenReturn(rumor);
          when(
            () => mockDao.insertOwnReactionSuperseding(
              placeholderId: any(named: 'placeholderId'),
              conversationId: any(named: 'conversationId'),
              targetMessageId: any(named: 'targetMessageId'),
              targetMessageAuthor: any(named: 'targetMessageAuthor'),
              reactorPubkey: any(named: 'reactorPubkey'),
              emoji: any(named: 'emoji'),
              createdAt: any(named: 'createdAt'),
              ownerPubkey: any(named: 'ownerPubkey'),
              rumorEventJson: any(named: 'rumorEventJson'),
              recipientPubkeys: any(named: 'recipientPubkeys'),
            ),
          ).thenAnswer((_) async => <String>[]);
          when(
            () => mockDao.markFailed(
              placeholderId: any(named: 'placeholderId'),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer((_) async {});

          final result =
              await createRepository(
                conversationsDao: mockConversationsDao,
              ).publish(
                conversationId: groupConversationId,
                targetMessageId: _targetMessageId,
                targetMessageAuthor: _otherPubkey,
                emoji: '🔥',
              );

          expect(result.success, isFalse);
          expect(result.optimisticInsertSucceeded, isTrue);
          expect(
            reporterSites,
            equals([
              DmReactionsRepositoryReportableSites
                  .wrapRecipientsConversationRead,
            ]),
          );
          verifyNever(
            () => mockMessageService.sendRumor(
              rumorEvent: any(named: 'rumorEvent'),
              recipientPubkey: any(named: 'recipientPubkey'),
              awaitRecipientOk: any(named: 'awaitRecipientOk'),
            ),
          );
        },
      );

      test(
        'publish holds a group reaction, and reports the failure, when the '
        'reacted message fails to read',
        () async {
          final mockMessagesDao = _MockDirectMessagesDao();
          when(
            () => mockMessagesDao.getMessageById(
              _targetMessageId,
              ownerPubkey: _ownerPubkey,
            ),
          ).thenThrow(StateError('database is locked'));
          final rumor = reactionRumor();
          when(
            () => mockMessageService.buildRumor(
              recipientPubkey: _otherPubkey,
              content: '🔥',
              eventKind: EventKind.reaction,
              additionalTags: any(named: 'additionalTags'),
            ),
          ).thenReturn(rumor);
          when(
            () => mockDao.insertOwnReactionSuperseding(
              placeholderId: any(named: 'placeholderId'),
              conversationId: any(named: 'conversationId'),
              targetMessageId: any(named: 'targetMessageId'),
              targetMessageAuthor: any(named: 'targetMessageAuthor'),
              reactorPubkey: any(named: 'reactorPubkey'),
              emoji: any(named: 'emoji'),
              createdAt: any(named: 'createdAt'),
              ownerPubkey: any(named: 'ownerPubkey'),
              rumorEventJson: any(named: 'rumorEventJson'),
              recipientPubkeys: any(named: 'recipientPubkeys'),
            ),
          ).thenAnswer((_) async => <String>[]);
          when(
            () => mockDao.markFailed(
              placeholderId: any(named: 'placeholderId'),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer((_) async {});

          final result =
              await createRepository(
                directMessagesDao: mockMessagesDao,
              ).publish(
                conversationId: groupConversationId,
                targetMessageId: _targetMessageId,
                targetMessageAuthor: _otherPubkey,
                emoji: '🔥',
              );

          expect(result.success, isFalse);
          expect(result.optimisticInsertSucceeded, isTrue);
          expect(
            reporterSites,
            equals([
              DmReactionsRepositoryReportableSites
                  .wrapRecipientsTargetMessageRead,
            ]),
          );
          verifyNever(
            () => mockMessageService.sendRumor(
              rumorEvent: any(named: 'rumorEvent'),
              recipientPubkey: any(named: 'recipientPubkey'),
              awaitRecipientOk: any(named: 'awaitRecipientOk'),
            ),
          );
        },
      );

      test(
        'publish does NOT mark a group reaction sent on PARTIAL fan-out — one '
        'member confirming while another fails must stay retryable, never '
        'swapped to sent (which would clear the rumor and strand the miss)',
        () async {
          final mockConversationsDao = _MockConversationsDao();
          when(
            () => mockConversationsDao.getConversation(
              groupConversationId,
              ownerPubkey: _ownerPubkey,
            ),
          ).thenAnswer(
            (_) async => ConversationRow(
              id: groupConversationId,
              participantPubkeys: jsonEncode([
                _ownerPubkey,
                _otherPubkey,
                thirdPubkey,
              ]),
              isGroup: true,
              isRead: true,
              currentUserHasSent: true,
              createdAt: 1700000000,
              ownerPubkey: _ownerPubkey,
            ),
          );
          final rumor = reactionRumor();
          when(
            () => mockMessageService.buildRumor(
              recipientPubkey: _otherPubkey,
              content: '🔥',
              eventKind: EventKind.reaction,
              additionalTags: any(named: 'additionalTags'),
            ),
          ).thenReturn(rumor);
          when(
            () => mockDao.insertOwnReactionSuperseding(
              placeholderId: any(named: 'placeholderId'),
              conversationId: any(named: 'conversationId'),
              targetMessageId: any(named: 'targetMessageId'),
              targetMessageAuthor: any(named: 'targetMessageAuthor'),
              reactorPubkey: any(named: 'reactorPubkey'),
              emoji: any(named: 'emoji'),
              createdAt: any(named: 'createdAt'),
              ownerPubkey: any(named: 'ownerPubkey'),
              rumorEventJson: any(named: 'rumorEventJson'),
              recipientPubkeys: any(named: 'recipientPubkeys'),
            ),
          ).thenAnswer((_) async => <String>[]);
          // Member A confirms; member B hard-fails.
          when(
            () => mockMessageService.sendRumor(
              rumorEvent: any(named: 'rumorEvent'),
              recipientPubkey: _otherPubkey,
              awaitRecipientOk: any(named: 'awaitRecipientOk'),
            ),
          ).thenAnswer(
            (_) async => NIP17SendResult.success(
              rumorEventId: rumor.id,
              messageEventId: _giftWrapId,
              recipientPubkey: _otherPubkey,
            ),
          );
          when(
            () => mockMessageService.sendRumor(
              rumorEvent: any(named: 'rumorEvent'),
              recipientPubkey: thirdPubkey,
              awaitRecipientOk: any(named: 'awaitRecipientOk'),
            ),
          ).thenAnswer(
            (_) async => const NIP17SendResult.failure('relay down'),
          );
          when(
            () => mockDao.markFailed(
              placeholderId: any(named: 'placeholderId'),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer((_) async {});

          final repository = createRepository(
            conversationsDao: mockConversationsDao,
          );
          final result = await repository.publish(
            conversationId: groupConversationId,
            targetMessageId: _targetMessageId,
            targetMessageAuthor: _otherPubkey,
            emoji: '🔥',
          );

          expect(
            result.success,
            isFalse,
            reason: 'A partial fan-out is not a delivered reaction.',
          );
          // The critical invariant: the row must NOT be swapped to `sent`, or
          // swapPlaceholderId would clear rumor_event_json and the missed
          // member could never be re-driven.
          verifyNever(
            () => mockDao.swapPlaceholderId(
              placeholderId: any(named: 'placeholderId'),
              realRumorId: any(named: 'realRumorId'),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          );
          // Hard-failed member → the whole reaction is failed (kept
          // retryable), so the sweep re-drives the full rumor.
          verify(
            () => mockDao.markFailed(
              placeholderId: rumor.id,
              ownerPubkey: _ownerPubkey,
            ),
          ).called(1);
        },
      );

      test(
        'persistIncoming resolves the group conversation via the reel message',
        () async {
          final mockMessagesDao = _MockDirectMessagesDao();
          when(
            () => mockMessagesDao.getMessageById(
              _targetMessageId,
              ownerPubkey: _ownerPubkey,
            ),
          ).thenAnswer(
            (_) async => const DirectMessageRow(
              id: _targetMessageId,
              conversationId: groupConversationId,
              senderPubkey: _otherPubkey,
              content: 'reel',
              createdAt: 1700000000,
              giftWrapId: _giftWrapId,
              messageKind: 14,
              isDeleted: false,
              twinCollapsed: false,
              ownerPubkey: _ownerPubkey,
            ),
          );
          when(
            () => mockDao.upsertIncoming(
              id: any(named: 'id'),
              conversationId: any(named: 'conversationId'),
              targetMessageId: any(named: 'targetMessageId'),
              targetMessageAuthor: any(named: 'targetMessageAuthor'),
              reactorPubkey: any(named: 'reactorPubkey'),
              emoji: any(named: 'emoji'),
              createdAt: any(named: 'createdAt'),
              giftWrapId: any(named: 'giftWrapId'),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer((_) async {});

          final repository = createRepository(
            directMessagesDao: mockMessagesDao,
          );
          // A third party (neither us nor the author) reacts in the group.
          await repository.persistIncoming(
            rumorEvent: reactionRumor(reactorPubkey: thirdPubkey),
            giftWrapId: _giftWrapId,
          );

          verify(
            () => mockDao.upsertIncoming(
              id: any(named: 'id'),
              conversationId: groupConversationId,
              targetMessageId: any(named: 'targetMessageId'),
              targetMessageAuthor: any(named: 'targetMessageAuthor'),
              reactorPubkey: thirdPubkey,
              emoji: any(named: 'emoji'),
              createdAt: any(named: 'createdAt'),
              giftWrapId: any(named: 'giftWrapId'),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).called(1);
        },
      );

      test(
        'persistIncoming drops a group reaction when the reel is unsynced',
        () async {
          final mockMessagesDao = _MockDirectMessagesDao();
          when(
            () => mockMessagesDao.getMessageById(
              _targetMessageId,
              ownerPubkey: _ownerPubkey,
            ),
          ).thenAnswer((_) async => null);

          final repository = createRepository(
            directMessagesDao: mockMessagesDao,
          );
          await repository.persistIncoming(
            rumorEvent: reactionRumor(reactorPubkey: thirdPubkey),
            giftWrapId: _giftWrapId,
          );

          verifyNever(
            () => mockDao.upsertIncoming(
              id: any(named: 'id'),
              conversationId: any(named: 'conversationId'),
              targetMessageId: any(named: 'targetMessageId'),
              targetMessageAuthor: any(named: 'targetMessageAuthor'),
              reactorPubkey: any(named: 'reactorPubkey'),
              emoji: any(named: 'emoji'),
              createdAt: any(named: 'createdAt'),
              giftWrapId: any(named: 'giftWrapId'),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          );
        },
      );
    });

    // ------------------------------------------------------------------
    // #7321 — kind-10050 inbox routing.
    //
    // Stubs live in this leaf group rather than a shared setUp: the shared-
    // setup ratchet does not baseline this file, and a decision stub is only
    // legible next to the tests it governs.
    // ------------------------------------------------------------------
    const inbox = ['wss://inbox.example'];
    const DmInboxLookup inboxFound = (
      relays: inbox,
      state: DmInboxResolution.found,
    );
    const DmInboxLookup inboxAbsent = (
      relays: null,
      state: DmInboxResolution.absent,
    );
    const DmInboxLookup inboxUnreadable = (
      relays: null,
      state: DmInboxResolution.unreadable,
    );

    /// Stubs the optimistic insert + placeholder swap a `publish` needs, and
    /// returns the rumor it will send.
    Event stubPublishPath({List<String> superseded = const []}) {
      final rumor = reactionRumor();
      when(
        () => mockMessageService.buildRumor(
          recipientPubkey: _otherPubkey,
          content: '🔥',
          eventKind: EventKind.reaction,
          additionalTags: any(named: 'additionalTags'),
        ),
      ).thenReturn(rumor);
      when(
        () => mockDao.insertOwnReactionSuperseding(
          placeholderId: rumor.id,
          conversationId: _conversationId,
          targetMessageId: _targetMessageId,
          targetMessageAuthor: _otherPubkey,
          reactorPubkey: _ownerPubkey,
          emoji: '🔥',
          createdAt: rumor.createdAt,
          ownerPubkey: _ownerPubkey,
          rumorEventJson: jsonEncode(rumor.toJson()),
          recipientPubkeys: jsonEncode([_otherPubkey]),
        ),
      ).thenAnswer((_) async => superseded);
      when(
        () => mockDao.swapPlaceholderId(
          placeholderId: rumor.id,
          realRumorId: rumor.id,
          ownerPubkey: _ownerPubkey,
        ),
      ).thenAnswer((_) async {});
      when(
        () => mockMessageService.sendRumor(
          rumorEvent: any(named: 'rumorEvent'),
          recipientPubkey: any(named: 'recipientPubkey'),
          targetRelays: any(named: 'targetRelays'),
          awaitRecipientOk: any(named: 'awaitRecipientOk'),
        ),
      ).thenAnswer(
        (_) async => NIP17SendResult.success(
          rumorEventId: rumor.id,
          messageEventId: _giftWrapId,
          recipientPubkey: _otherPubkey,
        ),
      );
      return rumor;
    }

    Future<DmReactionPublishResult> publishReaction(
      DmReactionsRepository repository,
    ) => repository.publish(
      conversationId: _conversationId,
      targetMessageId: _targetMessageId,
      targetMessageAuthor: _otherPubkey,
      emoji: '🔥',
    );

    group('kind-10050 inbox routing (#7321)', () {
      test(
        'routes the reaction wrap to the resolved kind-10050 inbox',
        () async {
          final rumor = stubPublishPath();
          final repository = createRepository()
            ..setDmInboxRelayResolver((_) async => inboxFound);

          await publishReaction(repository);

          // The exact resolved value, not any() — the whole defect was
          // that this
          // argument never arrived at all.
          verify(
            () => mockMessageService.sendRumor(
              rumorEvent: rumor,
              recipientPubkey: _otherPubkey,
              targetRelays: inbox,
              awaitRecipientOk: true,
            ),
          ).called(1);
        },
      );

      test(
        'falls back to the default pool when the recipient advertises no inbox',
        () async {
          final rumor = stubPublishPath();
          final repository = createRepository()
            ..setDmInboxRelayResolver((_) async => inboxAbsent);

          await publishReaction(repository);

          verify(
            () => mockMessageService.sendRumor(
              rumorEvent: rumor,
              recipientPubkey: _otherPubkey,
              // `any(that: isNull)` rather than a literal `null`: the literal
              // matches sendRumor's default and trips
              // avoid_redundant_argument_values, but asserting the fallback is
              // the point of these three tests.
              targetRelays: any(named: 'targetRelays', that: isNull),
              awaitRecipientOk: true,
            ),
          ).called(1);
        },
      );

      test('publishes untargeted when no resolver is wired', () async {
        final rumor = stubPublishPath();
        final repository = createRepository();

        final result = await publishReaction(repository);

        // Legacy/test wiring with no resolver never attempted an inbox read,
        // so it keeps the pre-#7321 contract: a pool OK is delivery.
        expect(result.success, isTrue);
        verify(
          () => mockMessageService.sendRumor(
            rumorEvent: rumor,
            recipientPubkey: _otherPubkey,
            targetRelays: any(named: 'targetRelays', that: isNull),
            awaitRecipientOk: true,
          ),
        ).called(1);
      });

      test(
        'a throwing resolver still publishes that recipient to the pool, '
        'but an inbox we never read cannot score the OK as delivered',
        () async {
          final rumor = stubPublishPath();
          when(
            () => mockDao.markPending(id: rumor.id, ownerPubkey: _ownerPubkey),
          ).thenAnswer((_) async {});
          final repository = createRepository()
            ..setDmInboxRelayResolver(
              (_) async => throw StateError('resolver blew up'),
            );

          final result = await publishReaction(repository);

          // Publishing to the pool is right — a broken resolver must not drop
          // the reaction — but a lookup that threw is an inbox we did not
          // read, so the pool OK is soft-pending (#8443), never `sent`.
          expect(result.success, isFalse);
          verifyNever(
            () => mockDao.swapPlaceholderId(
              placeholderId: any(named: 'placeholderId'),
              realRumorId: any(named: 'realRumorId'),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          );
          verify(
            () => mockMessageService.sendRumor(
              rumorEvent: rumor,
              recipientPubkey: _otherPubkey,
              // `any(that: isNull)` rather than a literal `null`: the literal
              // matches sendRumor's default and trips
              // avoid_redundant_argument_values, but asserting the fallback is
              // the point of these three tests.
              targetRelays: any(named: 'targetRelays', that: isNull),
              awaitRecipientOk: true,
            ),
          ).called(1);
        },
      );

      test('routes the kind-5 reaction removal to the same inbox', () async {
        final deletionRumor = reactionRumor(
          id: _giftWrapId,
          content: '',
          kind: EventKind.eventDeletion,
          tags: [
            ['e', _reactionRumorId],
            ['k', EventKind.reaction.toString()],
          ],
        );
        stubQueuedRow(publishStatus: 'sent');
        when(
          () => mockDao.markOwnDeletionPending(
            id: _reactionRumorId,
            ownerPubkey: _ownerPubkey,
            deletionRumorJson: any(named: 'deletionRumorJson'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockMessageService.buildRumor(
            recipientPubkey: _otherPubkey,
            content: '',
            eventKind: EventKind.eventDeletion,
            additionalTags: any(named: 'additionalTags'),
          ),
        ).thenReturn(deletionRumor);
        when(
          () => mockMessageService.sendRumor(
            rumorEvent: deletionRumor,
            recipientPubkey: _otherPubkey,
            targetRelays: any(named: 'targetRelays'),
            awaitRecipientOk: any(named: 'awaitRecipientOk'),
          ),
        ).thenAnswer((_) async => const NIP17SendResult.failure('offline'));

        final repository = createRepository()
          ..setDmInboxRelayResolver((_) async => inboxFound);
        await repository.removeOwn(
          rumorId: _reactionRumorId,
          targetMessageAuthor: _otherPubkey,
        );
        // _driveDeletion fires via unawaited; let it run.
        await Future<void>.delayed(Duration.zero);

        verify(
          () => mockMessageService.sendRumor(
            rumorEvent: deletionRumor,
            recipientPubkey: _otherPubkey,
            targetRelays: inbox,
            awaitRecipientOk: true,
          ),
        ).called(1);
      });

      test(
        'an emoji swap resolves the inbox once for both the kind-5 and kind-7',
        () async {
          final deletionRumor = reactionRumor(
            id: _giftWrapId,
            content: '',
            kind: EventKind.eventDeletion,
            tags: [
              ['e', _reactionRumorId],
              ['k', EventKind.reaction.toString()],
            ],
          );
          stubPublishPath(superseded: const [_reactionRumorId]);
          when(
            () => mockDao.markOwnDeletionPending(
              id: _reactionRumorId,
              ownerPubkey: _ownerPubkey,
              deletionRumorJson: any(named: 'deletionRumorJson'),
            ),
          ).thenAnswer((_) async {});
          when(
            () => mockMessageService.buildRumor(
              recipientPubkey: _otherPubkey,
              content: '',
              eventKind: EventKind.eventDeletion,
              additionalTags: any(named: 'additionalTags'),
            ),
          ).thenReturn(deletionRumor);
          // _driveDeletion writes this on a confirmed kind-5. Unstubbed it
          // returns null, the await throws, and the drive logs "DM reaction
          // deletion publish threw" — the test would still pass while
          // exercising the error branch.
          when(
            () => mockDao.markDeletionSent(
              id: _reactionRumorId,
              ownerPubkey: _ownerPubkey,
            ),
          ).thenAnswer((_) async {});

          var resolveCalls = 0;
          final repository = createRepository()
            ..setDmInboxRelayResolver((_) async {
              resolveCalls++;
              return inboxFound;
            });

          await publishReaction(repository);
          await Future<void>.delayed(Duration.zero);

          // One recipient, one tap — the supersede kind-5 and the new kind-7
          // concern the same person at the same moment, so a second lookup
          // would be latency for an answer that cannot have changed.
          expect(resolveCalls, 1);
        },
      );

      test(
        'an emoji swap persists its deletion before inbox resolution finishes',
        () async {
          final deletionRumor = reactionRumor(
            id: _giftWrapId,
            content: '',
            kind: EventKind.eventDeletion,
            tags: [
              ['e', _reactionRumorId],
              ['k', EventKind.reaction.toString()],
            ],
          );
          stubPublishPath(superseded: const [_reactionRumorId]);
          when(
            () => mockMessageService.buildRumor(
              recipientPubkey: _otherPubkey,
              content: '',
              eventKind: EventKind.eventDeletion,
              additionalTags: any(named: 'additionalTags'),
            ),
          ).thenReturn(deletionRumor);
          when(
            () => mockDao.markOwnDeletionPending(
              id: _reactionRumorId,
              ownerPubkey: _ownerPubkey,
              deletionRumorJson: any(named: 'deletionRumorJson'),
            ),
          ).thenAnswer((_) async {});
          when(
            () => mockDao.markDeletionSent(
              id: _reactionRumorId,
              ownerPubkey: _ownerPubkey,
            ),
          ).thenAnswer((_) async {});

          final inboxResolution = Completer<DmInboxLookup>();
          addTearDown(() {
            if (!inboxResolution.isCompleted) {
              inboxResolution.complete(inboxFound);
            }
          });
          final repository = createRepository()
            ..setDmInboxRelayResolver((_) => inboxResolution.future);

          final publish = publishReaction(repository);
          await Future<void>.delayed(Duration.zero);

          verify(
            () => mockDao.markOwnDeletionPending(
              id: _reactionRumorId,
              ownerPubkey: _ownerPubkey,
              deletionRumorJson: any(named: 'deletionRumorJson'),
            ),
          ).called(1);

          inboxResolution.complete(inboxFound);
          await publish;
        },
      );
    });

    group('unreadable inbox is not delivery (#8443)', () {
      const thirdPubkey =
          '1111111111111111111111111111111111111111111111111111111111111111';
      const groupConversationId = 'group-convo-id';

      /// The relay a wrap was sent to — the default pool, when the inbox did
      /// not resolve — OK-confirms every recipient wrap.
      void stubSendRumorConfirmed(Event rumor) {
        when(
          () => mockMessageService.sendRumor(
            rumorEvent: any(named: 'rumorEvent'),
            recipientPubkey: any(named: 'recipientPubkey'),
            targetRelays: any(named: 'targetRelays'),
            awaitRecipientOk: any(named: 'awaitRecipientOk'),
          ),
        ).thenAnswer(
          (_) async => NIP17SendResult.success(
            rumorEventId: rumor.id,
            messageEventId: _giftWrapId,
            recipientPubkey: _otherPubkey,
          ),
        );
      }

      Event deletionRumor() => reactionRumor(
        id: _giftWrapId,
        content: '',
        kind: EventKind.eventDeletion,
        tags: [
          ['e', _reactionRumorId],
          ['k', EventKind.reaction.toString()],
        ],
      );

      test(
        'publish holds the reaction pending when the recipient inbox could '
        'not be read, even though the fallback pool confirmed the wrap',
        () async {
          final rumor = stubPublishPath();
          when(
            () => mockDao.markPending(id: rumor.id, ownerPubkey: _ownerPubkey),
          ).thenAnswer((_) async {});
          final repository = createRepository()
            ..setDmInboxRelayResolver((_) async => inboxUnreadable);

          final result = await publishReaction(repository);

          // Routing is unchanged: the wrap still went to the pool.
          verify(
            () => mockMessageService.sendRumor(
              rumorEvent: rumor,
              recipientPubkey: _otherPubkey,
              targetRelays: any(named: 'targetRelays', that: isNull),
              awaitRecipientOk: true,
            ),
          ).called(1);
          // But the pool's OK is not delivery to an inbox we never read. The
          // row stays `pending` with its rumor JSON so the sweep can
          // re-resolve; `swapPlaceholderId` clears that JSON and would make
          // the row unrecoverable, so it must never run here.
          expect(result.success, isFalse);
          verify(
            () => mockDao.markPending(id: rumor.id, ownerPubkey: _ownerPubkey),
          ).called(1);
          verifyNever(
            () => mockDao.swapPlaceholderId(
              placeholderId: any(named: 'placeholderId'),
              realRumorId: any(named: 'realRumorId'),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          );
          verifyNever(
            () => mockDao.markFailed(
              placeholderId: any(named: 'placeholderId'),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          );
        },
      );

      test(
        'publish still scores a fallback-pool OK as sent when the recipient '
        'genuinely advertises no inbox',
        () async {
          final rumor = stubPublishPath();
          final repository = createRepository()
            ..setDmInboxRelayResolver((_) async => inboxAbsent);

          final result = await publishReaction(repository);

          // Absent is a fact about the recipient: the pool is where they
          // read, so the OK is real delivery and reachability holds (#570).
          expect(result.success, isTrue);
          verify(
            () => mockDao.swapPlaceholderId(
              placeholderId: rumor.id,
              realRumorId: rumor.id,
              ownerPubkey: _ownerPubkey,
            ),
          ).called(1);
        },
      );

      test(
        'retry leaves the row pending and never swaps it to sent when the '
        'inbox is unreadable',
        () async {
          final rumor = reactionRumor();
          stubQueuedRow(
            rumorEventJson: jsonEncode(rumor.toJson()),
            publishStatus: 'failed',
          );
          when(
            () => mockDao.markPending(id: rumor.id, ownerPubkey: _ownerPubkey),
          ).thenAnswer((_) async {});
          stubSendRumorConfirmed(rumor);
          final repository = createRepository()
            ..setDmInboxRelayResolver((_) async => inboxUnreadable);

          final result = await repository.retry(
            rumorId: rumor.id,
            targetMessageAuthor: _otherPubkey,
          );

          // Without this the sweep undoes the publish path: it re-resolves
          // to the same unreadable inbox, republishes to the pool, and would
          // score that OK as sent one sweep later — #7317's retry half.
          expect(result.success, isFalse);
          verify(
            () => mockDao.markPending(id: rumor.id, ownerPubkey: _ownerPubkey),
          ).called(1);
          verify(
            () => mockMessageService.sendRumor(
              rumorEvent: any(named: 'rumorEvent'),
              recipientPubkey: _otherPubkey,
              targetRelays: any(named: 'targetRelays', that: isNull),
              awaitRecipientOk: true,
            ),
          ).called(1);
          verifyNever(
            () => mockDao.swapPlaceholderId(
              placeholderId: any(named: 'placeholderId'),
              realRumorId: any(named: 'realRumorId'),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          );
          verifyNever(
            () => mockDao.markFailed(
              placeholderId: any(named: 'placeholderId'),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          );
        },
      );

      test(
        'removeOwn keeps the kind-5 deletion_pending when the inbox is '
        'unreadable, so the removal is re-driven rather than assumed seen',
        () async {
          final deletion = deletionRumor();
          stubQueuedRow(publishStatus: 'sent');
          when(
            () => mockDao.markOwnDeletionPending(
              id: _reactionRumorId,
              ownerPubkey: _ownerPubkey,
              deletionRumorJson: any(named: 'deletionRumorJson'),
            ),
          ).thenAnswer((_) async {});
          when(
            () => mockMessageService.buildRumor(
              recipientPubkey: _otherPubkey,
              content: '',
              eventKind: EventKind.eventDeletion,
              additionalTags: any(named: 'additionalTags'),
            ),
          ).thenReturn(deletion);
          stubSendRumorConfirmed(deletion);
          final repository = createRepository()
            ..setDmInboxRelayResolver((_) async => inboxUnreadable);

          await repository.removeOwn(
            rumorId: _reactionRumorId,
            targetMessageAuthor: _otherPubkey,
          );
          // _driveDeletion fires via unawaited; let it run.
          await Future<void>.delayed(Duration.zero);

          verify(
            () => mockMessageService.sendRumor(
              rumorEvent: deletion,
              recipientPubkey: _otherPubkey,
              targetRelays: any(named: 'targetRelays', that: isNull),
              awaitRecipientOk: true,
            ),
          ).called(1);
          // A falsely `deletion_sent` row is worse than a falsely `sent` one:
          // it is already hidden (is_deleted = 1) and the terminal status
          // clears the stored kind-5, so nothing could ever re-drive the
          // removal the recipient may still be looking at.
          verifyNever(
            () => mockDao.markDeletionSent(
              id: any(named: 'id'),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          );
        },
      );

      test(
        'retryDeletion does not mark the removal deletion_sent when the '
        'inbox is unreadable',
        () async {
          final deletion = deletionRumor();
          when(
            () => mockDao.getById(
              id: _reactionRumorId,
              ownerPubkey: _ownerPubkey,
            ),
          ).thenAnswer(
            (_) async => makeRow(
              isDeleted: true,
              publishStatus: 'deletion_pending',
              rumorEventJson: jsonEncode(deletion.toJson()),
              recipientPubkeys: jsonEncode([_otherPubkey]),
            ),
          );
          stubSendRumorConfirmed(deletion);
          final repository = createRepository()
            ..setDmInboxRelayResolver((_) async => inboxUnreadable);

          final result = await repository.retryDeletion(
            rumorId: _reactionRumorId,
            targetMessageAuthor: _otherPubkey,
          );

          expect(result, DmReactionDeletionOutcome.unconfirmed);
          verifyNever(
            () => mockDao.markDeletionSent(
              id: any(named: 'id'),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          );
        },
      );

      test(
        'one unreadable member holds the whole group reaction pending, even '
        'though every other member confirmed',
        () async {
          final mockConversationsDao = _MockConversationsDao();
          when(
            () => mockConversationsDao.getConversation(
              groupConversationId,
              ownerPubkey: _ownerPubkey,
            ),
          ).thenAnswer(
            (_) async => ConversationRow(
              id: groupConversationId,
              participantPubkeys: jsonEncode([
                _ownerPubkey,
                _otherPubkey,
                thirdPubkey,
              ]),
              isGroup: true,
              isRead: true,
              currentUserHasSent: true,
              createdAt: 1700000000,
              ownerPubkey: _ownerPubkey,
            ),
          );
          final rumor = reactionRumor();
          when(
            () => mockMessageService.buildRumor(
              recipientPubkey: _otherPubkey,
              content: '🔥',
              eventKind: EventKind.reaction,
              additionalTags: any(named: 'additionalTags'),
            ),
          ).thenReturn(rumor);
          when(
            () => mockDao.insertOwnReactionSuperseding(
              placeholderId: any(named: 'placeholderId'),
              conversationId: any(named: 'conversationId'),
              targetMessageId: any(named: 'targetMessageId'),
              targetMessageAuthor: any(named: 'targetMessageAuthor'),
              reactorPubkey: any(named: 'reactorPubkey'),
              emoji: any(named: 'emoji'),
              createdAt: any(named: 'createdAt'),
              ownerPubkey: any(named: 'ownerPubkey'),
              rumorEventJson: any(named: 'rumorEventJson'),
              recipientPubkeys: any(named: 'recipientPubkeys'),
            ),
          ).thenAnswer((_) async => <String>[]);
          when(
            () => mockDao.markPending(id: rumor.id, ownerPubkey: _ownerPubkey),
          ).thenAnswer((_) async {});
          stubSendRumorConfirmed(rumor);
          final repository =
              createRepository(conversationsDao: mockConversationsDao)
                ..setDmInboxRelayResolver(
                  (pubkey) async =>
                      pubkey == thirdPubkey ? inboxUnreadable : inboxFound,
                );

          final result = await repository.publish(
            conversationId: groupConversationId,
            targetMessageId: _targetMessageId,
            targetMessageAuthor: _otherPubkey,
            emoji: '🔥',
          );

          // One row tracks the whole fan-out, so a member whose inbox we
          // could not read holds it — the same all-or-nothing rule as a
          // partial fan-out failure. The confirmed member's copy dedups on
          // the rumor id when the sweep re-drives.
          expect(result.success, isFalse);
          verify(
            () => mockDao.markPending(id: rumor.id, ownerPubkey: _ownerPubkey),
          ).called(1);
          verifyNever(
            () => mockDao.swapPlaceholderId(
              placeholderId: any(named: 'placeholderId'),
              realRumorId: any(named: 'realRumorId'),
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          );
        },
      );
    });
  });
}
