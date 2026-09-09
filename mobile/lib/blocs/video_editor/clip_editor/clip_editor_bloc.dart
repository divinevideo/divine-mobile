import 'dart:io';
import 'dart:typed_data';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion/stop_motion_frame_ops.dart';
import 'package:openvine/models/video_editor/clip_chroma_key.dart';
import 'package:openvine/models/video_editor/composition_duration.dart';
import 'package:openvine/models/video_editor/editor_overlay_snapshot.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/services/audio_extraction_service.dart';
import 'package:openvine/services/video_editor/chroma_key_bake_service.dart';
import 'package:openvine/services/video_editor/clip_placeholder_render_service.dart';
import 'package:openvine/services/video_editor/stop_motion_frame_transform_service.dart';
import 'package:openvine/services/video_editor/video_editor_clip_library_save_service.dart';
import 'package:openvine/services/video_editor/video_editor_merge_service.dart';
import 'package:openvine/services/video_editor/video_editor_reverse_service.dart';
import 'package:openvine/services/video_editor/video_editor_split_service.dart';
import 'package:openvine/services/video_editor/video_editor_transform_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show EditorVideo, ExportTransform;
import 'package:unified_logger/unified_logger.dart';

part 'clip_editor_event.dart';
part 'clip_editor_state.dart';

/// Function signature matching [VideoEditorSplitService.splitClip], used as
/// an injectable seam so tests can swap in a pure-Dart fake that does not
/// touch `path_provider` or `pro_video_editor` plugins.
typedef SplitClipFn = Future<void> Function({
  required DivineVideoClip sourceClip,
  required Duration splitPosition,
  required void Function(
    DivineVideoClip startClip,
    DivineVideoClip endClip,
  )?
  onClipsCreated,
  required void Function(DivineVideoClip clip, String thumbnailPath)?
  onThumbnailExtracted,
});

/// Function signature matching [VideoEditorReverseService.reverseClip], used as
/// an injectable seam so tests can swap in a pure-Dart fake.
typedef ReverseClipFn = Future<EditorVideo> Function({
  required DivineVideoClip sourceClip,
  required String renderId,
});

/// Function signature matching
/// [StopMotionFrameTransformService.writeTransformedFrame], injectable so tests
/// can persist a still without touching the file system.
typedef WriteStopMotionFrameFn = Future<String> Function(Uint8List bytes);

/// Function signature matching [VideoEditorTransformService.transformClip],
/// used as an injectable seam so tests can swap in a pure-Dart fake.
typedef TransformClipFn = Future<EditorVideo> Function({
  required DivineVideoClip sourceClip,
  required ExportTransform transform,
  required String renderId,
});

/// Function signature matching [VideoEditorTransformService.aspectRatioOf],
/// used as an injectable seam so tests can state a rendered clip's shape
/// without a decoder.
typedef MeasureAspectRatioFn = Future<double?> Function(EditorVideo video);

/// Function signature matching [VideoEditorMergeService.mergeClips], used as an
/// injectable seam so tests can swap in a pure-Dart fake that does not touch
/// the render pipeline.
typedef MergeClipsFn = Future<DivineVideoClip?> Function({
  required List<DivineVideoClip> clips,
  required String renderId,
});

/// Function signature matching
/// [VideoEditorClipLibrarySaveService.flattenClipForLibrary], used as an
/// injectable seam so tests can swap in a pure-Dart fake that does not touch
/// `path_provider` or `pro_video_editor` plugins.
typedef FlattenClipForLibraryFn = Future<DivineVideoClip?> Function({
  required DivineVideoClip clip,
  required String renderId,
  EditorOverlaySnapshot? overlays,
});

/// Function signature matching
/// [VideoEditorClipLibrarySaveService.cleanupFlattenedClip], the injectable
/// seam that deletes a flattened clip's documents-dir files when the save
/// doesn't reach the library, so tests can assert cleanup without touching the
/// file system.
typedef CleanupFlattenedClipFn = Future<void> Function(
  DivineVideoClip flattened, {
  String? keepThumbnailPath,
});

/// Queues files that became unreachable when a clip's file references were
/// rewritten — a transform's pre-transform render, a bake's previous output,
/// the chroma-key metadata a bake or a transform cleared.
///
/// Queued, not deleted: the editor's undo history still points at them for the
/// rest of the session. Wired by the widget layer to
/// `VideoEditorNotifier.deferFileCleanup`, which reference-checks each path and
/// reaps it at session end.
typedef DeferFileCleanupFn = void Function(Iterable<String?> paths);

void _noopDeferFileCleanup(Iterable<String?> paths) {}

/// Function signature matching [ClipPlaceholderRenderService.render], the
/// injectable seam that turns a colour or photo into the still filling a
/// detached clip's slot, so tests can exercise detach without a renderer.
typedef RenderClipPlaceholderFn =
    Future<DivineVideoClip?> Function({
      required ClipPlaceholderFill fill,
      required DivineVideoClip source,
      String? taskId,
    });

/// Persists an already-flattened clip to the device's clip library, returning
/// whether it was stored.
///
/// Wired by the widget layer to `ClipManagerNotifier.saveClipToLibrary`. The
/// library lives behind a Riverpod provider this BLoC cannot reach, so the
/// dependency arrives as a callback — the same transition seam that already
/// brings the clip list in (see [ClipEditorBloc]).
typedef SaveClipToLibraryFn = Future<bool> Function({
  required DivineVideoClip clip,
});

/// BLoC for managing video clip editor state.
///
/// Owns a local copy of the clip list so that all mutations (add, remove,
/// trim, split) happen in-memory without touching the Riverpod
/// [ClipManagerProvider]. The parent screen syncs the final clip list
/// back to the provider when the editor closes.
///
/// **Transition seam**: This BLoC receives its initial clip list from the
/// Riverpod [ClipManagerProvider] via [ClipEditorInitialized] dispatched in
/// the widget layer. This is an intentional migration boundary — the target
/// architecture replaces the Riverpod provider with a [VideoEditorRepository]
/// injected directly into this BLoC.
class ClipEditorBloc extends Bloc<ClipEditorEvent, ClipEditorState> {
  ClipEditorBloc({
    required this.onFinalClipInvalidated,
    required SaveClipToLibraryFn saveClipToLibrary,
    AudioExtractionService? audioExtractionService,
    SplitClipFn? splitClip,
    ReverseClipFn? reverseClip,
    TransformClipFn? transformClip,
    MeasureAspectRatioFn? measureAspectRatio,
    WriteStopMotionFrameFn? writeStopMotionFrame,
    ChromaKeyBakeFn? bakeChromaKey,
    MergeClipsFn? mergeClips,
    FlattenClipForLibraryFn? flattenClipForLibrary,
    CleanupFlattenedClipFn? cleanupFlattenedClip,
    DeferFileCleanupFn? deferFileCleanup,
    RenderClipPlaceholderFn? renderClipPlaceholder,
  }) : _audioExtractionService =
           audioExtractionService ?? AudioExtractionService(),
       _splitClip = splitClip ?? VideoEditorSplitService.splitClip,
       _reverseClip = reverseClip ?? VideoEditorReverseService.reverseClip,
       _transformClip =
           transformClip ?? VideoEditorTransformService.transformClip,
       _measureAspectRatio =
           measureAspectRatio ?? VideoEditorTransformService.aspectRatioOf,
       _writeStopMotionFrame =
           writeStopMotionFrame ??
           StopMotionFrameTransformService.writeTransformedFrame,
       _bakeChromaKey = bakeChromaKey ?? ChromaKeyBakeService.bakeClip,
       _mergeClips = mergeClips ?? VideoEditorMergeService.mergeClips,
       _flattenClipForLibrary =
           flattenClipForLibrary ??
           VideoEditorClipLibrarySaveService.flattenClipForLibrary,
       _cleanupFlattenedClip =
           cleanupFlattenedClip ??
           VideoEditorClipLibrarySaveService.cleanupFlattenedClip,
       _deferFileCleanup = deferFileCleanup ?? _noopDeferFileCleanup,
       _renderClipPlaceholder =
           renderClipPlaceholder ?? ClipPlaceholderRenderService.render,
       _saveClipToLibrary = saveClipToLibrary,
       super(const ClipEditorState()) {
    // Clip data
    on<ClipEditorInitialized>(_onInitialized);
    on<ClipEditorClipRemoved>(_onClipRemoved);
    on<ClipEditorClipInserted>(_onClipInserted);
    on<ClipEditorClipUpdated>(_onClipUpdated);
    on<ClipEditorClipThumbnailUpdated>(_onClipThumbnailUpdated);

    // Clip selection
    on<ClipEditorClipSelected>(_onClipSelected);
    on<ClipEditorFrameSelected>(_onFrameSelected);

    // Multi-select
    on<ClipEditorMultiSelectStarted>(_onMultiSelectStarted);
    on<ClipEditorMultiSelectClipToggled>(_onMultiSelectClipToggled);
    on<ClipEditorMultiSelectCancelled>(_onMultiSelectCancelled);
    on<ClipEditorFrameMultiSelectStarted>(_onFrameMultiSelectStarted);
    on<ClipEditorFrameMultiSelectToggled>(_onFrameMultiSelectToggled);
    on<ClipEditorFrameMultiSelectionSet>(_onFrameMultiSelectionSet);
    on<ClipEditorSelectedClipsRemoved>(_onSelectedClipsRemoved);
    on<ClipEditorSelectedClipsMergeRequested>(
      _onSelectedClipsMergeRequested,
      transformer: droppable(),
    );

    // Editing mode
    on<ClipEditorEditingStarted>(_onEditingStarted);
    on<ClipEditorEditingStopped>(_onEditingStopped);
    on<ClipEditorEditingToggled>(_onEditingToggled);
    on<ClipEditorSplitPositionChanged>(_onSplitPositionChanged);

    // Split
    on<ClipEditorOriginalClipReplaced>(_onOriginalClipReplaced);
    // sequential (not droppable) so a split requested on a different clip while
    // one is rendering is queued and runs, rather than being silently dropped.
    on<ClipEditorSplitRequested>(_onSplitRequested, transformer: sequential());

    // Trim
    on<ClipEditorTrimUpdated>(_onTrimUpdated, transformer: restartable());
    on<ClipEditorTrimDragStarted>(_onTrimDragStarted);
    on<ClipEditorTrimDragEnded>(_onTrimDragEnded);

    // Audio extraction
    // sequential (not droppable) so an extraction requested on a different clip
    // while one is running is queued and runs, rather than being dropped.
    on<ClipEditorAudioExtractionRequested>(
      _onAudioExtractionRequested,
      transformer: sequential(),
    );

    // Reverse
    on<ClipEditorClipReverseRequested>(
      _onClipReverseRequested,
      transformer: droppable(),
    );

    // Transform (crop / rotate / flip)
    on<ClipEditorStopMotionFrameTransformed>(
      _onStopMotionFrameTransformed,
      transformer: sequential(),
    );
    on<ClipEditorClipTransformRequested>(
      _onClipTransformRequested,
      transformer: droppable(),
    );
    on<ClipEditorDetachedClipTransformRequested>(
      _onDetachedClipTransformRequested,
      transformer: droppable(),
    );

    // Burn a green screen into the clip's file
    on<ClipEditorChromaKeyRequested>(
      _onChromaKeyRequested,
      transformer: droppable(),
    );
    on<ClipEditorChromaKeyRemoved>(_onChromaKeyRemoved);

    // Lift a clip off the timeline and onto the canvas
    // sequential (not droppable) so detaching a second clip while the first
    // one's placeholder renders is queued rather than silently dropped.
    on<ClipEditorClipDetachRequested>(
      _onClipDetachRequested,
      transformer: sequential(),
    );

    // Save a single clip to the persistent clip library
    on<ClipEditorSaveClipToLibraryRequested>(
      _onSaveClipToLibraryRequested,
      transformer: droppable(),
    );

    // Volume
    on<ClipEditorClipVolumeChanged>(
      _onClipVolumeChanged,
      transformer: sequential(),
    );
    on<ClipEditorAllClipsVolumeChanged>(
      _onAllClipsVolumeChanged,
      transformer: sequential(),
    );
  }

