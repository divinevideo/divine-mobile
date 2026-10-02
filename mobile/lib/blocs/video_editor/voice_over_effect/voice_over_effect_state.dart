part of 'voice_over_effect_bloc.dart';

/// Where the voice-effect sheet is in its lifecycle.
enum VoiceOverEffectStatus {
  /// The creator is picking a setting.
  editing,

  /// The picked setting is being baked into the take.
  applying,

  /// Rendering or baking failed; the setting is kept so the creator can try
  /// again.
  failure,

  /// Finished: [VoiceOverEffectState.result] holds the processed track, or
  /// `null` when nothing had to change.
  done,
}

/// State of the voice-effect sheet for one voice-over [track].
class VoiceOverEffectState extends Equatable {
  /// Creates the state.
  const VoiceOverEffectState({
    required this.track,
    required this.effect,
    required this.noiseReduction,
    this.status = VoiceOverEffectStatus.editing,
    this.auditionPath,
    this.result,
  });

  /// The voice-over track as it is on the timeline.
  final AudioEvent track;

  /// The picked voice effect.
  final VoiceEffect effect;

  /// Whether noise reduction is picked.
  final bool noiseReduction;

  /// Lifecycle of the sheet.
  final VoiceOverEffectStatus status;

  /// The file looping as the audition of the setting heard last.
  final String? auditionPath;

  /// The processed track once [status] is [VoiceOverEffectStatus.done].
  final AudioEvent? result;

  /// Whether the picked setting is being baked into the take.
  bool get isApplying => status == VoiceOverEffectStatus.applying;

  /// The preset whose setting is picked, or `null` for a setting made with
  /// the sliders.
  VoiceOverEffectPreset? get preset => VoiceOverEffectPreset.matching(effect);

  /// Whether the pick differs from what [track] already plays.
  bool get hasChanges =>
      effect != track.voiceEffect || noiseReduction != track.noiseReduction;

  /// Creates a copy with the given fields replaced.
  VoiceOverEffectState copyWith({
    VoiceEffect? effect,
    bool? noiseReduction,
    VoiceOverEffectStatus? status,
    String? auditionPath,
    AudioEvent? result,
  }) {
    return VoiceOverEffectState(
      track: track,
      effect: effect ?? this.effect,
      noiseReduction: noiseReduction ?? this.noiseReduction,
      status: status ?? this.status,
      auditionPath: auditionPath ?? this.auditionPath,
      result: result ?? this.result,
    );
  }

  @override
  List<Object?> get props => [
    track,
    effect,
    noiseReduction,
    status,
    auditionPath,
    result,
  ];
}
