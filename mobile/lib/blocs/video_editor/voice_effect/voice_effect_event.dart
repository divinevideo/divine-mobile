part of 'voice_effect_bloc.dart';

/// Events of the [VoiceEffectBloc].
sealed class VoiceEffectEvent extends Equatable {
  const VoiceEffectEvent();

  @override
  List<Object?> get props => [];
}

/// The creator changed the setting, or the sheet opened (no fields) and the
/// current one should be heard.
///
/// A [preset] picks its setting and its speed — a preset without a speed of
/// its own the speed [VoiceEffectState.speedWithoutPreset] — and [effect] is
/// then ignored. Any other field left `null` keeps its value, and so does the
/// speed. With [audition] set the new setting is rendered and looped; a slider
/// sends its moves without it and only the final position with it, so the
/// sound is not rendered for every step.
final class VoiceEffectSettingsChanged extends VoiceEffectEvent {
  const VoiceEffectSettingsChanged({
    this.preset,
    this.effect,
    this.noiseReduction,
    this.audition = true,
  });

  final VoiceEffectPreset? preset;
  final VoiceEffect? effect;
  final bool? noiseReduction;
  final bool audition;

  @override
  List<Object?> get props => [preset, effect, noiseReduction, audition];
}

/// The creator confirmed the setting: bake it into the sound.
final class VoiceEffectApplyRequested extends VoiceEffectEvent {
  const VoiceEffectApplyRequested();
}
