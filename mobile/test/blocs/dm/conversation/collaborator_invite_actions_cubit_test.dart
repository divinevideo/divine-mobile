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

    test('loads an accept left in flight by an earlier session as pending', () {
      when(
        () => store.getState(
          videoAddress: invite.videoAddress,
          creatorPubkey: invite.creatorPubkey,
          collaboratorPubkey: currentUserPubkey,
        ),
      ).thenReturn(CollaboratorInviteState.accepting);

      final cubit = buildCubit()..loadInvites([invite]);

      expect(cubit.state.stateFor(invite), CollaboratorInviteState.pending);
    });

    test('keeps its own accept in flight when a card reloads it', () async {
      final publish = Completer<CollaboratorResponseResult>();
      when(
        () => store.setState(
          videoAddress: any(named: 'videoAddress'),
          creatorPubkey: any(named: 'creatorPubkey'),
          collaboratorPubkey: any(named: 'collaboratorPubkey'),
          state: any(named: 'state'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => store.getState(
          videoAddress: invite.videoAddress,
          creatorPubkey: invite.creatorPubkey,
          collaboratorPubkey: currentUserPubkey,
        ),
      ).thenReturn(CollaboratorInviteState.accepting);
      when(
        () => responseService.acceptInvite(any()),
      ).thenAnswer((_) => publish.future);
      final cubit = buildCubit();
      addTearDown(cubit.close);

      final accepting = cubit.acceptInvite(invite);
      await pumpEventQueue();
      expect(cubit.state.stateFor(invite), CollaboratorInviteState.accepting);

      cubit.loadInvites([invite]);

      expect(cubit.state.stateFor(invite), CollaboratorInviteState.accepting);
      publish.complete(const CollaboratorResponseResult.failure('offline'));
      await accepting;
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

  group(CollaboratorInviteActionsState, () {
    group('displayStateFor', () {
      CollaboratorInviteActionsState withLocal(CollaboratorInviteState local) {
        final state = CollaboratorInviteActionsState(
          inviteStates: {'${invite.videoAddress}|$creatorPubkey': local},
        );
        expect(state.stateFor(invite), local);
        return state;
      }

      test('shows accepted when the relay holds an acceptance and nothing '
          'is stored locally', () {
        expect(
          const CollaboratorInviteActionsState().displayStateFor(
            invite,
            relayStatus: CollaboratorStatus.confirmed,
          ),
          CollaboratorInviteState.accepted,
        );
      });

      test('lets a relay acceptance replace a failed local attempt', () {
        expect(
          withLocal(CollaboratorInviteState.failed).displayStateFor(
            invite,
            relayStatus: CollaboratorStatus.confirmed,
          ),
          CollaboratorInviteState.accepted,
        );
      });

      test('keeps a local ignore over any relay acceptance', () {
        expect(
          withLocal(CollaboratorInviteState.ignored).displayStateFor(
            invite,
            relayStatus: CollaboratorStatus.confirmed,
          ),
          CollaboratorInviteState.ignored,
        );
      });

      test('keeps accepting while the local publish is in flight', () {
        expect(
          withLocal(
            CollaboratorInviteState.accepting,
          ).displayStateFor(invite, relayStatus: CollaboratorStatus.pending),
          CollaboratorInviteState.accepting,
        );
      });

      test('shows accepted once the relay holds an acceptance during an '
          'accept', () {
        expect(
          withLocal(CollaboratorInviteState.accepting).displayStateFor(
            invite,
            relayStatus: CollaboratorStatus.confirmed,
          ),
          CollaboratorInviteState.accepted,
        );
      });

      test('shows ignored when the repository reports an ignore', () {
        expect(
          withLocal(
            CollaboratorInviteState.pending,
          ).displayStateFor(invite, relayStatus: CollaboratorStatus.ignored),
          CollaboratorInviteState.ignored,
        );
      });

      test('falls back to the local state when the relay has no answer', () {
        expect(
          withLocal(
            CollaboratorInviteState.failed,
          ).displayStateFor(invite, relayStatus: CollaboratorStatus.pending),
          CollaboratorInviteState.failed,
        );
        expect(
          const CollaboratorInviteActionsState().displayStateFor(invite),
          CollaboratorInviteState.pending,
        );
      });
    });
  });
}
