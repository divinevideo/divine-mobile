// ABOUTME: BLoC for managing saved video clips in the library
// ABOUTME: Handles loading, selection, deletion, and gallery export

import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/models/clip_category.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:openvine/services/gallery_save_service.dart';
import 'package:openvine/services/video_editor/stop_motion_render_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show RenderCanceledException;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

part 'clips_library_event.dart';
part 'clips_library_state.dart';

/// BLoC for managing saved video clips in the library.
///
/// Loads clips from [ClipLibraryService], manages selection state,
/// handles deletion, and exports to gallery via [GallerySaveService].
class ClipsLibraryBloc extends Bloc<ClipsLibraryEvent, ClipsLibraryState> {
  ClipsLibraryBloc({
    required ClipLibraryService clipLibraryService,
    required GallerySaveService gallerySaveService,
    required SharedPreferences sharedPreferences,
    this.clipTypeFilter = LibraryClipTypeFilter.all,
    bool allowsMixedClipTypes = false,
  }) : _clipLibraryService = clipLibraryService,
       _gallerySaveService = gallerySaveService,
       _sharedPreferences = sharedPreferences,
       super(
         ClipsLibraryState(
           clipSort: _readPersistedSort(sharedPreferences),
           gridColumnCount: _readPersistedGridColumns(sharedPreferences),
           allowsMixedClipTypes: allowsMixedClipTypes,
         ),
       ) {
    on<ClipsLibraryLoadRequested>(_onLoadRequested, transformer: droppable());
    on<ClipsLibraryToggleSelection>(_onToggleSelection);
    on<ClipsLibraryClearSelection>(_onClearSelection);
    on<ClipsLibraryDragSelectionStarted>(_onDragSelectionStarted);
    on<ClipsLibraryDragSelectionExtended>(_onDragSelectionExtended);
    on<ClipsLibraryDragSelectionEnded>(_onDragSelectionEnded);
    on<ClipsLibraryDeleteSelected>(_onDeleteSelected, transformer: droppable());
    on<ClipsLibraryDeleteClip>(_onDeleteClip, transformer: droppable());
    on<ClipsLibrarySaveToGallery>(_onSaveToGallery, transformer: droppable());
    on<ClipsLibrarySortChanged>(_onSortChanged);
    on<ClipsLibraryGridColumnsChanged>(
      _onGridColumnsChanged,
      transformer: sequential(),
    );
    on<ClipsLibraryEnterSelectionMode>(_onEnterSelectionMode);
    on<ClipsLibraryExitSelectionMode>(_onExitSelectionMode);
    on<ClipsLibraryAutoOpenSelectionMode>(_onAutoOpenSelectionMode);
    on<ClipsLibraryTrashLoadRequested>(
      _onTrashLoadRequested,
      transformer: droppable(),
    );
    on<ClipsLibraryRestoreClips>(_onRestoreClips, transformer: droppable());
    on<ClipsLibraryHardDeleteClip>(_onHardDeleteClip, transformer: droppable());
    on<ClipsLibraryEmptyTrash>(_onEmptyTrash, transformer: droppable());
    on<ClipsLibraryFilterChanged>(_onFilterChanged);
    on<ClipsLibraryCategoryCreated>(
      _onCategoryCreated,
      transformer: sequential(),
    );
    on<ClipsLibraryCategoryRenamed>(
      _onCategoryRenamed,
      transformer: sequential(),
    );
    on<ClipsLibraryCategoryDeleted>(
      _onCategoryDeleted,
      transformer: sequential(),
    );
    on<ClipsLibraryClipsMovedToCategory>(
      _onClipsMovedToCategory,
      transformer: sequential(),
    );
    on<ClipsLibraryClipsArchiveChanged>(
      _onClipsArchiveChanged,
      transformer: sequential(),
    );
  }

  /// SharedPreferences key for the persisted [ClipSort] selection.
  static const _sortPrefsKey = 'library_clip_sort';

  final ClipLibraryService _clipLibraryService;
  final GallerySaveService _gallerySaveService;
  final SharedPreferences _sharedPreferences;

  /// Restricts which clip types this library instance loads. Set by the
  /// recorder entry-point to the mode's type; [LibraryClipTypeFilter.all]
  /// (both types) for the standalone library.
  final LibraryClipTypeFilter clipTypeFilter;

  /// Applies [clipTypeFilter] to a freshly loaded clip list.
  List<DivineVideoClip> _applyTypeFilter(List<DivineVideoClip> clips) {
    if (clipTypeFilter == LibraryClipTypeFilter.all) return clips;
    return clips.where(clipTypeFilter.matches).toList();
  }

