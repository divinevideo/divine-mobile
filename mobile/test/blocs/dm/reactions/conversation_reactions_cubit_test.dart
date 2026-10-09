// ABOUTME: Cubit tests for ConversationReactionsCubit.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/reactions/conversation_reactions_cubit.dart';

class _MockReactionsRepository extends Mock implements DmReactionsRepository {}

const _owner =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _peer =
    '2222222222222222222222222222222222222222222222222222222222222222';
const _convo =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const _msgId =
    'mmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmm';

void main() {
  group(ConversationReactionsCubit, () {
    late _MockReactionsRepository repo;
    late StreamController<List<DmReaction>> streamController;
    late Completer<void> watching;

    setUp(() {
      repo = _MockReactionsRepository();
      watching = Completer<void>();
      streamController = StreamController<List<DmReaction>>.broadcast(
        onListen: watching.complete,
      );
      when(
        () => repo.watchForConversation(any()),
      ).thenAnswer((_) => streamController.stream);
      when(
        () => repo.hasOutstandingOwnDeletion(
          targetMessageId: any(named: 'targetMessageId'),
        ),
      ).thenAnswer((_) async => false);
    });

    tearDown(() async {
      await streamController.close();
    });

    blocTest<ConversationReactionsCubit, ConversationReactionsState>(
      'transitions through loading -> loaded on subscription tick',
      build: () => ConversationReactionsCubit(
        reactionsRepository: repo,
        ownerPubkey: _owner,
      ),
      act: (cubit) async {
        cubit.add(
          const ConversationReactionsStarted(conversationId: _convo),
        );
        await watching.future;
        streamController.add(const <DmReaction>[]);
      },
      expect: () => [
        isA<ConversationReactionsState>().having(
          (s) => s.status,
          'status',
          ConversationReactionsStatus.loading,
        ),
        isA<ConversationReactionsState>().having(
          (s) => s.status,
          'status',
          ConversationReactionsStatus.loaded,
        ),
      ],
    );

    blocTest<ConversationReactionsCubit, ConversationReactionsState>(
      'toggle publishes; pending then cleared on success',
      build: () {
        when(
          () => repo.publish(
            conversationId: any(named: 'conversationId'),
            targetMessageId: any(named: 'targetMessageId'),
            targetMessageAuthor: any(named: 'targetMessageAuthor'),
            emoji: any(named: 'emoji'),
          ),
        ).thenAnswer(
          (_) async => const DmReactionPublishResult(
            success: true,
            rumorId: 'r-1',
          ),
        );
        return ConversationReactionsCubit(
          reactionsRepository: repo,
          ownerPubkey: _owner,
        );
      },
      act: (cubit) async {
        cubit.add(
          const ConversationReactionToggled(
            conversationId: _convo,
            messageId: _msgId,
            messageAuthorPubkey: _peer,
            emoji: '❤️',
          ),
        );
      },
      expect: () => [
        isA<ConversationReactionsState>().having(
          (s) =>
              s.pending[const ReactionPublishKey(
                messageId: _msgId,
                emoji: '❤️',
              )],
          'pending entry',
          ReactionPublishLocalStatus.sending,
        ),
        isA<ConversationReactionsState>().having(
          (s) => s.pending.isEmpty,
          'pending cleared',
          isTrue,
        ),
      ],
    );

    blocTest<ConversationReactionsCubit, ConversationReactionsState>(
      'toggle publish failure marks pending as failed',
      build: () {
        when(
          () => repo.publish(
            conversationId: any(named: 'conversationId'),
            targetMessageId: any(named: 'targetMessageId'),
            targetMessageAuthor: any(named: 'targetMessageAuthor'),
            emoji: any(named: 'emoji'),
          ),
        ).thenAnswer(
          (_) async => const DmReactionPublishResult(
            success: false,
            rumorId: 'r-2',
            errorMessage: 'relay down',
          ),
        );
        return ConversationReactionsCubit(
          reactionsRepository: repo,
          ownerPubkey: _owner,
        );
      },
      act: (cubit) async {
        cubit.add(
          const ConversationReactionToggled(
            conversationId: _convo,
            messageId: _msgId,
            messageAuthorPubkey: _peer,
            emoji: '🔥',
          ),
        );
      },
      verify: (cubit) {
        final entry =
            cubit.state.pending[const ReactionPublishKey(
              messageId: _msgId,
              emoji: '🔥',
            )];
        expect(entry, ReactionPublishLocalStatus.failed);
      },
    );

    DmReaction ownReaction(String emoji) => DmReaction(
      id: 'own-$emoji',
      conversationId: _convo,
      targetMessageId: _msgId,
      targetMessageAuthor: _peer,
      reactorPubkey: _owner,
      emoji: emoji,
      createdAt: 1700000000,
      ownerPubkey: _owner,
      publishStatus: DmReactionPublishStatus.sent,
    );

    DmReaction ownReactionStatus(
      String emoji,
      DmReactionPublishStatus status,
    ) => DmReaction(
      id: 'own-$emoji',
      conversationId: _convo,
      targetMessageId: _msgId,
      targetMessageAuthor: _peer,
      reactorPubkey: _owner,
      emoji: emoji,
      createdAt: 1700000000,
      ownerPubkey: _owner,
      publishStatus: status,
    );

    blocTest<ConversationReactionsCubit, ConversationReactionsState>(
      'set publishes when there is no active reaction',
      build: () {
        when(
          () => repo.publish(
            conversationId: any(named: 'conversationId'),
            targetMessageId: any(named: 'targetMessageId'),
            targetMessageAuthor: any(named: 'targetMessageAuthor'),
            emoji: any(named: 'emoji'),
          ),
        ).thenAnswer(
          (_) async =>
              const DmReactionPublishResult(success: true, rumorId: 'r-set'),
        );
        return ConversationReactionsCubit(
          reactionsRepository: repo,
          ownerPubkey: _owner,
        );
      },
      act: (cubit) => cubit.add(
        const ConversationReactionSet(
          conversationId: _convo,
          messageId: _msgId,
          messageAuthorPubkey: _peer,
          emoji: '❤️',
        ),
      ),
      verify: (_) {
        verify(
          () => repo.publish(
            conversationId: _convo,
            targetMessageId: _msgId,
            targetMessageAuthor: _peer,
            emoji: '❤️',
          ),
        ).called(1);
      },
    );

    blocTest<ConversationReactionsCubit, ConversationReactionsState>(
      'set is a no-op when the active emoji already matches',
      build: () {
        when(
          () => repo.publish(
            conversationId: any(named: 'conversationId'),
            targetMessageId: any(named: 'targetMessageId'),
            targetMessageAuthor: any(named: 'targetMessageAuthor'),
            emoji: any(named: 'emoji'),
          ),
        ).thenAnswer(
          (_) async =>
              const DmReactionPublishResult(success: true, rumorId: 'x'),
        );
        return ConversationReactionsCubit(
          reactionsRepository: repo,
          ownerPubkey: _owner,
        );
      },
      act: (cubit) async {
        cubit.add(const ConversationReactionsStarted(conversationId: _convo));
        await watching.future;
        streamController.add([ownReaction('❤️')]);
        await pumpEventQueue();
        cubit.add(
          const ConversationReactionSet(
            conversationId: _convo,
            messageId: _msgId,
            messageAuthorPubkey: _peer,
            emoji: '❤️',
          ),
        );
        await pumpEventQueue();
      },
      verify: (_) {
        verifyNever(
          () => repo.publish(
            conversationId: any(named: 'conversationId'),
            targetMessageId: any(named: 'targetMessageId'),
            targetMessageAuthor: any(named: 'targetMessageAuthor'),
            emoji: any(named: 'emoji'),
          ),
        );
        // And it must NOT remove the active reaction (set != toggle).
        verifyNever(
          () => repo.removeOwn(
            rumorId: any(named: 'rumorId'),
            targetMessageAuthor: any(named: 'targetMessageAuthor'),
          ),
        );
      },
    );

    blocTest<ConversationReactionsCubit, ConversationReactionsState>(
      'rapid double-tap set is a no-op during the pre-persist optimistic '
      'window (publishes once)',
      build: () {
        when(
          () => repo.publish(
            conversationId: any(named: 'conversationId'),
            targetMessageId: any(named: 'targetMessageId'),
            targetMessageAuthor: any(named: 'targetMessageAuthor'),
            emoji: any(named: 'emoji'),
          ),
        ).thenAnswer(
          (_) async =>
              const DmReactionPublishResult(success: true, rumorId: 'r-set'),
        );
        return ConversationReactionsCubit(
          reactionsRepository: repo,
          ownerPubkey: _owner,
        );
      },
      act: (cubit) async {
        final published = cubit.stream.firstWhere(
          (state) => state.pending.isEmpty && state.optimistic.isNotEmpty,
        );
        // Two sets in a burst, before any persisted row (or stream tick) lands.
        // The first paints the optimistic ❤️; the second must see it via the
        // optimistic-inclusive guard and no-op — so only one gift-wrap is sent
        // and the pre-persist window can't fan out duplicates.
        cubit
          ..add(
            const ConversationReactionSet(
              conversationId: _convo,
              messageId: _msgId,
              messageAuthorPubkey: _peer,
              emoji: '❤️',
            ),
          )
          ..add(
            const ConversationReactionSet(
              conversationId: _convo,
              messageId: _msgId,
              messageAuthorPubkey: _peer,
              emoji: '❤️',
            ),
          );
        await published;
      },
      verify: (_) {
        verify(
          () => repo.publish(
            conversationId: _convo,
            targetMessageId: _msgId,
            targetMessageAuthor: _peer,
            emoji: '❤️',
          ),
        ).called(1);
      },
    );

    blocTest<ConversationReactionsCubit, ConversationReactionsState>(
      'set with a different emoji publishes (supersede handled by repo)',
      build: () {
        when(
          () => repo.publish(
            conversationId: any(named: 'conversationId'),
            targetMessageId: any(named: 'targetMessageId'),
            targetMessageAuthor: any(named: 'targetMessageAuthor'),
            emoji: any(named: 'emoji'),
          ),
        ).thenAnswer(
          (_) async =>
              const DmReactionPublishResult(success: true, rumorId: 'r-new'),
        );
        return ConversationReactionsCubit(
          reactionsRepository: repo,
          ownerPubkey: _owner,
        );
      },
      act: (cubit) async {
        cubit.add(const ConversationReactionsStarted(conversationId: _convo));
        await watching.future;
        streamController.add([ownReaction('❤️')]);
        await pumpEventQueue();
        cubit.add(
          const ConversationReactionSet(
            conversationId: _convo,
            messageId: _msgId,
            messageAuthorPubkey: _peer,
            emoji: '😂',
          ),
        );
        await pumpEventQueue();
      },
      verify: (_) {
        verify(
          () => repo.publish(
            conversationId: _convo,
            targetMessageId: _msgId,
            targetMessageAuthor: _peer,
            emoji: '😂',
          ),
        ).called(1);
      },
    );

    blocTest<ConversationReactionsCubit, ConversationReactionsState>(
      'subscription tick groups reactions by message id',
      build: () => ConversationReactionsCubit(
        reactionsRepository: repo,
        ownerPubkey: _owner,
      ),
      act: (cubit) async {
        cubit.add(
          const ConversationReactionsStarted(conversationId: _convo),
        );
        await watching.future;
        streamController.add([
          const DmReaction(
            id: 'r-3',
            conversationId: _convo,
            targetMessageId: _msgId,
            targetMessageAuthor: _peer,
            reactorPubkey: _peer,
            emoji: '👍',
            createdAt: 1700000000,
            ownerPubkey: _owner,
            publishStatus: DmReactionPublishStatus.received,
          ),
        ]);
      },
      verify: (cubit) {
        final list = cubit.state.reactionsByMessageId[_msgId];
        expect(list, isNotNull);
        expect(list!.length, 1);
        expect(list.first.emoji, '👍');
      },
    );

    group('optimistic chip (#5389)', () {
      bool ownPending(ConversationReactionsState s, String emoji) => s
          .reactionsFor(_msgId)
          .any(
            (r) =>
                r.reactorPubkey == _owner &&
                r.emoji == emoji &&
                r.publishStatus == DmReactionPublishStatus.pending,
          );

      blocTest<ConversationReactionsCubit, ConversationReactionsState>(
        'paints the own chip synchronously, before the publish resolves',
        build: () {
          when(
            () => repo.publish(
              conversationId: any(named: 'conversationId'),
              targetMessageId: any(named: 'targetMessageId'),
              targetMessageAuthor: any(named: 'targetMessageAuthor'),
              emoji: any(named: 'emoji'),
            ),
          ).thenAnswer(
            (_) async =>
                const DmReactionPublishResult(success: true, rumorId: 'r-1'),
          );
          return ConversationReactionsCubit(
            reactionsRepository: repo,
            ownerPubkey: _owner,
          );
        },
        act: (cubit) => cubit.add(
          const ConversationReactionToggled(
            conversationId: _convo,
            messageId: _msgId,
            messageAuthorPubkey: _peer,
            emoji: '❤️',
          ),
        ),
        expect: () => [
          // FIRST emit already carries the chip — no stream tick, no DB wait.
          isA<ConversationReactionsState>()
              .having(
                (s) => ownPending(s, '❤️'),
                'optimistic chip present',
                isTrue,
              )
              .having(
                (s) =>
                    s.pending[const ReactionPublishKey(
                      messageId: _msgId,
                      emoji: '❤️',
                    )],
                'pending sending',
                ReactionPublishLocalStatus.sending,
              ),
          // After publish: pending cleared, overlay still bridges until a tick.
          isA<ConversationReactionsState>()
              .having((s) => s.pending.isEmpty, 'pending cleared', isTrue)
              .having((s) => ownPending(s, '❤️'), 'chip still present', isTrue),
        ],
      );

      blocTest<ConversationReactionsCubit, ConversationReactionsState>(
        'reconciles the optimistic add when the persisted row arrives (no dupe)',
        build: () {
          when(
            () => repo.publish(
              conversationId: any(named: 'conversationId'),
              targetMessageId: any(named: 'targetMessageId'),
              targetMessageAuthor: any(named: 'targetMessageAuthor'),
              emoji: any(named: 'emoji'),
            ),
          ).thenAnswer(
            (_) async =>
                const DmReactionPublishResult(success: true, rumorId: 'r-1'),
          );
          return ConversationReactionsCubit(
            reactionsRepository: repo,
            ownerPubkey: _owner,
          );
        },
        act: (cubit) async {
          cubit.add(const ConversationReactionsStarted(conversationId: _convo));
          await watching.future;
          cubit.add(
            const ConversationReactionToggled(
              conversationId: _convo,
              messageId: _msgId,
              messageAuthorPubkey: _peer,
              emoji: '❤️',
            ),
          );
          await pumpEventQueue();
          streamController.add([ownReaction('❤️')]);
          await pumpEventQueue();
        },
        verify: (cubit) {
          expect(cubit.state.optimistic, isEmpty);
          final chips = cubit.state
              .reactionsFor(_msgId)
              .where((r) => r.emoji == '❤️')
              .toList();
          expect(chips, hasLength(1));
          expect(chips.first.publishStatus, DmReactionPublishStatus.sent);
        },
      );

      blocTest<ConversationReactionsCubit, ConversationReactionsState>(
        'toggle-off hides the own chip synchronously',
        build: () {
          when(
            () => repo.removeOwn(
              rumorId: any(named: 'rumorId'),
              targetMessageAuthor: any(named: 'targetMessageAuthor'),
            ),
          ).thenAnswer((_) async {});
          return ConversationReactionsCubit(
            reactionsRepository: repo,
            ownerPubkey: _owner,
          );
        },
        act: (cubit) async {
          cubit.add(const ConversationReactionsStarted(conversationId: _convo));
          await watching.future;
          streamController.add([ownReaction('❤️')]);
          await pumpEventQueue();
          cubit.add(
            const ConversationReactionToggled(
              conversationId: _convo,
              messageId: _msgId,
              messageAuthorPubkey: _peer,
              emoji: '❤️',
            ),
          );
          await pumpEventQueue();
        },
        verify: (cubit) {
          expect(
            cubit.state.reactionsFor(_msgId).any((r) => r.isOwn),
            isFalse,
          );
          verify(
            () => repo.removeOwn(
              rumorId: 'own-❤️',
              targetMessageAuthor: _peer,
            ),
          ).called(1);
        },
      );

      blocTest<ConversationReactionsCubit, ConversationReactionsState>(
        'toggle-off puts the own chip back when the removal fails',
        build: () {
          when(
            () => repo.removeOwn(
              rumorId: any(named: 'rumorId'),
              targetMessageAuthor: any(named: 'targetMessageAuthor'),
            ),
          ).thenAnswer((_) async => throw Exception('disk I/O error'));
          return ConversationReactionsCubit(
            reactionsRepository: repo,
            ownerPubkey: _owner,
          );
        },
        act: (cubit) async {
          cubit.add(const ConversationReactionsStarted(conversationId: _convo));
          await watching.future;
          streamController.add([ownReaction('❤️')]);
          await pumpEventQueue();
          cubit.add(
            const ConversationReactionToggled(
              conversationId: _convo,
              messageId: _msgId,
              messageAuthorPubkey: _peer,
              emoji: '❤️',
            ),
          );
          await pumpEventQueue();
        },
        errors: () => [isA<Exception>()],
        verify: (cubit) {
          expect(cubit.state.optimistic, isEmpty);
          expect(
            cubit.state.reactionsFor(_msgId).where((r) => r.isOwn),
            hasLength(1),
          );
          verify(
            () => repo.removeOwn(
              rumorId: 'own-❤️',
              targetMessageAuthor: _peer,
            ),
          ).called(1);
        },
      );

      for (final status in [
        DmReactionPublishStatus.failed,
        DmReactionPublishStatus.pending,
      ]) {
        blocTest<ConversationReactionsCubit, ConversationReactionsState>(
          're-tapping a $status own reaction retries instead of removing it',
          build: () {
            when(
              () => repo.retry(
                rumorId: any(named: 'rumorId'),
                targetMessageAuthor: any(named: 'targetMessageAuthor'),
              ),
            ).thenAnswer(
              (_) async => const DmReactionPublishResult(
                success: true,
                rumorId: 'own-❤️',
                optimisticInsertSucceeded: true,
              ),
            );
            return ConversationReactionsCubit(
              reactionsRepository: repo,
              ownerPubkey: _owner,
            );
          },
          act: (cubit) async {
            cubit.add(
              const ConversationReactionsStarted(conversationId: _convo),
            );
            await watching.future;
            streamController.add([ownReactionStatus('❤️', status)]);
            await pumpEventQueue();
            cubit.add(
              const ConversationReactionToggled(
                conversationId: _convo,
                messageId: _msgId,
                messageAuthorPubkey: _peer,
                emoji: '❤️',
              ),
            );
            await pumpEventQueue();
          },
          verify: (_) {
            // A re-tap on an undelivered reaction re-drives delivery; it must
            // NOT be read as toggle-off (which soft-deletes it + emits a
            // kind-5, permanently losing a reaction the recipient may have).
            verify(
              () => repo.retry(rumorId: 'own-❤️', targetMessageAuthor: _peer),
            ).called(1);
            verifyNever(
              () => repo.removeOwn(
                rumorId: any(named: 'rumorId'),
                targetMessageAuthor: any(named: 'targetMessageAuthor'),
              ),
            );
          },
        );
      }

      blocTest<ConversationReactionsCubit, ConversationReactionsState>(
        're-tapping a refused removal retries its stored deletion',
        build: () {
          when(
            () => repo.retryDeletion(
              rumorId: any(named: 'rumorId'),
              targetMessageAuthor: any(named: 'targetMessageAuthor'),
            ),
          ).thenAnswer((_) async => DmReactionDeletionOutcome.sent);
          return ConversationReactionsCubit(
            reactionsRepository: repo,
            ownerPubkey: _owner,
          );
        },
        act: (cubit) async {
          cubit.add(
            const ConversationReactionsStarted(conversationId: _convo),
          );
          await watching.future;
          streamController.add([
            ownReactionStatus(
              '❤️',
              DmReactionPublishStatus.removalRefused,
            ),
          ]);
          await pumpEventQueue();
          cubit.add(
            const ConversationReactionToggled(
              conversationId: _convo,
              messageId: _msgId,
              messageAuthorPubkey: _peer,
              emoji: '❤️',
            ),
          );
          await pumpEventQueue();
        },
        verify: (_) {
          verify(
            () => repo.retryDeletion(
              rumorId: 'own-❤️',
              targetMessageAuthor: _peer,
            ),
          ).called(1);
          verifyNever(
            () => repo.removeOwn(
              rumorId: any(named: 'rumorId'),
              targetMessageAuthor: any(named: 'targetMessageAuthor'),
            ),
          );
        },
      );

      blocTest<ConversationReactionsCubit, ConversationReactionsState>(
        'a removal retry replays the stored deletion, not the reaction',
        build: () {
          when(
            () => repo.retryDeletion(
              rumorId: any(named: 'rumorId'),
              targetMessageAuthor: any(named: 'targetMessageAuthor'),
            ),
          ).thenAnswer((_) async => DmReactionDeletionOutcome.sent);
          return ConversationReactionsCubit(
            reactionsRepository: repo,
            ownerPubkey: _owner,
          );
        },
        act: (cubit) => cubit.add(
          const ConversationReactionRemovalRetryRequested(
            rumorId: 'own-❤️',
            messageAuthorPubkey: _peer,
          ),
        ),
        verify: (_) {
          verify(
            () => repo.retryDeletion(
              rumorId: 'own-❤️',
              targetMessageAuthor: _peer,
            ),
          ).called(1);
          verifyNever(
            () => repo.retry(
              rumorId: any(named: 'rumorId'),
              targetMessageAuthor: any(named: 'targetMessageAuthor'),
            ),
          );
        },
      );

      blocTest<ConversationReactionsCubit, ConversationReactionsState>(
        'a different emoji cannot orphan a refused removal',
        build: () => ConversationReactionsCubit(
          reactionsRepository: repo,
          ownerPubkey: _owner,
        ),
        act: (cubit) async {
          cubit.add(const ConversationReactionsStarted(conversationId: _convo));
          await watching.future;
          streamController.add([
            ownReactionStatus(
              '❤️',
              DmReactionPublishStatus.removalRefused,
            ),
          ]);
          await pumpEventQueue();
          cubit.add(
            const ConversationReactionToggled(
              conversationId: _convo,
              messageId: _msgId,
              messageAuthorPubkey: _peer,
              emoji: '🔥',
            ),
          );
          await pumpEventQueue();
        },
        verify: (cubit) {
          verifyNever(
            () => repo.publish(
              conversationId: any(named: 'conversationId'),
              targetMessageId: any(named: 'targetMessageId'),
              targetMessageAuthor: any(named: 'targetMessageAuthor'),
              emoji: any(named: 'emoji'),
            ),
          );
          expect(
            cubit.state.reactionsFor(_msgId).single.publishStatus,
            DmReactionPublishStatus.removalRefused,
          );
          expect(cubit.state.blockedReactionAttempts, 1);
        },
      );

      blocTest<ConversationReactionsCubit, ConversationReactionsState>(
        'set cannot orphan a refused removal',
        build: () => ConversationReactionsCubit(
          reactionsRepository: repo,
          ownerPubkey: _owner,
        ),
        act: (cubit) async {
          cubit.add(const ConversationReactionsStarted(conversationId: _convo));
          await watching.future;
          streamController.add([
            ownReactionStatus(
              '🔥',
              DmReactionPublishStatus.removalRefused,
            ),
          ]);
          await pumpEventQueue();
          cubit.add(
            const ConversationReactionSet(
              conversationId: _convo,
              messageId: _msgId,
              messageAuthorPubkey: _peer,
              emoji: '❤️',
            ),
          );
          await pumpEventQueue();
        },
        verify: (cubit) {
          verifyNever(
            () => repo.publish(
              conversationId: any(named: 'conversationId'),
              targetMessageId: any(named: 'targetMessageId'),
              targetMessageAuthor: any(named: 'targetMessageAuthor'),
              emoji: any(named: 'emoji'),
            ),
          );
          expect(cubit.state.blockedReactionAttempts, 1);
        },
      );

      for (final useSet in [false, true]) {
        blocTest<ConversationReactionsCubit, ConversationReactionsState>(
          '${useSet ? 'set' : 'toggle'} cannot overtake a pending removal',
          setUp: () {
            when(
              () => repo.hasOutstandingOwnDeletion(
                targetMessageId: _msgId,
              ),
            ).thenAnswer((_) async => true);
          },
          build: () => ConversationReactionsCubit(
            reactionsRepository: repo,
            ownerPubkey: _owner,
          ),
          act: (cubit) {
            if (useSet) {
              cubit.add(
                const ConversationReactionSet(
                  conversationId: _convo,
                  messageId: _msgId,
                  messageAuthorPubkey: _peer,
                  emoji: '🔥',
                ),
              );
            } else {
              cubit.add(
                const ConversationReactionToggled(
                  conversationId: _convo,
                  messageId: _msgId,
                  messageAuthorPubkey: _peer,
                  emoji: '🔥',
                ),
              );
            }
          },
          expect: () => [
            isA<ConversationReactionsState>().having(
              (state) => state.blockedReactionAttempts,
              'blocked attempts',
              1,
            ),
          ],
          verify: (_) {
            verifyNever(
              () => repo.publish(
                conversationId: any(named: 'conversationId'),
                targetMessageId: any(named: 'targetMessageId'),
                targetMessageAuthor: any(named: 'targetMessageAuthor'),
                emoji: any(named: 'emoji'),
              ),
            );
          },
        );
      }

      for (final outcome in DmReactionDeletionOutcome.values) {
        blocTest<ConversationReactionsCubit, ConversationReactionsState>(
          'surfaces the $outcome removal retry outcome',
          build: () {
            when(
              () => repo.retryDeletion(
                rumorId: any(named: 'rumorId'),
                targetMessageAuthor: any(named: 'targetMessageAuthor'),
              ),
            ).thenAnswer((_) async => outcome);
            return ConversationReactionsCubit(
              reactionsRepository: repo,
              ownerPubkey: _owner,
            );
          },
          act: (cubit) => cubit.add(
            const ConversationReactionRemovalRetryRequested(
              rumorId: 'own-❤️',
              messageAuthorPubkey: _peer,
            ),
          ),
          verify: (cubit) {
            expect(
              cubit.state.removalRetries['own-❤️'],
              switch (outcome) {
                DmReactionDeletionOutcome.sent =>
                  ReactionRemovalRetryLocalStatus.sent,
                DmReactionDeletionOutcome.refused =>
                  ReactionRemovalRetryLocalStatus.refused,
                DmReactionDeletionOutcome.unconfirmed =>
                  ReactionRemovalRetryLocalStatus.unconfirmed,
                DmReactionDeletionOutcome.unavailable =>
                  ReactionRemovalRetryLocalStatus.unavailable,
              },
            );
          },
        );
      }

      blocTest<ConversationReactionsCubit, ConversationReactionsState>(
        'a refused deletion row clears the optimistic removal overlay',
        build: () => ConversationReactionsCubit(
          reactionsRepository: repo,
          ownerPubkey: _owner,
        ),
        act: (cubit) async {
          cubit.add(const ConversationReactionsStarted(conversationId: _convo));
          await watching.future;
          streamController.add([ownReaction('❤️')]);
          await pumpEventQueue();
          when(
            () => repo.removeOwn(
              rumorId: any(named: 'rumorId'),
              targetMessageAuthor: any(named: 'targetMessageAuthor'),
            ),
          ).thenAnswer((_) async {});
          cubit.add(
            const ConversationReactionToggled(
              conversationId: _convo,
              messageId: _msgId,
              messageAuthorPubkey: _peer,
              emoji: '❤️',
            ),
          );
          await pumpEventQueue();
          streamController.add([
            ownReactionStatus(
              '❤️',
              DmReactionPublishStatus.removalRefused,
            ),
          ]);
        },
        verify: (cubit) {
          expect(cubit.state.optimistic, isEmpty);
          expect(
            cubit.state.reactionsFor(_msgId).single.publishStatus,
            DmReactionPublishStatus.removalRefused,
          );
        },
      );

      blocTest<ConversationReactionsCubit, ConversationReactionsState>(
        'keeps the optimistic chip on a durable-row publish failure '
        '(before the DAO stream ticks)',
        build: () {
          when(
            () => repo.publish(
              conversationId: any(named: 'conversationId'),
              targetMessageId: any(named: 'targetMessageId'),
              targetMessageAuthor: any(named: 'targetMessageAuthor'),
              emoji: any(named: 'emoji'),
            ),
          ).thenAnswer(
            (_) async => const DmReactionPublishResult(
              success: false,
              rumorId: 'r-unconf',
              errorMessage: 'unconfirmed',
              optimisticInsertSucceeded: true,
            ),
          );
          return ConversationReactionsCubit(
            reactionsRepository: repo,
            ownerPubkey: _owner,
          );
        },
        act: (cubit) => cubit.add(
          const ConversationReactionToggled(
            conversationId: _convo,
            messageId: _msgId,
            messageAuthorPubkey: _peer,
            emoji: '🔥',
          ),
        ),
        verify: (cubit) {
          // The durable row exists (the DAO stream just hasn't re-emitted yet),
          // so the chip must stay visible rather than blank to nothing and
          // invite a "repair" re-tap.
          final own = cubit.state
              .reactionsFor(_msgId)
              .where((r) => r.isOwn)
              .toList();
          expect(own, hasLength(1));
          expect(own.first.emoji, '🔥');
          expect(cubit.state.optimistic, isNotEmpty);
        },
      );

      blocTest<ConversationReactionsCubit, ConversationReactionsState>(
        'set with a different emoji optimistically swaps the chip',
        build: () {
          when(
            () => repo.publish(
              conversationId: any(named: 'conversationId'),
              targetMessageId: any(named: 'targetMessageId'),
              targetMessageAuthor: any(named: 'targetMessageAuthor'),
              emoji: any(named: 'emoji'),
            ),
          ).thenAnswer(
            (_) async =>
                const DmReactionPublishResult(success: true, rumorId: 'r-new'),
          );
          return ConversationReactionsCubit(
            reactionsRepository: repo,
            ownerPubkey: _owner,
          );
        },
        act: (cubit) async {
          cubit.add(const ConversationReactionsStarted(conversationId: _convo));
          await watching.future;
          streamController.add([ownReaction('❤️')]);
          await pumpEventQueue();
          cubit.add(
            const ConversationReactionSet(
              conversationId: _convo,
              messageId: _msgId,
              messageAuthorPubkey: _peer,
              emoji: '😂',
            ),
          );
          await pumpEventQueue();
        },
        verify: (cubit) {
          final emojis = cubit.state
              .reactionsFor(_msgId)
              .where((r) => r.isOwn)
              .map((r) => r.emoji)
              .toSet();
          expect(emojis, contains('😂'));
          expect(emojis, isNot(contains('❤️')));
        },
      );

      blocTest<ConversationReactionsCubit, ConversationReactionsState>(
        'drops the optimistic add when the insert never persisted',
        build: () {
          when(
            () => repo.publish(
              conversationId: any(named: 'conversationId'),
              targetMessageId: any(named: 'targetMessageId'),
              targetMessageAuthor: any(named: 'targetMessageAuthor'),
              emoji: any(named: 'emoji'),
            ),
          ).thenAnswer(
            (_) async => const DmReactionPublishResult(
              success: false,
              rumorId: 'r-x',
              errorMessage: 'Optimistic insert failed',
            ),
          );
          return ConversationReactionsCubit(
            reactionsRepository: repo,
            ownerPubkey: _owner,
          );
        },
        act: (cubit) => cubit.add(
          const ConversationReactionToggled(
            conversationId: _convo,
            messageId: _msgId,
            messageAuthorPubkey: _peer,
            emoji: '🔥',
          ),
        ),
        verify: (cubit) {
          expect(cubit.state.optimistic, isEmpty);
          expect(cubit.state.reactionsFor(_msgId), isEmpty);
          expect(
            cubit.state.pending[const ReactionPublishKey(
              messageId: _msgId,
              emoji: '🔥',
            )],
            ReactionPublishLocalStatus.failed,
          );
        },
      );
    });
  });

  group('ConversationReactionsState.ownReactionPendingOrLive', () {
    const heart = '❤️';

    DmReaction reaction({
      required String id,
      required String reactor,
      required String emoji,
      DmReactionPublishStatus status = DmReactionPublishStatus.sent,
    }) => DmReaction(
      id: id,
      conversationId: _convo,
      targetMessageId: _msgId,
      targetMessageAuthor: _peer,
      reactorPubkey: reactor,
      emoji: emoji,
      createdAt: 1700000000,
      ownerPubkey: _owner,
      publishStatus: status,
    );

    test('true when the owner has a persisted matching reaction', () {
      final state = ConversationReactionsState(
        reactionsByMessageId: {
          _msgId: [reaction(id: 'own', reactor: _owner, emoji: heart)],
        },
      );
      expect(
        state.ownReactionPendingOrLive(
          messageId: _msgId,
          emoji: heart,
          ownerPubkey: _owner,
        ),
        isTrue,
      );
    });

    test('false when the message has no reactions', () {
      const state = ConversationReactionsState();
      expect(
        state.ownReactionPendingOrLive(
          messageId: _msgId,
          emoji: heart,
          ownerPubkey: _owner,
        ),
        isFalse,
      );
    });

    test('false when only another reactor has the emoji', () {
      final state = ConversationReactionsState(
        reactionsByMessageId: {
          _msgId: [reaction(id: 'peer', reactor: _peer, emoji: heart)],
        },
      );
      expect(
        state.ownReactionPendingOrLive(
          messageId: _msgId,
          emoji: heart,
          ownerPubkey: _owner,
        ),
        isFalse,
      );
    });

    test('true from an optimistic add before the row persists', () {
      final state = ConversationReactionsState(
        optimistic: {
          const ReactionPublishKey(
            messageId: _msgId,
            emoji: heart,
          ): OptimisticReactionAdded(
            reaction(
              id: 'optimistic:$_msgId:$heart',
              reactor: _owner,
              emoji: heart,
              status: DmReactionPublishStatus.pending,
            ),
          ),
        },
      );
      expect(
        state.ownReactionPendingOrLive(
          messageId: _msgId,
          emoji: heart,
          ownerPubkey: _owner,
        ),
        isTrue,
      );
      // The persisted-only getter does NOT see the optimistic overlay — this
      // is exactly the pre-persist window the double-tap guard must cover.
      expect(
        state.ownReactionMatches(
          messageId: _msgId,
          emoji: heart,
          ownerPubkey: _owner,
        ),
        isFalse,
      );
    });

    test('false when an optimistic remove hides the persisted reaction', () {
      final state = ConversationReactionsState(
        reactionsByMessageId: {
          _msgId: [reaction(id: 'own', reactor: _owner, emoji: heart)],
        },
        optimistic: {
          const ReactionPublishKey(messageId: _msgId, emoji: heart):
              const OptimisticReactionRemoved(),
        },
      );
      expect(
        state.ownReactionPendingOrLive(
          messageId: _msgId,
          emoji: heart,
          ownerPubkey: _owner,
        ),
        isFalse,
      );
    });
  });
}
