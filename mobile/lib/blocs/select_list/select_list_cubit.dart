// ABOUTME: Cubit for the sheet that picks which of the viewer's lists hold a
// ABOUTME: video: tracks the picks and writes them to the lists on submit.

import 'package:collection/collection.dart';
import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/blocs/select_list/select_list_state.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:unified_logger/unified_logger.dart';

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
  ///
  /// Pass the video's [videoAddress] when it has one: the video is then added
  /// by that coordinate, which outlives an edit, and a list holding either
  /// name counts as holding it (#7135). With [resolveVideoAddresses] too, the
  /// event-id items of the lists are looked up once, so an item naming an
  /// older version of the video counts as holding it as well.
  SelectListCubit({
    required CuratedListService service,
    required String videoEventId,
    required String? Function() currentOwnerPubkey,
    String? videoAddress,
    CuratedListVideoAddressResolver? resolveVideoAddresses,
  }) : this._(
         service: service,
         video: CuratedListVideo(eventId: videoEventId, address: videoAddress),
         currentOwnerPubkey: currentOwnerPubkey,
         resolveVideoAddresses: resolveVideoAddresses,
       );

  SelectListCubit._({
    required CuratedListService service,
    required CuratedListVideo video,
    required String? Function() currentOwnerPubkey,
    required CuratedListVideoAddressResolver? resolveVideoAddresses,
  }) : _service = service,
       _currentOwnerPubkey = currentOwnerPubkey,
       _openingOwnerPubkey = currentOwnerPubkey(),
       _video = video,
       super(_initialState(service, video, currentOwnerPubkey())) {
    _service.addListener(_listsChanged);
    _olderVersionsLookup =
        resolveVideoAddresses != null && video.address != null
        ? _lookUpOlderVersions(resolveVideoAddresses)
        : Future<void>.value();
    runDetached(
      _olderVersionsLookup,
      'look up older versions of the video',
      logName: 'SelectListCubit',
      category: LogCategory.ui,
    );
  }

  CuratedListService _service;
  int _writeEpoch = 0;
  final CuratedListVideo _video;

  /// The lookup of older versions started with the sheet; already complete
  /// when none runs. A save waits for it before writing, so it neither adds
  /// the video to a list holding an older version nor leaves that version
  /// behind when removing.
  late final Future<void> _olderVersionsLookup;

  /// Whether [_olderVersionsLookup] has finished, so a save only waits on one
  /// still running.
  bool _olderVersionsSettled = true;
  final String? Function() _currentOwnerPubkey;
  final String? _openingOwnerPubkey;

  bool get isSessionCurrent =>
      _service.isCurrentSession &&
      _openingOwnerPubkey != null &&
      _openingOwnerPubkey.isNotEmpty &&
      _currentOwnerPubkey() == _openingOwnerPubkey;

  static List<CuratedList> _ownedLists(
    CuratedListService service,
    String? owner,
  ) => owner == null || owner.isEmpty
      ? const []
      : service
            .pickerListsForOwner(owner)
            .where(
              (list) => list.pubkey == null || list.pubkey == owner,
            )
            .toList();

  bool _canMutate(String listId) =>
      state.serviceAvailable &&
      !_service.recoveryNeedsRepair &&
      isSessionCurrent &&
      _ownedLists(
        _service,
        _openingOwnerPubkey,
      ).any((list) => list.id == listId);

  CuratedList? _ownedList(String listId) => _ownedLists(
    _service,
    _openingOwnerPubkey,
  ).firstWhereOrNull((list) => list.id == listId);

  String? _mutationCoordinate(String listId) =>
      _ownedList(listId)?.authorScopedId;

  bool _permissionRecoveryBlocks(Set<String> ids) => _ownedLists(
    _service,
    _openingOwnerPubkey,
  ).any((list) => ids.contains(list.id) && list.hasPendingPermissionRecovery);

  SelectListStatus _recoveryRequired() {
    emitIfOpen(state.copyWith(status: SelectListStatus.recoveryPendingSync));
    return SelectListStatus.recoveryPendingSync;
  }

  SelectListStatus _pendingNotice({
    List<CuratedList>? lists,
    Set<String>? members,
  }) =>
      (lists ?? state.lists).any((list) {
        final notice = SelectListState.syncNoticeOf(
          list,
          members ?? state.memberListIds,
        );
        return notice != null && notice != SelectListSyncNotice.videoPending;
      })
      ? SelectListStatus.recoveryPendingSync
      : SelectListStatus.videoPendingSync;

  SelectListStatus _sessionFailure() {
    emitIfOpen(
      state.copyWith(
        lists: const [],
        memberListIds: const {},
        selectedListIds: const {},
        syncingListIds: const {},
        failedSyncListIds: const {},
        status: SelectListStatus.failure,
        serviceAvailable: false,
      ),
    );
    return SelectListStatus.failure;
  }

  static SelectListState _initialState(
    CuratedListService service,
    CuratedListVideo video,
    String? owner, {
    Map<String, String> addressByEventId = const {},
  }) {
    final lists = service.isCurrentSession
        ? _ownedLists(service, owner)
        : const <CuratedList>[];
    final members = _membership(lists, video, addressByEventId);
    return SelectListState(
      lists: lists,
      memberListIds: members,
      selectedListIds: members,
      recoveryReadOnly: service.recoveryNeedsRepair,
      serviceAvailable: service.isCurrentSession,
      addressByEventId: addressByEventId,
    );
  }

  static Set<String> _membership(
    List<CuratedList> lists,
    CuratedListVideo video,
    Map<String, String> addressByEventId,
  ) {
    return {
      for (final list in lists)
        if (video.isIn(list, addressByEventId: addressByEventId)) list.id,
    };
  }

  /// Learns which event-id items in the lists are older versions of the
  /// video, then follows the lists again so they count as holding it. Picks
  /// made meanwhile stand, as for any change to the lists.
  ///
  /// Best effort: a failed lookup leaves membership as it was.
  Future<void> _lookUpOlderVersions(
    CuratedListVideoAddressResolver resolve,
  ) async {
    final eventIds = CuratedListVideo.eventIdItemsOf(
      state.lists,
      except: {_video.eventId},
    );
    if (eventIds.isEmpty) return;
    _olderVersionsSettled = false;
    try {
      final Map<String, String> addresses;
      try {
        addresses = await resolve(eventIds);
      } on Object catch (error) {
        Log.warning(
          'Could not look up the videos of ${eventIds.length} list items: '
          '$error',
          name: 'SelectListCubit',
          category: LogCategory.ui,
        );
        return;
      }
      if (isClosed) return;
      emitIfOpen(
        state.copyWith(
          addressByEventId: {...state.addressByEventId, ...addresses},
        ),
      );
      _listsChanged();
    } finally {
      _olderVersionsSettled = true;
    }
  }

  /// Follows the provider's current service without carrying staged picks
  /// across service replacement. Missing services preserve a known recovery
  /// hold and the last safe rows, while keeping all writes unavailable.
  void serviceChanged(CuratedListService? service) {
    if (isClosed) return;
    if (_currentOwnerPubkey() != _openingOwnerPubkey) {
      _writeEpoch++;
      _sessionFailure();
      return;
    }
    if (service == null) {
      if (state.serviceAvailable) _writeEpoch++;
      emitIfOpen(
        state.copyWith(
          serviceAvailable: false,
          status: SelectListStatus.editing,
          syncingListIds: const {},
        ),
      );
      return;
    }
    if (!identical(service, _service)) {
      _writeEpoch++;
      _service.removeListener(_listsChanged);
      _service = service;
      _service.addListener(_listsChanged);
      emitIfOpen(
        _initialState(
          service,
          _video,
          _openingOwnerPubkey,
          addressByEventId: state.addressByEventId,
        ),
      );
    } else {
      emitIfOpen(state.copyWith(serviceAvailable: true));
    }
    _listsChanged();
  }

  /// Checks the live service as well as the rendered state, so callbacks
  /// captured before a recovery hold cannot stage or publish a change.
  void refreshRecoveryReadOnly() {
    if (isClosed || !state.serviceAvailable) return;
    final held = _service.recoveryNeedsRepair;
    if (held == state.recoveryReadOnly) return;
    if (held) _writeEpoch++;
    emitIfOpen(
      state.copyWith(
        recoveryReadOnly: held,
        selectedListIds: held ? state.memberListIds : state.selectedListIds,
        status: SelectListStatus.editing,
        syncingListIds: const {},
      ),
    );
  }

  bool _writesPaused() {
    refreshRecoveryReadOnly();
    return !state.serviceAvailable || state.recoveryReadOnly;
  }

  bool _writeInterrupted(int epoch) => _writesPaused() || epoch != _writeEpoch;

  /// Picks the list with [listId], or unpicks it when it is picked.
  ///
  /// Ignored during read-only recovery or a save, for an unavailable list, and
  /// for one waiting on an accepted permission change. Clears the sheet instead
  /// once the account it opened for is no longer current.
  void toggled(String listId) {
    if (state.isSaving) return;
    if (!isSessionCurrent) {
      _sessionFailure();
      return;
    }
    if (_writesPaused()) return;
    if (state.lists.none(
      (list) => list.id == listId && !list.hasPendingPermissionRecovery,
    )) {
      return;
    }
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
  /// [SelectListStatus.failureListFull] with the rest still picked. Stops
  /// before a list waiting on an accepted permission change, ending in
  /// [SelectListStatus.recoveryPendingSync], and clears the sheet with
  /// [SelectListStatus.failure] once the account it opened for is no longer
  /// current or no longer owns a list it would change. Ignored while
  /// [SelectListState.canSubmit] is false, as the sheet's check is then
  /// disabled. Read-only recovery also blocks every write. Returns the outcome
  /// so a caller can report failure even after the sheet closes.
  Future<SelectListStatus?> submitted() async {
    if (!isSessionCurrent) return _sessionFailure();
    if (_writesPaused() || !state.canSubmit) return null;
    final epoch = _writeEpoch;
    final service = _service;
    final toAdd = state.listIdsToAdd;
    final toRemove = state.listIdsToRemove;
    if (_permissionRecoveryBlocks({...toAdd, ...toRemove})) {
      return _recoveryRequired();
    }
    if (toAdd.isEmpty && toRemove.isEmpty) {
      emitIfOpen(state.copyWith(status: SelectListStatus.saved));
      return SelectListStatus.saved;
    }
    emitIfOpen(state.copyWith(status: SelectListStatus.saving));

    var failed = 0;
    var full = 0;
    try {
      // The lookup can show that a list already holds the video by an older
      // version's event id, so the picks are read again once it answers: a
      // quick save then neither adds the video to that list a second time nor
      // leaves the older item behind when removing.
      if (!_olderVersionsSettled) {
        await _olderVersionsLookup;
        if (!isSessionCurrent) return _sessionFailure();
        if (_writeInterrupted(epoch)) return null;
      }
      final adds = state.listIdsToAdd;
      final removes = state.listIdsToRemove;
      for (final listId in adds) {
        if (_writeInterrupted(epoch)) return null;
        if (!_canMutate(listId)) return _sessionFailure();
        if (_permissionRecoveryBlocks({listId})) return _recoveryRequired();
        final coordinate = _mutationCoordinate(listId);
        if (coordinate == null) return _sessionFailure();
        final added = await service.addVideoToList(
          coordinate,
          _video.reference,
        );
        if (!isSessionCurrent) return _sessionFailure();
        if (_writeInterrupted(epoch)) return null;
        if (added) continue;
        failed++;
        final list = state.lists.firstWhereOrNull((it) => it.id == listId);
        if (list != null &&
            CuratedListConverter.wouldExceedPrivateItemLimit(
              list,
              _video.reference,
            )) {
          full++;
        }
      }
      for (final listId in removes) {
        if (_writeInterrupted(epoch)) return null;
        if (!_canMutate(listId)) return _sessionFailure();
        if (_permissionRecoveryBlocks({listId})) return _recoveryRequired();
        final list = _ownedList(listId);
        if (list == null) return _sessionFailure();
        // A list can hold the video by its coordinate and by an older event
        // id at once; each name is a separate item to drop.
        var removed = true;
        for (final reference in _video.referencesIn(
          list,
          addressByEventId: state.addressByEventId,
        )) {
          final dropped = await service.removeVideoFromList(
            list.authorScopedId,
            reference,
          );
          removed = removed && dropped;
          if (!isSessionCurrent) return _sessionFailure();
          if (_writeInterrupted(epoch)) return null;
        }
        if (!removed) {
          failed++;
        }
      }
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!isSessionCurrent) return _sessionFailure();
      if (_writeInterrupted(epoch)) return null;
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
    if (_writesPaused() || state.isSaving || !isSessionCurrent) return;
    emitIfOpen(state.copyWith(status: SelectListStatus.createdWithoutVideo));
  }

  void createdListWithVideoPendingSync() {
    if (isClosed || _writesPaused() || state.isSaving || !isSessionCurrent) {
      return;
    }
    _listsChanged();
    emitIfOpen(
      state.copyWith(
        status: state.pendingSyncListIds.isEmpty
            ? SelectListStatus.editing
            : _pendingNotice(),
      ),
    );
  }

  /// Retries publication of the existing local membership.
  Future<void> syncRequested(String listId) async {
    if (isClosed) return;
    if (!isSessionCurrent) {
      _sessionFailure();
      return;
    }
    if (_writesPaused()) return;
    if (state.isSaving ||
        !_canMutate(listId) ||
        !state.pendingSyncListIds.contains(listId)) {
      return;
    }
    final coordinate = _mutationCoordinate(listId);
    if (coordinate == null) return;
    emitIfOpen(
      state.copyWith(
        status: SelectListStatus.saving,
        syncingListIds: {listId},
        failedSyncListIds: state.failedSyncListIds.difference({listId}),
      ),
    );
    final epoch = _writeEpoch;
    final service = _service;
    var synced = false;
    try {
      synced = await service.retryListSync(coordinate);
    } catch (error, stackTrace) {
      addError(error, stackTrace);
    }
    if (!isSessionCurrent) {
      _sessionFailure();
      return;
    }
    if (_writeInterrupted(epoch)) return;
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
            ? _pendingNotice()
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
    if (isClosed || !state.serviceAvailable) return;
    refreshRecoveryReadOnly();
    if (!isSessionCurrent) {
      emitIfOpen(
        state.copyWith(
          lists: const [],
          memberListIds: const {},
          selectedListIds: const {},
          status: SelectListStatus.failure,
          syncingListIds: const {},
          failedSyncListIds: const {},
          serviceAvailable: false,
        ),
      );
      return;
    }
    final lists = _ownedLists(_service, _openingOwnerPubkey);
    final members = _membership(lists, _video, state.addressByEventId);
    final gained = members.difference(state.memberListIds);
    final lost = state.memberListIds.difference(members);
    final offered = {for (final list in lists) list.id};
    final selected = state.selectedListIds
        .union(gained)
        .difference(lost)
        .intersection(offered);
    final pending = {
      for (final list in lists)
        if (list.needsSync) list.id,
    };
    final failed = state.failedSyncListIds.intersection(pending);
    final followsSync =
        state.status == SelectListStatus.videoPendingSync ||
        state.status == SelectListStatus.recoveryPendingSync ||
        state.status == SelectListStatus.syncFailed;
    final status = followsSync
        ? failed.isNotEmpty
              ? SelectListStatus.syncFailed
              : pending.isNotEmpty
              ? _pendingNotice(lists: lists, members: members)
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