  Future<List<DivineVideoClip>> _getFilteredTrashedClips() async =>
      _applyTypeFilter(await _clipLibraryService.getTrashedClips());

  static ClipSort _readPersistedSort(SharedPreferences prefs) {
    final saved = prefs.getString(_sortPrefsKey);
    if (saved == null) return ClipSort.newestCreation;
    return ClipSort.fromPersistenceKey(saved);
  }

  static int _readPersistedGridColumns(SharedPreferences prefs) {
    final saved = prefs.getInt(ClipGridColumns.prefsKey);
    if (saved == null) return ClipGridColumns.initial;
    return ClipGridColumns.clamp(saved);
  }

  /// Returns [clips] sorted according to [sort]. Pure — does not
  /// mutate the input list.
  static List<DivineVideoClip> _applySort(
    List<DivineVideoClip> clips,
    ClipSort sort,
  ) {
    final sorted = List<DivineVideoClip>.from(clips);
    switch (sort) {
      case ClipSort.newestCreation:
        sorted.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
      case ClipSort.oldestCreation:
        sorted.sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
      case ClipSort.longestClip:
        sorted.sort((a, b) => b.duration.compareTo(a.duration));
      case ClipSort.shortestClip:
        sorted.sort((a, b) => a.duration.compareTo(b.duration));
      case ClipSort.squareFirst:
        sorted.sort((a, b) {
          final aRank = a.targetAspectRatio == .square ? 0 : 1;
          final bRank = b.targetAspectRatio == .square ? 0 : 1;
          if (aRank != bRank) return aRank.compareTo(bRank);
          return b.recordedAt.compareTo(a.recordedAt);
        });
      case ClipSort.verticalFirst:
        sorted.sort((a, b) {
          final aRank = a.targetAspectRatio == .vertical ? 0 : 1;
          final bRank = b.targetAspectRatio == .vertical ? 0 : 1;
          if (aRank != bRank) return aRank.compareTo(bRank);
          return b.recordedAt.compareTo(a.recordedAt);
        });
    }
    return sorted;
  }

  /// Returns the clips [filter] admits, sorted by [sort].
  static List<DivineVideoClip> _visibleClips(
    List<DivineVideoClip> clips,
    ClipLibraryFilter filter,
    ClipSort sort,
  ) => _applySort(clips.where(filter.admits).toList(), sort);

  /// Total duration of the clips in [ids], ignoring ids [clips] has no clip
  /// for.
  static Duration _totalDuration(List<DivineVideoClip> clips, Set<String> ids) {
    var total = Duration.zero;
    for (final clip in clips) {
      if (ids.contains(clip.id)) total += clip.duration;
    }
    return total;
  }

  Future<void> _onLoadRequested(
    ClipsLibraryLoadRequested event,
    Emitter<ClipsLibraryState> emit,
  ) async {
    emit(state.copyWith(status: ClipsLibraryStatus.loading));

    try {
      final clips = _applyTypeFilter(await _clipLibraryService.getAllClips());
      final categories = await _clipLibraryService.getCategories();

      Log.debug(
        '📚 Loaded ${clips.length} clips from library',
        name: 'ClipsLibraryBloc',
        category: LogCategory.video,
      );

      // Pre-select clips that are already in the editor.
      // Iterate preSelectedIds (which preserves ClipManager order)
      // so the selection indices match the editor timeline.
      final clipsById = {for (final c in clips) c.id: c};
      final preSelectedIds = <String>{};
      var preSelectedDuration = Duration.zero;
      for (final id in event.preSelectedIds) {
        final clip = clipsById[id];
        if (clip != null) {
          preSelectedIds.add(id);
          preSelectedDuration += clip.duration;
        }
      }

      final filter = _resolveFilter(state.filter, categories);
      emit(
        state.copyWith(
          status: ClipsLibraryStatus.loaded,
          clips: clips,
          categories: categories,
          filter: filter,
          sortedClips: _visibleClips(clips, filter, state.clipSort),
          selectedClipIds: preSelectedIds,
          preSelectedIds: event.preSelectedIds,
          disabledClipIds: event.disabledClipIds,
          selectedDuration: preSelectedDuration,
        ),
      );

      // Kick off background recovery for clips missing thumbnails/ghost
      // frames. When done, a fresh load event is dispatched so the UI
      // picks up the updated assets.
      final hasIncomplete = clips.any(
        (c) => c.thumbnailPath == null || c.ghostFramePath == null,
      );
      if (hasIncomplete) {
        unawaited(_recoverAndReload(clips));
      }
    } catch (e, stackTrace) {
      Log.error(
        '📚 Failed to load clips: $e',
        name: 'ClipsLibraryBloc',
        category: LogCategory.video,
      );
      // Matrix-NO: ClipLibraryService.getAllClips is local Drift IO.
      addError(e, stackTrace);
      emit(state.copyWith(status: ClipsLibraryStatus.error));
    }
  }

