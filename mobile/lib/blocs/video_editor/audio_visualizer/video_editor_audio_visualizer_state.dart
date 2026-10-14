part of 'video_editor_audio_visualizer_cubit.dart';

/// Where the sound the audio visualizers of the preview follow stands.
enum VideoEditorAudioLevelStatus {
  /// No visualizer needs the sound yet.
  idle,

  /// The sound is being read.
  loading,

  /// [VideoEditorAudioVisualizerState.energies] follows what plays.
  ready,

  /// Nothing plays in the video, so the visualizers rest.
  noSound,

  /// The sound could not be read, so the visualizers rest.
  failed,
}

/// What plays in the video: the parts of sound the visualizers follow, on a
/// video ending at [videoEnd].
class VideoEditorAudioLevelInput extends Equatable {
  const VideoEditorAudioLevelInput({
    required this.parts,
    required this.videoEnd,
  });

  final List<AudioLevelPart> parts;
  final Duration videoEnd;

  @override
  List<Object?> get props => [parts, videoEnd];
}

class VideoEditorAudioVisualizerState extends Equatable {
  const VideoEditorAudioVisualizerState({
    this.status = VideoEditorAudioLevelStatus.idle,
    this.energies,
    this.input,
    this.timelineMap,
    this.isActive = false,
    this.isPreviewing = false,
  });

  final VideoEditorAudioLevelStatus status;

  /// The band energies of everything that plays, on the exported video; see
  /// [VideoEditorAudioLevelResolver.energiesOnOutput]. `null` until read, and
  /// a new list whenever what plays changes.
  final Float32List? energies;

  /// What plays in the video, as last synced.
  final VideoEditorAudioLevelInput? input;

  /// Maps the editor's timeline, which the playhead runs on, onto the
  /// exported video, which [energies] is timed on.
  final TransitionTimelineMap? timelineMap;

  /// Whether a visualizer is on the canvas, so the sound needs reading.
  final bool isActive;

  /// Whether the visualizer sheet previews the sound, which needs it read
  /// before a visualizer is on the canvas.
  final bool isPreviewing;

  /// Whether anything needs the sound read.
  bool get needsSound => isActive || isPreviewing;

  VideoEditorAudioVisualizerState copyWith({
    VideoEditorAudioLevelStatus? status,
    Float32List? energies,
    VideoEditorAudioLevelInput? input,
    TransitionTimelineMap? timelineMap,
    bool? isActive,
    bool? isPreviewing,
  }) => VideoEditorAudioVisualizerState(
    status: status ?? this.status,
    energies: energies ?? this.energies,
    input: input ?? this.input,
    timelineMap: timelineMap ?? this.timelineMap,
    isActive: isActive ?? this.isActive,
    isPreviewing: isPreviewing ?? this.isPreviewing,
  );

  @override
  List<Object?> get props => [
    status,
    energies,
    input,
    timelineMap,
    isActive,
    isPreviewing,
  ];
}
