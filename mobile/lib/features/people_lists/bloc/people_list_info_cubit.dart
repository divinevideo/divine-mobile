// ABOUTME: Cubit for the sheet that edits a people list's info: holds the
// ABOUTME: form's values and publishes the renamed list when it is submitted.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/features/people_lists/bloc/people_list_info_state.dart';
import 'package:people_lists_repository/people_lists_repository.dart';

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
    required PeopleListsRepository repository,
    required String ownerPubkey,
    required UserList list,
  }) : _repository = repository,
       _ownerPubkey = ownerPubkey,
       _listId = list.id,
       super(
         PeopleListInfoState(
           name: list.name,
           description: list.description ?? '',
         ),
       );

  final PeopleListsRepository _repository;
  final String _ownerPubkey;
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
  /// Ends in [PeopleListInfoStatus.saved] or [PeopleListInfoStatus.failure].
  Future<void> submitted() async {
    if (!state.canSubmit) return;

    emitIfOpen(state.copyWith(status: PeopleListInfoStatus.saving));
    try {
      final result = await _repository.updateListInfo(
        ownerPubkey: _ownerPubkey,
        listId: _listId,
        name: state.name,
        description: state.description,
      );
      emitIfOpen(
        state.copyWith(
          status: result.status == PeopleListPublishStatus.failed
              ? PeopleListInfoStatus.failure
              : PeopleListInfoStatus.saved,
        ),
      );
    } catch (error, stackTrace) {
      // A relay or storage failure, surfaced through the status rather than
      // Crashlytics, per the reportable-error decision matrix.
      addError(error, stackTrace);
      emitIfOpen(state.copyWith(status: PeopleListInfoStatus.failure));
    }
  }
}
