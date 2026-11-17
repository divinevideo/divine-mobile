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
    this.dropsSettings = const DropsEffectSettings(),
    this.onBeat = false,
    this.startedPlayback = false,
    this.beatInput,
    this.beats = const [],
    this.beatStatus = VideoEditorBeatStatus.idle,
    this.timelineEnd,
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

  /// How the drops look when [selectedType] is [EditorEffectType.drops].
  final DropsEffectSettings dropsSettings;

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

  /// Where the video ends and loops, on the editor timeline, which an outro
  /// is placed against; `null` before the editor said.
  final Duration? timelineEnd;

  /// Whether the picked effect fires on the beat.
  bool get selectionOnBeat =>
      onBeat && selectedType != null && selectedType!.supportsOnBeat;

  /// The effect the open editor would commit, or `null` for none.
  ///
  /// It lies over the whole video, except for an intro or an outro, which
  /// only plays out right over its own window: that is the edited effect's
  /// while it was an intro or an outro of the same kind, and otherwise where
  /// a new one goes (see [defaultVideoEffectWindow]).
  EditorVideoEffect? get selection {
    final type = selectedType;
    if (type == null) return null;
    final window = _selectionWindow(type);
    return EditorVideoEffect.of(
      id: editingId ?? _pickedId,
      type: type,
      intensity: intensity,
      startTime: window.startTime,
      endTime: window.endTime,
      onBeat: selectionOnBeat,
      settings: settingsFor(type),
    );
  }

  ({Duration? startTime, Duration? endTime}) _selectionWindow(
    EditorEffectType type,
  ) {
    if (!type.isIntroOutro) return (startTime: null, endTime: null);
    final edited = applied.where((e) => e.id == editingId).firstOrNull;
    if (edited != null && edited.type.placement == type.placement) {
      return (startTime: edited.startTime, endTime: edited.endTime);
    }
    return defaultVideoEffectWindow(type, timelineEnd: timelineEnd);
  }

  /// Where the preview jumps to when an intro or outro is picked, so it
  /// shows right away, or `null` for an effect over the whole video.
  ///
  /// A [playing] video jumps to the start of an intro, and a second before an
  /// outro, so the outro is seen closing over the video. A paused one jumps
  /// to the middle of its window, the one frame that shows what it does.
  Duration? introOutroPreviewPosition({required bool playing}) {
    final picked = isEditing ? selection : null;
    if (picked == null || !picked.type.isIntroOutro) return null;
    final start = picked.startTime ?? Duration.zero;
    if (!playing) {
      final end = picked.endTime ?? timelineEnd ?? start;
      return end > start ? start + (end - start) ~/ 2 : start;
    }
    if (picked.type.placement == EditorEffectPlacement.opening) return start;
    final leadIn = start - introOutroEffectDuration;
    return leadIn.isNegative ? Duration.zero : leadIn;
  }

  /// The settings a picked effect of [type] stores next to its intensity.
  Map<String, Object> settingsFor(EditorEffectType type) =>
      type == EditorEffectType.drops ? dropsSettings.toParams() : const {};

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
  /// [previewEffects], except a picked intro or outro, which shows over its
  /// own window (see [selection]): the native player draws these.
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
    DropsEffectSettings? dropsSettings,
    bool? onBeat,
    bool? startedPlayback,
    VideoEditorBeatInput? beatInput,
    List<Duration>? beats,
    VideoEditorBeatStatus? beatStatus,
    Duration? timelineEnd,
  }) {
    return VideoEditorEffectsState(
      applied: applied ?? this.applied,
      isEditing: isEditing ?? this.isEditing,
      editingId: clearEditingId ? null : (editingId ?? this.editingId),
      selectedType: clearSelectedType
          ? null
          : (selectedType ?? this.selectedType),
      intensity: intensity ?? this.intensity,
      dropsSettings: dropsSettings ?? this.dropsSettings,
      onBeat: onBeat ?? this.onBeat,
      startedPlayback: startedPlayback ?? this.startedPlayback,
      beatInput: beatInput ?? this.beatInput,
      beats: beats ?? this.beats,
      beatStatus: beatStatus ?? this.beatStatus,
      timelineEnd: timelineEnd ?? this.timelineEnd,
    );
  }

  @override
  List<Object?> get props => [
    applied,
    isEditing,
    editingId,
    selectedType,
    intensity,
    dropsSettings,
    onBeat,
    startedPlayback,
    beatInput,
    beats,
    beatStatus,
    timelineEnd,
  ];
}
