part of 'chroma_key_editor_cubit.dart';

/// Where the auto-detect measurement stands.
enum ChromaKeyDetectionStatus {
  /// No measurement has been asked for, or the last one already landed.
  idle,

  /// A measurement is running.
  detecting,

  /// The last measurement found no usable screen.
  ///
  /// The most common cause is a screen that does not reach the frame border —
  /// only a ring around the edge is sampled, which is what lets the subject be
  /// ignored. The key is left untouched so the user can set it by hand.
  failure,
}

class ChromaKeyEditorState extends Equatable {
  const ChromaKeyEditorState({
    required this.chromaKey,
    this.detectionStatus = ChromaKeyDetectionStatus.idle,
  });

  /// The key as currently configured. Drives the live preview and is what the
  /// screen returns on confirm.
  final ClipChromaKey chromaKey;

  final ChromaKeyDetectionStatus detectionStatus;

  /// Which background the keyed area is filled with.
  ClipChromaKeyBackgroundType get backgroundType => chromaKey.backgroundType;

  /// Whether a measurement is in flight whose result is still wanted.
  ///
  /// Only Auto-detect is disabled while one runs, so a second tap cannot
  /// start a second decode. Everything else stays live: setting the colour or
  /// amount by hand, or picking a preset, writes the measurement off and takes
  /// this back to `false`, and its result is dropped when it lands rather than
  /// overwriting that edit. The written-off decode is still executing when
  /// Auto-detect comes back that way, so a re-tap can start another one; the
  /// cubit keeps only the newest measurement's result.
  bool get isDetecting => detectionStatus == ChromaKeyDetectionStatus.detecting;

  ChromaKeyEditorState copyWith({
    ClipChromaKey? chromaKey,
    ChromaKeyDetectionStatus? detectionStatus,
  }) {
    return ChromaKeyEditorState(
      chromaKey: chromaKey ?? this.chromaKey,
      detectionStatus: detectionStatus ?? this.detectionStatus,
    );
  }

  @override
  List<Object?> get props => [chromaKey, detectionStatus];
}
