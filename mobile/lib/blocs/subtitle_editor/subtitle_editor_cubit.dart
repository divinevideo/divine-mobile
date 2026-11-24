// ABOUTME: Cubit that orchestrates the subtitle-editor flow: load cues,
// ABOUTME: allow text edits, and publish the updated subtitle track.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:openvine/repositories/subtitle_repository.dart';
import 'package:openvine/services/subtitle_fetcher.dart';
import 'package:openvine/services/subtitle_service.dart';

part 'subtitle_editor_state.dart';

/// Manages the subtitle-editing lifecycle for a single video.
class SubtitleEditorCubit extends Cubit<SubtitleEditorState> {
  /// Creates the cubit with the [repository] and the [video] being edited.
  SubtitleEditorCubit({
    required SubtitleRepository repository,
    required VideoEvent video,
  }) : _repository = repository,
       _video = video,
       super(
         SubtitleEditorState(
           videoDurationMs: video.duration == null || video.duration! <= 0
               ? null
               : video.duration! * Duration.millisecondsPerSecond,
         ),
       );

  /// How long a hand-authored cue runs before the creator adjusts it.
  static const _newCueDurationMs = 2000;

  final SubtitleRepository _repository;
  final VideoEvent _video;

  /// Loads existing subtitle cues for the video.
  ///
  /// Emits [SubtitleEditorStatus.loading] then either:
  /// - [SubtitleEditorStatus.ready] with cues when they are available.
  /// - [SubtitleEditorStatus.processing] when transcription is still running.
  /// - [SubtitleEditorStatus.empty] when transcription finished but found
  ///   nothing to transcribe.
  /// - [SubtitleEditorStatus.unavailable] when no source held a track.
  /// - [SubtitleEditorStatus.failure] and calls [addError] on any exception.
  ///
  /// Whatever it resolves to describes the whole state: a load that finds no
  /// track drops any cues a previous load left behind rather than leaving
  /// them editable underneath an empty-state screen.
  Future<void> load() async {
    if (isClosed) return;
    emit(state.copyWith(status: SubtitleEditorStatus.loading));
    try {
      final result = await _repository.loadCues(_video);
      if (isClosed) return;
      final loaded = switch (result.status) {
        SubtitleFetchStatus.available => SubtitleEditorStatus.ready,
        SubtitleFetchStatus.processing => SubtitleEditorStatus.processing,
        SubtitleFetchStatus.empty => SubtitleEditorStatus.empty,
        SubtitleFetchStatus.unavailable => SubtitleEditorStatus.unavailable,
      };
      emit(
        state.copyWith(
          status: loaded,
          cues: result.cues.map(EditableCue.fromCue).toList(),
          isDirty: false,
          clearSelectedCue: true,
          loadedTrackRef: result.ref,
          clearLoadedTrackRef: result.ref == null,
        ),
      );
    } catch (e, st) {
      if (isClosed) return;
      addError(e, st);
      emit(state.copyWith(status: SubtitleEditorStatus.failure));
    }
  }

  /// Whether an edit must be dropped: the cubit is gone, or a publish is in
  /// flight. Editing mid-publish would clear the busy state and let a second
  /// save start on top of the first.
  bool get _rejectsEdits =>
      isClosed || state.status == SubtitleEditorStatus.saving;

  /// Replaces the text of the cue at [index] with [text] and marks the
  /// state as dirty.
  ///
  /// Out-of-range indices are silently ignored, as are edits made while a
  /// save is in flight.
  void updateCueText(int index, String text) =>
      _replaceCue(index, (cue) => cue.copyWith(text: text));

  /// Replaces the timing of the cue at [index], in milliseconds.
  ///
  /// Leaves a bound untouched when it is `null`. Out-of-range indices are
  /// silently ignored, as are edits made while a save is in flight. Timings
  /// are not validated here so the creator can type through an intermediate
  /// state; [SubtitleEditorState.isValid] gates the save instead.
  void updateCueTiming(int index, {int? start, int? end}) =>
      _replaceCue(index, (cue) => cue.copyWith(start: start, end: end));

