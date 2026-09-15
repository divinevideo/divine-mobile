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

  /// The last measurement did not return within
  /// [VideoEditorConstants.chromaKeyDetectTimeout].
  ///
  /// Says nothing about the footage — the decode stalled. Kept apart from
  /// [failure] so the UI does not tell the user their screen is wrong when it
  /// never got looked at. The key is left untouched, as for [failure].
  timedOut,
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
  /// While this is true the key on screen is still the automatic guess with a
  /// better one on its way, so two controls wait on it: Auto-detect, so a
  /// second tap cannot start a second decode, and Done, so the guess is not
  /// baked seconds before the measurement replaces it (#8904). Everything
  /// else stays live: setting the colour or amount by hand, or picking a
  /// preset, writes the measurement off and takes this back to `false` — Done
  /// with it — and its result is dropped when it lands rather than overwriting
  /// that edit. The written-off decode is still executing when Auto-detect
  /// comes back that way, so a re-tap can start another one; the cubit keeps
  /// only the newest measurement's result. A decode that never returns is
  /// bounded by [VideoEditorConstants.chromaKeyDetectTimeout], so Done cannot
  /// stay held for good.
  bool get isDetecting => detectionStatus == ChromaKeyDetectionStatus.detecting;

  /// Whether the last measurement ended without a result, for either reason.
  bool get detectionFailed => switch (detectionStatus) {
    ChromaKeyDetectionStatus.failure ||
    ChromaKeyDetectionStatus.timedOut => true,
    ChromaKeyDetectionStatus.idle ||
    ChromaKeyDetectionStatus.detecting => false,
  };

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