  void _onToggleSelection(
    ClipsLibraryToggleSelection event,
    Emitter<ClipsLibraryState> emit,
  ) {
    final clip = event.clip;

    // Disabled clips (already in the editor) cannot be toggled.
    if (state.disabledClipIds.contains(clip.id)) return;

    final selectedIds = Set<String>.from(state.selectedClipIds);
    var selectedDuration = state.selectedDuration;

    if (selectedIds.contains(clip.id)) {
      selectedIds.remove(clip.id);
      selectedDuration -= clip.duration;
    } else {
      // No mixing: a clip of a different type than the current selection
      // (stop-motion vs normal video) cannot be added unless the state allows
      // it (see ClipsLibraryState.allowsMixedClipTypes). The grid also
      // disables such clips; this guards the event path.
      final selectedType = state.selectedIsStopMotion;
      if (selectedType != null && clip.isStopMotion != selectedType) return;
      selectedIds.add(clip.id);
      selectedDuration += clip.duration;
    }

    emit(
      state.copyWith(
        selectedClipIds: selectedIds,
        selectedDuration: selectedDuration,
      ),
    );
  }

  void _onDragSelectionStarted(
    ClipsLibraryDragSelectionStarted event,
    Emitter<ClipsLibraryState> emit,
  ) {
    final clip = event.clip;
    // Disabled clips (already in the editor) cannot be toggled, so they are
    // no anchor either.
    if (state.disabledClipIds.contains(clip.id)) return;

    final next = _withDragRange(
      ClipsLibraryDragSelection(
        anchorClipId: clip.id,
        // A press that lands while the selection is out of sight cannot be
        // toggling it — it is the one that brings the selection up.
        selecting:
            !event.selectionEnabled || !state.selectedClipIds.contains(clip.id),
        baseSelectedClipIds: state.selectedClipIds,
        targetAspectRatio: event.targetAspectRatio,
      ),
      focusClipId: clip.id,
    );

    emit(
      event.selectionEnabled
          ? next
          : next.copyWith(
              isLibrarySelectionMode: true,
              didAutoOpenSelectionMode: false,
            ),
    );
  }

  void _onDragSelectionExtended(
    ClipsLibraryDragSelectionExtended event,
    Emitter<ClipsLibraryState> emit,
  ) {
    final drag = state.dragSelection;
    if (drag == null) return;
    emit(_withDragRange(drag, focusClipId: event.clip.id));
  }

  void _onDragSelectionEnded(
    ClipsLibraryDragSelectionEnded event,
    Emitter<ClipsLibraryState> emit,
  ) {
    if (state.dragSelection == null) return;
    emit(state.copyWith(clearDragSelection: true));
  }

  /// The state a drag reaching [focusClipId] leaves behind.
  ///
  /// Runs the range from the anchor to the clip under the finger over the
  /// selection the drag started from, so clips the finger has moved back past
  /// return to whatever they were before it.
  ClipsLibraryState _withDragRange(
    ClipsLibraryDragSelection drag, {
    required String focusClipId,
  }) {
    final clips = state.sortedClips;
    final anchorIndex = clips.indexWhere((c) => c.id == drag.anchorClipId);
    final focusIndex = clips.indexWhere((c) => c.id == focusClipId);
    if (anchorIndex < 0 || focusIndex < 0) return state;

    final selectedIds = Set<String>.from(drag.baseSelectedClipIds);
    // Both constraints tighten as the range grows: with nothing selected yet,
    // the first clip the drag picks up is what the rest has to match. The
    // type constraint is off entirely where mixing is allowed.
    final mixTypes = state.allowsMixedClipTypes;
    var isStopMotion = mixTypes
        ? null
        : state.stopMotionTypeOf(drag.baseSelectedClipIds);
    var aspectRatio = drag.targetAspectRatio;
    final step = focusIndex >= anchorIndex ? 1 : -1;

    for (var i = anchorIndex; ; i += step) {
      final clip = clips[i];
      if (!state.disabledClipIds.contains(clip.id)) {
        if (!drag.selecting) {
          selectedIds.remove(clip.id);
        } else if ((isStopMotion == null ||
                clip.isStopMotion == isStopMotion) &&
            (aspectRatio == null ||
                aspectRatio == clip.targetAspectRatio.value)) {
          selectedIds.add(clip.id);
          if (!mixTypes) isStopMotion ??= clip.isStopMotion;
          aspectRatio ??= clip.targetAspectRatio.value;
        }
      }
      if (i == focusIndex) break;
    }

    return state.copyWith(
      selectedClipIds: selectedIds,
      selectedDuration: state.durationOf(selectedIds),
      dragSelection: drag,
    );
  }