  /// Marks the cue at [index] as the one being worked on, or clears the
  /// selection when [index] is `null`.
  ///
  /// The preview seeks to the selected cue and the list highlights its row.
  /// Out-of-range indices clear the selection instead of pointing the editor at
  /// a cue that is not there.
  void selectCue(int? index) {
    if (isClosed) return;
    if (index == null || index < 0 || index >= state.cues.length) {
      if (state.selectedCueIndex == null) return;
      emit(state.copyWith(clearSelectedCue: true));
      return;
    }
    if (state.selectedCueIndex == index) return;
    emit(state.copyWith(selectedCueIndex: index));
  }

  /// Appends a blank cue after the last one and switches to editing.
  ///
  /// The new cue starts where the previous one ends and runs for
  /// [_newCueDurationMs], trimmed to the video's end when its duration is
  /// known. This is the entry point for authoring captions on a video that
  /// has none.
  ///
  /// Ignored while a save is in flight, and once the last cue already reaches
  /// the end of the video — the UI keeps the action disabled in that case, so
  /// this is the backstop rather than the message.
  void addCue() {
    if (_rejectsEdits || !state.canAddCue) return;
    final start = state.cues.isEmpty ? 0 : state.cues.last.end;
    final videoEndMs = state.videoDurationMs;
    var end = start + _newCueDurationMs;
    if (videoEndMs != null && end > videoEndMs) end = videoEndMs;

    emit(
      state.copyWith(
        status: SubtitleEditorStatus.ready,
        cues: [
          ...state.cues,
          EditableCue(start: start, end: end, text: ''),
        ],
        isDirty: true,
        // A blank cue is useless until it is written, so hand the creator the
        // new one rather than leaving the previous selection in place.
        selectedCueIndex: state.cues.length,
      ),
    );
  }

  /// Removes the cue at [index].
  ///
  /// Out-of-range indices are silently ignored, as are removals made while a
  /// save is in flight.
  void removeCue(int index) {
    if (_rejectsEdits) return;
    if (index < 0 || index >= state.cues.length) return;
    final updated = List<EditableCue>.from(state.cues)..removeAt(index);
    // Cues are addressed positionally, so removing one shifts every later
    // index down; without this the selection would silently point at the
    // cue's neighbour.
    final selected = state.selectedCueIndex;
    emit(
      state.copyWith(
        cues: updated,
        isDirty: true,
        clearSelectedCue: selected == null || selected == index,
        selectedCueIndex: selected != null && selected > index
            ? selected - 1
            : selected,
      ),
    );
  }

  void _replaceCue(int index, EditableCue Function(EditableCue cue) update) {
    if (_rejectsEdits) return;
    if (index < 0 || index >= state.cues.length) return;
    final updated = List<EditableCue>.from(state.cues);
    updated[index] = update(updated[index]);
    emit(state.copyWith(cues: updated, isDirty: true));
  }

  /// Publishes the current cues via the repository.
  ///
  /// Cues are published in timeline order — hand-edited timings can leave the
  /// list out of order, and VTT readers expect ascending cues.
  ///
  /// Emits [SubtitleEditorStatus.saving] then either:
  /// - [SubtitleEditorStatus.success] with `isDirty` reset to `false`.
  /// - [SubtitleEditorStatus.failure] and calls [addError] on any exception.
  Future<void> save() async {
    if (isClosed) return;
    emit(state.copyWith(status: SubtitleEditorStatus.saving));
    try {
      final ordered = List<EditableCue>.from(state.cues)
        ..sort((a, b) => a.start.compareTo(b.start));
      final updatedVideo = await _repository.publishEditedSubtitles(
        video: _video,
        cues: ordered.map((c) => c.toCue()).toList(),
        loadedRef: state.loadedTrackRef,
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          status: SubtitleEditorStatus.success,
          isDirty: false,
          updatedVideo: updatedVideo,
        ),
      );
    } catch (e, st) {
      if (isClosed) return;
      addError(e, st);
      emit(state.copyWith(status: SubtitleEditorStatus.failure));
    }
  }
}
