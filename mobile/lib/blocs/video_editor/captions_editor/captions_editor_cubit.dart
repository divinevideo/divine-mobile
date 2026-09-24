// ABOUTME: Screen-local cubit for the captions editor.
// ABOUTME: Runs caption generation and manages the editable cue list.

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/caption_style.dart';
import 'package:openvine/models/video_editor/caption_track.dart';
import 'package:openvine/services/video_editor/caption_generation_service.dart';
import 'package:openvine/services/video_editor/caption_remote_transcriber.dart';
import 'package:uuid/uuid.dart';

part 'captions_editor_state.dart';

/// Manages one captions editing session.
///
/// Created per captions-sheet visit (`showCaptionsEditorSheet`), like
/// `AudioTimingCubit`.
/// A fresh session (no `initialCues`) starts with caption generation; an
/// existing session starts ready with its cues.
class CaptionsEditorCubit extends Cubit<CaptionsEditorState> {
  /// Creates the cubit. Omitting [generationService] uses the production
  /// pipeline: server-side transcription through [blossomUploadService] when
  /// given, falling back to on-device recognition.
  CaptionsEditorCubit({
    required List<DivineVideoClip> clips,
    required Duration totalDuration,
    required String presetId,
    required String languageTag,
    bool burnIn = false,
    CaptionCustomStyle? customStyle,
    List<CaptionCue>? initialCues,
    BlossomUploadService? blossomUploadService,
    CaptionGenerationService? generationService,
  }) : _generationService =
           generationService ??
           CaptionGenerationService.production(
             remoteTranscriber: blossomUploadService != null
                 ? BlossomCaptionTranscriber(blossomUploadService)
                 : null,
           ),
       _clips = clips,
       _totalDuration = totalDuration,
       super(
         CaptionsEditorState(
           burnIn: burnIn,
           presetId: presetId,
           customStyle: customStyle,
           languageTag: languageTag,
           status: initialCues != null
               ? CaptionsEditorStatus.ready
               : CaptionsEditorStatus.generating,
           cues: initialCues ?? const [],
         ),
       );

  final CaptionGenerationService _generationService;
  final List<DivineVideoClip> _clips;
  final Duration _totalDuration;

  /// Default length of a manually added cue.
  static const Duration _newCueDuration = Duration(seconds: 2);

  static const _uuid = Uuid();

  /// Runs caption generation for a fresh session. No-op when the session
  /// started from existing cues.
  Future<void> initialize() async {
    if (state.status != CaptionsEditorStatus.generating) return;
    final CaptionGenerationOutcome outcome;
    try {
      outcome = await _generationService.generateForClips(
        clips: _clips,
        localeIdentifier: state.languageTag,
      );
    } catch (_) {
      // The service contract is "never throws", but this call is unawaited by
      // the sheet — guard so an unexpected escape lands on the manual-entry
      // fallback instead of stranding the editor on the loading state.
      if (isClosed) return;
      emit(
        state.copyWith(
          status: CaptionsEditorStatus.failed,
          failure: CaptionGenerationFailure.failed,
        ),
      );
      return;
    }
    if (isClosed) return;
    switch (outcome) {
      case CaptionsGenerated(:final cues):
        emit(
          state.copyWith(
            status: CaptionsEditorStatus.ready,
            cues: cues,
            clearFailure: true,
          ),
        );
      case CaptionsEmpty():
        emit(
          state.copyWith(
            status: CaptionsEditorStatus.empty,
            clearFailure: true,
          ),
        );
      case CaptionsFailed(:final reason):
        emit(
          state.copyWith(status: CaptionsEditorStatus.failed, failure: reason),
        );
    }
  }

  /// Switches to manual editing after [CaptionsEditorStatus.empty] or
  /// [CaptionsEditorStatus.failed], seeding one blank cue so an input field is
  /// ready to type into immediately.
  void startEmpty() {
    emit(
      state.copyWith(
        status: CaptionsEditorStatus.ready,
        cues: [_newCue(after: Duration.zero)],
        clearFailure: true,
      ),
    );
  }

