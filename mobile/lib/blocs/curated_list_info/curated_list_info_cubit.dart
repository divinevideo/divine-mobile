// ABOUTME: Cubit for the list info sheet: holds the form's values and creates
// ABOUTME: or updates the curated list when the form is submitted.

import 'package:collection/collection.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nip19/pubkeys_equal.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/blocs/curated_list_info/curated_list_info_state.dart';
import 'package:openvine/services/curated_list_service.dart';

export 'package:openvine/blocs/curated_list_info/curated_list_info_state.dart';

/// Drives the sheet that creates a curated list or edits one's info.
///
/// One instance lives for one visit to the sheet. It outlives the sheet by
/// the length of a save still waiting on a relay, so that a rename which let
/// the sheet close early can still report that no relay accepted it.
class CuratedListInfoCubit extends Cubit<CuratedListInfoState>
    with CloseGuardedEmit<CuratedListInfoState> {
  /// Creates the cubit for one visit to the sheet.
  ///
  /// Pass [existingList] to edit that list; leave it out to create one.
  /// [videoEventId] is added to a newly created list.
  ///
  /// [resolveService] is asked for the service when a save starts: the app
  /// builds a new one when its relay client is replaced, and a save has to
  /// reach the one it holds then. It answers null when there is none.
  CuratedListInfoCubit({
    required CuratedListService? Function() resolveService,
    required String? Function() currentOwnerPubkey,
    CuratedList? existingList,
    String? videoEventId,
  }) : _resolveService = resolveService,
       _currentOwnerPubkey = currentOwnerPubkey,
       _openingOwnerPubkey = currentOwnerPubkey(),
       _listOwnerPubkey = existingList?.pubkey,
       _listId = existingList?.id,
       _storedCollaborators = existingList?.allowedCollaborators ?? const [],
       _videoEventId = videoEventId,
       super(
         CuratedListInfoState(
           name: existingList?.name ?? '',
           description: existingList?.description ?? '',
           isPublic: existingList?.publicationTarget.isPublic ?? true,
           collaboratorPubkeys:
               existingList?.publicationTarget.allowedCollaborators ?? const [],
           wasPublic: existingList?.isPublic,
           needsSync: existingList?.needsSync ?? false,
           permissionRecoveryPending:
               existingList?.hasPendingPermissionRecovery ?? false,
         ),
       );

  final CuratedListService? Function() _resolveService;
  final String? Function() _currentOwnerPubkey;
  final String? _openingOwnerPubkey;
  final String? _listOwnerPubkey;
  final String? _listId;

  bool get isSessionCurrent =>
      _openingOwnerPubkey != null &&
      _openingOwnerPubkey.isNotEmpty &&
      _currentOwnerPubkey() == _openingOwnerPubkey;

  /// The collaborators the list was opened with.
  List<String> _storedCollaborators;
  final String? _videoEventId;

  /// Records the list name as typed.
  void nameChanged(String name) {
    if (!state.canEdit) return;
    emitIfOpen(
      state.copyWith(name: name, status: CuratedListInfoStatus.editing),
    );
  }

  /// Records the description as typed.
  void descriptionChanged(String description) {
    if (!state.canEdit) return;
    emitIfOpen(
      state.copyWith(
        description: description,
        status: CuratedListInfoStatus.editing,
      ),
    );
  }

  /// Records whether the list should be public.
  void visibilityChanged({required bool isPublic}) {
    if (!state.canEdit) return;
    emitIfOpen(
      state.copyWith(
        isPublic: isPublic,
        status: CuratedListInfoStatus.editing,
      ),
    );
  }

  /// Replaces the collaborators with [picked], keeping any the picker was
  /// never offered.
  ///
  /// [offered] is the full set the picker opened with, including fallback
  /// profiles whose names have not resolved. A caller that intentionally
  /// offers only part of that set must not remove permissions it did not offer.
  /// [viewerPubkey] is dropped from the result: the
  /// owner is not their own collaborator.
  void collaboratorsPicked({
    required Set<String> offered,
    required Set<String> picked,
    String? viewerPubkey,
  }) {
    if (!state.canEdit || isClosed || !isSessionCurrent) return;
    final neverOffered = state.collaboratorPubkeys.where(
      (pubkey) => !offered.contains(pubkey),
    );
    final next = <String>{...picked, ...neverOffered}
        .where(
          (pubkey) =>
              viewerPubkey == null || !pubkeysEqual(pubkey, viewerPubkey),
        )
        .toList();
    emitIfOpen(
      state.copyWith(
        collaboratorPubkeys: next,
        status: CuratedListInfoStatus.editing,
      ),
    );
  }

  /// Completes only previously confirmed recovery or pending delivery.
  Future<void> retrySync() async {
    final listId = _listId;
    final service = _resolveService();
    if (listId == null ||
        service == null ||
        state.isSaving ||
        !isSessionCurrent) {
      return;
    }
    emitIfOpen(state.copyWith(status: CuratedListInfoStatus.saving));
    var recovered = false;
    try {
      recovered = await service.retryListSync(listId);
    } catch (error, stackTrace) {
      addError(error, stackTrace);
    }
    if (!isSessionCurrent || isClosed) return;
    final list = service.getListById(listId);
    if (list == null || list.pubkey != _openingOwnerPubkey) {
      emitIfOpen(state.copyWith(status: CuratedListInfoStatus.failure));
      return;
    }
    _storedCollaborators = list.allowedCollaborators;
    emitIfOpen(
      state.copyWith(
        status: recovered
            ? CuratedListInfoStatus.editing
            : CuratedListInfoStatus.failure,
        isPublic: list.publicationTarget.isPublic,
        collaboratorPubkeys: list.publicationTarget.allowedCollaborators,
        wasPublic: list.isPublic,
        needsSync: list.needsSync,
        permissionRecoveryPending: list.hasPendingPermissionRecovery,
      ),
    );
  }

  /// Creates the list, or saves the edits to it.
  ///
  /// Ends in [CuratedListInfoStatus.saved] or
  /// [CuratedListInfoStatus.failure]. A creation whose list exists but did
  /// not take the video ends in [CuratedListInfoStatus.createdWithoutVideo].
  /// A locally added video awaiting publication ends in
  /// [CuratedListInfoStatus.createdWithVideoPendingSync]. Permissions edits
  /// without a confirmed relay outcome end in
  /// [CuratedListInfoStatus.permissionsUnconfirmed].
  /// An edit that leaves visibility and collaborator permissions unchanged
  /// passes through [CuratedListInfoStatus.savedAwaitingRelay] first and can end in
  /// [CuratedListInfoStatus.publishFailed] instead.
  Future<void> submitted() async {
    if (!state.canSubmit) return;
    if (!isSessionCurrent) {
      emitIfOpen(state.copyWith(status: CuratedListInfoStatus.failure));
      return;
    }

    final name = state.name.trim();
    final description = state.description.trim();
    final isPublic = state.isPublic;
    final collaborators = state.savedCollaboratorPubkeys;
    final visibilityWillChange = state.visibilityWillChange;
    final service = _resolveService();
    final listId = _listId;

    emitIfOpen(state.copyWith(status: CuratedListInfoStatus.saving));
    if (service == null) {
      emitIfOpen(state.copyWith(status: CuratedListInfoStatus.failure));
      return;
    }

    try {
      if (listId != null &&
          (_listOwnerPubkey == null ||
              _listOwnerPubkey != _openingOwnerPubkey ||
              service.getListById(listId)?.pubkey != _listOwnerPubkey)) {
        emitIfOpen(state.copyWith(status: CuratedListInfoStatus.failure));
        return;
      }
      if (listId == null) {
        final created = await service.createList(
          name: name,
          description: description.isEmpty ? null : description,
          isPublic: isPublic,
          isCollaborative: collaborators.isNotEmpty,
          allowedCollaborators: collaborators,
        );
        if (!isSessionCurrent) {
          emitIfOpen(state.copyWith(status: CuratedListInfoStatus.failure));
          return;
        }
        // createList catches its own exceptions and answers with null.
        if (created == null) {
          emitIfOpen(state.copyWith(status: CuratedListInfoStatus.failure));
          return;
        }
        final videoEventId = _videoEventId;
        // addVideoToList answers false for a private list with no room or a
        // publish no relay took; the list exists either way, so the form
        // closes and the opener hands the outcome to its caller.
        final videoAdded =
            videoEventId == null ||
            await service.addVideoToList(created.id, videoEventId);
        if (!isSessionCurrent) {
          emitIfOpen(state.copyWith(status: CuratedListInfoStatus.failure));
          return;
        }
        final pendingVideo =
            !videoAdded &&
            service
                    .getListById(created.id)
                    ?.videoEventIds
                    .contains(videoEventId) ==
                true;
        emitIfOpen(
          state.copyWith(
            status: videoAdded
                ? CuratedListInfoStatus.saved
                : pendingVideo
                ? CuratedListInfoStatus.createdWithVideoPendingSync
                : CuratedListInfoStatus.createdWithoutVideo,
          ),
        );
        return;
      }

      // Only an explicit permissions edit or privacy flip changes collaborators.
      final writesCollaborators =
          (visibilityWillChange && !isPublic) ||
          !const SetEquality<String>().equals(
            collaborators.toSet(),
            _storedCollaborators.toSet(),
          );
      // Only a flip sends visibility: the list may have changed since the
      // sheet opened, and resending the opening value would undo that.
      final permissionsWillChange = visibilityWillChange || writesCollaborators;
      var publicationUnconfirmed = false;
      final update = service.updateList(
        listId: listId,
        name: name,
        description: description,
        isPublic: visibilityWillChange ? isPublic : null,
        isCollaborative: writesCollaborators ? collaborators.isNotEmpty : null,
        allowedCollaborators: writesCollaborators ? collaborators : null,
        onPublicationUnconfirmed: permissionsWillChange
            ? () => publicationUnconfirmed = true
            : null,
        onLocalSaved: permissionsWillChange
            ? null
            : () {
                if (isSessionCurrent) {
                  emitIfOpen(
                    state.copyWith(
                      status: CuratedListInfoStatus.savedAwaitingRelay,
                    ),
                  );
                }
              },
      );

      // Explicit visibility and collaborator changes wait for relay acceptance.
      // A missing acknowledgement is not proof that the relay did not receive
      // the change, so keep that outcome separate from a rejected/local save.
      if (permissionsWillChange) {
        final updated = await update;
        if (!isSessionCurrent) {
          emitIfOpen(state.copyWith(status: CuratedListInfoStatus.failure));
          return;
        }
        final pending = service.getListById(listId);
        emitIfOpen(
          state.copyWith(
            needsSync: pending?.needsSync ?? false,
            permissionRecoveryPending:
                pending?.hasPendingPermissionRecovery ?? false,
            status: updated
                ? CuratedListInfoStatus.saved
                : publicationUnconfirmed
                ? CuratedListInfoStatus.permissionsUnconfirmed
                : CuratedListInfoStatus.failure,
          ),
        );
        return;
      }

      await _closeThenAwait(update);
    } catch (error, stackTrace) {
      // Expected domain or network failure: surfaced through the status, not
      // Crashlytics, per the reportable-error decision matrix.
      addError(error, stackTrace);
      final pending = isSessionCurrent && _listId != null
          ? _resolveService()?.getListById(_listId)
          : null;
      emitIfOpen(
        state.copyWith(
          needsSync: pending?.needsSync ?? state.needsSync,
          permissionRecoveryPending:
              pending?.hasPendingPermissionRecovery ??
              state.permissionRecoveryPending,
          status: state.status == CuratedListInfoStatus.savedAwaitingRelay
              ? CuratedListInfoStatus.publishFailed
              : CuratedListInfoStatus.failure,
        ),
      );
    }
  }

  /// Lets the form close, then reports how [update] ended.
  ///
  /// The service emits the local milestone only after this edit reaches
  /// storage, including when it was queued behind another publication.
  Future<void> _closeThenAwait(Future<bool> update) async {
    final published = await update;
    if (!isSessionCurrent) {
      emitIfOpen(state.copyWith(status: CuratedListInfoStatus.failure));
      return;
    }
    emitIfOpen(
      state.copyWith(
        status: published
            ? CuratedListInfoStatus.saved
            : state.status == CuratedListInfoStatus.savedAwaitingRelay
            ? CuratedListInfoStatus.publishFailed
            : CuratedListInfoStatus.failure,
      ),
    );
  }
}
