// ABOUTME: BLoC for managing draft video projects in the library
// ABOUTME: Handles loading and deleting drafts with proper state management

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:unified_logger/unified_logger.dart';

part 'drafts_library_event.dart';
part 'drafts_library_state.dart';

/// BLoC for managing draft video projects in the library.
///
/// Loads drafts from [DraftStorageService] and handles deletion.
/// Filters out empty autosaves and already published drafts.
class DraftsLibraryBloc extends Bloc<DraftsLibraryEvent, DraftsLibraryState> {
  DraftsLibraryBloc({
    required DraftStorageService draftStorageService,
    this.includeAutosaveDraft = true,
  }) : _draftStorageService = draftStorageService,
       super(const DraftsLibraryInitial()) {
    // Restartable, not droppable: a reload asked for *after* a write has to
    // run, and droppable discarded exactly that one whenever a load was
    // already in flight — which is the norm here, because the writes that
    // reclaim a draft land right as the library reopens. The handler only
    // reads and emits, so losing an older one mid-await costs nothing.
    on<DraftsLibraryLoadRequested>(
      _onLoadRequested,
      transformer: restartable(),
    );
    // Duplicate and delete share ONE sequential queue so their handlers never
    // interleave; separate buckets would let one finish mid-flight and emit a
    // stale draft list (see [DraftsLibraryMutationEvent]).
    on<DraftsLibraryMutationEvent>(_onMutation, transformer: sequential());
  }

  final DraftStorageService _draftStorageService;

  /// Whether the in-progress autosave draft may appear in the list.
  ///
  /// The recorder opens its library on top of the session that owns the
  /// autosave, so listing it there would offer the user their own live
  /// session as something to reopen.
  final bool includeAutosaveDraft;

  /// Whether [draft] belongs in the library list.
  ///
  /// Drops published, publishing and scheduled drafts (the last belong to
  /// the Scheduled tab), plus the autosave when it holds nothing yet or
  /// [includeAutosaveDraft] is off.
  bool _isListable(DivineVideoDraft draft) {
    if (draft.id == VideoEditorConstants.autoSaveId &&
        (!includeAutosaveDraft || draft.clips.isEmpty)) {
      return false;
    }
    return draft.publishStatus != PublishStatus.published &&
        draft.publishStatus != PublishStatus.publishing &&
        draft.publishStatus != PublishStatus.scheduled;
  }

  Future<void> _onMutation(
    DraftsLibraryMutationEvent event,
    Emitter<DraftsLibraryState> emit,
  ) {
    return switch (event) {
      DraftsLibraryDuplicateRequested() => _onDuplicateRequested(event, emit),
      DraftsLibraryDeleteRequested() => _onDeleteRequested(event, emit),
    };
  }

  Future<void> _onLoadRequested(
    DraftsLibraryLoadRequested event,
    Emitter<DraftsLibraryState> emit,
  ) async {
    emit(const DraftsLibraryLoading());

    try {
      final allDrafts = await _draftStorageService.getAllDrafts();

      final filteredDrafts = allDrafts.where(_isListable).toList()
        ..sort((a, b) => b.lastModified.compareTo(a.lastModified));

      Log.debug(
        '📚 Loaded ${filteredDrafts.length} drafts',
        name: 'DraftsLibraryBloc',
        category: LogCategory.video,
      );

      emit(DraftsLibraryLoaded(drafts: filteredDrafts));
    } catch (e, stackTrace) {
      Log.error(
        '📚 Failed to load drafts: $e',
        name: 'DraftsLibraryBloc',
        category: LogCategory.video,
      );
      addError(e, stackTrace);
      emit(const DraftsLibraryError());
    }
  }

  Future<void> _onDuplicateRequested(
    DraftsLibraryDuplicateRequested event,
    Emitter<DraftsLibraryState> emit,
  ) async {
    final currentDrafts = switch (state) {
      DraftsLibraryLoaded(:final drafts) ||
      DraftsLibraryDraftDuplicated(:final drafts) ||
      DraftsLibraryDuplicateFailed(:final drafts) ||
      DraftsLibraryDraftDeleted(:final drafts) ||
      DraftsLibraryDeleteFailed(:final drafts) => drafts,
      _ => null,
    };
    if (currentDrafts == null) return;

    DivineVideoDraft? source;
    for (final draft in currentDrafts) {
      if (draft.id == event.draftId) {
        source = draft;
        break;
      }
    }
    if (source == null) return;

    try {
      Log.info(
        '📚 Duplicating draft: ${event.draftId}',
        name: 'DraftsLibraryBloc',
        category: LogCategory.video,
      );

      final copy = source.duplicate(title: event.newTitle);
      await _draftStorageService.saveDraft(copy);

      final updatedDrafts = [...currentDrafts, copy]
        ..sort((a, b) => b.lastModified.compareTo(a.lastModified));

      emit(DraftsLibraryDraftDuplicated(drafts: updatedDrafts));
      emit(DraftsLibraryLoaded(drafts: updatedDrafts));
    } catch (e, stackTrace) {
      Log.error(
        '📚 Failed to duplicate draft: $e',
        name: 'DraftsLibraryBloc',
        category: LogCategory.video,
      );
      addError(e, stackTrace);
      emit(DraftsLibraryDuplicateFailed(drafts: currentDrafts));
      emit(DraftsLibraryLoaded(drafts: currentDrafts));
    }
  }

  Future<void> _onDeleteRequested(
    DraftsLibraryDeleteRequested event,
    Emitter<DraftsLibraryState> emit,
  ) async {
    final currentDrafts = switch (state) {
      DraftsLibraryLoaded(:final drafts) ||
      DraftsLibraryDraftDuplicated(:final drafts) ||
      DraftsLibraryDuplicateFailed(:final drafts) ||
      DraftsLibraryDraftDeleted(:final drafts) ||
      DraftsLibraryDeleteFailed(:final drafts) => drafts,
      _ => null,
    };
    if (currentDrafts == null) return;

    try {
      Log.info(
        '📚 Deleting draft: ${event.draftId}',
        name: 'DraftsLibraryBloc',
        category: LogCategory.video,
      );

      await _draftStorageService.deleteDraft(event.draftId);

      // Update the list by removing the deleted draft
      final updatedDrafts = currentDrafts
          .where((d) => d.id != event.draftId)
          .toList();

      emit(DraftsLibraryDraftDeleted(drafts: updatedDrafts));
      emit(DraftsLibraryLoaded(drafts: updatedDrafts));
    } catch (e, stackTrace) {
      Log.error(
        '📚 Failed to delete draft: $e',
        name: 'DraftsLibraryBloc',
        category: LogCategory.video,
      );
      addError(e, stackTrace);
      emit(DraftsLibraryDeleteFailed(drafts: currentDrafts));
      emit(DraftsLibraryLoaded(drafts: currentDrafts));
    }
  }
}