  final void Function() onFinalClipInvalidated;
  final AudioExtractionService _audioExtractionService;
  final SplitClipFn _splitClip;
  final ReverseClipFn _reverseClip;
  final TransformClipFn _transformClip;
  final MeasureAspectRatioFn _measureAspectRatio;
  final WriteStopMotionFrameFn _writeStopMotionFrame;
  final ChromaKeyBakeFn _bakeChromaKey;
  final MergeClipsFn _mergeClips;
  final FlattenClipForLibraryFn _flattenClipForLibrary;
  final CleanupFlattenedClipFn _cleanupFlattenedClip;
  final DeferFileCleanupFn _deferFileCleanup;
  final SaveClipToLibraryFn _saveClipToLibrary;
  final RenderClipPlaceholderFn _renderClipPlaceholder;

  // === CLIP DATA ===

  void _onInitialized(
    ClipEditorInitialized event,
    Emitter<ClipEditorState> emit,
  ) {
    // While a split is in flight (including splits still queued behind it),
    // this bloc owns the clip list optimistically — the split has already
    // inserted its result, but the editor-history round-trip that drives the
    // canvas re-sync still reflects the pre-split state. Applying that stale
    // snapshot here wipes the just-applied (queued) split, which then never
    // appears. Defer: the post-split reconcile re-syncs once isSplitting
    // clears. The canvas guards its dispatch on the same condition; this is
    // the matching guard for any other re-init source.
    if (state.isSplitting) {
      Log.debug(
        '📋 Ignoring clip re-init during in-flight split '
        '(${event.clips.length} clip(s))',
        name: 'ClipEditorBloc',
        category: LogCategory.video,
      );
      return;
    }
    Log.debug(
      '📋 Initialized with ${event.clips.length} clip(s)',
      name: 'ClipEditorBloc',
      category: LogCategory.video,
    );
    emit(state.copyWith(clips: List.unmodifiable(event.clips)));
  }

  void _onClipRemoved(
    ClipEditorClipRemoved event,
    Emitter<ClipEditorState> emit,
  ) {
    final index = state.clips.indexWhere((c) => c.id == event.clipId);
    if (index == -1) return;

    final newClips = List<DivineVideoClip>.of(state.clips)..removeAt(index);

    Log.debug(
      '🗑️ Removed clip ${event.clipId} (${newClips.length} remaining)',
      name: 'ClipEditorBloc',
      category: LogCategory.video,
    );

    emit(state.copyWith(clips: List.unmodifiable(newClips)));
  }

  void _onClipInserted(
    ClipEditorClipInserted event,
    Emitter<ClipEditorState> emit,
  ) {
    final newClips = List<DivineVideoClip>.of(state.clips)
      ..insert(event.index.clamp(0, state.clips.length), event.clip);

    Log.debug(
      '➕ Inserted clip ${event.clip.id} at index ${event.index}',
      name: 'ClipEditorBloc',
      category: LogCategory.video,
    );

    emit(state.copyWith(clips: List.unmodifiable(newClips)));
  }

  void _onClipUpdated(
    ClipEditorClipUpdated event,
    Emitter<ClipEditorState> emit,
  ) {
    final index = state.clips.indexWhere((c) => c.id == event.clipId);
    if (index == -1) return;

    final newClips = List<DivineVideoClip>.of(state.clips)
      ..[index] = event.clip;

    // A frame delete/reorder replaces the stop-motion clip with a shorter or
    // reordered frame list; clamp the selection so it never points past the end.
    final selected = state.selectedFrameIndex;
    final frames = event.clip.stopMotionFrames;
    final clampedSelection = frames == null
        ? selected
        : frames.isEmpty
        ? null
        : selected?.clamp(0, frames.length - 1);
    final prunedMultiSelection = frames != null
        ? {
            for (final index in state.selectedFrameIndexes)
              if (index < frames.length) index,
          }
        : state.selectedFrameIndexes;

    emit(
      state.copyWith(
        clips: List.unmodifiable(newClips),
        selectedFrameIndex: clampedSelection,
        clearSelectedFrameIndex:
            selected != null &&
            event.clip.video == null &&
            (frames == null || frames.isEmpty),
        selectedFrameIndexes: prunedMultiSelection,
      ),
    );
  }

  void _onClipThumbnailUpdated(
    ClipEditorClipThumbnailUpdated event,
    Emitter<ClipEditorState> emit,
  ) {
    final index = state.clips.indexWhere((c) => c.id == event.clipId);
    if (index == -1) return;

    final newClips = List<DivineVideoClip>.of(state.clips)
      ..[index] = state.clips[index].copyWith(
        thumbnailPath: event.thumbnailPath,
      );

    emit(state.copyWith(clips: List.unmodifiable(newClips)));
  }

  // === CLIP SELECTION ===

  void _onClipSelected(
    ClipEditorClipSelected event,
    Emitter<ClipEditorState> emit,
  ) {
    final clips = state.clips;
    if (event.index < 0 || event.index >= clips.length) return;

    Log.debug(
      '🎯 Selected clip ${event.index}',
      name: 'ClipEditorBloc',
      category: LogCategory.video,
    );
    emit(
      state.copyWith(
        currentClipIndex: event.index,
        splitPosition: Duration.zero,
        clearSelectedFrameIndex: true,
      ),
    );
  }

  void _onFrameSelected(
    ClipEditorFrameSelected event,
    Emitter<ClipEditorState> emit,
  ) {
    final clips = state.clips;
    if (!isStopMotionComposition(clips)) return;
    final frames = clips.first.stopMotionFrames;
    if (frames == null ||
        event.frameIndex < 0 ||
        event.frameIndex >= frames.length) {
      return;
    }

    emit(
      state.copyWith(
        currentClipIndex: 0,
        isEditing: true,
        selectedFrameIndex: event.frameIndex,
      ),
    );
  }

  // === MULTI-SELECT ===

  void _onMultiSelectStarted(
    ClipEditorMultiSelectStarted event,
    Emitter<ClipEditorState> emit,
  ) {
    final initialId = event.initialClipId;
    final selected = <String>{
      if (initialId != null && state.clips.any((c) => c.id == initialId))
        initialId,
    };
    emit(
      state.copyWith(
        isMultiSelectMode: true,
        isEditing: false,
        selectedClipIds: selected,
      ),
    );
  }

  void _onMultiSelectClipToggled(
    ClipEditorMultiSelectClipToggled event,
    Emitter<ClipEditorState> emit,
  ) {
    if (!state.isMultiSelectMode) return;
    if (!state.clips.any((c) => c.id == event.clipId)) return;

    final selected = Set<String>.of(state.selectedClipIds);
    if (!selected.remove(event.clipId)) {
      selected.add(event.clipId);
    }
    emit(state.copyWith(selectedClipIds: selected));
  }

  void _onMultiSelectCancelled(
    ClipEditorMultiSelectCancelled event,
    Emitter<ClipEditorState> emit,
  ) {
    emit(
      state.copyWith(
        isMultiSelectMode: false,
        selectedClipIds: const {},
        selectedFrameIndexes: const {},
      ),
    );
  }

  void _onFrameMultiSelectStarted(
    ClipEditorFrameMultiSelectStarted event,
    Emitter<ClipEditorState> emit,
  ) {
    if (!isStopMotionComposition(state.clips)) return;
    final frames = state.clips.first.stopMotionFrames ?? const [];
    final initial = event.initialFrameIndex;
    emit(
      state.copyWith(
        isMultiSelectMode: true,
        isEditing: false,
        clearSelectedFrameIndex: true,
        selectedFrameIndexes: {
          if (initial != null && initial >= 0 && initial < frames.length)
            initial,
        },
      ),
    );
  }

