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
/// Reads durable follow status when the repository signals a change, so a
/// missing cached list never reads as an unfollow.
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
  int _watchGeneration = 0;
  int _readGeneration = 0;

  /// Starts tracking whether the viewer follows the list. Safe to call again.
  Future<void> started() async {
    final watchGeneration = ++_watchGeneration;
    _readGeneration++;
    await _subscription?.cancel();
    if (isClosed || watchGeneration != _watchGeneration) return;
    _subscription = _repository
        .watchFollowedLists(viewerPubkey: _viewerPubkey)
        .listen(
          (_) {
            if (watchGeneration != _watchGeneration) return;
            unawaited(_readFollowStatus());
          },
          onError: (Object error, StackTrace stackTrace) {
            if (isClosed || watchGeneration != _watchGeneration) return;
            _readGeneration++;
            addError(error, stackTrace);
            emitIfOpen(state.copyWith(status: PeopleListFollowStatus.failure));
            // The follow is kept apart from the copies that could not be
            // read, so it can still be known, and a followed list must not
            // read as one to follow.
            unawaited(_readFollowStatus());
          },
        );
  }

  Future<void> _readFollowStatus() async {
    if (isClosed) return;
    final generation = ++_readGeneration;
    try {
      final isFollowing = await _repository.isFollowingList(
        viewerPubkey: _viewerPubkey,
        ownerPubkey: _ownerPubkey,
        listId: _listId,
      );
      if (isClosed || generation != _readGeneration) return;
      emitIfOpen(
        state.copyWith(
          isFollowing: isFollowing,
          hasReadFollowing: true,
          status: state.status == PeopleListFollowStatus.loading
              ? PeopleListFollowStatus.ready
              : null,
        ),
      );
    } catch (error, stackTrace) {
      if (isClosed || generation != _readGeneration) return;
      addError(error, stackTrace);
      emitIfOpen(state.copyWith(status: PeopleListFollowStatus.failure));
    }
  }

  /// Re-reads durable status after an initial read could not establish it.
  Future<void> retryRead() async {
    if (isClosed || state.status == PeopleListFollowStatus.updating) return;
    emitIfOpen(state.copyWith(status: PeopleListFollowStatus.loading));
    await _readFollowStatus();
  }

  /// Follows [list] when it is not followed, and unfollows it when it is.
  ///
  /// [list] is the copy on screen, which is what gets stored on a follow.
  Future<void> toggled(UserList list) => _updateFollow(list: list);

  /// Removes the durable follow even when the remote list cannot be resolved.
  Future<void> unfollowed() {
    if (!state.isFollowing) return Future<void>.value();
    return _updateFollow();
  }

  Future<void> _updateFollow({UserList? list}) async {
    if (state.isBusy) return;
    final wasFollowing = state.isFollowing;
    _readGeneration++;
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
          list: list!,
        );
      }
      _readGeneration++;
      emitIfOpen(
        state.copyWith(
          status: PeopleListFollowStatus.ready,
          isFollowing: !wasFollowing,
        ),
      );
      await _readFollowStatus();
    } on Exception catch (error, stackTrace) {
      _readGeneration++;
      addError(error, stackTrace);
      emitIfOpen(state.copyWith(status: PeopleListFollowStatus.failure));
    } catch (error, stackTrace) {
      _readGeneration++;
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
    _watchGeneration++;
    _readGeneration++;
    await _subscription?.cancel();
    _subscription = null;
    return super.close();
  }
}
