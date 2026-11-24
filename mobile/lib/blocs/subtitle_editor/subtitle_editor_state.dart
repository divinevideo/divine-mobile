part of 'subtitle_editor_cubit.dart';

/// Loading and editing status for the subtitle editor.
enum SubtitleEditorStatus {
  /// Initial cue-load is in progress.
  loading,

  /// Auto-transcription is still running; polling is expected.
  processing,

  /// Auto-transcription finished but found nothing to transcribe.
  empty,

  /// No subtitle track could be reached for this video.
  unavailable,

  /// Cues are loaded and ready to edit.
  ready,

  /// Edited cues are being published.
  saving,

  /// Publish completed successfully.
  success,

  /// An operation failed; check [addError] for details.
  failure,
}

/// A single subtitle cue the creator can edit — text and timing alike.
class EditableCue extends Equatable {
  /// Creates an editable cue.
  const EditableCue({
    required this.start,
    required this.end,
    required this.text,
  });

  /// Converts a [SubtitleCue] to an [EditableCue].
  factory EditableCue.fromCue(SubtitleCue cue) =>
      EditableCue(start: cue.start, end: cue.end, text: cue.text);

  /// Start time in milliseconds.
  final int start;

  /// End time in milliseconds.
  final int end;

  /// The subtitle text content.
  final String text;

  /// Converts back to a [SubtitleCue] for publishing.
  SubtitleCue toCue() => SubtitleCue(start: start, end: end, text: text);

  /// Returns a copy with the given fields replaced.
  EditableCue copyWith({int? start, int? end, String? text}) => EditableCue(
    start: start ?? this.start,
    end: end ?? this.end,
    text: text ?? this.text,
  );

  /// Whether this cue can be published: it says something, and it ends after
  /// it starts.
  bool get isValid => text.trim().isNotEmpty && end > start;

  /// `M:SS` label derived from [start] for display purposes.
  String get timestampLabel {
    final totalSeconds = start ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  List<Object?> get props => [start, end, text];
}

/// State for [SubtitleEditorCubit].
class SubtitleEditorState extends Equatable {
  /// Creates the initial state.
  const SubtitleEditorState({
    this.status = SubtitleEditorStatus.loading,
    this.cues = const [],
    this.isDirty = false,
    this.updatedVideo,
    this.videoDurationMs,
    this.selectedCueIndex,
    this.loadedTrackRef,
  });

  /// Timeline room left past the last cue when the video length is unknown.
  ///
  /// Without a declared duration the axis would end exactly on the last cue,
  /// leaving no space to drag it later or stretch it longer.
  static const _unknownDurationHeadroomMs = 2000;

  /// Current editor status.
  final SubtitleEditorStatus status;

  /// The editable cues loaded from the subtitle track.
  final List<EditableCue> cues;

  /// Whether [cues] have been modified since the last save or load.
  final bool isDirty;

  /// Updated video event returned after a successful subtitle republish.
  final VideoEvent? updatedVideo;

  /// How long the video runs, in milliseconds, when the event declares it.
  ///
  /// `null` means unknown, in which case cue timings are not bounded.
  final int? videoDurationMs;

  /// Index into [cues] of the cue the creator is working on, or `null` when
  /// none is selected.
  ///
  /// Drives which cue the preview seeks to and which row the list highlights.
  final int? selectedCueIndex;

  /// The `text-track` reference [cues] were loaded from, or `null` when they
  /// came from somewhere else or were written from scratch. A save replaces
  /// that track, which can be a fallback in another language.
  final String? loadedTrackRef;

  /// Whether [cues] can be published as they stand.
  bool get isValid => cues.isNotEmpty && cues.every((cue) => cue.isValid);

  /// Length of the timeline axis in milliseconds.
  ///
  /// The video's own duration when it declares one, stretched to cover a cue
  /// that already runs past it so no line ends up off the axis. Without a
  /// declared duration the axis is derived from the cues themselves.
  int get timelineDurationMs {
    final lastEnd = cues.isEmpty
        ? 0
        : cues.map((cue) => cue.end).reduce((a, b) => a > b ? a : b);
    final declared = videoDurationMs;
    if (declared != null && declared > 0) {
      return declared > lastEnd ? declared : lastEnd;
    }
    return lastEnd + _unknownDurationHeadroomMs;
  }

  /// The selected cue, or `null` when the selection is unset or stale.
  EditableCue? get selectedCue {
    final index = selectedCueIndex;
    if (index == null || index < 0 || index >= cues.length) return null;
    return cues[index];
  }

  /// Whether there is room in the video for another cue.
  ///
  /// A cue past the end of the video would never be shown, so once the last
  /// one reaches the end there is nothing left to caption.
  bool get canAddCue {
    final durationMs = videoDurationMs;
    if (durationMs == null || durationMs <= 0 || cues.isEmpty) return true;
    return cues.last.end < durationMs;
  }

  /// Returns a copy with selected fields replaced.
  ///
  /// Pass [clearSelectedCue] to drop the selection, or
  /// [clearLoadedTrackRef] to drop the loaded track, which `null` cannot
  /// express.
  SubtitleEditorState copyWith({
    SubtitleEditorStatus? status,
    List<EditableCue>? cues,
    bool? isDirty,
    VideoEvent? updatedVideo,
    int? videoDurationMs,
    int? selectedCueIndex,
    bool clearSelectedCue = false,
    String? loadedTrackRef,
    bool clearLoadedTrackRef = false,
  }) {
    return SubtitleEditorState(
      status: status ?? this.status,
      cues: cues ?? this.cues,
      isDirty: isDirty ?? this.isDirty,
      updatedVideo: updatedVideo ?? this.updatedVideo,
      videoDurationMs: videoDurationMs ?? this.videoDurationMs,
      selectedCueIndex: clearSelectedCue
          ? null
          : (selectedCueIndex ?? this.selectedCueIndex),
      loadedTrackRef: clearLoadedTrackRef
          ? null
          : (loadedTrackRef ?? this.loadedTrackRef),
    );
  }

  @override
  List<Object?> get props => [
    status,
    cues,
    isDirty,
    updatedVideo,
    videoDurationMs,
    selectedCueIndex,
    loadedTrackRef,
  ];
}
