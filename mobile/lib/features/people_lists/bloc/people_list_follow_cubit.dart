// ABOUTME: Cubit behind the Follow control on someone else's people list.
// ABOUTME: A followed list becomes a feed in Home's feed selector.

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/features/people_lists/bloc/people_list_follow_state.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:people_lists_repository/people_lists_repository.dart';

export 'package:openvine/features/people_lists/bloc/people_list_follow_state.dart';

/// Follows and unfollows one public people list on behalf of the viewer.
///
/// Whether the list is followed comes from the repository's stream, not from
/// the writes made here, so a follow made anywhere else shows up too.
class PeopleListFollowCubit extends Cubit<PeopleListFollowState>
    with CloseGuardedEmit<PeopleListFollowState> {
  PeopleListFollowCubit({
    required PeopleListsRepository repository,
    required String viewerPubkey,
    required String ownerPubkey,
    required String listId,
  }) : _repository = repository,
       _viewerPubkey = viewerPubkey,
       _ownerPubkey = ownerPubkey,
       _listId = listId,
       super(const PeopleListFollowState());

  final PeopleListsRepository _repository;
  final String _viewerPubkey;
  final String _ownerPubkey;
  final String _listId;
  StreamSubscription<List<PeopleListSearchResult>>? _subscription;

  /// Starts tracking whether the viewer follows the list. Safe to call again.
  Future<void> started() async {
    await _subscription?.cancel();
    if (isClosed) return;
    _subscription = _repository
        .watchFollowedLists(viewerPubkey: _viewerPubkey)
        .listen(
          (followed) {
            final isFollowing = followed.any(
              (list) =>
                  list.ownerPubkey == _ownerPubkey && list.list.id == _listId,
            );
            emitIfOpen(
              state.copyWith(
                isFollowing: isFollowing,
                status: state.status == PeopleListFollowStatus.loading
                    ? PeopleListFollowStatus.ready
                    : null,
              ),
            );
          },
          onError: (Object error, StackTrace stackTrace) {
            addError(error, stackTrace);
            emitIfOpen(state.copyWith(status: PeopleListFollowStatus.failure));
          },
        );
  }

  /// Follows [list] when it is not followed, and unfollows it when it is.
  ///
  /// [list] is the copy on screen, which is what gets stored on a follow.
  Future<void> toggled(UserList list) async {
    if (state.isBusy) return;
    final wasFollowing = state.isFollowing;
    emitIfOpen(state.copyWith(status: PeopleListFollowStatus.updating));
    try {
      if (wasFollowing) {
        await _repository.unfollowList(
          viewerPubkey: _viewerPubkey,
          ownerPubkey: _ownerPubkey,
          listId: _listId,
        );
      } else {
        await _repository.followList(
          viewerPubkey: _viewerPubkey,
          ownerPubkey: _ownerPubkey,
          list: list,
        );
      }
      emitIfOpen(
        state.copyWith(
          status: PeopleListFollowStatus.ready,
          isFollowing: !wasFollowing,
        ),
      );
    } on Exception catch (error, stackTrace) {
      addError(error, stackTrace);
      emitIfOpen(state.copyWith(status: PeopleListFollowStatus.failure));
    } catch (error, stackTrace) {
      // Anything else is a bug, so it is reported; the control still has to
      // come back, or it would show progress for ever.
      addError(
        Reportable(error, context: 'PeopleListFollowCubit.toggled'),
        stackTrace,
      );
      emitIfOpen(state.copyWith(status: PeopleListFollowStatus.failure));
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    _subscription = null;
    return super.close();
  }
}
