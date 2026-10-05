// ABOUTME: Cubit for the sheet that picks which of the viewer's lists hold a
// ABOUTME: video: tracks the picks and writes them to the lists on submit.

import 'package:collection/collection.dart';
import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/blocs/select_list/select_list_state.dart';
import 'package:openvine/services/curated_list_service.dart';

export 'package:openvine/blocs/select_list/select_list_state.dart';

/// Drives the sheet that picks which of the viewer's lists hold a video.
///
/// One instance lives for one visit to the sheet. The picks are held here
/// until they are submitted, so the same video can be put in several lists
/// with one save. The lists on offer follow the service: a list created from
/// the sheet shows up, already picked when it holds the video.
class SelectListCubit extends Cubit<SelectListState>
    with CloseGuardedEmit<SelectListState> {
  /// Creates the cubit for one visit to the sheet, opened on [videoEventId].
  SelectListCubit({
    required CuratedListService service,
    required String videoEventId,
    required String? Function() currentOwnerPubkey,
  }) : _service = service,
       _currentOwnerPubkey = currentOwnerPubkey,
       _openingOwnerPubkey = currentOwnerPubkey(),
       _videoEventId = videoEventId,
       super(_initialState(service, videoEventId, currentOwnerPubkey())) {
    _service.addListener(_listsChanged);
  }

  final CuratedListService _service;
  final String _videoEventId;
  final String? Function() _currentOwnerPubkey;
  final String? _openingOwnerPubkey;

  bool get isSessionCurrent =>
      _openingOwnerPubkey != null &&
      _openingOwnerPubkey.isNotEmpty &&
      _currentOwnerPubkey() == _openingOwnerPubkey;

  static List<CuratedList> _ownedLists(
    CuratedListService service,
    String? owner,
  ) => owner == null || owner.isEmpty
      ? const []
      : service.myLists.where((list) => list.pubkey == owner).toList();

  bool _canMutate(String listId) =>
      isSessionCurrent &&
      _ownedLists(
        _service,
        _openingOwnerPubkey,
      ).any((list) => list.id == listId);

  SelectListStatus _sessionFailure() {
    emitIfOpen(
      state.copyWith(
        lists: const [],
        memberListIds: const {},
        selectedListIds: const {},
        syncingListIds: const {},
        failedSyncListIds: const {},
        status: SelectListStatus.failure,
      ),
    );
    return SelectListStatus.failure;
  }

  static SelectListState _initialState(
    CuratedListService service,
    String videoEventId,
    String? owner,
  ) {
    final lists = _ownedLists(service, owner);
    final members = _membership(lists, videoEventId);
    return SelectListState(
      lists: lists,
      memberListIds: members,
      selectedListIds: members,
    );
  }

  static Set<String> _membership(List<CuratedList> lists, String videoEventId) {
    return {
      for (final list in lists)
        if (list.videoEventIds.contains(videoEventId)) list.id,
    };
  }

  /// Picks the list with [listId], or unpicks it when it is picked.
  ///
  /// Ignored while a save runs, and for a list the sheet does not offer.
  void toggled(String listId) {
    if (state.isSaving || !isSessionCurrent) return;
    if (state.lists.none((list) => list.id == listId)) return;
    final selected = {...state.selectedListIds};
    if (!selected.add(listId)) selected.remove(listId);
    emitIfOpen(
      state.copyWith(
        selectedListIds: selected,
        status: SelectListStatus.editing,
      ),
    );
  }

  /// Writes the picks: adds the video to each newly picked list and removes
  /// it from each unpicked one.
  ///
  /// Ends in [SelectListStatus.saved] when every list took the change, so a
  /// visit with no changes closes at once. Otherwise the lists that did take
  /// it are done, and the state ends in [SelectListStatus.failure] or
  /// [SelectListStatus.failureListFull] with the rest still picked. Ignored
  /// while [SelectListState.canSubmit] is false, as the sheet's check is then
  /// disabled. Returns the outcome so a caller can report failure even after
  /// the sheet closes.
  Future<SelectListStatus?> submitted() async {
    if (!state.canSubmit) return null;
    if (!isSessionCurrent) return _sessionFailure();
    final toAdd = state.listIdsToAdd;
    final toRemove = state.listIdsToRemove;
    if (toAdd.isEmpty && toRemove.isEmpty) {
      emitIfOpen(state.copyWith(status: SelectListStatus.saved));
      return SelectListStatus.saved;
    }
    emitIfOpen(state.copyWith(status: SelectListStatus.saving));

    var failed = 0;
    var full = 0;
    try {
      for (final listId in toAdd) {
        if (!_canMutate(listId)) return _sessionFailure();
        final added = await _service.addVideoToList(listId, _videoEventId);
        if (!isSessionCurrent) return _sessionFailure();
        if (added) continue;
        failed++;
        final list = state.lists.firstWhereOrNull((it) => it.id == listId);
        if (list != null &&
            CuratedListConverter.wouldExceedPrivateItemLimit(
              list,
              _videoEventId,
            )) {
          full++;
        }
      }
      for (final listId in toRemove) {
        if (!_canMutate(listId)) return _sessionFailure();
        final removed = await _service.removeVideoFromList(
          listId,
          _videoEventId,
        );
        if (!isSessionCurrent) return _sessionFailure();
        if (!removed) {
          failed++;
        }
      }
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emitIfOpen(state.copyWith(status: SelectListStatus.failure));
      return SelectListStatus.failure;
    }

    final status = failed == 0
        ? SelectListStatus.saved
        : full == failed
        ? SelectListStatus.failureListFull
        : SelectListStatus.failure;
    emitIfOpen(state.copyWith(status: status));
    return status;
  }

  /// Says the list the sheet's create button made refused the video.
  ///
  /// The create sheet closes on that, since the list exists, and this picker
  /// is what covers the screen underneath, so the failure line shows here;
  /// the new list's row shows whether the video is in it.
  void createdListRefusedVideo() {
    if (state.isSaving || !isSessionCurrent) return;
    emitIfOpen(state.copyWith(status: SelectListStatus.createdWithoutVideo));
  }

  void createdListWithVideoPendingSync() {
    if (isClosed || state.isSaving || !isSessionCurrent) return;
    _listsChanged();
    emitIfOpen(
      state.copyWith(
        status: state.pendingSyncListIds.isEmpty
            ? SelectListStatus.editing
            : SelectListStatus.videoPendingSync,
      ),
    );
  }

  /// Retries publication of the existing local membership.
  Future<void> syncRequested(String listId) async {
    if (isClosed ||
        state.isSaving ||
        !_canMutate(listId) ||
        !state.pendingSyncListIds.contains(listId)) {
      return;
    }
    emitIfOpen(
      state.copyWith(
        status: SelectListStatus.saving,
        syncingListIds: {listId},
        failedSyncListIds: state.failedSyncListIds.difference({listId}),
      ),
    );
    var synced = false;
    try {
      synced = await _service.retryListSync(listId);
    } catch (error, stackTrace) {
      addError(error, stackTrace);
    }
    if (!isSessionCurrent) {
      _sessionFailure();
      return;
    }
    // A service may settle before its listener notification; read its durable
    // membership again rather than treating the retry bool as a row snapshot.
    _listsChanged();
    final pending = state.pendingSyncListIds;
    final failed = state.failedSyncListIds.intersection(pending);
    if (!synced && pending.contains(listId)) failed.add(listId);
    emitIfOpen(
      state.copyWith(
        status: failed.isNotEmpty
            ? SelectListStatus.syncFailed
            : pending.isNotEmpty
            ? SelectListStatus.videoPendingSync
            : SelectListStatus.editing,
        syncingListIds: const {},
        failedSyncListIds: failed,
      ),
    );
  }

  /// Follows the service's lists.
  ///
  /// A list that gained the video since the last look is picked, one that
  /// lost it is unpicked, and one that is gone drops out of the picks; every
  /// other pick stands, so a save in progress keeps what was chosen.
  void _listsChanged() {
    if (isClosed) return;
    if (!isSessionCurrent) {
      emitIfOpen(
        state.copyWith(
          lists: const [],
          memberListIds: const {},
          selectedListIds: const {},
          status: SelectListStatus.failure,
          syncingListIds: const {},
          failedSyncListIds: const {},
        ),
      );
      return;
    }
    final lists = _ownedLists(_service, _openingOwnerPubkey);
    final members = _membership(lists, _videoEventId);
    final gained = members.difference(state.memberListIds);
    final lost = state.memberListIds.difference(members);
    final offered = {for (final list in lists) list.id};
    final selected = state.selectedListIds
        .union(gained)
        .difference(lost)
        .intersection(offered);
    final pending = {
      for (final list in lists)
        if (list.pendingRepublish && members.contains(list.id)) list.id,
    };
    final failed = state.failedSyncListIds.intersection(pending);
    final followsSync =
        state.status == SelectListStatus.videoPendingSync ||
        state.status == SelectListStatus.syncFailed;
    final status = followsSync
        ? failed.isNotEmpty
              ? SelectListStatus.syncFailed
              : pending.isNotEmpty
              ? SelectListStatus.videoPendingSync
              : SelectListStatus.editing
        : state.status;
    emitIfOpen(
      state.copyWith(
        lists: lists,
        memberListIds: members,
        selectedListIds: selected,
        status: status,
        failedSyncListIds: failed,
      ),
    );
  }

  @override
  Future<void> close() {
    _service.removeListener(_listsChanged);
    return super.close();
  }
}
