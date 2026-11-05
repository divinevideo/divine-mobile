// ABOUTME: Cubit for local collaborator invite accept/ignore UI actions.
// ABOUTME: Accept publishes a response; ignore only updates local UX state.

import 'package:bloc/bloc.dart';
import 'package:collaborator_repository/collaborator_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:models/models.dart';
import 'package:openvine/models/collaborator_invite.dart';
import 'package:openvine/services/collaborator_invite_state_store.dart';
import 'package:openvine/services/collaborator_response_service.dart';

class CollaboratorInviteActionsState extends Equatable {
  const CollaboratorInviteActionsState({
    this.inviteStates = const {},
  });

  final Map<String, CollaboratorInviteState> inviteStates;

  CollaboratorInviteState stateFor(CollaboratorInvite invite) {
    return inviteStates[_keyFor(invite)] ?? CollaboratorInviteState.pending;
  }

  /// What the card shows: this device's action state for [invite] merged with
  /// [relayStatus], the repository's status for the current user.
  ///
  /// A local ignore wins over any acceptance (#6970). Otherwise an acceptance
  /// made on any device wins over an accept in flight, a failed attempt or no
  /// decision; without one, the local state shows.
  CollaboratorInviteState displayStateFor(
    CollaboratorInvite invite, {
    CollaboratorStatus? relayStatus,
  }) {
    final local = stateFor(invite);
    return switch (local) {
      CollaboratorInviteState.ignored ||
      CollaboratorInviteState.accepted => local,
      _ when relayStatus == CollaboratorStatus.confirmed =>
        CollaboratorInviteState.accepted,
      _ when relayStatus == CollaboratorStatus.ignored =>
        CollaboratorInviteState.ignored,
      _ => local,
    };
  }

  CollaboratorInviteActionsState copyWith({
    Map<String, CollaboratorInviteState>? inviteStates,
  }) {
    return CollaboratorInviteActionsState(
      inviteStates: inviteStates ?? this.inviteStates,
    );
  }

  static String _keyFor(CollaboratorInvite invite) {
    return '${invite.videoAddress}|${invite.creatorPubkey}';
  }

  @override
  List<Object?> get props => [inviteStates];
}

class CollaboratorInviteActionsCubit
    extends Cubit<CollaboratorInviteActionsState> {
  CollaboratorInviteActionsCubit({
    required CollaboratorInviteStateStore stateStore,
    required CollaboratorResponseService responseService,
    required String currentUserPubkey,
    CollaboratorConfirmationRepository? confirmationRepository,
  }) : _stateStore = stateStore,
       _responseService = responseService,
       _currentUserPubkey = currentUserPubkey,
       _confirmationRepository = confirmationRepository,
       super(const CollaboratorInviteActionsState());

  final CollaboratorInviteStateStore _stateStore;
  final CollaboratorResponseService _responseService;
  final String _currentUserPubkey;
  final CollaboratorConfirmationRepository? _confirmationRepository;

  void loadInvites(Iterable<CollaboratorInvite> invites) {
    if (_currentUserPubkey.isEmpty) return;

    final updated = Map<String, CollaboratorInviteState>.of(
      state.inviteStates,
    );
    for (final invite in invites) {
      final key = CollaboratorInviteActionsState._keyFor(invite);
      // This instance's own accept already holds `accepting` in state. One
      // read back from the store was left by an earlier session that never
      // finished, so offering the actions again is the honest state.
      if (state.inviteStates[key] == CollaboratorInviteState.accepting) {
        continue;
      }
      final stored = _stateStore.getState(
        videoAddress: invite.videoAddress,
        creatorPubkey: invite.creatorPubkey,
        collaboratorPubkey: _currentUserPubkey,
      );
      updated[key] = stored == CollaboratorInviteState.accepting
          ? CollaboratorInviteState.pending
          : stored;
    }
    emit(state.copyWith(inviteStates: updated));
  }

  Future<void> acceptInvite(CollaboratorInvite invite) async {
    assert(
      !_isCurrentUserInviteCreator(invite),
      'CollaboratorInviteCard should not surface accept for sender-side '
      'invites (#3559)',
    );
    if (_currentUserPubkey.isEmpty) return;
    if (_isCurrentUserInviteCreator(invite)) return;

    await _setInviteState(invite, CollaboratorInviteState.accepting);

    final result = await _responseService.acceptInvite(invite);
    await _setInviteState(
      invite,
      result.success
          ? CollaboratorInviteState.accepted
          : CollaboratorInviteState.failed,
    );
    if (result.success) {
      _confirmationRepository?.markLocal(
        videoAddress: invite.videoAddress,
        collaboratorPubkey: _currentUserPubkey,
        status: CollaboratorStatus.confirmed,
      );
    }
  }

  Future<void> ignoreInvite(CollaboratorInvite invite) async {
    assert(
      !_isCurrentUserInviteCreator(invite),
      'CollaboratorInviteCard should not surface ignore for sender-side '
      'invites (#3559)',
    );
    if (_currentUserPubkey.isEmpty) return;
    if (_isCurrentUserInviteCreator(invite)) return;
    await _setInviteState(invite, CollaboratorInviteState.ignored);
    _confirmationRepository?.markLocal(
      videoAddress: invite.videoAddress,
      collaboratorPubkey: _currentUserPubkey,
      status: CollaboratorStatus.ignored,
    );
  }

  Future<void> _setInviteState(
    CollaboratorInvite invite,
    CollaboratorInviteState inviteState,
  ) async {
    await _stateStore.setState(
      videoAddress: invite.videoAddress,
      creatorPubkey: invite.creatorPubkey,
      collaboratorPubkey: _currentUserPubkey,
      state: inviteState,
    );

    if (!isClosed) {
      emit(
        state.copyWith(
          inviteStates: {
            ...state.inviteStates,
            CollaboratorInviteActionsState._keyFor(invite): inviteState,
          },
        ),
      );
    }
  }

  bool _isCurrentUserInviteCreator(CollaboratorInvite invite) =>
      _currentUserPubkey.toLowerCase() == invite.creatorPubkey.toLowerCase();
}