  void _onClearSelection(
    ClipsLibraryClearSelection event,
    Emitter<ClipsLibraryState> emit,
  ) {
    emit(
      state.copyWith(
        selectedClipIds: const {},
        selectedDuration: Duration.zero,
      ),
    );
  }

  Future<void> _onDeleteSelected(
    ClipsLibraryDeleteSelected event,
    Emitter<ClipsLibraryState> emit,
  ) async {
    // Only what the active filter shows: the rest of the selection was made
    // under another filter and is off screen, so a single tap here must not
    // reach it. See [ClipsLibraryState.visibleSelectedClipIds].
    final deletedIds = state.visibleSelectedClipIds;
    if (deletedIds.isEmpty) return;
    // The two delete events sit in separate `droppable()` buckets, so the
    // transformer alone does not stop one delete overlapping the other.
    if (state.isDeleting) return;

    emit(
      state.copyWith(
        status: ClipsLibraryStatus.deleting,
        clearDeletedCount: true,
      ),
    );

    final deletedCount = deletedIds.length;
    final remainingIds = state.selectedClipIds.difference(deletedIds);

    try {
      Log.info(
        '📚 Soft-deleting $deletedCount clips',
        name: 'ClipsLibraryBloc',
        category: LogCategory.video,
      );

      for (final clipId in deletedIds) {
        await _clipLibraryService.softDelete(clipId);
      }

      // Reload clips; the deleted ones drop out of the selection, anything
      // selected under another filter stays in it.
      final clips = _applyTypeFilter(await _clipLibraryService.getAllClips());

      emit(
        state.copyWith(
          status: ClipsLibraryStatus.loaded,
          clips: clips,
          sortedClips: _visibleClips(clips, state.filter, state.clipSort),
          selectedClipIds: remainingIds,
          selectedDuration: _totalDuration(clips, remainingIds),
          lastDeletedCount: deletedCount,
          lastDeletedClipIds: deletedIds,
        ),
      );
    } catch (e, stackTrace) {
      Log.error(
        '📚 Failed to delete clips: $e',
        name: 'ClipsLibraryBloc',
        category: LogCategory.video,
      );
      // Matrix-NO: deleteClip loop + getAllClips reload are local Drift IO.
      addError(e, stackTrace);
      emit(state.copyWith(status: ClipsLibraryStatus.error));
    }
  }

  Future<void> _onDeleteClip(
    ClipsLibraryDeleteClip event,
    Emitter<ClipsLibraryState> emit,
  ) async {
    // See _onDeleteSelected: separate `droppable()` buckets do not exclude
    // each other, so the in-flight delete has to be checked explicitly.
    if (state.isDeleting) return;

    emit(
      state.copyWith(
        status: ClipsLibraryStatus.deleting,
        clearDeletedCount: true,
      ),
    );

    try {
      Log.info(
        '📚 Deleting clip: ${event.clip.id}',
        name: 'ClipsLibraryBloc',
        category: LogCategory.video,
      );

      await _clipLibraryService.softDelete(event.clip.id);

      // Reload clips
      final clips = _applyTypeFilter(await _clipLibraryService.getAllClips());

      // Remove from selection if selected
      final selectedIds = Set<String>.from(state.selectedClipIds);
      var selectedDuration = state.selectedDuration;
      if (selectedIds.contains(event.clip.id)) {
        selectedIds.remove(event.clip.id);
        selectedDuration -= event.clip.duration;
      }

      emit(
        state.copyWith(
          status: ClipsLibraryStatus.loaded,
          clips: clips,
          sortedClips: _visibleClips(clips, state.filter, state.clipSort),
          selectedClipIds: selectedIds,
          selectedDuration: selectedDuration,
          lastDeletedCount: 1,
          lastDeletedClipIds: {event.clip.id},
        ),
      );
    } catch (e, stackTrace) {
      Log.error(
        '📚 Failed to delete clip: $e',
        name: 'ClipsLibraryBloc',
        category: LogCategory.video,
      );
      // Matrix-NO: deleteClip + getAllClips reload are local Drift IO.
      addError(e, stackTrace);
      emit(state.copyWith(status: ClipsLibraryStatus.error));
    }
  }

