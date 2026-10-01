part of 'video_editor_effects_cubit.dart';

/// State of the video effects (glitch, VHS, old film, …) in the editor.
class VideoEditorEffectsState extends Equatable {
  const VideoEditorEffectsState({
    this.applied = const [],
    this.isEditing = false,
    this.editingId,
    this.selectedType,
    this.intensity = VideoEditorEffectsCubit.defaultIntensity,
    this.startedPlayback = false,
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
  final VideoEffectType? selectedType;

  /// The intensity of [selectedType], from 0 to 1.
  final double intensity;

  /// Whether opening the editor started the video, which closing it should
  /// then pause again.
  final bool startedPlayback;

  /// The effect the open editor would commit, over the whole video, or `null`
  /// for none.
  VideoEffect? get selection => selectedType == null
      ? null
      : VideoEffect(type: selectedType!, intensity: intensity);

  /// What the preview shows, on the editor timeline.
  ///
  /// While editing, the selection takes the edited effect's place, or joins
  /// the others as a new one. It shows over the whole video, so the pick is
  /// visible wherever the playhead is. A flashing pick hides the other
  /// flashing effects, which would otherwise flash along with it while the
  /// video plays; confirming replaces them where they overlap anyway.
  List<VideoEffect> get previewEffects {
    final picked = isEditing ? selection : null;
    final hidesFlashing = picked != null && isFlashingVideoEffect(picked.type);
    final effects = <VideoEffect>[];
    var edited = false;
    for (final entry in applied) {
      if (isEditing && entry.id == editingId) {
        edited = true;
        if (picked != null) effects.add(picked);
      } else if (!hidesFlashing || !isFlashingVideoEffect(entry.effect.type)) {
        effects.add(entry.effect);
      }
    }
    if (!edited && picked != null) effects.add(picked);
    return effects;
  }

  VideoEditorEffectsState copyWith({
    List<EditorVideoEffect>? applied,
    bool? isEditing,
    String? editingId,
    bool clearEditingId = false,
    VideoEffectType? selectedType,
    bool clearSelectedType = false,
    double? intensity,
    bool? startedPlayback,
  }) {
    return VideoEditorEffectsState(
      applied: applied ?? this.applied,
      isEditing: isEditing ?? this.isEditing,
      editingId: clearEditingId ? null : (editingId ?? this.editingId),
      selectedType: clearSelectedType
          ? null
          : (selectedType ?? this.selectedType),
      intensity: intensity ?? this.intensity,
      startedPlayback: startedPlayback ?? this.startedPlayback,
    );
  }

  @override
  List<Object?> get props => [
    applied,
    isEditing,
    editingId,
    selectedType,
    intensity,
    startedPlayback,
  ];
}
