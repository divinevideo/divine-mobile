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
    CuratedList? existingList,
    String? videoEventId,
  }) : _resolveService = resolveService,
       _listId = existingList?.id,
       _storedCollaborators = existingList?.allowedCollaborators ?? const [],
       _videoEventId = videoEventId,
       super(
         CuratedListInfoState(
           name: existingList?.name ?? '',
           description: existingList?.description ?? '',
           isPublic: existingList?.isPublic ?? true,
           collaboratorPubkeys: existingList?.allowedCollaborators ?? const [],
           wasPublic: existingList?.isPublic,
         ),
       );

  final CuratedListService? Function() _resolveService;
  final String? _listId;

  /// The collaborators the list was opened with.
  final List<String> _storedCollaborators;
  final String? _videoEventId;

  /// Records the list name as typed.
  void nameChanged(String name) {
    if (state.isSaving) return;
    emitIfOpen(
      state.copyWith(name: name, status: CuratedListInfoStatus.editing),
    );
  }

  /// Records the description as typed.
  void descriptionChanged(String description) {
    if (state.isSaving) return;
    emitIfOpen(
      state.copyWith(
        description: description,
        status: CuratedListInfoStatus.editing,
      ),
    );
  }

  /// Records whether the list should be public.
  void visibilityChanged({required bool isPublic}) {
    if (state.isSaving) return;
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
  /// A collaborator whose profile has not resolved cannot be shown in the
  /// picker, so its absence from [picked] is not a removal. [offered] is what
  /// the picker opened with. [viewerPubkey] is dropped from the result: the
  /// owner is not their own collaborator.
  void collaboratorsPicked({
    required Set<String> offered,
    required Set<String> picked,
    String? viewerPubkey,
  }) {
    if (state.isSaving) return;
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

  /// Creates the list, or saves the edits to it.
  ///
  /// Ends in [CuratedListInfoStatus.saved] or
  /// [CuratedListInfoStatus.failure]. A creation whose list exists but did
  /// not take the video ends in [CuratedListInfoStatus.createdWithoutVideo].
  /// An edit that leaves visibility alone passes through
  /// [CuratedListInfoStatus.savedAwaitingRelay] first and can end in
  /// [CuratedListInfoStatus.publishFailed] instead, as do the collaborators of
  /// a list that has just gone public.
  Future<void> submitted() async {
    if (!state.canSubmit) return;

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
      if (listId == null) {
        final created = await service.createList(
          name: name,
          description: description.isEmpty ? null : description,
          isPublic: isPublic,
          isCollaborative: collaborators.isNotEmpty,
          allowedCollaborators: collaborators,
        );
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
        emitIfOpen(
          state.copyWith(
            status: videoAdded
                ? CuratedListInfoStatus.saved
                : CuratedListInfoStatus.createdWithoutVideo,
          ),
        );
        return;
      }

      // An edit that leaves the collaborators alone passes none, so the
      // list keeps what it has stored, its collaborative flag included. A
      // private list cannot be collaborative at all, so it always writes
      // them, as none.
      final writesCollaborators =
          !isPublic ||
          !const SetEquality<String>().equals(
            collaborators.toSet(),
            _storedCollaborators.toSet(),
          );
      // A list going public takes its collaborators once the flip is
      // accepted: updateList stores them before any relay answers, so a
      // refused flip would leave a private list that is collaborative.
      final collaboratorsFollowFlip =
          visibilityWillChange && isPublic && writesCollaborators;
      final carriesCollaborators =
          writesCollaborators && !collaboratorsFollowFlip;
      // Only a flip sends visibility: the list may have changed since the
      // sheet opened, and resending the opening value would undo that.
      final update = service.updateList(
        listId: listId,
        name: name,
        description: description,
        isPublic: visibilityWillChange ? isPublic : null,
        isCollaborative: carriesCollaborators ? collaborators.isNotEmpty : null,
        allowedCollaborators: carriesCollaborators ? collaborators : null,
      );

      // Visibility is the one field updateList holds back until a relay
      // accepts the change, so a rejection means the switch the user flipped
      // did not take. Wait for the answer and keep the form open on failure.
      if (visibilityWillChange) {
        if (!await update) {
          emitIfOpen(state.copyWith(status: CuratedListInfoStatus.failure));
          return;
        }
        if (collaboratorsFollowFlip) {
          await _closeThenAwait(
            service.updateList(
              listId: listId,
              isCollaborative: collaborators.isNotEmpty,
              allowedCollaborators: collaborators,
            ),
          );
        } else {
          emitIfOpen(state.copyWith(status: CuratedListInfoStatus.saved));
        }
        return;
      }

      await _closeThenAwait(update);
    } catch (error, stackTrace) {
      // Expected domain or network failure: surfaced through the status, not
      // Crashlytics, per the reportable-error decision matrix.
      addError(error, stackTrace);
      emitIfOpen(
        state.copyWith(
          status: state.status == CuratedListInfoStatus.savedAwaitingRelay
              ? CuratedListInfoStatus.publishFailed
              : CuratedListInfoStatus.failure,
        ),
      );
    }
  }

  /// Lets the form close, then reports how [update] ended.
  ///
  /// Everything but visibility is stored on this device before updateList
  /// awaits a relay, so nothing typed rides on the answer. That write waits
  /// its turn behind an earlier save to the same list that is still waiting on
  /// a relay. The form closes now rather than stay open on a slow relay.
  Future<void> _closeThenAwait(Future<bool> update) async {
    emitIfOpen(
      state.copyWith(status: CuratedListInfoStatus.savedAwaitingRelay),
    );
    final published = await update;
    emitIfOpen(
      state.copyWith(
        status: published
            ? CuratedListInfoStatus.saved
            : CuratedListInfoStatus.publishFailed,
      ),
    );
  }
}