  Future<void> _onSaveToGallery(
    ClipsLibrarySaveToGallery event,
    Emitter<ClipsLibraryState> emit,
  ) async {
    if (state.selectedClipIds.isEmpty) return;

    emit(
      state.copyWith(
        status: ClipsLibraryStatus.savingToGallery,
        clearGallerySaveResult: true,
      ),
    );

    final clipsToSave = state.selectedClips;
    final clipCount = clipsToSave.length;

    Log.info(
      '📚 Saving $clipCount clips to gallery',
      name: 'ClipsLibraryBloc',
      category: LogCategory.video,
    );

    var successCount = 0;
    var failureCount = 0;

    for (final clip in clipsToSave) {
      DivineVideoClip? materialized;
      try {
        // Stop-motion clips render their mp4 on demand before saving.
        try {
          materialized = await StopMotionRenderService.materialize(clip);
        } on RenderCanceledException {
          materialized = null;
        }
        if (materialized == null) {
          failureCount++;
          continue;
        }
        final result = await _gallerySaveService.saveVideoToGallery(
          materialized.requireVideo,
        );

        switch (result) {
          case GallerySaveSuccess():
            successCount++;
          case GallerySavePermissionDenied():
            // Stop immediately on permission denied
            emit(
              state.copyWith(
                status: ClipsLibraryStatus.loaded,
                lastGallerySaveResult:
                    const GallerySaveResultPermissionDenied(),
              ),
            );
            return;
          case GallerySaveFailure():
            failureCount++;
        }
      } catch (e, s) {
        // Matrix-NO: GallerySaveService is documented as never throwing
        // (returns result objects). This catch is defensive against the
        // contract drifting; when-in-doubt classification applies.
        addError(e, s);
        emit(
          state.copyWith(
            status: ClipsLibraryStatus.loaded,
            lastGallerySaveResult: const GallerySaveResultError(),
          ),
        );
        return;
      } finally {
        await StopMotionRenderService.cleanupMaterializedOutput(
          sourceClip: clip,
          materializedClip: materialized,
        );
      }
    }

    // Clear selection after saving
    emit(
      state.copyWith(
        status: ClipsLibraryStatus.loaded,
        selectedClipIds: const {},
        selectedDuration: Duration.zero,
        lastGallerySaveResult: GallerySaveResultSuccess(
          successCount: successCount,
          failureCount: failureCount,
        ),
      ),
    );
  }

  /// Runs asset recovery in the background and dispatches a fresh load
  /// event when done so the UI picks up the updated thumbnails/ghost frames.
  Future<void> _recoverAndReload(List<DivineVideoClip> clips) async {
    try {
      final recovered = await _clipLibraryService.recoverMissingAssets(clips);
      if (!identical(recovered, clips) && !isClosed) {
        add(
          ClipsLibraryLoadRequested(
            preSelectedIds: state.preSelectedIds,
            disabledClipIds: state.disabledClipIds,
          ),
        );
      }
    } catch (e, stackTrace) {
      Log.error(
        '📚 Background asset recovery failed: $e',
        name: 'ClipsLibraryBloc',
        category: LogCategory.video,
      );
      // Matrix-NO: background recoverMissingAssets is filesystem + thumbnail
      // IO (Network/IO category).
      // Guarded for symmetry with the sibling add() above: this method
      // runs fire-and-forget via unawaited() and post-close addError
      // throws StateError.
      if (!isClosed) {
        addError(e, stackTrace);
      }
    }
  }

  Future<void> _onSortChanged(
    ClipsLibrarySortChanged event,
    Emitter<ClipsLibraryState> emit,
  ) async {
    if (event.sort == state.clipSort) return;
    try {
      await _sharedPreferences.setString(
        _sortPrefsKey,
        event.sort.persistenceKey,
      );
    } catch (e, stackTrace) {
      Log.warning(
        '📚 Failed to persist clip sort: $e',
        name: 'ClipsLibraryBloc',
        category: LogCategory.video,
      );
      // Matrix-NO: SharedPreferences.setString is local platform-channel IO.
      addError(e, stackTrace);
    }
    emit(
      state.copyWith(
        clipSort: event.sort,
        sortedClips: _visibleClips(state.clips, state.filter, event.sort),
      ),
    );
  }