  void _onFrameMultiSelectToggled(
    ClipEditorFrameMultiSelectToggled event,
    Emitter<ClipEditorState> emit,
  ) {
    if (!state.isMultiSelectMode) return;
    if (!isStopMotionComposition(state.clips)) return;
    final frames = state.clips.first.stopMotionFrames ?? const [];
    if (event.frameIndex < 0 || event.frameIndex >= frames.length) return;

    final selected = Set<int>.of(state.selectedFrameIndexes);
    if (!selected.remove(event.frameIndex)) {
      selected.add(event.frameIndex);
    }
    emit(state.copyWith(selectedFrameIndexes: selected));
  }

  void _onFrameMultiSelectionSet(
    ClipEditorFrameMultiSelectionSet event,
    Emitter<ClipEditorState> emit,
  ) {
    if (!state.isMultiSelectMode) return;
    if (!isStopMotionComposition(state.clips)) return;
    final frames = state.clips.first.stopMotionFrames ?? const [];
    if (event.frameIndexes.any(
      (index) => index < 0 || index >= frames.length,
    )) {
      return;
    }
    emit(state.copyWith(selectedFrameIndexes: event.frameIndexes));
  }

  void _onSelectedClipsRemoved(
    ClipEditorSelectedClipsRemoved event,
    Emitter<ClipEditorState> emit,
  ) {
    final selected = state.selectedClipIds;
    if (selected.isEmpty) return;

    final previousClips = state.clips;
    final remaining = previousClips
        .where((c) => !selected.contains(c.id))
        .toList();
    // At least one clip must always remain in the timeline.
    if (remaining.isEmpty) return;

    Log.info(
      '🗑️ Removed ${previousClips.length - remaining.length} selected clip(s)',
      name: 'ClipEditorBloc',
      category: LogCategory.video,
    );

    emit(
      state.copyWith(
        clips: List.unmodifiable(remaining),
        currentClipIndex: state.currentClipIndex.clamp(0, remaining.length - 1),
        isMultiSelectMode: false,
        selectedClipIds: const {},
        lastClipsRemovedResult: ClipsRemovedResult(
          previousClips: previousClips,
        ),
      ),
    );
  }

  Future<void> _onSelectedClipsMergeRequested(
    ClipEditorSelectedClipsMergeRequested event,
    Emitter<ClipEditorState> emit,
  ) async {
    final selectedIds = state.selectedClipIds;
    final selectedClips = state.clips
        .where((c) => selectedIds.contains(c.id))
        .toList();
    if (selectedClips.length < 2) return;

    final renderId = 'merge_${DateTime.now().microsecondsSinceEpoch}';

    Log.info(
      '🧬 Merging ${selectedClips.length} selected clip(s)',
      name: 'ClipEditorBloc',
      category: LogCategory.video,
    );

    emit(state.copyWith(isMerging: true, mergingRenderId: renderId));

    try {
      final merged = await _mergeClips(
        clips: selectedClips,
        renderId: renderId,
      );

      if (merged == null) {
        // Matrix-NO: render cancel/failure is surfaced as a null output by
        // VideoEditorRenderService.renderVideo (Network/IO).
        emit(
          state.copyWith(
            isMerging: false,
            clearMergingRenderId: true,
            lastMergeResult: ClipMergeFailure(),
          ),
        );
        return;
      }

      // Reconcile against current state after the async gap. The full-screen
      // progress overlay blocks competing edits, but guard anyway so a stale
      // result never resurrects removed clips.
      final currentClips = state.clips;
      final stillPresent = selectedIds.every(
        (id) => currentClips.any((c) => c.id == id),
      );
      if (!stillPresent) {
        Log.warning(
          '⚠️ Merge result discarded: a selected clip no longer exists',
          name: 'ClipEditorBloc',
          category: LogCategory.video,
        );
        emit(
          state.copyWith(
            isMerging: false,
            clearMergingRenderId: true,
            isMultiSelectMode: false,
            selectedClipIds: const {},
            lastMergeResult: ClipMergeDiscarded(),
          ),
        );
        return;
      }

      final earliestIndex = currentClips.indexWhere(
        (c) => selectedIds.contains(c.id),
      );
      final newClips =
          currentClips.where((c) => !selectedIds.contains(c.id)).toList()
            ..insert(earliestIndex, merged);

      emit(
        state.copyWith(
          clips: List.unmodifiable(newClips),
          currentClipIndex: earliestIndex,
          isMerging: false,
          clearMergingRenderId: true,
          isMultiSelectMode: false,
          selectedClipIds: const {},
          lastMergeResult: ClipMergeSuccess(previousClips: currentClips),
        ),
      );

      Log.info(
        '✅ Merged into clip ${merged.id}',
        name: 'ClipEditorBloc',
        category: LogCategory.video,
      );
    } catch (e, stackTrace) {
      final error = switch (e) {
        StateError() || TypeError() || RangeError() => Reportable(
          e,
          context: '_onSelectedClipsMergeRequested',
        ),
        _ => e,
      };
      addError(error, stackTrace);
      Log.error(
        '❌ Failed to merge clips: $e',
        name: 'ClipEditorBloc',
        category: LogCategory.video,
      );
      emit(
        state.copyWith(
          isMerging: false,
          clearMergingRenderId: true,
          lastMergeResult: ClipMergeFailure(),
        ),
      );
    }
  }

  // === EDITING MODE ===

  void _onEditingStarted(
    ClipEditorEditingStarted event,
    Emitter<ClipEditorState> emit,
  ) {
    final clips = state.clips;
    if (state.currentClipIndex >= clips.length) return;

    Log.info(
      '✂️ Started editing clip ${state.currentClipIndex}',
      name: 'ClipEditorBloc',
      category: LogCategory.video,
    );
    emit(
      state.copyWith(
        isEditing: true,
        splitPosition: clips[state.currentClipIndex].trimmedDuration ~/ 2,
      ),
    );
  }

  void _onEditingStopped(
    ClipEditorEditingStopped event,
    Emitter<ClipEditorState> emit,
  ) {
    Log.info(
      '✅ Stopped editing clip ${state.currentClipIndex}',
      name: 'ClipEditorBloc',
      category: LogCategory.video,
    );
    emit(state.copyWith(isEditing: false, clearSelectedFrameIndex: true));
  }

  void _onEditingToggled(
    ClipEditorEditingToggled event,
    Emitter<ClipEditorState> emit,
  ) {
    if (state.isEditing) {
      _onEditingStopped(const ClipEditorEditingStopped(), emit);
    } else {
      _onEditingStarted(const ClipEditorEditingStarted(), emit);
    }
  }

  void _onSplitPositionChanged(
    ClipEditorSplitPositionChanged event,
    Emitter<ClipEditorState> emit,
  ) {
    emit(state.copyWith(splitPosition: event.position));
  }

  // === SPLIT ===

  void _onOriginalClipReplaced(
    ClipEditorOriginalClipReplaced event,
    Emitter<ClipEditorState> emit,
  ) {
    final index = state.clips.indexWhere((c) => c.id == event.sourceClipId);
    if (index == -1) return;

    final newClips = List<DivineVideoClip>.of(state.clips)
      ..[index] = event.startClip
      ..insert(index + 1, event.endClip);

    Log.debug(
      '✂️ Replaced ${event.sourceClipId} with '
      '${event.startClip.id} + ${event.endClip.id}',
      name: 'ClipEditorBloc',
      category: LogCategory.video,
    );

    emit(state.copyWith(clips: List.unmodifiable(newClips)));
  }

