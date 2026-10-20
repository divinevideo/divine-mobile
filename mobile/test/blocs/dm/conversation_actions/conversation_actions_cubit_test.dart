// ABOUTME: Tests for ConversationActionsCubit — block, remove.
// ABOUTME: Verifies service delegation, return values, and error handling.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/conversation_actions/conversation_actions_cubit.dart';

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

class _MockDmRepository extends Mock implements DmRepository {}

void main() {
  const pubkey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const currentUserPubkey =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  const conversationId =
      'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

  group(ConversationActionsCubit, () {
    late _MockContentBlocklistRepository mockBlocklistRepository;
    late _MockDmRepository mockDmRepo;

    setUp(() {
      mockBlocklistRepository = _MockContentBlocklistRepository();
      mockDmRepo = _MockDmRepository();
    });

    ConversationActionsCubit createCubit() => ConversationActionsCubit(
      contentBlocklistRepository: mockBlocklistRepository,
      dmRepository: mockDmRepo,
      currentUserPubkey: currentUserPubkey,
    );

    test('does not emit or throw when closed mid-block', () async {
      final completer = Completer<bool>();
      when(
        () => mockBlocklistRepository.blockUser(
          pubkey,
          ourPubkey: currentUserPubkey,
        ),
      ).thenAnswer((_) => completer.future);

      final cubit = createCubit();
      final future = cubit.blockUser(pubkey);
      // processing emitted synchronously; close before the block resolves.
      await cubit.close();
      completer.complete(true);
      await expectLater(future, completes);

      expect(cubit.state.status, ConversationActionsStatus.processing);
    });

    test('initial state is idle', () async {
      final cubit = createCubit();
      expect(cubit.state.status, ConversationActionsStatus.idle);
      await cubit.close();
    });

    group('markAsRead', () {
      for (final written in [true, false]) {
        blocTest<ConversationActionsCubit, ConversationActionsState>(
          'reports the repository result when written is $written',
          setUp: () {
            when(() => mockDmRepo.markConversationAsRead(conversationId))
                .thenAnswer((_) async => written);
          },
          build: createCubit,
          act: (cubit) async {
            expect(await cubit.markAsRead(conversationId), written);
          },
          expect: () => [
            const ConversationActionsState(
              status: ConversationActionsStatus.processing,
            ),
            ConversationActionsState(
              status: written
                  ? ConversationActionsStatus.success
                  : ConversationActionsStatus.failure,
            ),
          ],
        );
      }
    });

    group('isBlocked', () {
      test('delegates to ContentBlocklistRepository', () async {
        when(() => mockBlocklistRepository.isBlocked(pubkey)).thenReturn(true);

        final cubit = createCubit();
        expect(cubit.isBlocked(pubkey), isTrue);

        verify(() => mockBlocklistRepository.isBlocked(pubkey)).called(1);
        await cubit.close();
      });
    });

    group('blockUser', () {
      blocTest<ConversationActionsCubit, ConversationActionsState>(
        'emits processing then success and calls blocklistRepository',
        setUp: () {
          when(
            () => mockBlocklistRepository.blockUser(
              pubkey,
              ourPubkey: currentUserPubkey,
            ),
          ).thenAnswer((_) async => true);
        },
        build: createCubit,
        act: (cubit) => cubit.blockUser(pubkey),
        expect: () => [
          const ConversationActionsState(
            status: ConversationActionsStatus.processing,
          ),
          const ConversationActionsState(
            status: ConversationActionsStatus.success,
          ),
        ],
        verify: (_) {
          verify(
            () => mockBlocklistRepository.blockUser(
              pubkey,
              ourPubkey: currentUserPubkey,
            ),
          ).called(1);
        },
      );

      blocTest<ConversationActionsCubit, ConversationActionsState>(
        'emits failure and calls addError when blocklistRepository throws',
        setUp: () {
          when(
            () => mockBlocklistRepository.blockUser(
              pubkey,
              ourPubkey: currentUserPubkey,
            ),
          ).thenAnswer((_) async => throw Exception('block failed'));
        },
        build: createCubit,
        act: (cubit) => cubit.blockUser(pubkey),
        expect: () => [
          const ConversationActionsState(
            status: ConversationActionsStatus.processing,
          ),
          const ConversationActionsState(
            status: ConversationActionsStatus.failure,
          ),
        ],
        errors: () => [isA<Exception>()],
      );
    });

    group('unblockUser', () {
      blocTest<ConversationActionsCubit, ConversationActionsState>(
        'emits processing then success and calls unblockUser',
        setUp: () {
          when(
            () => mockBlocklistRepository.unblockUser(pubkey),
          ).thenAnswer((_) async => true);
        },
        build: createCubit,
        act: (cubit) => cubit.unblockUser(pubkey),
        expect: () => [
          const ConversationActionsState(
            status: ConversationActionsStatus.processing,
          ),
          const ConversationActionsState(
            status: ConversationActionsStatus.success,
          ),
        ],
        verify: (_) {
          verify(() => mockBlocklistRepository.unblockUser(pubkey)).called(1);
        },
      );

      blocTest<ConversationActionsCubit, ConversationActionsState>(
        'emits failure and calls addError when unblockUser throws',
        setUp: () {
          when(
            () => mockBlocklistRepository.unblockUser(pubkey),
          ).thenAnswer((_) async => throw Exception('unblock failed'));
        },
        build: createCubit,
        act: (cubit) => cubit.unblockUser(pubkey),
        expect: () => [
          const ConversationActionsState(
            status: ConversationActionsStatus.processing,
          ),
          const ConversationActionsState(
            status: ConversationActionsStatus.failure,
          ),
        ],
        errors: () => [isA<Exception>()],
      );
    });

    group('removeConversation', () {
      blocTest<ConversationActionsCubit, ConversationActionsState>(
        'reports removed on success',
        setUp: () {
          when(
            () => mockDmRepo.removeConversation(any()),
          ).thenAnswer((_) async => ConversationRemovalOutcome.removed);
        },
        build: createCubit,
        act: (cubit) async {
          final result = await cubit.removeConversation(conversationId);
          expect(result, equals(RemoveConversationOutcome.removed));
        },
        expect: () => [
          const ConversationActionsState(
            status: ConversationActionsStatus.processing,
          ),
          const ConversationActionsState(
            status: ConversationActionsStatus.success,
          ),
        ],
        verify: (_) {
          verify(() => mockDmRepo.removeConversation(conversationId)).called(1);
        },
      );

      blocTest<ConversationActionsCubit, ConversationActionsState>(
        'reports failed and calls addError on failure',
        setUp: () {
          when(
            () => mockDmRepo.removeConversation(any()),
          ).thenThrow(Exception('DB error'));
        },
        build: createCubit,
        act: (cubit) async {
          final result = await cubit.removeConversation(conversationId);
          expect(result, equals(RemoveConversationOutcome.failed));
        },
        expect: () => [
          const ConversationActionsState(
            status: ConversationActionsStatus.processing,
          ),
          const ConversationActionsState(
            status: ConversationActionsStatus.failure,
          ),
        ],
        errors: () => [isA<Exception>()],
      );

      // #8391: the inbox long-press could destroy a Divine Moderation
      // enforcement notice — the user's only copy of why they were actioned —
      // because the guard #8302 added lived in MessageRequestActionsCubit
      // only. A refusal is not a failure, so it must not emit `failure` and
      // must not reach addError.
      blocTest<ConversationActionsCubit, ConversationActionsState>(
        'reports refused without erroring when the repository protects it',
        setUp: () {
          when(
            () => mockDmRepo.removeConversation(any()),
          ).thenAnswer((_) async => ConversationRemovalOutcome.refused);
        },
        build: createCubit,
        act: (cubit) async {
          final result = await cubit.removeConversation(conversationId);
          expect(result, equals(RemoveConversationOutcome.refused));
        },
        expect: () => [
          const ConversationActionsState(
            status: ConversationActionsStatus.processing,
          ),
          // Back to idle: a refusal is not a failure.
          const ConversationActionsState(),
        ],
        errors: () => <Object>[],
      );
    });

    group('isRemovalProtected', () {
      test('delegates to the repository rather than re-deciding', () {
        final conversation = DmConversation(
          id: conversationId,
          participantPubkeys: const [currentUserPubkey, pubkey],
          isGroup: false,
          createdAt: 1700000000,
          lastMessageTimestamp: 1700000000,
        );
        when(
          () => mockDmRepo.isRemovalProtected(conversation),
        ).thenReturn(true);

        expect(createCubit().isRemovalProtected(conversation), isTrue);
        verify(() => mockDmRepo.isRemovalProtected(conversation)).called(1);
      });
    });
  });
}