  Future<void> _onGridColumnsChanged(
    ClipsLibraryGridColumnsChanged event,
    Emitter<ClipsLibraryState> emit,
  ) async {
    final columns = ClipGridColumns.clamp(event.columnCount);
    if (columns == state.gridColumnCount) return;
    try {
      await _sharedPreferences.setInt(ClipGridColumns.prefsKey, columns);
    } catch (e, stackTrace) {
      Log.warning(
        '📚 Failed to persist clip grid columns: $e',
        name: 'ClipsLibraryBloc',
        category: LogCategory.video,
      );
      // Matrix-NO: SharedPreferences.setInt is local platform-channel IO.
      addError(e, stackTrace);
    }
    emit(state.copyWith(gridColumnCount: columns));
  }

  void _onEnterSelectionMode(
    ClipsLibraryEnterSelectionMode event,
    Emitter<ClipsLibraryState> emit,
  ) {
    emit(
      state.copyWith(
        isLibrarySelectionMode: true,
        didAutoOpenSelectionMode: false,
      ),
    );
  }

  void _onExitSelectionMode(
    ClipsLibraryExitSelectionMode event,
    Emitter<ClipsLibraryState> emit,
  ) {
    emit(
      state.copyWith(
        isLibrarySelectionMode: false,
        didAutoOpenSelectionMode: false,
        selectedClipIds: const {},
        selectedDuration: Duration.zero,
      ),
    );
  }

  void _onAutoOpenSelectionMode(
    ClipsLibraryAutoOpenSelectionMode event,
    Emitter<ClipsLibraryState> emit,
  ) {
    if (state.isLibrarySelectionMode) return;
    emit(
      state.copyWith(
        isLibrarySelectionMode: true,
        didAutoOpenSelectionMode: true,
      ),
    );
  }

  Future<void> _onTrashLoadRequested(
    ClipsLibraryTrashLoadRequested event,
    Emitter<ClipsLibraryState> emit,
  ) async {
    emit(state.copyWith(status: ClipsLibraryStatus.trashLoading));
    try {
      final trashed = await _getFilteredTrashedClips();
      emit(
        state.copyWith(
          status: ClipsLibraryStatus.trashLoaded,
          trashedClips: trashed,
        ),
      );
    } catch (e, stackTrace) {
      Log.error(
        '📚 Failed to load trashed clips: $e',
        name: 'ClipsLibraryBloc',
        category: LogCategory.video,
      );
      addError(e, stackTrace);
      emit(state.copyWith(status: ClipsLibraryStatus.error));
    }
  }

  Future<void> _onRestoreClips(
    ClipsLibraryRestoreClips event,
    Emitter<ClipsLibraryState> emit,
  ) async {
    if (event.clipIds.isEmpty) return;
    try {
      for (final id in event.clipIds) {
        await _clipLibraryService.restore(id);
      }
      Log.info(
        '♻️ Restored ${event.clipIds.length} clip(s) from trash',
        name: 'ClipsLibraryBloc',
        category: LogCategory.video,
      );
      await _reloadClipsAndTrash(emit);
    } catch (e, stackTrace) {
      Log.error(
        '📚 Failed to restore clips: $e',
        name: 'ClipsLibraryBloc',
        category: LogCategory.video,
      );
      addError(e, stackTrace);
      emit(state.copyWith(status: ClipsLibraryStatus.error));
    }
  }

  Future<void> _onHardDeleteClip(
    ClipsLibraryHardDeleteClip event,
    Emitter<ClipsLibraryState> emit,
  ) async {
    try {
      await _clipLibraryService.hardDelete(event.clip.id);
      final trashed = await _getFilteredTrashedClips();
      emit(
        state.copyWith(
          status: ClipsLibraryStatus.trashLoaded,
          trashedClips: trashed,
        ),
      );
    } catch (e, stackTrace) {
      Log.error(
        '📚 Failed to hard-delete clip: $e',
        name: 'ClipsLibraryBloc',
        category: LogCategory.video,
      );
      addError(e, stackTrace);
      emit(state.copyWith(status: ClipsLibraryStatus.error));
    }
  }

  Future<void> _onEmptyTrash(
    ClipsLibraryEmptyTrash event,
    Emitter<ClipsLibraryState> emit,
  ) async {
    try {
      final trashed = await _getFilteredTrashedClips();
      for (final clip in trashed) {
        await _clipLibraryService.hardDelete(clip.id);
      }
      Log.info(
        '🧹 Emptied trash (${trashed.length} clip(s))',
        name: 'ClipsLibraryBloc',
        category: LogCategory.video,
      );
      emit(
        state.copyWith(
          status: ClipsLibraryStatus.trashLoaded,
          trashedClips: const [],
        ),
      );
    } catch (e, stackTrace) {
      Log.error(
        '📚 Failed to empty trash: $e',
        name: 'ClipsLibraryBloc',
        category: LogCategory.video,
      );
      addError(e, stackTrace);
      emit(state.copyWith(status: ClipsLibraryStatus.error));
    }
  }