  /// Replaces the text of the cue with [cueId].
  void updateCueText(String cueId, String text) {
    emit(
      state.copyWith(
        cues: [
          for (final cue in state.cues)
            if (cue.id == cueId) cue.copyWith(text: text) else cue,
        ],
      ),
    );
  }

  /// Applies a manually entered start/end time for [cueId].
  ///
  /// The edited edge is clamped so the cue keeps
  /// [VideoEditorConstants.minCaptionCueDuration] and stays inside the
  /// video. Cues may freely overlap each other.
  void updateCueTiming(String cueId, {Duration? start, Duration? end}) {
    final index = state.cues.indexWhere((cue) => cue.id == cueId);
    if (index == -1) return;
    final cue = state.cues[index];

    var newStart = cue.start;
    if (start != null) {
      var upper = cue.end - VideoEditorConstants.minCaptionCueDuration;
      if (upper < Duration.zero) upper = Duration.zero;
      newStart = _clampDuration(start, Duration.zero, upper);
    }
    var newEnd = cue.end;
    if (end != null) {
      var lower = newStart + VideoEditorConstants.minCaptionCueDuration;
      if (lower > _totalDuration) lower = _totalDuration;
      newEnd = _clampDuration(end, lower, _totalDuration);
    }
    if (newStart == cue.start && newEnd == cue.end) return;

    emit(
      state.copyWith(
        cues: [
          for (final other in state.cues)
            if (other.id == cueId)
              other.copyWith(start: newStart, end: newEnd)
            else
              other,
        ],
      ),
    );
  }

  static Duration _clampDuration(Duration value, Duration min, Duration max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  /// Removes the cue with [cueId].
  void removeCue(String cueId) {
    emit(
      state.copyWith(
        cues: [
          for (final cue in state.cues)
            if (cue.id != cueId) cue,
        ],
      ),
    );
  }

  /// Appends a new cue after the last one (or at the timeline start),
  /// clamped to the video duration. Near the video end it back-shifts over
  /// the previous cue — overlapping is allowed. Fine-tuning happens on the
  /// timeline.
  void addCue() {
    final lastEnd = state.cues.isEmpty ? Duration.zero : state.cues.last.end;
    emit(
      state.copyWith(
        status: CaptionsEditorStatus.ready,
        clearFailure: true,
        cues: [
          ...state.cues,
          _newCue(after: lastEnd),
        ],
      ),
    );
  }

  /// A blank cue spanning [_newCueDuration] starting at [after], back-shifted
  /// to stay inside the video near its end. Its id is a UUID so it never
  /// collides with cues from an earlier session after re-opening the sheet.
  CaptionCue _newCue({required Duration after}) {
    var start = after;
    var end = start + _newCueDuration;
    if (end > _totalDuration) {
      end = _totalDuration;
      start = end - _newCueDuration;
      if (start < Duration.zero) start = Duration.zero;
    }
    return CaptionCue(
      id: 'manual-${_uuid.v4()}',
      text: '',
      start: start,
      end: end,
    );
  }

  /// Selects a built-in style preset (burn-in mode), dropping any custom
  /// style.
  void setPreset(String presetId) {
    emit(state.copyWith(presetId: presetId, clearCustomStyle: true));
  }

  /// Applies a user-defined style (burn-in mode), taking precedence over the
  /// preset.
  void setCustomStyle(CaptionCustomStyle customStyle) {
    emit(state.copyWith(customStyle: customStyle));
  }

  /// Toggles burning the captions into the video (CC is always published).
  /// Cue text and timing survive; the commit handler materializes or removes
  /// the burned-in layers accordingly.
  void setBurnIn({required bool burnIn}) {
    emit(state.copyWith(burnIn: burnIn));
  }
}