  Future<void> _onSplitRequested(
    ClipEditorSplitRequested event,
    Emitter<ClipEditorState> emit,
  ) async {
    final clips = state.clips;
    // Resolve the target from the event (captured at dispatch) so a queued
    // split still hits the intended clip; fall back to the current selection.
    final index = event.clipId != null
        ? clips.indexWhere((c) => c.id == event.clipId)
        : state.currentClipIndex;
    if (index < 0 || index >= clips.length) return;

    final selectedClip = clips[index];
    final splitPosition = event.splitPosition ?? state.splitPosition;

    // Validate split position before changing state
    if (!VideoEditorSplitService.isValidSplitPosition(
      selectedClip,
      splitPosition,
    )) {
      Log.warning(
        '⚠️ Invalid split position ${splitPosition.inSeconds}s - '
        'clips must be at least '
        '${VideoEditorSplitService.minClipDuration.inMilliseconds}ms',
        name: 'ClipEditorBloc',
        category: LogCategory.video,
      );
      return;
    }

    Log.info(
      '✂️ Splitting clip ${selectedClip.id} at '
      '${splitPosition.inSeconds}s',
      name: 'ClipEditorBloc',
      category: LogCategory.video,
    );

    // Stop editing mode
    emit(
      state.copyWith(
        isEditing: false,
        isSplitting: true,
        splittingClipId: selectedClip.id,
      ),
    );

    ClipSplitFailure? splitFailure;
    String? splitStartClipId;
    String? splitEndClipId;
    try {
      // Emit directly from callbacks instead of dispatching events.
      // Cross-event-type handlers run concurrently in BLoC, which
      // caused a race where a follow-up clip update was processed before
      // the new clip ids were inserted — the index lookup failed and the
      // clips kept pointing at the original source video.
      await _splitClip(
        sourceClip: selectedClip,
        splitPosition: splitPosition,
        onClipsCreated: (startClip, endClip) {
          splitStartClipId = startClip.id;
          splitEndClipId = endClip.id;

          // The background thumbnail callback can fire after the bloc is
          // closed (user navigates away from the editor) — guard each one
          // against a done emitter.
          if (emit.isDone) return;
          final clips = state.clips;
          final index = clips.indexWhere((c) => c.id == selectedClip.id);
          if (index == -1) return;
          // Preserve the user's live selection identity across the insert. The
          // split may target a clip *before* the currently-selected one (the
          // user can switch clips while an earlier split renders), and
          // inserting the tail shifts every later index by one — re-point
          // currentClipIndex at the same clip so the selection doesn't
          // silently jump. When the selected clip *is* the split source, its
          // id is gone (replaced by startClip); keep the index unchanged so it
          // lands on startClip.
          final currentIndex = state.currentClipIndex;
          final selectedClipId =
              currentIndex >= 0 && currentIndex < clips.length
              ? clips[currentIndex].id
              : null;
          final newClips = List<DivineVideoClip>.of(clips)
            ..[index] = startClip
            ..insert(index + 1, endClip);
          final newSelectedIndex = selectedClipId == null
              ? currentIndex
              : newClips.indexWhere((c) => c.id == selectedClipId);
          emit(
            state.copyWith(
              clips: List.unmodifiable(newClips),
              currentClipIndex: newSelectedIndex >= 0
                  ? newSelectedIndex
                  : currentIndex,
              lastSplit: ClipSplitEvent(
                sourceClipId: selectedClip.id,
                startClipId: startClip.id,
                endClipId: endClip.id,
                absoluteSplitPosition: selectedClip.trimStart + splitPosition,
                sourceDuration: selectedClip.duration,
                sourceTrimStart: selectedClip.trimStart,
                sourceTrimEnd: selectedClip.trimEnd,
              ),
            ),
          );
          Log.debug(
            '✂️ Replaced ${selectedClip.id} with '
            '${startClip.id} + ${endClip.id}',
            name: 'ClipEditorBloc',
            category: LogCategory.video,
          );
        },
        onThumbnailExtracted: (clip, thumbnailPath) {
          // The thumbnail decode is fire-and-forget, so it lands after this
          // split handler completes and its emitter is done. Dispatch a fresh
          // event so the poster still updates (unless the bloc was closed).
          if (isClosed) return;
          add(
            ClipEditorClipThumbnailUpdated(
              clipId: clip.id,
              thumbnailPath: thumbnailPath,
            ),
          );
        },
      );

      // onFinalClipInvalidated reaches into the editor screen that owns this
      // bloc. The trim-based split is instant, but the same callback also
      // guards long clip renders elsewhere (reverse / transform, ~15-20s) that
      // can land after the user backs out — the screen callback must guard on
      // `mounted`; the bloc can't detect the torn-down screen from this side.
      onFinalClipInvalidated.call();

      Log.info(
        '✅ Successfully split clip into 2 segments',
        name: 'ClipEditorBloc',
        category: LogCategory.video,
      );
    } catch (e, stackTrace) {
      // Matrix-NO: rethrown render exceptions and file IO. ArgumentError from
      // VideoEditorSplitService is pre-validated by isValidSplitPosition at
      // line 259 above and cannot reach this catch.
      addError(e, stackTrace);
      Log.error(
        '❌ Failed to split clip: $e',
        name: 'ClipEditorBloc',
        category: LogCategory.video,
      );
      splitFailure = ClipSplitFailure();
    } finally {
      if (!emit.isDone) {
        final rollbackClips = splitFailure == null
            ? null
            : _clipsWithFailedSplitRolledBack(
                state.clips,
                sourceClip: selectedClip,
                startClipId: splitStartClipId,
                endClipId: splitEndClipId,
              );
        emit(
          state.copyWith(
            clips: rollbackClips,
            isSplitting: false,
            clearSplittingClipId: true,
            lastSplitFailure: splitFailure,
            clearLastSplit: splitFailure != null,
          ),
        );
      }
    }
  }

  List<DivineVideoClip>? _clipsWithFailedSplitRolledBack(
    List<DivineVideoClip> clips, {
    required DivineVideoClip sourceClip,
    required String? startClipId,
    required String? endClipId,
  }) {
    if (startClipId == null || endClipId == null) return null;

    final startIndex = clips.indexWhere((clip) => clip.id == startClipId);
    if (startIndex == -1 || startIndex + 1 >= clips.length) return null;
    if (clips[startIndex + 1].id != endClipId) return null;

    final restoredClips = List<DivineVideoClip>.of(clips)
      ..replaceRange(startIndex, startIndex + 2, [sourceClip]);
    return List.unmodifiable(restoredClips);
  }

  // === TRIM ===

  void _onTrimUpdated(
    ClipEditorTrimUpdated event,
    Emitter<ClipEditorState> emit,
  ) {
    final index = state.clips.indexWhere((c) => c.id == event.clipId);
    if (index == -1) return;

    final clip = state.clips[index];
    final maxTrim = clip.duration - TimelineConstants.minTrimDuration;
    // A trim-based split's end half carries a source floor so its start handle
    // can't be dragged back before the split into the start half's frames.
    // The upper bound can dip below that floor when the visible span is shorter
    // than minTrimDuration (the split guard allows a 30ms half); keep the floor
    // authoritative so the clamp can never emit a trimStart below it.
    final minStart = clip.minTrimStart;
    final maxStart = (maxTrim - clip.trimEnd) < minStart
        ? minStart
        : maxTrim - clip.trimEnd;
    final clampedStart = event.trimStart < minStart
        ? minStart
        : event.trimStart > maxStart
        ? maxStart
        : event.trimStart;
    final clampedEnd = event.trimEnd < Duration.zero
        ? Duration.zero
        : event.trimEnd > maxTrim - clampedStart
        ? maxTrim - clampedStart
        : event.trimEnd;

    final newClips = List<DivineVideoClip>.of(state.clips);
    newClips[index] = newClips[index].copyWith(
      trimStart: clampedStart,
      trimEnd: clampedEnd,
    );

    // Position of the dragged handle within the clip's *untrimmed*
    // timeline (0..clip.duration). The preview player is switched to
    // a single-clip view of [event.clipId] for the duration of the
    // gesture, so seeking to this position lands on the correct frame.
    final trimPosition = event.isStart
        ? clampedStart
        : clip.duration - clampedEnd;

    emit(
      state.copyWith(
        clips: List.unmodifiable(newClips),
        trimPosition: trimPosition,
        trimmingClipId: event.clipId,
      ),
    );
  }

  void _onTrimDragStarted(
    ClipEditorTrimDragStarted event,
    Emitter<ClipEditorState> emit,
  ) {
    emit(state.copyWith(isTrimDragging: true));
  }

  void _onTrimDragEnded(
    ClipEditorTrimDragEnded event,
    Emitter<ClipEditorState> emit,
  ) {
    emit(
      state.copyWith(
        isTrimDragging: false,
        clearTrimPosition: true,
        clearTrimmingClipId: true,
      ),
    );
  }

  // === VOLUME ===

  void _onClipVolumeChanged(
    ClipEditorClipVolumeChanged event,
    Emitter<ClipEditorState> emit,
  ) {
    final index = state.clips.indexWhere((c) => c.id == event.clipId);
    if (index == -1) return;
    final nextVolume = event.volume.clamp(0.0, 1.0);
    if (state.clips[index].volume == nextVolume) return;
    final updated = List<DivineVideoClip>.of(state.clips);
    updated[index] = updated[index].copyWith(volume: nextVolume);
    emit(
      state.copyWith(
        clips: List.unmodifiable(updated),
        clipsVolumeRevision: state.clipsVolumeRevision + 1,
      ),
    );
  }

  void _onAllClipsVolumeChanged(
    ClipEditorAllClipsVolumeChanged event,
    Emitter<ClipEditorState> emit,
  ) {
    final nextVolume = event.volume.clamp(0.0, 1.0);
    if (state.clips.isEmpty) return;
    if (state.clips.every((c) => c.volume == nextVolume)) return;
    final updated = state.clips
        .map((c) => c.copyWith(volume: nextVolume))
        .toList(growable: false);
    emit(
      state.copyWith(
        clips: List.unmodifiable(updated),
        clipsVolumeRevision: state.clipsVolumeRevision + 1,
      ),
    );
  }

  // === SAVE TO CLIP LIBRARY ===