  /// Keeps [current] only while it still points at something selectable,
  /// falling back to All when its category has been deleted (on another
  /// device, by a sibling bloc, or by the category-delete handler).
  static ClipLibraryFilter _resolveFilter(
    ClipLibraryFilter current,
    List<ClipCategory> categories,
  ) {
    if (current is! ClipLibraryCategoryFilter) return current;
    final stillExists = categories.any((c) => c.id == current.categoryId);
    return stillExists ? current : const ClipLibraryAllFilter();
  }

  void _onFilterChanged(
    ClipsLibraryFilterChanged event,
    Emitter<ClipsLibraryState> emit,
  ) {
    if (event.filter == state.filter) return;

    // Trashed and active clips are different domains: a selection made in one
    // must not survive into the other, or a bulk action would hit clips the
    // user can no longer see. Switching between the active filters keeps the
    // selection, so picking clips across categories still works.
    final crossesTrashBoundary =
        (event.filter is ClipLibraryTrashFilter) != state.isShowingTrash;

    emit(
      state.copyWith(
        filter: event.filter,
        sortedClips: _visibleClips(state.clips, event.filter, state.clipSort),
        selectedClipIds: crossesTrashBoundary ? const {} : null,
        selectedDuration: crossesTrashBoundary ? Duration.zero : null,
        clearOrganizeResult: true,
        // A drag resolves its range against `sortedClips`. The list the
        // finger started on is gone, so end the drag rather than run the
        // anchor's range over positions the user never dragged across.
        clearDragSelection: true,
      ),
    );

    if (event.filter is ClipLibraryTrashFilter) {
      add(const ClipsLibraryTrashLoadRequested());
    }
  }

  Future<void> _onCategoryCreated(
    ClipsLibraryCategoryCreated event,
    Emitter<ClipsLibraryState> emit,
  ) async {
    try {
      final created = await _clipLibraryService.createCategory(event.name);
      // A blank or whitespace-only name is rejected by the service; there is
      // nothing to report and nothing to reload.
      if (created == null) return;

      for (final clipId in event.clipIds) {
        await _clipLibraryService.setClipCategory(
          clipId: clipId,
          categoryId: created.id,
        );
      }

      await _reloadAfterOrganize(
        emit,
        organizedIds: event.clipIds,
        result: event.clipIds.isEmpty
            ? null
            : ClipsLibraryOrganizeResult(
                action: ClipsLibraryOrganizeAction.movedToCategory,
                clipIds: event.clipIds,
                categoryName: created.name,
              ),
      );
    } catch (e, stackTrace) {
      _handleOrganizeFailure('create category', e, stackTrace, emit);
    }
  }

  Future<void> _onCategoryRenamed(
    ClipsLibraryCategoryRenamed event,
    Emitter<ClipsLibraryState> emit,
  ) async {
    try {
      final renamed = await _clipLibraryService.renameCategory(
        id: event.categoryId,
        rawName: event.name,
      );
      if (!renamed) return;
      emit(
        state.copyWith(categories: await _clipLibraryService.getCategories()),
      );
    } catch (e, stackTrace) {
      _handleOrganizeFailure('rename category', e, stackTrace, emit);
    }
  }

  Future<void> _onCategoryDeleted(
    ClipsLibraryCategoryDeleted event,
    Emitter<ClipsLibraryState> emit,
  ) async {
    try {
      final deleted = await _clipLibraryService.deleteCategory(
        event.categoryId,
      );
      if (!deleted) return;
      // Deleting a category leaves its clips alone — they only lose their
      // filing — so nothing drops out of the selection here.
      await _reloadAfterOrganize(emit, organizedIds: const {});
    } catch (e, stackTrace) {
      _handleOrganizeFailure('delete category', e, stackTrace, emit);
    }
  }

  Future<void> _onClipsMovedToCategory(
    ClipsLibraryClipsMovedToCategory event,
    Emitter<ClipsLibraryState> emit,
  ) async {
    if (event.clipIds.isEmpty) return;

    try {
      for (final clipId in event.clipIds) {
        await _clipLibraryService.setClipCategory(
          clipId: clipId,
          categoryId: event.categoryId,
        );
      }

      final targetId = event.categoryId;
      final target = targetId == null
          ? null
          : state.categories.firstWhereOrNull((c) => c.id == targetId);

      await _reloadAfterOrganize(
        emit,
        organizedIds: event.clipIds,
        result: ClipsLibraryOrganizeResult(
          action: targetId == null
              ? ClipsLibraryOrganizeAction.removedFromCategory
              : ClipsLibraryOrganizeAction.movedToCategory,
          clipIds: event.clipIds,
          categoryName: target?.name,
        ),
      );
    } catch (e, stackTrace) {
      _handleOrganizeFailure('move clips to category', e, stackTrace, emit);
    }
  }

