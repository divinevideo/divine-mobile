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
    required this.playbackSpeed,
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

  /// The speed the sound plays at with the pick: [track]'s own, unless a
  /// preset with a speed of its own is picked.
  final double playbackSpeed;

  /// Lifecycle of the sheet.
  final VoiceEffectStatus status;

  /// The file or address looping as the audition of the setting heard last.
  final String? auditionPath;

  /// The processed track once [status] is [VoiceEffectStatus.done].
  final AudioEvent? result;

  /// Whether the picked setting is being baked into the sound.
  bool get isApplying => status == VoiceEffectStatus.applying;

  /// The preset to show as picked: the one whose setting and speed are
  /// picked, else the one whose filter the setting keeps, since no slider
  /// shows a filter; `null` for any other setting made with the sliders.
  VoiceEffectPreset? get preset =>
      VoiceEffectPreset.matching(effect, playbackSpeed: playbackSpeed) ??
      switch (effect.filter) {
        VoiceFilter.none => null,
        VoiceFilter.telephone => VoiceEffectPreset.telephone,
        VoiceFilter.megaphone => VoiceEffectPreset.megaphone,
        VoiceFilter.underwater => VoiceEffectPreset.underwater,
      };

  /// The speed a preset without a speed of its own plays the sound at:
  /// [track]'s, unless [track] already plays a preset's speed, which picking
  /// another preset undoes.
  double get speedWithoutPreset {
    final current = VoiceEffectPreset.matching(
      track.voiceEffect,
      playbackSpeed: track.playbackSpeed,
    );
    return current?.playbackSpeed == null ? track.playbackSpeed : 1;
  }

  /// Whether the sound keeps playing along [track]'s speed ramp: no preset
  /// picked a speed of its own.
  bool get keepsSpeedRamp =>
      track.speedRamp != null && playbackSpeed == track.playbackSpeed;

  /// Whether the pick differs from what [track] already plays.
  bool get hasChanges =>
      effect != track.voiceEffect ||
      noiseReduction != track.noiseReduction ||
      playbackSpeed != track.playbackSpeed;

  /// Creates a copy with the given fields replaced.
  VoiceEffectState copyWith({
    VoiceEffect? effect,
    bool? noiseReduction,
    double? playbackSpeed,
    VoiceEffectStatus? status,
    String? auditionPath,
    AudioEvent? result,
  }) {
    return VoiceEffectState(
      track: track,
      effect: effect ?? this.effect,
      noiseReduction: noiseReduction ?? this.noiseReduction,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
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
    playbackSpeed,
    status,
    auditionPath,
    result,
  ];
}