  /// Re-encodes the requested clip's trim window into its own file and stores
  /// it in the clip library, leaving the timeline untouched.
  ///
  /// `droppable` rather than `sequential`: while a save runs the controls
  /// disable Save on *every* clip (not just the in-flight one), so a second
  /// event here can only come from a double-tap race in the frame before that
  /// disable renders — queuing it would silently store a duplicate copy. Only
  /// one re-encode runs at a time; the user can still select and edit other
  /// clips, they just can't launch a concurrent save.
  Future<void> _onSaveClipToLibraryRequested(
    ClipEditorSaveClipToLibraryRequested event,
    Emitter<ClipEditorState> emit,
  ) async {
    final index = state.clips.indexWhere((c) => c.id == event.clipId);
    if (index == -1) return;
    final clip = state.clips[index];

    // Overlay windows are authored against the editor timeline — every clip at
    // its full playback length — so this clip's slice of it starts after every
    // preceding clip's playbackDuration. Window the overlays down to that slice
    // and rebase to zero, so the standalone render draws exactly what sat over
    // this clip, at the right moments (#5322).
    var clipStart = Duration.zero;
    for (var i = 0; i < index; i++) {
      clipStart += state.clips[i].playbackDuration;
    }
    final overlays = event.overlays?.windowedTo(
      start: clipStart,
      end: clipStart + clip.playbackDuration,
    );

    // Namespaced from the clip id so it can't collide with a concurrent
    // reverse render keyed on the same clip id.
    final renderId = '${clip.id}_clip_library_save';

    Log.info(
      '💾 Saving clip ${clip.id} to the clip library',
      name: 'ClipEditorBloc',
      category: LogCategory.video,
    );

    emit(
      state.copyWith(
        isSavingClipToLibrary: true,
        savingClipToLibraryClipId: clip.id,
      ),
    );

    // The flattened file lands in the persistent documents dir, so any path
    // that doesn't hand it to the library must delete it — nothing else ever
    // reclaims an unreferenced documents-dir file. Held outside the try so the
    // catch can clean up a file that was rendered before a later step threw.
    DivineVideoClip? flattened;
    try {
      flattened = await _flattenClipForLibrary(
        clip: clip,
        renderId: renderId,
        overlays: overlays,
      );

      if (flattened == null) {
        // Matrix-NO: render cancel/failure surfaces as a null output from
        // VideoEditorRenderService.renderVideo (Network/IO). No file was
        // written, so there is nothing to clean up.
        emit(
          state.copyWith(
            isSavingClipToLibrary: false,
            clearSavingClipToLibraryClipId: true,
            lastClipLibrarySave: ClipLibrarySaveFailure(),
          ),
        );
        return;
      }

      // Reconcile after the async gap: the user can delete the source clip
      // while the ~15-20s re-encode runs. Saving it anyway would resurrect a
      // clip they just discarded.
      if (state.clips.every((c) => c.id != clip.id)) {
        Log.warning(
          '⚠️ Library save discarded: clip ${clip.id} no longer exists',
          name: 'ClipEditorBloc',
          category: LogCategory.video,
        );
        await _cleanupFlattenedClip(
          flattened,
          keepThumbnailPath: clip.thumbnailPath,
        );
        emit(
          state.copyWith(
            isSavingClipToLibrary: false,
            clearSavingClipToLibraryClipId: true,
            lastClipLibrarySave: ClipLibrarySaveDiscarded(),
          ),
        );
        return;
      }

      final saved = await _saveClipToLibrary(clip: flattened);

      if (!saved) {
        await _cleanupFlattenedClip(
          flattened,
          keepThumbnailPath: clip.thumbnailPath,
        );
      }

      emit(
        state.copyWith(
          isSavingClipToLibrary: false,
          clearSavingClipToLibraryClipId: true,
          lastClipLibrarySave: saved
              ? ClipLibrarySaveSuccess()
              : ClipLibrarySaveFailure(),
        ),
      );

      Log.info(
        saved
            ? '✅ Saved clip ${clip.id} to the library as ${flattened.id}'
            : '❌ Library rejected clip ${flattened.id}',
        name: 'ClipEditorBloc',
        category: LogCategory.video,
      );
    } catch (e, stackTrace) {
      if (flattened != null) {
        await _cleanupFlattenedClip(
          flattened,
          keepThumbnailPath: clip.thumbnailPath,
        );
      }
      final error = switch (e) {
        StateError() ||
        TypeError() ||
        RangeError() => Reportable(e, context: '_onSaveClipToLibraryRequested'),
        _ => e,
      };
      addError(error, stackTrace);
      Log.error(
        '❌ Failed to save clip to library: $e',
        name: 'ClipEditorBloc',
        category: LogCategory.video,
        error: e,
        stackTrace: stackTrace,
      );
      emit(
        state.copyWith(
          isSavingClipToLibrary: false,
          clearSavingClipToLibraryClipId: true,
          lastClipLibrarySave: ClipLibrarySaveFailure(),
        ),
      );
    }
  }

  // === REVERSE ===

  Future<void> _onClipReverseRequested(
    ClipEditorClipReverseRequested event,
    Emitter<ClipEditorState> emit,
  ) async {
    final index = state.clips.indexWhere((c) => c.id == event.clipId);
    if (index == -1) return;

    final clip = state.clips[index];
    final videoPath = clip.requireVideo.file?.path;

    if (videoPath == null) {
      Log.warning(
        '⚠️ Reverse skipped: clip ${clip.id} has no local file',
        name: 'ClipEditorBloc',
        category: LogCategory.video,
      );
      emit(state.copyWith(lastReverseResult: ClipReverseNoLocalFile()));
      return;
    }

    if (clip.reversed && clip.forwardVideoPath != null) {
      final restoredClip = clip.copyWith(
        video: EditorVideo.file(clip.forwardVideoPath),
        trimStart: clip.trimEnd,
        trimEnd: clip.trimStart,
        reversed: false,
        // A different file is now the clip's video, so a recorded chroma-key
        // source no longer describes it. The key stays baked in; only
        // re-tuning it is lost.
        clearChromaKey: true,
      );
      final newClips = List<DivineVideoClip>.of(state.clips)
        ..[index] = restoredClip;
      emit(
        state.copyWith(
          clips: List.unmodifiable(newClips),
          lastReverseResult: ClipReverseSuccess(),
        ),
      );
      onFinalClipInvalidated.call();
      _deferSupersededFiles(clip);
      return;
    }

    if (!clip.reversed && clip.reversedVideoPath != null) {
      final restoredClip = clip.copyWith(
        video: EditorVideo.file(clip.reversedVideoPath),
        trimStart: clip.trimEnd,
        trimEnd: clip.trimStart,
        reversed: true,
        // See the forward branch above.
        clearChromaKey: true,
      );
      final newClips = List<DivineVideoClip>.of(state.clips)
        ..[index] = restoredClip;
      emit(
        state.copyWith(
          clips: List.unmodifiable(newClips),
          lastReverseResult: ClipReverseSuccess(),
        ),
      );
      onFinalClipInvalidated.call();
      _deferSupersededFiles(clip);
      return;
    }

    emit(state.copyWith(isReversing: true, reversingClipId: clip.id));

    try {
      final reversedVideo = await _reverseClip(
        sourceClip: clip,
        renderId: clip.id,
      );

      // Screen dispose closes this bloc while a long reverse can still be
      // finishing. The new file is on disk either way — queue it when we can
      // no longer commit it to state.
      if (isClosed) {
        _deferOrphanedPaths([reversedVideo.file?.path]);
        return;
      }

      final currentClips = state.clips;
      final currentIndex = currentClips.indexWhere((c) => c.id == clip.id);
      if (currentIndex == -1) {
        Log.warning(
          '⚠️ Reverse result discarded: clip ${clip.id} no longer exists',
          name: 'ClipEditorBloc',
          category: LogCategory.video,
        );
        // The render never reached a clip, so nothing but this queue can name it.
        _deferOrphanedPaths([reversedVideo.file?.path]);
        emit(
          state.copyWith(
            isReversing: false,
            clearReversingClipId: true,
            lastReverseResult: ClipReverseDiscarded(),
          ),
        );
        return;
      }

      final currentClip = currentClips[currentIndex];

      // The reverse bakes the clip's visible window, so the result is a
      // standalone clip: its file is exactly the window reversed. Reset trims,
      // set [duration] to the window length, and clear the split floor — the
      // reversed file holds only this clip's frames, so there is no sibling to
      // guard and no capped-duration mismatch (the old trimStart/trimEnd swap
      // was only valid when duration == real file length).
      final renderedPath = reversedVideo.file?.path;
      final reversedDuration = clip.trimmedDuration;

      // The swap-based cached toggle only round-trips when the forward clip
      // spanned its whole file (trims zero); a windowed clip re-renders on
      // toggle instead. The render input (`videoPath`) holds content in the
      // clip's current direction, the output (`reversedVideo`) the opposite, so
      // map each to its matching cache slot.
      final keepCache =
          clip.trimStart == Duration.zero && clip.trimEnd == Duration.zero;
      final String? forwardVideoPath;
      final String? reversedVideoPath;
      if (!keepCache) {
        forwardVideoPath = null;
        reversedVideoPath = null;
      } else if (clip.reversed) {
        forwardVideoPath = renderedPath ?? currentClip.forwardVideoPath;
        reversedVideoPath = currentClip.reversedVideoPath ?? videoPath;
      } else {
        forwardVideoPath = currentClip.forwardVideoPath ?? videoPath;
        reversedVideoPath = renderedPath ?? currentClip.reversedVideoPath;
      }

      final updatedClip = currentClip.copyWith(
        video: reversedVideo,
        trimStart: Duration.zero,
        trimEnd: Duration.zero,
        duration: reversedDuration,
        minTrimStart: Duration.zero,
        sourceStartOffset: Duration.zero,
        reversed: !clip.reversed,
        forwardVideoPath: forwardVideoPath,
        reversedVideoPath: reversedVideoPath,
        clearForwardVideoPath: forwardVideoPath == null,
        clearReversedVideoPath: reversedVideoPath == null,
        // The reversed render is a new file; re-keying from the un-reversed
        // chroma source would undo the reverse.
        clearChromaKey: true,
      );
      final newClips = List<DivineVideoClip>.of(currentClips)
        ..[currentIndex] = updatedClip;

      emit(
        state.copyWith(
          clips: List.unmodifiable(newClips),
          isReversing: false,
          clearReversingClipId: true,
          lastReverseResult: ClipReverseSuccess(),
        ),
      );

      onFinalClipInvalidated.call();
      _deferSupersededFiles(currentClip);
    } catch (e, stackTrace) {
      final error = switch (e) {
        StateError() ||
        TypeError() ||
        RangeError() => Reportable(e, context: '_onClipReverseRequested'),
        _ => e,
      };
      addError(error, stackTrace);
      Log.error(
        '❌ Failed to reverse clip ${clip.id}: $e',
        name: 'ClipEditorBloc',
        category: LogCategory.video,
      );
      emit(
        state.copyWith(
          isReversing: false,
          clearReversingClipId: true,
          lastReverseResult: ClipReverseFailure(),
        ),
      );
    }
  }

  // === TRANSFORM ===