  Future<void> _onClipsArchiveChanged(
    ClipsLibraryClipsArchiveChanged event,
    Emitter<ClipsLibraryState> emit,
  ) async {
    if (event.clipIds.isEmpty) return;

    final clearCategory = event.archived && event.clearCategory;
    // Read before the writes land, so the undo can put the clips back where
    // they were rather than returning them category-less.
    final previousCategoryIds = clearCategory
        ? {
            for (final clip in state.clips)
              if (event.clipIds.contains(clip.id) && clip.categoryId != null)
                clip.id: clip.categoryId!,
          }
        : const <String, String>{};

    try {
      for (final clipId in event.clipIds) {
        if (clearCategory) {
          await _clipLibraryService.setClipCategory(
            clipId: clipId,
            categoryId: null,
          );
        } else if (!event.archived) {
          final restored = event.restoreCategoryIds[clipId];
          // Restore the category independently; the archive write below
          // restores the other half of the state.
          if (restored != null) {
            await _clipLibraryService.setClipCategory(
              clipId: clipId,
              categoryId: restored,
            );
          }
        }
        await _clipLibraryService.setClipArchived(
          clipId: clipId,
          archived: event.archived,
        );
      }

      await _reloadAfterOrganize(
        emit,
        organizedIds: event.clipIds,
        result: ClipsLibraryOrganizeResult(
          action: event.archived
              ? ClipsLibraryOrganizeAction.archived
              : ClipsLibraryOrganizeAction.unarchived,
          clipIds: event.clipIds,
          previousCategoryIds: previousCategoryIds,
        ),
      );
    } catch (e, stackTrace) {
      _handleOrganizeFailure('archive clips', e, stackTrace, emit);
    }
  }

  /// Reloads clips and categories after an organization change.
  ///
  /// [organizedIds] leave the selection, since those clips have usually just
  /// left the view. Clips selected under another filter stay selected, the
  /// same way switching filters keeps them. Required rather than defaulted:
  /// an empty set keeps the whole selection, which is a decision each caller
  /// should have to state rather than inherit.
  Future<void> _reloadAfterOrganize(
    Emitter<ClipsLibraryState> emit, {
    required Set<String> organizedIds,
    ClipsLibraryOrganizeResult? result,
  }) async {
    final clips = _applyTypeFilter(await _clipLibraryService.getAllClips());
    final categories = await _clipLibraryService.getCategories();
    final filter = _resolveFilter(state.filter, categories);
    final selectedIds = state.selectedClipIds.difference(organizedIds);

    emit(
      state.copyWith(
        status: ClipsLibraryStatus.loaded,
        clips: clips,
        categories: categories,
        filter: filter,
        sortedClips: _visibleClips(clips, filter, state.clipSort),
        selectedClipIds: selectedIds,
        selectedDuration: _totalDuration(clips, selectedIds),
        lastOrganizeResult: result,
        clearOrganizeResult: result == null,
      ),
    );
  }

  void _handleOrganizeFailure(
    String action,
    Object error,
    StackTrace stackTrace,
    Emitter<ClipsLibraryState> emit,
  ) {
    Log.error(
      '📚 Failed to $action: $error',
      name: 'ClipsLibraryBloc',
      category: LogCategory.video,
    );
    // Matrix-NO: the category and archive writes are local Drift IO.
    addError(error, stackTrace);
    emit(state.copyWith(status: ClipsLibraryStatus.error));
  }

  /// Reloads both the active and trashed clip lists. Used after restore
  /// so both views reflect the change.
  Future<void> _reloadClipsAndTrash(Emitter<ClipsLibraryState> emit) async {
    final clips = _applyTypeFilter(await _clipLibraryService.getAllClips());
    final trashed = await _getFilteredTrashedClips();
    emit(
      state.copyWith(
        status:
            state.status == ClipsLibraryStatus.trashLoading ||
                state.status == ClipsLibraryStatus.trashLoaded
            ? ClipsLibraryStatus.trashLoaded
            : ClipsLibraryStatus.loaded,
        clips: clips,
        sortedClips: _visibleClips(clips, state.filter, state.clipSort),
        trashedClips: trashed,
        clearDeletedClipIds: true,
      ),
    );
  }
}
