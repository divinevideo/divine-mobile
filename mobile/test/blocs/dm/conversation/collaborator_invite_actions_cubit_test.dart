// ABOUTME: Tests collaborator invite accept/ignore UI action state.
// ABOUTME: Verifies accept publishes while ignore stays local-only.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:collaborator_repository/collaborator_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/conversation/collaborator_invite_actions_cubit.dart';
import 'package:openvine/models/collaborator_invite.dart';
import 'package:openvine/services/collaborator_invite_state_store.dart';
import 'package:openvine/services/collaborator_response_service.dart';

class _MockCollaboratorInviteStateStore extends Mock
    implements CollaboratorInviteStateStore {}

class _MockCollaboratorResponseService extends Mock
    implements CollaboratorResponseService {}

class _MockConfirmationRepository extends Mock
    implements CollaboratorConfirmationRepository {}

void main() {
  const currentUserPubkey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const creatorPubkey =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  const invite = CollaboratorInvite(
    messageId:
        'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
    videoAddress: '34236:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb:skate-loop',
    videoKind: 34236,
    creatorPubkey: creatorPubkey,
    videoDTag: 'skate-loop',
    role: 'Collaborator',
    title: 'Skate loop',
  );

  late _MockCollaboratorInviteStateStore store;
  late _MockCollaboratorResponseService responseService;
  late _MockConfirmationRepository confirmationRepository;

  setUpAll(() {
    registerFallbackValue(invite);
    registerFallbackValue(CollaboratorInviteState.pending);
    registerFallbackValue(CollaboratorStatus.pending);
  });

  setUp(() {
    store = _MockCollaboratorInviteStateStore();
    responseService = _MockCollaboratorResponseService();
    confirmationRepository = _MockConfirmationRepository();
    when(
      () => confirmationRepository.markLocal(
        videoAddress: any(named: 'videoAddress'),
        collaboratorPubkey: any(named: 'collaboratorPubkey'),
        status: any(named: 'status'),
      ),
    ).thenReturn(null);
  });

  CollaboratorInviteActionsCubit buildCubit() {
    return CollaboratorInviteActionsCubit(
      stateStore: store,
      responseService: responseService,
      currentUserPubkey: currentUserPubkey,
      confirmationRepository: confirmationRepository,
    );
  }

  group(CollaboratorInviteActionsCubit, () {
    test('does not emit or throw when closed mid-ignore', () async {
      final completer = Completer<void>();
      when(
        () => store.setState(
          videoAddress: any(named: 'videoAddress'),
          creatorPubkey: any(named: 'creatorPubkey'),
          collaboratorPubkey: any(named: 'collaboratorPubkey'),
          state: any(named: 'state'),
        ),
      ).thenAnswer((_) => completer.future);

      final cubit = buildCubit();
      final future = cubit.ignoreInvite(invite);
      await cubit.close();
      completer.complete();
      await expectLater(future, completes);

      expect(cubit.state.stateFor(invite), CollaboratorInviteState.pending);
    });

    test('loads persisted invite state', () {
      when(
        () => store.getState(
          videoAddress: invite.videoAddress,
          creatorPubkey: invite.creatorPubkey,
          collaboratorPubkey: currentUserPubkey,
        ),
      ).thenReturn(CollaboratorInviteState.accepted);

      final cubit = buildCubit()..loadInvites([invite]);

      expect(cubit.state.stateFor(invite), CollaboratorInviteState.accepted);
    });

    blocTest<CollaboratorInviteActionsCubit, CollaboratorInviteActionsState>(
      'acceptInvite persists accepting, publishes, then persists accepted',
      setUp: () {
        when(
          () => store.setState(
            videoAddress: invite.videoAddress,
            creatorPubkey: invite.creatorPubkey,
            collaboratorPubkey: currentUserPubkey,
            state: any(named: 'state'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => responseService.acceptInvite(invite),
        ).thenAnswer(
          (_) async => const CollaboratorResponseResult.success(
            'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
          ),
        );
      },
      build: buildCubit,
      act: (cubit) => cubit.acceptInvite(invite),
      expect: () => [
        isA<CollaboratorInviteActionsState>().having(
          (state) => state.stateFor(invite),
          'invite state',
          CollaboratorInviteState.accepting,
        ),
        isA<CollaboratorInviteActionsState>().having(
          (state) => state.stateFor(invite),
          'invite state',
          CollaboratorInviteState.accepted,
        ),
      ],
      verify: (_) {
        verifyInOrder([
          () => store.setState(
            videoAddress: invite.videoAddress,
            creatorPubkey: invite.creatorPubkey,
            collaboratorPubkey: currentUserPubkey,
            state: CollaboratorInviteState.accepting,
          ),
          () => responseService.acceptInvite(invite),
          () => store.setState(
            videoAddress: invite.videoAddress,
            creatorPubkey: invite.creatorPubkey,
            collaboratorPubkey: currentUserPubkey,
            state: CollaboratorInviteState.accepted,
          ),
          () => confirmationRepository.markLocal(
            videoAddress: invite.videoAddress,
            collaboratorPubkey: currentUserPubkey,
            status: CollaboratorStatus.confirmed,
          ),
        ]);
      },
    );

    blocTest<CollaboratorInviteActionsCubit, CollaboratorInviteActionsState>(
      'acceptInvite persists failed when publishing fails',
      setUp: () {
        when(
          () => store.setState(
            videoAddress: any(named: 'videoAddress'),
            creatorPubkey: any(named: 'creatorPubkey'),
            collaboratorPubkey: any(named: 'collaboratorPubkey'),
            state: any(named: 'state'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => responseService.acceptInvite(invite),
        ).thenAnswer(
          (_) async => const CollaboratorResponseResult.failure('relay down'),
        );
      },
      build: buildCubit,
      act: (cubit) => cubit.acceptInvite(invite),
      expect: () => [
        isA<CollaboratorInviteActionsState>().having(
          (state) => state.stateFor(invite),
          'invite state',
          CollaboratorInviteState.accepting,
        ),
        isA<CollaboratorInviteActionsState>().having(
          (state) => state.stateFor(invite),
          'invite state',
          CollaboratorInviteState.failed,
        ),
      ],
      verify: (_) {
        // Failed publish must NOT optimistically promote the local fast-path
        // to confirmed.
        verifyNever(
          () => confirmationRepository.markLocal(
            videoAddress: any(named: 'videoAddress'),
            collaboratorPubkey: any(named: 'collaboratorPubkey'),
            status: any(named: 'status'),
          ),
        );
      },
    );

    blocTest<CollaboratorInviteActionsCubit, CollaboratorInviteActionsState>(
      'ignoreInvite persists ignored without publishing',
      setUp: () {
        when(
          () => store.setState(
            videoAddress: invite.videoAddress,
            creatorPubkey: invite.creatorPubkey,
            collaboratorPubkey: currentUserPubkey,
            state: CollaboratorInviteState.ignored,
          ),
        ).thenAnswer((_) async {});
      },
      build: buildCubit,
      act: (cubit) => cubit.ignoreInvite(invite),
      expect: () => [
        isA<CollaboratorInviteActionsState>().having(
          (state) => state.stateFor(invite),
          'invite state',
          CollaboratorInviteState.ignored,
        ),
      ],
      verify: (_) {
        verifyNever(() => responseService.acceptInvite(any()));
        verify(
          () => confirmationRepository.markLocal(
            videoAddress: invite.videoAddress,
            collaboratorPubkey: currentUserPubkey,
            status: CollaboratorStatus.ignored,
          ),
        ).called(1);
      },
    );

    // #3559 — defense-in-depth. The render layer should not surface
    // accept/ignore for sender-side (self-creator) invites; if it ever
    // does, the cubit's assert fails loudly in debug and the runtime
    // guard suppresses any side effect in release.
    test(
      'acceptInvite no-ops when current user is the invite creator',
      () async {
        final selfCreatorCubit = CollaboratorInviteActionsCubit(
          stateStore: store,
          responseService: responseService,
          currentUserPubkey: creatorPubkey,
        );
        addTearDown(selfCreatorCubit.close);

        await expectLater(
          selfCreatorCubit.acceptInvite(invite),
          throwsA(isA<AssertionError>()),
        );

        verifyNever(() => responseService.acceptInvite(any()));
        verifyNever(
          () => store.setState(
            videoAddress: any(named: 'videoAddress'),
            creatorPubkey: any(named: 'creatorPubkey'),
            collaboratorPubkey: any(named: 'collaboratorPubkey'),
            state: any(named: 'state'),
          ),
        );
      },
    );

    test(
      'ignoreInvite no-ops when current user is the invite creator',
      () async {
        final selfCreatorCubit = CollaboratorInviteActionsCubit(
          stateStore: store,
          responseService: responseService,
          currentUserPubkey: creatorPubkey,
        );
        addTearDown(selfCreatorCubit.close);

        await expectLater(
          selfCreatorCubit.ignoreInvite(invite),
          throwsA(isA<AssertionError>()),
        );

        verifyNever(
          () => store.setState(
            videoAddress: any(named: 'videoAddress'),
            creatorPubkey: any(named: 'creatorPubkey'),
            collaboratorPubkey: any(named: 'collaboratorPubkey'),
            state: any(named: 'state'),
          ),
        );
      },
    );

    test(
      'acceptInvite no-ops when current user matches uppercase invite creator',
      () async {
        final uppercaseInvite = CollaboratorInvite(
          messageId: invite.messageId,
          videoAddress: '34236:${creatorPubkey.toUpperCase()}:skate-loop',
          videoKind: invite.videoKind,
          creatorPubkey: creatorPubkey.toUpperCase(),
          videoDTag: invite.videoDTag,
          role: invite.role,
          title: invite.title,
        );
        final selfCreatorCubit = CollaboratorInviteActionsCubit(
          stateStore: store,
          responseService: responseService,
          currentUserPubkey: creatorPubkey,
        );
        addTearDown(selfCreatorCubit.close);

        await expectLater(
          selfCreatorCubit.acceptInvite(uppercaseInvite),
          throwsA(isA<AssertionError>()),
        );

        verifyNever(() => responseService.acceptInvite(any()));
        verifyNever(
          () => store.setState(
            videoAddress: any(named: 'videoAddress'),
            creatorPubkey: any(named: 'creatorPubkey'),
            collaboratorPubkey: any(named: 'collaboratorPubkey'),
            state: any(named: 'state'),
          ),
        );
      },
    );
  });
}