  void _onChromaKeyRemoved(
    ClipEditorChromaKeyRemoved event,
    Emitter<ClipEditorState> emit,
  ) {
    final index = state.clips.indexWhere((c) => c.id == event.clipId);
    if (index == -1) return;

    final clip = state.clips[index];
    final source = clip.chromaKeySourcePath;
    if (clip.chromaKey == null || source == null) return;

    // The clip kept the footage the key was applied to, so undoing it is a
    // file swap rather than another render. Without that file there is nothing
    // to go back to — report it instead of leaving the key on screen.
    if (!File(source).existsSync()) {
      Log.warning(
        '⚠️ Cannot drop the green screen on clip ${clip.id}: '
        'its pre-key video $source is gone',
        name: 'ClipEditorBloc',
        category: LogCategory.video,
      );
      emit(state.copyWith(lastChromaKeyResult: ChromaKeyRemoveFailure()));
      return;
    }

    final restored = clip.copyWith(
      video: EditorVideo.file(source),
      clearChromaKey: true,
      // The cached reverse files were rendered from the keyed video, so they
      // no longer match the footage this clip is going back to.
      clearForwardVideoPath: true,
      clearReversedVideoPath: true,
    );
    final newClips = List<DivineVideoClip>.of(state.clips)..[index] = restored;

    emit(
      state.copyWith(
        clips: List.unmodifiable(newClips),
        lastChromaKeyResult: ChromaKeySuccess(),
      ),
    );

    onFinalClipInvalidated.call();
    _deferSupersededFiles(clip);
  }

  /// Lifts a clip off the timeline so the widget layer can place it on the
  /// canvas, and either closes the gap it leaves or fills it with a still.
  ///
  /// The clip list mutation happens here; adding the layer and writing both to
  /// editor history is the widget layer's half, driven by
  /// [ClipEditorState.lastDetachResult]. Splitting it that way keeps the bloc
  /// free of the editor, and keeps the two changes in one undo entry.
  Future<void> _onClipDetachRequested(
    ClipEditorClipDetachRequested event,
    Emitter<ClipEditorState> emit,
  ) async {
    final index = state.clips.indexWhere((c) => c.id == event.clipId);
    if (index == -1) return;
    final clip = state.clips[index];

    // Closing the gap is the one case a lone clip cannot take: the composition
    // would be left with no track at all. The action bar already hides it, so
    // this is the belt-and-braces half.
    final replacement = event.replacement;
    if (replacement == null && state.clips.length <= 1) {
      Log.warning(
        '⚠️ Refusing to detach the only clip without a replacement',
        name: 'ClipEditorBloc',
        category: LogCategory.video,
      );
      return;
    }

    DivineVideoClip? placeholder;
    if (replacement != null) {
      // Namespaced off the clip id like every other render here, so the
      // progress overlay keys on this encode and not a concurrent one.
      final renderId = '${clip.id}_detach';
      emit(
        state.copyWith(
          isDetaching: true,
          detachingClipId: clip.id,
          detachingRenderId: renderId,
        ),
      );
      try {
        placeholder = await _renderClipPlaceholder(
          fill: replacement,
          source: clip,
          taskId: renderId,
        );
      } catch (e, stackTrace) {
        final error = switch (e) {
          StateError() ||
          TypeError() ||
          RangeError() => Reportable(e, context: '_onClipDetachRequested'),
          _ => e,
        };
        addError(error, stackTrace);
        Log.error(
          '❌ Failed to render the placeholder for clip ${clip.id}: $e',
          name: 'ClipEditorBloc',
          category: LogCategory.video,
        );
      }

      // Leaving the editor mid-render still wrote a documents-dir file; hand it
      // to the reaper rather than orphaning it.
      if (isClosed) {
        _deferOrphanedPaths(placeholder?.ownedFilePaths ?? const <String?>[]);
        return;
      }

      if (placeholder == null) {
        emit(
          state.copyWith(
            isDetaching: false,
            clearDetachingClipId: true,
            lastDetachResult: ClipDetachFailure(),
          ),
        );
        return;
      }
    }

    final currentClips = state.clips;
    final currentIndex = currentClips.indexWhere((c) => c.id == clip.id);
    if (currentIndex == -1) {
      Log.warning(
        '⚠️ Detach discarded: clip ${clip.id} no longer exists',
        name: 'ClipEditorBloc',
        category: LogCategory.video,
      );
      _deferOrphanedPaths(placeholder?.ownedFilePaths ?? const <String?>[]);
      emit(
        state.copyWith(
          isDetaching: false,
          clearDetachingClipId: true,
          lastDetachResult: ClipDetachDiscarded(),
        ),
      );
      return;
    }

    final newClips = List<DivineVideoClip>.of(currentClips);
    if (placeholder == null) {
      newClips.removeAt(currentIndex);
    } else {
      newClips[currentIndex] = placeholder;
    }

    // The detached clip's own file is deliberately *not* reaped: the layer
    // that now carries it plays from exactly that file.
    emit(
      state.copyWith(
        clips: List.unmodifiable(newClips),
        currentClipIndex: currentIndex.clamp(
          0,
          newClips.isEmpty ? 0 : newClips.length - 1,
        ),
        isEditing: false,
        isDetaching: false,
        clearDetachingClipId: true,
        lastDetachResult: ClipDetachSuccess(
          previousClips: currentClips,
          detachedClip: clip,
          placeholder: placeholder,
        ),
      ),
    );
  }

  Future<void> _onChromaKeyRequested(
    ClipEditorChromaKeyRequested event,
    Emitter<ClipEditorState> emit,
  ) async {
    final index = state.clips.indexWhere((c) => c.id == event.clipId);
    if (index == -1) return;

    final clip = state.clips[index];

    final renderId = ChromaKeyBakeService.renderIdFor(clip.id);
    emit(
      state.copyWith(
        isChromaKeying: true,
        chromaKeyingClipId: clip.id,
        chromaKeyingRenderId: renderId,
      ),
    );

    try {
      final baked = await _bakeChromaKey(
        sourceClip: clip,
        chromaKey: event.chromaKey,
        renderId: renderId,
      );

      // See reverse: leave-during-bake still wrote a documents-dir file.
      if (isClosed) {
        _deferOrphanedPaths([baked.video.file?.path]);
        return;
      }

      final currentClips = state.clips;
      final currentIndex = currentClips.indexWhere((c) => c.id == clip.id);
      if (currentIndex == -1) {
        Log.warning(
          '⚠️ Chroma-key result discarded: clip ${clip.id} no longer exists',
          name: 'ClipEditorBloc',
          category: LogCategory.video,
        );
        // Baked output never landed on a clip. Keep `baked.source` — that is the
        // pre-key file some other draft or the library may still play.
        _deferOrphanedPaths([baked.video.file?.path]);
        emit(
          state.copyWith(
            isChromaKeying: false,
            clearChromaKeyingClipId: true,
            lastChromaKeyResult: ChromaKeyDiscarded(),
          ),
        );
        return;
      }

      // Remember the settings and the footage they were applied to, so
      // re-opening the editor restores what the user set and re-keys from the
      // clean original instead of stacking a second key on baked pixels.
      //
      // The cached forward/reversed paths now point at stale (unkeyed) files —
      // clear them so a later reverse re-renders from the keyed video instead
      // of restoring footage that still has the screen in it.
      final currentClip = currentClips[currentIndex];
      final updatedClip = currentClip.copyWith(
        video: baked.video,
        chromaKey: event.chromaKey,
        chromaKeySourcePath: baked.source,
        clearForwardVideoPath: true,
        clearReversedVideoPath: true,
      );
      final newClips = List<DivineVideoClip>.of(currentClips)
        ..[currentIndex] = updatedClip;

      emit(
        state.copyWith(
          clips: List.unmodifiable(newClips),
          isChromaKeying: false,
          clearChromaKeyingClipId: true,
          lastChromaKeyResult: ChromaKeySuccess(),
        ),
      );

      onFinalClipInvalidated.call();
      _deferSupersededFiles(currentClip);
    } on ChromaKeyBackdropMissingException catch (e, stackTrace) {
      addError(e, stackTrace);
      Log.warning(
        '⚠️ Chroma-key backdrop disappeared while baking clip ${clip.id}: $e',
        name: 'ClipEditorBloc',
        category: LogCategory.video,
      );
      emit(
        state.copyWith(
          isChromaKeying: false,
          clearChromaKeyingClipId: true,
          lastChromaKeyResult: ChromaKeyFailure(),
        ),
      );
    } catch (e, stackTrace) {
      final error = switch (e) {
        StateError() ||
        TypeError() ||
        RangeError() => Reportable(e, context: '_onChromaKeyRequested'),
        _ => e,
      };
      addError(error, stackTrace);
      Log.error(
        '❌ Failed to bake the green screen into clip ${clip.id}: $e',
        name: 'ClipEditorBloc',
        category: LogCategory.video,
      );
      emit(
        state.copyWith(
          isChromaKeying: false,
          clearChromaKeyingClipId: true,
          lastChromaKeyResult: ChromaKeyFailure(),
        ),
      );
    }
  }

  /// Queues every file [superseded] pointed at that the clip list no longer
  /// does, so the editor session reclaims it once undo can no longer reach it.
  ///
  /// Call after the emit that replaced the clip: the current [state] is the
  /// other half of the diff.
  ///
  /// Diffed against live state rather than queued outright, because the
  /// reaper's own reference check reads the database, which lags the editor by
  /// an autosave. A file two clips share — a duplicated clip, a still
  /// duplicated inside one — would otherwise be queued while it is still on
  /// screen, and one cancelled autosave away from being deleted under it.
  void _deferSupersededFiles(DivineVideoClip superseded) =>
      _deferOrphanedPaths(superseded.ownedFilePaths);

  /// Queues whichever of [paths] no clip in the current [state] points at.
  ///
  /// See [_deferSupersededFiles] for why the live clip list filters the queue.
  void _deferOrphanedPaths(Iterable<String?> paths) {
    final live = state.clips
        .expand((clip) => clip.ownedFilePaths)
        .nonNulls
        .toSet();
    final orphans = paths.nonNulls
        .where((path) => path.isNotEmpty && !live.contains(path))
        .toList();
    if (orphans.isEmpty) return;
    try {
      _deferFileCleanup(orphans);
    } catch (e, stackTrace) {
      Log.warning(
        '⚠️ Failed to queue superseded files for cleanup: $e',
        name: 'ClipEditorBloc',
        category: LogCategory.video,
      );
      addError(e, stackTrace);
    }
  }

