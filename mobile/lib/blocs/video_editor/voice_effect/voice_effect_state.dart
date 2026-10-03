part of 'voice_effect_bloc.dart';

/// Where the voice-effect sheet is in its lifecycle.
enum VoiceEffectStatus {
  /// The creator is picking a setting.
  editing,

  /// The picked setting is being baked into the sound.
  applying,

  /// Rendering or baking failed; the setting is kept so the creator can try
  /// again.
  failure,

  /// Finished: [VoiceEffectState.result] holds the processed track, or
  /// `null` when nothing had to change.
  done,
}

/// State of the voice-effect sheet for one timeline sound, [track].
class VoiceEffectState extends Equatable {
  /// Creates the state.
  const VoiceEffectState({
    required this.track,
    required this.effect,
    required this.noiseReduction,
    this.status = VoiceEffectStatus.editing,
    this.auditionPath,
    this.result,
  });

  /// The sound as it is on the timeline.
  final AudioEvent track;

  /// The picked voice effect.
  final VoiceEffect effect;

  /// Whether noise reduction is picked.
  final bool noiseReduction;

  /// Lifecycle of the sheet.
  final VoiceEffectStatus status;

  /// The file or address looping as the audition of the setting heard last.
  final String? auditionPath;

  /// The processed track once [status] is [VoiceEffectStatus.done].
  final AudioEvent? result;

  /// Whether the picked setting is being baked into the sound.
  bool get isApplying => status == VoiceEffectStatus.applying;

  /// The preset whose setting is picked, or `null` for a setting made with
  /// the sliders.
  VoiceEffectPreset? get preset => VoiceEffectPreset.matching(effect);

  /// Whether the pick differs from what [track] already plays.
  bool get hasChanges =>
      effect != track.voiceEffect || noiseReduction != track.noiseReduction;

  /// Creates a copy with the given fields replaced.
  VoiceEffectState copyWith({
    VoiceEffect? effect,
    bool? noiseReduction,
    VoiceEffectStatus? status,
    String? auditionPath,
    AudioEvent? result,
  }) {
    return VoiceEffectState(
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
