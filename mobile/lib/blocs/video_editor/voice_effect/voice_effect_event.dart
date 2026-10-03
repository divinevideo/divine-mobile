part of 'voice_over_effect_bloc.dart';

/// Events of the [VoiceOverEffectBloc].
sealed class VoiceOverEffectEvent extends Equatable {
  const VoiceOverEffectEvent();

  @override
  List<Object?> get props => [];
}

/// The creator changed the setting, or the sheet opened (no fields) and the
/// current one should be heard.
///
/// Fields left `null` keep their value. With [audition] set the new setting
/// is rendered and looped; a slider sends its moves without it and only the
/// final position with it, so the take is not rendered for every step.
final class VoiceOverEffectSettingsChanged extends VoiceOverEffectEvent {
  const VoiceOverEffectSettingsChanged({
    this.effect,
    this.noiseReduction,
    this.audition = true,
  });

  final VoiceEffect? effect;
  final bool? noiseReduction;
  final bool audition;

  @override
  List<Object?> get props => [effect, noiseReduction, audition];
}

/// The creator confirmed the setting: bake it into the take.
final class VoiceOverEffectApplyRequested extends VoiceOverEffectEvent {
  const VoiceOverEffectApplyRequested();
}