  /// Persists the crop / rotate / flip the image editor rasterized for one
  /// stop-motion still and points that still at the new file.
  ///
  /// Always a new file, never an overwrite of the source: editor undo history
  /// keeps pointing at the previous path, and duplicated stills share one file,
  /// so rewriting in place would silently transform every copy and make undo a
  /// no-op. Only the frame's path changes — its hold belongs to the slot in the
  /// sequence, not to the pixels — so the composition's length is untouched and
  /// no marker or audio window has to move.
  Future<void> _onStopMotionFrameTransformed(
    ClipEditorStopMotionFrameTransformed event,
    Emitter<ClipEditorState> emit,
  ) async {
    final index = state.clips.indexWhere((c) => c.id == event.clipId);
    if (index == -1) return;
    final frames = state.clips[index].stopMotionFrames;
    if (frames == null ||
        event.frameIndex < 0 ||
        event.frameIndex >= frames.length) {
      return;
    }
    // The editor hands back an empty list when its screenshot pass failed
    // (`CropRotateEditor.done` retries, then closes with `Uint8List(0)`
    // anyway). Writing that would produce a frame pointing at a broken image,
    // and dropping it silently leaves the user staring at an unchanged still
    // after a visible wait — so it surfaces as the same failure a bad write
    // does.
    if (event.imageBytes.isEmpty) {
      Log.error(
        '❌ Transform produced no image for ${event.clipId} '
        'frame ${event.frameIndex}',
        name: 'ClipEditorBloc',
        category: LogCategory.video,
      );
      emit(state.copyWith(lastTransformResult: ClipTransformFrameFailure()));
      return;
    }

    // The still this transform was started from. Re-checked after the write:
    // the sequence can be edited while the bytes are on their way to disk, and
    // an index alone would then name a different still.
    final sourcePath = frames[event.frameIndex].path;

    final String path;
    try {
      path = await _writeStopMotionFrame(event.imageBytes);
    } catch (e, stackTrace) {
      // Matches `_onClipTransformRequested`: an IO failure here is expected
      // (full disk, revoked sandbox) and stays out of Crashlytics, while a
      // broken invariant is a bug worth reporting.
      final error = switch (e) {
        StateError() ||
        TypeError() ||
        RangeError() => Reportable(e, context: '_onStopMotionFrameTransformed'),
        _ => e,
      };
      addError(error, stackTrace);
      Log.error(
        '❌ Failed to save transformed still for ${event.clipId}: $e',
        name: 'ClipEditorBloc',
        category: LogCategory.video,
      );
      if (!isClosed) {
        emit(state.copyWith(lastTransformResult: ClipTransformFrameFailure()));
      }
      return;
    }

    // Leave-during-write: still lands on disk and must be queued even though
    // state can no longer accept it.
    if (isClosed) {
      _deferOrphanedPaths([path]);
      return;
    }

    final currentClips = state.clips;
    final currentIndex = currentClips.indexWhere((c) => c.id == event.clipId);
    if (currentIndex == -1) {
      // Whole clip gone while the still was writing — same leak class as a
      // moved frame: the new file never became a reference anyone tracks.
      Log.warning(
        '⚠️ Transformed still discarded: clip ${event.clipId} no longer exists',
        name: 'ClipEditorBloc',
        category: LogCategory.video,
      );
      _deferOrphanedPaths([path]);
      return;
    }
    final currentFrames = currentClips[currentIndex].stopMotionFrames;
    if (currentFrames == null ||
        event.frameIndex >= currentFrames.length ||
        currentFrames[event.frameIndex].path != sourcePath) {
      // The slot no longer holds the still the user transformed — it was
      // deleted, reordered or already repointed. Repointing it now would apply
      // the crop to whatever moved in, so the write is abandoned instead. It
      // never reached a clip, so nothing but this queue can reclaim it.
      Log.warning(
        '⚠️ Transformed still discarded: frame ${event.frameIndex} of '
        '${event.clipId} moved while the image was being written',
        name: 'ClipEditorBloc',
        category: LogCategory.video,
      );
      _deferOrphanedPaths([path]);
      return;
    }

    final supersededClip = currentClips[currentIndex];
    final updatedClip = StopMotionFrameOps.clipWithFrames(
      supersededClip,
      StopMotionFrameOps.setFramePath(currentFrames, event.frameIndex, path),
    );
    final newClips = List<DivineVideoClip>.of(currentClips)
      ..[currentIndex] = updatedClip;

    emit(state.copyWith(clips: List.unmodifiable(newClips)));

    // Writes the new clip list into editor history, so undo restores the still
    // that was there before — the same hook every other clip render uses.
    onFinalClipInvalidated.call();
    // Queues the still this one replaced, unless a duplicate of it is still in
    // the sequence. Deleting it now would break the undo the line above just
    // wrote; the session reaps it once that history is gone.
    _deferSupersededFiles(supersededClip);
  }

  Future<void> _onClipTransformRequested(
    ClipEditorClipTransformRequested event,
    Emitter<ClipEditorState> emit,
  ) async {
    final index = state.clips.indexWhere((c) => c.id == event.clipId);
    if (index == -1) return;

    final clip = state.clips[index];
    final videoPath = clip.requireVideo.file?.path;

    if (videoPath == null) {
      Log.warning(
        '⚠️ Transform skipped: clip ${clip.id} has no local file',
        name: 'ClipEditorBloc',
        category: LogCategory.video,
      );
      emit(state.copyWith(lastTransformResult: ClipTransformNoLocalFile()));
      return;
    }

    // Namespace the render id so a transform never shares an id with a
    // concurrent reverse render on the same clip — both would otherwise key on
    // clip.id, letting the transform's cancel() abort the in-flight reverse.
    final renderId = '${clip.id}_transform';
    emit(state.copyWith(isTransforming: true, transformingClipId: renderId));

    try {
      final transformedVideo = await _transformClip(
        sourceClip: clip,
        transform: event.transform,
        renderId: renderId,
      );

      // Leave-during-transform: the new documents-dir render exists even when
      // this bloc was closed by screen dispose and can no longer emit.
      if (isClosed) {
        _deferOrphanedPaths([transformedVideo.file?.path]);
        return;
      }

      final currentClips = state.clips;
      final currentIndex = currentClips.indexWhere((c) => c.id == clip.id);
      if (currentIndex == -1) {
        Log.warning(
          '⚠️ Transform result discarded: clip ${clip.id} no longer exists',
          name: 'ClipEditorBloc',
          category: LogCategory.video,
        );
        // New render never swapped onto a clip — queue it the same way an
        // abandoned stop-motion still is, so session end can reclaim it.
        _deferOrphanedPaths([transformedVideo.file?.path]);
        emit(
          state.copyWith(
            isTransforming: false,
            clearTransformingClipId: true,
            lastTransformResult: ClipTransformDiscarded(),
          ),
        );
        return;
      }

      // The transform bakes a new file from the clip's *current* video, so the
      // cached forward/reversed paths now point at stale (pre-transform)
      // files — clear them so a later reverse re-renders from the transformed
      // source instead of restoring untransformed content.
      final currentClip = currentClips[currentIndex];
      final updatedClip = currentClip.copyWith(
        video: transformedVideo,
        clearForwardVideoPath: true,
        clearReversedVideoPath: true,
        // The transform re-renders the clip's geometry, so a recorded
        // chroma-key source no longer matches it — re-keying from that file
        // would silently drop the crop. The key stays baked into the video;
        // only the ability to re-tune it is lost.
        clearChromaKey: true,
      );
      final newClips = List<DivineVideoClip>.of(currentClips)
        ..[currentIndex] = updatedClip;

      emit(
        state.copyWith(
          clips: List.unmodifiable(newClips),
          isTransforming: false,
          clearTransformingClipId: true,
          lastTransformResult: ClipTransformSuccess(),
        ),
      );

      onFinalClipInvalidated.call();
      // Queues the render this one supersedes — the clip's previous video, the
      // reverse caches cleared above, the chroma-key files with them. The
      // history entry written a line earlier still points at all of them, so
      // the session deletes them at teardown rather than now.
      _deferSupersededFiles(currentClip);
    } catch (e, stackTrace) {
      final error = switch (e) {
        StateError() ||
        TypeError() ||
        RangeError() => Reportable(e, context: '_onClipTransformRequested'),
        _ => e,
      };
      addError(error, stackTrace);
      Log.error(
        '❌ Failed to transform clip ${clip.id}: $e',
        name: 'ClipEditorBloc',
        category: LogCategory.video,
      );
      emit(
        state.copyWith(
          isTransforming: false,
          clearTransformingClipId: true,
          lastTransformResult: ClipTransformFailure(),
        ),
      );
    }
  }

