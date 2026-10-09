part of 'video_editor_effects_cubit.dart';

/// Where the beats for effects on the beat stand.
enum VideoEditorBeatStatus {
  /// No effect fires on the beat, so the beats were not looked for.
  idle,

  /// The beats are being read from the music.
  loading,

  /// The beats are read; [VideoEditorEffectsState.beats] is empty when the
  /// music has no steady beat.
  ready,

  /// Nothing plays that could give a beat: no music, and every clip muted.
  noSound,

  /// The music could not be read.
  failed,
}

/// What the beats of the video come from, and how they land on it.
class VideoEditorBeatInput extends Equatable {
  const VideoEditorBeatInput({
    required this.parts,
    required this.videoEnd,
  });

  /// The stretches of music, or of the clips' own sound, the beats are read
  /// from.
  final List<BeatSourcePart> parts;

  /// Where the exported video ends and loops.
  final Duration videoEnd;

  @override
  List<Object?> get props => [parts, videoEnd];
}

/// State of the video effects (glitch, VHS, old film, …) in the editor.
class VideoEditorEffectsState extends Equatable {
  const VideoEditorEffectsState({
    this.applied = const [],
    this.isEditing = false,
    this.editingId,
    this.selectedType,
    this.intensity = VideoEditorEffectsCubit.defaultIntensity,
    this.onBeat = false,
    this.startedPlayback = false,
    this.beatInput,
    this.beats = const [],
    this.beatStatus = VideoEditorBeatStatus.idle,
  });

  /// The effects committed to the editor history, in the order they combine,
  /// which the preview shows and the export renders.
  final List<EditorVideoEffect> applied;

  /// Whether the effects editor is open.
  final bool isEditing;

  /// The committed effect the open editor changes, or `null` when it adds a
  /// new one.
  final String? editingId;

  /// The effect picked in the open editor, or `null` for none.
  final EditorEffectType? selectedType;

  /// The intensity of [selectedType], from 0 to 1.
  final double intensity;

  /// Whether the picked effect fires on the beat; only applies when
  /// [selectedType] [EditorEffectType.supportsOnBeat].
  final bool onBeat;

  /// Whether opening the editor started the video, which closing it should
  /// then pause again.
  final bool startedPlayback;

  /// What the beats come from, or `null` before the editor said.
  final VideoEditorBeatInput? beatInput;

  /// The beats of the video's music on the exported video, in order.
  final List<Duration> beats;

  /// Where finding [beats] stands.
  final VideoEditorBeatStatus beatStatus;

  /// Whether the picked effect fires on the beat.
  bool get selectionOnBeat =>
      onBeat && selectedType != null && selectedType!.supportsOnBeat;

  /// The effect the open editor would commit, over the whole video, or `null`
  /// for none.
  EditorVideoEffect? get selection => selectedType == null
      ? null
      : EditorVideoEffect.of(
          id: editingId ?? _pickedId,
          type: selectedType!,
          intensity: intensity,
          onBeat: selectionOnBeat,
        );

  /// Whether any effect, committed or picked, fires on the beat, so the beats
  /// are needed.
  bool get needsBeats =>
      applied.any((entry) => entry.onBeat) || (isEditing && selectionOnBeat);

  /// What the preview shows, on the editor timeline.
  ///
  /// While editing, the selection takes the edited effect's place, or joins
  /// the others as a new one. It shows over the whole video, so the pick is
  /// visible wherever the playhead is. A flashing pick hides the other
  /// flashing effects, which would otherwise flash along with it while the
  /// video plays; confirming replaces them where they overlap anyway.
  ///
  /// Only built-in effects: `VideoEffectPreview` cannot show a custom one,
  /// which [previewCustomEffects] hands to the native player instead.
  List<EditorVideoEffect> get previewEffects {
    final selection = isEditing ? this.selection : null;
    final picked = selection?.effect == null ? null : selection;
    final hidesFlashing = picked != null && picked.type.isFlashing;
    final effects = <EditorVideoEffect>[];
    var edited = false;
    for (final entry in applied) {
      if (isEditing && entry.id == editingId) {
        edited = true;
        if (picked != null) effects.add(picked);
      } else if (entry.effect != null &&
          (!hidesFlashing || !entry.type.isFlashing)) {
        effects.add(entry);
      }
    }
    if (!edited && picked != null) effects.add(picked);
    return effects;
  }

  /// The effects Divine renders itself that the preview shows, placed like
  /// [previewEffects]: the native player draws these.
  List<CustomVideoEffect> get previewCustomEffects {
    final picked = isEditing ? selection?.custom : null;
    final effects = <CustomVideoEffect>[];
    var edited = false;
    for (final entry in applied) {
      if (isEditing && entry.id == editingId) {
        edited = true;
        if (picked != null) effects.add(picked);
      } else if (entry.custom case final custom?) {
        effects.add(custom);
      }
    }
    if (!edited && picked != null) effects.add(picked);
    return effects;
  }

  /// The id the preview gives a new effect while it is picked.
  static const _pickedId = 'picked';

  VideoEditorEffectsState copyWith({
    List<EditorVideoEffect>? applied,
    bool? isEditing,
    String? editingId,
    bool clearEditingId = false,
    EditorEffectType? selectedType,
    bool clearSelectedType = false,
    double? intensity,
    bool? onBeat,
    bool? startedPlayback,
    VideoEditorBeatInput? beatInput,
    List<Duration>? beats,
    VideoEditorBeatStatus? beatStatus,
  }) {
    return VideoEditorEffectsState(
      applied: applied ?? this.applied,
      isEditing: isEditing ?? this.isEditing,
      editingId: clearEditingId ? null : (editingId ?? this.editingId),
      selectedType: clearSelectedType
          ? null
          : (selectedType ?? this.selectedType),
      intensity: intensity ?? this.intensity,
      onBeat: onBeat ?? this.onBeat,
      startedPlayback: startedPlayback ?? this.startedPlayback,
      beatInput: beatInput ?? this.beatInput,
      beats: beats ?? this.beats,
      beatStatus: beatStatus ?? this.beatStatus,
    );
  }

  @override
  List<Object?> get props => [
    applied,
    isEditing,
    editingId,
    selectedType,
    intensity,
    onBeat,
    startedPlayback,
    beatInput,
    beats,
    beatStatus,
  ];
}
