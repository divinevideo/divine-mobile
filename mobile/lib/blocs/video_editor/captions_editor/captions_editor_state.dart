// ABOUTME: State for the captions editor screen.
// ABOUTME: Holds status, burn-in flag, preset, language, and the cue list.

part of 'captions_editor_cubit.dart';

/// Lifecycle of the captions editor session.
enum CaptionsEditorStatus {
  /// Transcription is running.
  generating,

  /// Cues are editable (possibly an empty list the user fills manually).
  ready,

  /// Generation finished without recognizing any speech.
  empty,

  /// Generation failed; `failure` carries the reason.
  failed,
}

/// State of the captions editor screen.
class CaptionsEditorState extends Equatable {
  /// Creates the state.
  const CaptionsEditorState({
    required this.presetId,
    required this.languageTag,
    this.burnIn = false,
    this.customStyle,
    this.status = CaptionsEditorStatus.generating,
    this.failure,
    this.cues = const [],
  });

  /// Current lifecycle status.
  final CaptionsEditorStatus status;

  /// Why generation failed; only set for [CaptionsEditorStatus.failed].
  final CaptionGenerationFailure? failure;

  /// Whether captions are additionally burned into the video (CC is always
  /// published either way).
  final bool burnIn;

  /// The built-in style preset id (burn-in only, when [customStyle] is null).
  final String presetId;

  /// The user-defined style, taking precedence over [presetId] when set.
  final CaptionCustomStyle? customStyle;

  /// BCP-47 recognition/caption language.
  final String languageTag;

  /// The editable cues, in edit order (free timing edits can reorder them; see
  /// [committedCues] for the start-sorted commit view).
  final List<CaptionCue> cues;

  /// Whether a custom style is active (vs a built-in preset).
  bool get hasCustomStyle => customStyle != null;

  /// The caption track this session produces on confirm. Cues are always the
  /// source of truth; [CaptionTrack.burnIn] adds the burned-in render.
  CaptionTrack get track => CaptionTrack(
    burnIn: burnIn,
    presetId: presetId,
    customStyle: customStyle,
    languageTag: languageTag,
    cues: cues,
  );

  /// The cues committed on confirm: cues whose text was cleared are dropped
  /// (they render as nothing and would only clutter the timeline and VTT), and
  /// the remainder is sorted by start time — free timing edits can reorder
  /// cues, but everything downstream (timeline, VTT) expects timeline order.
  List<CaptionCue> get committedCues => [
    for (final cue in cues)
      if (cue.text.trim().isNotEmpty) cue,
  ]..sort((a, b) => a.start.compareTo(b.start));

  /// The caption track committed on confirm — [track] carrying only the
  /// normalized [committedCues].
  CaptionTrack get committedTrack => track.copyWith(cues: committedCues);

  /// Copy with the given fields replaced. Pass [clearCustomStyle] to drop a
  /// custom style (selecting a built-in preset again), and [clearFailure] when
  /// leaving a failed state.
  CaptionsEditorState copyWith({
    CaptionsEditorStatus? status,
    CaptionGenerationFailure? failure,
    bool? burnIn,
    String? presetId,
    CaptionCustomStyle? customStyle,
    bool clearCustomStyle = false,
    bool clearFailure = false,
    List<CaptionCue>? cues,
  }) => CaptionsEditorState(
    status: status ?? this.status,
    failure: clearFailure ? null : (failure ?? this.failure),
    burnIn: burnIn ?? this.burnIn,
    presetId: presetId ?? this.presetId,
    customStyle: clearCustomStyle ? null : (customStyle ?? this.customStyle),
    languageTag: languageTag,
    cues: cues ?? this.cues,
  );

  @override
  List<Object?> get props => [
    status,
    failure,
    burnIn,
    presetId,
    customStyle,
    languageTag,
    cues,
  ];
}
