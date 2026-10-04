// ABOUTME: Cubit for the sheet that edits a people list's info: holds the
// ABOUTME: form's values and publishes the renamed list when it is submitted.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/features/people_lists/bloc/people_list_info_state.dart';
import 'package:openvine/features/people_lists/bloc/people_lists_bloc.dart';

export 'package:openvine/features/people_lists/bloc/people_list_info_state.dart';

/// Drives the sheet that edits a people list's name and description.
///
/// One instance lives for one visit to the sheet. The renamed list reaches
/// the screens that show it through the repository's stream, the same way a
/// change made on another device does.
class PeopleListInfoCubit extends Cubit<PeopleListInfoState>
    with CloseGuardedEmit<PeopleListInfoState> {
  /// Creates the cubit for one visit to the sheet, opened on [list].
  PeopleListInfoCubit({
    required Future<PeopleListsOperationResult> Function(
      PeopleListsInfoUpdateRequested request,
    )
    submitMutation,
    required String ownerPubkey,
    required String? Function() currentOwnerPubkey,
    required UserList list,
  }) : _submitMutation = submitMutation,
       _ownerPubkey = ownerPubkey,
       _currentOwnerPubkey = currentOwnerPubkey,
       _listId = list.id,
       super(
         PeopleListInfoState(
           name: list.name,
           description: list.description ?? '',
         ),
       );

  final Future<PeopleListsOperationResult> Function(
    PeopleListsInfoUpdateRequested request,
  )
  _submitMutation;
  final String _ownerPubkey;
  final String? Function() _currentOwnerPubkey;

  /// The editor visit remains bound to the owner that opened it.
  bool get isSessionCurrent =>
      _ownerPubkey.isNotEmpty && _currentOwnerPubkey() == _ownerPubkey;
  final String _listId;

  /// Records the list name as typed.
  void nameChanged(String name) {
    if (state.isSaving) return;
    emitIfOpen(
      state.copyWith(name: name, status: PeopleListInfoStatus.editing),
    );
  }

  /// Records the description as typed.
  void descriptionChanged(String description) {
    if (state.isSaving) return;
    emitIfOpen(
      state.copyWith(
        description: description,
        status: PeopleListInfoStatus.editing,
      ),
    );
  }

  /// Publishes the list with the name and description as they stand.
  ///
  /// Returns the outcome even after this cubit closes so a dismissed sheet
  /// can report a refused save; returns null if submission was unavailable.
  Future<PeopleListInfoStatus?> submitted() async {
    if (isClosed || !state.canSubmit) return null;
    if (!isSessionCurrent) {
      emitIfOpen(state.copyWith(status: PeopleListInfoStatus.failure));
      return PeopleListInfoStatus.failure;
    }

    emitIfOpen(state.copyWith(status: PeopleListInfoStatus.saving));
    try {
      final result = await _submitMutation(
        PeopleListsInfoUpdateRequested(
          expectedOwnerPubkey: _ownerPubkey,
          listId: _listId,
          name: state.name,
          description: state.description,
        ),
      );
      if (!isSessionCurrent) {
        emitIfOpen(state.copyWith(status: PeopleListInfoStatus.failure));
        return PeopleListInfoStatus.failure;
      }
      final status = result == PeopleListsOperationResult.succeeded
          ? PeopleListInfoStatus.saved
          : PeopleListInfoStatus.failure;
      // The outcome remains available after manual dismissal while guarded
      // emissions protect disposed fields.
      emitIfOpen(state.copyWith(status: status));
      return status;
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emitIfOpen(state.copyWith(status: PeopleListInfoStatus.failure));
      return PeopleListInfoStatus.failure;
    }
  }
}