  /// Bakes a crop / rotation / flip into a clip that already left the timeline
  /// and now lives in a canvas layer.
  ///
  /// Deliberately not folded into [_onClipTransformRequested]: that one looks
  /// its clip up in [ClipEditorState.clips] and swaps the rendered file back
  /// in there, and a detached clip is in neither place. What the two do share
  /// is the render — same service, same progress-stream id shape — so the
  /// existing transform overlay covers this one for free.
  ///
  /// The layer write-back is the widget layer's half, driven by
  /// [ClipEditorState.lastDetachedClipTransformResult], for the same reason
  /// detaching is split that way: the BLoC has no editor to reach into.
  Future<void> _onDetachedClipTransformRequested(
    ClipEditorDetachedClipTransformRequested event,
    Emitter<ClipEditorState> emit,
  ) async {
    final clip = event.clip;
    if (clip.video?.file?.path == null) {
      Log.warning(
        '⚠️ Detached transform skipped: clip ${clip.id} has no local file',
        name: 'ClipEditorBloc',
        category: LogCategory.video,
      );
      emit(
        state.copyWith(
          lastDetachedClipTransformResult: DetachedClipTransformFailure(),
        ),
      );
      return;
    }

    final renderId = '${clip.id}_detached_transform';
    emit(state.copyWith(isTransforming: true, transformingClipId: renderId));

    try {
      final transformedVideo = await _transformClip(
        sourceClip: clip,
        transform: event.transform,
        renderId: renderId,
      );

      // Leaving the editor mid-render still wrote a documents-dir file.
      if (isClosed) {
        _deferOrphanedPaths([transformedVideo.file?.path]);
        return;
      }

      // A detached clip is a free-floating object on the canvas rather than
      // something bound to the composition's ratio, so a crop changes its
      // shape and the layer has to be re-proportioned to match. Read off the
      // rendered file, because only the renderer knows what it produced.
      final aspectRatio = await _measureAspectRatio(transformedVideo);
      if (isClosed) return;

      emit(
        state.copyWith(
          isTransforming: false,
          clearTransformingClipId: true,
          lastDetachedClipTransformResult: DetachedClipTransformSuccess(
            layerId: event.layerId,
            clip: clip.copyWith(
              video: transformedVideo,
              originalAspectRatio: aspectRatio,
              // The cached forward/reversed renders describe the pre-crop
              // footage, and a recorded chroma-key source no longer lines up
              // with the new geometry — re-keying from it would drop the crop.
              clearForwardVideoPath: true,
              clearReversedVideoPath: true,
              clearChromaKey: true,
            ),
          ),
        ),
      );

      // The pre-crop file is deliberately left on disk, exactly as the detach
      // itself leaves the clip's file: the layer's undo history points at it,
      // a duplicated layer may still play it, and a saved draft records it by
      // basename. Nothing in [clips] refers to it, so the orphan sweep cannot
      // tell those apart — reaping here would break all three.
    } catch (e, stackTrace) {
      final error = switch (e) {
        StateError() || TypeError() || RangeError() => Reportable(
          e,
          context: '_onDetachedClipTransformRequested',
        ),
        _ => e,
      };
      addError(error, stackTrace);
      Log.error(
        '❌ Failed to transform detached clip ${clip.id}: $e',
        name: 'ClipEditorBloc',
        category: LogCategory.video,
      );
      emit(
        state.copyWith(
          isTransforming: false,
          clearTransformingClipId: true,
          lastDetachedClipTransformResult: DetachedClipTransformFailure(),
        ),
      );
    }
  }

  // === AUDIO EXTRACTION ===

  Future<void> _onAudioExtractionRequested(
    ClipEditorAudioExtractionRequested event,
    Emitter<ClipEditorState> emit,
  ) async {
    final clips = state.clips;
    // Resolve the target from the event (captured at dispatch) so a queued
    // extraction still hits the intended clip; fall back to current selection.
    final index = event.clipId != null
        ? clips.indexWhere((c) => c.id == event.clipId)
        : state.currentClipIndex;
    if (index < 0 || index >= clips.length) return;

    final clip = clips[index];

    // Dedupe a queued re-extraction. With sequential(), a second Extract tap
    // on a clip queues behind the first; once the first mutes the clip, the
    // second would re-extract and emit another success, adding a duplicate
    // audio track. Skip when this clip's audio was already extracted and it is
    // still muted as a result; a manual un-mute (volume > 0) lifts the guard.
    if (state.extractedAudioClipIds.contains(clip.id) && clip.volume == 0) {
      Log.info(
        '🎵 Skipping duplicate audio extraction for clip ${clip.id}',
        name: 'ClipEditorBloc',
        category: LogCategory.video,
      );
      return;
    }

    final videoPath = clip.requireVideo.file?.path;
    final extractionSpeed = _effectiveAudioExtractionSpeed(clip);

    if (videoPath == null) {
      Log.warning(
        '⚠️ Audio extraction skipped: clip ${clip.id} has no local file',
        name: 'ClipEditorBloc',
        category: LogCategory.video,
      );
      emit(
        state.copyWith(lastAudioExtraction: ClipAudioExtractionNoLocalFile()),
      );
      return;
    }

    emit(
      state.copyWith(isExtractingAudio: true, extractingAudioClipId: clip.id),
    );

    try {
      // Draft-owned rather than temporary: this track is written into the
      // editor history the draft persists, so it has to outlive both the
      // session and the next app update.
      final result = await _audioExtractionService.extractAudioForDraft(
        videoPath: videoPath,
        speed: extractionSpeed,
      );

      // Reconcile against current state after the async gap.
      // Other event handlers (remove, split, insert) may have mutated
      // the clip list while extraction was running. Using the pre-await
      // snapshot would overwrite newer state or resurrect deleted clips.
      final currentClips = state.clips;
      final currentIndex = currentClips.indexWhere((c) => c.id == clip.id);
      if (currentIndex == -1) {
        // Source clip was removed while extraction was in progress —
        // discard the result to avoid resurrecting a deleted clip.
        Log.warning(
          '⚠️ Audio extraction result discarded: clip ${clip.id} '
          'no longer exists in the timeline',
          name: 'ClipEditorBloc',
          category: LogCategory.video,
        );
        await _cleanupDiscardedAudioExtraction(result.audioFilePath);
        emit(
          state.copyWith(
            isExtractingAudio: false,
            clearExtractingAudioClipId: true,
            lastAudioExtraction: ClipAudioExtractionDiscarded(),
          ),
        );
        return;
      }

      final currentClip = currentClips[currentIndex];
      final currentVideoPath = currentClip.requireVideo.file?.path;
      final currentExtractionSpeed = _effectiveAudioExtractionSpeed(
        currentClip,
      );
      if (currentVideoPath != videoPath ||
          currentExtractionSpeed != extractionSpeed) {
        Log.warning(
          '⚠️ Audio extraction result discarded: clip ${clip.id} source '
          'changed while extraction was running',
          name: 'ClipEditorBloc',
          category: LogCategory.video,
        );
        await _cleanupDiscardedAudioExtraction(result.audioFilePath);
        emit(
          state.copyWith(
            isExtractingAudio: false,
            clearExtractingAudioClipId: true,
            lastAudioExtraction: ClipAudioExtractionDiscarded(),
          ),
        );
        return;
      }

      // Recompute absolute start from current state so clips inserted
      // or removed before this one are accounted for.
      var clipStart = Duration.zero;
      for (var i = 0; i < currentIndex; i++) {
        clipStart += currentClips[i].playbackDuration;
      }

      final audioEvent = AudioEvent(
        id:
            '${AudioEvent.localExtractedMarker}_'
            '${DateTime.now().microsecondsSinceEpoch}',
        pubkey: '',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        url: result.audioFilePath,
        mimeType: result.mimeType,
        sha256: result.sha256Hash,
        fileSize: result.fileSize,
        duration: result.duration,
        title: event.clipTitle,
        startOffset: currentClip.sourceDurationToPlaybackDuration(
          currentClip.trimStart,
        ),
        startTime: clipStart,
        endTime: clipStart + currentClip.playbackDuration,
        // Anchor the extracted audio to its source clip so it follows the
        // clip's trims (J-Cut) until the user manually moves it.
        anchorClipId: currentClip.id,
      );

      // Mute the source clip now that its audio has been extracted.
      final newClips = List<DivineVideoClip>.of(currentClips)
        ..[currentIndex] = currentClip.copyWith(volume: 0);

      Log.info(
        '🎵 Audio extracted for clip ${currentClip.id}',
        name: 'ClipEditorBloc',
        category: LogCategory.video,
      );

      emit(
        state.copyWith(
          clips: List.unmodifiable(newClips),
          isExtractingAudio: false,
          clearExtractingAudioClipId: true,
          extractedAudioClipIds: {
            ...state.extractedAudioClipIds,
            currentClip.id,
          },
          lastAudioExtraction: ClipAudioExtractionSuccess(
            audioEvent: audioEvent,
          ),
        ),
      );
    } on AudioExtractionException catch (e, stackTrace) {
      Log.error(
        '❌ Audio extraction failed: ${e.message}',
        name: 'ClipEditorBloc',
        error: e,
        stackTrace: stackTrace,
        category: LogCategory.video,
      );
      // Matrix-NO: AudioExtractionException is the typed expected failure
      // (Network/IO — FFmpeg + file IO).
      addError(e, stackTrace);
      emit(
        state.copyWith(
          isExtractingAudio: false,
          clearExtractingAudioClipId: true,
          lastAudioExtraction: ClipAudioExtractionFailure(),
        ),
      );
    } catch (e, stackTrace) {
      Log.error(
        '❌ Unexpected error during audio extraction: $e',
        name: 'ClipEditorBloc',
        error: e,
        stackTrace: stackTrace,
        category: LogCategory.video,
      );
      addError(
        Reportable(e, context: '_onAudioExtractionRequested'),
        stackTrace,
      );
      emit(
        state.copyWith(
          isExtractingAudio: false,
          clearExtractingAudioClipId: true,
          lastAudioExtraction: ClipAudioExtractionFailure(),
        ),
      );
    }
  }

  double _effectiveAudioExtractionSpeed(DivineVideoClip clip) {
    final speed = clip.playbackSpeed;
    return speed != null && speed > 0 ? speed : 1.0;
  }

  Future<void> _cleanupDiscardedAudioExtraction(String audioFilePath) async {
    try {
      await _audioExtractionService.cleanupAudioFile(audioFilePath);
    } catch (e) {
      Log.warning(
        '⚠️ Failed to cleanup discarded extracted audio: $e',
        name: 'ClipEditorBloc',
        category: LogCategory.video,
      );
    }
  }
}
