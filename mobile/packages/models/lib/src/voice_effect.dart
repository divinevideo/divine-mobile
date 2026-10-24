// ABOUTME: How a recorded voice-over take is changed: its pitch, how robotic
// ABOUTME: it sounds, how much it echoes and reverberates, and what it plays
// ABOUTME: through, in combinable steps.

import 'package:meta/meta.dart';

/// What a voice is played through, which narrows or muffles it.
enum VoiceFilter {
  /// Nothing: the voice as it is.
  none,

  /// A phone line or an old radio: thin and a little gritty.
  telephone,

  /// A handheld loudspeaker: narrow, honky and distorted.
  megaphone,

  /// Water: muffled, with a gently drifting pitch.
  underwater,
}

/// How a recorded voice-over take is changed.
///
/// The changes combine — a deep robot with an echo is one value — and [none]
/// is the voice as recorded. Each amount is a whole number and the [filter]
/// one of a few, so a value persists exactly and names the file it was
/// rendered into.
@immutable
class VoiceEffect {
  /// Creates a voice effect, clamping every amount to its range.
  const VoiceEffect({
    int pitch = 0,
    int robot = 0,
    int echo = 0,
    int reverb = 0,
    this.filter = VoiceFilter.none,
  }) : pitch = pitch < minPitch
           ? minPitch
           : (pitch > maxPitch ? maxPitch : pitch),
       robot = robot < 0 ? 0 : (robot > maxAmount ? maxAmount : robot),
       echo = echo < 0 ? 0 : (echo > maxAmount ? maxAmount : echo),
       reverb = reverb < 0 ? 0 : (reverb > maxAmount ? maxAmount : reverb);

  /// Reads a value [toJson] wrote. Missing changes, and a filter this version
  /// does not know, are none.
  factory VoiceEffect.fromJson(Map<String, dynamic> json) => VoiceEffect(
    pitch: (json['pitch'] as num?)?.round() ?? 0,
    robot: (json['robot'] as num?)?.round() ?? 0,
    echo: (json['echo'] as num?)?.round() ?? 0,
    reverb: (json['reverb'] as num?)?.round() ?? 0,
    filter: VoiceFilter.values.asNameMap()[json['filter']] ?? VoiceFilter.none,
  );

  /// The voice as recorded.
  static const none = VoiceEffect();

  /// Lowest [pitch], an octave down.
  static const minPitch = -12;

  /// Highest [pitch], an octave up.
  static const maxPitch = 12;

  /// Highest [robot], [echo] and [reverb].
  static const maxAmount = 100;

  /// Semitones the voice moves, from [minPitch] to [maxPitch].
  final int pitch;

  /// How much of a monotone robot replaces the voice, in percent.
  final int robot;

  /// How strongly the voice echoes, in percent.
  final int echo;

  /// How much the voice sounds as if it was in a room or a hall, in percent.
  final int reverb;

  /// What the voice is played through.
  final VoiceFilter filter;

  /// Whether this leaves the voice as recorded.
  bool get isNone =>
      pitch == 0 &&
      robot == 0 &&
      echo == 0 &&
      reverb == 0 &&
      filter == VoiceFilter.none;

  /// Creates a copy with the given changes replaced.
  VoiceEffect copyWith({
    int? pitch,
    int? robot,
    int? echo,
    int? reverb,
    VoiceFilter? filter,
  }) => VoiceEffect(
    pitch: pitch ?? this.pitch,
    robot: robot ?? this.robot,
    echo: echo ?? this.echo,
    reverb: reverb ?? this.reverb,
    filter: filter ?? this.filter,
  );

  /// The changes that are not none.
  Map<String, dynamic> toJson() => {
    if (pitch != 0) 'pitch': pitch,
    if (robot != 0) 'robot': robot,
    if (echo != 0) 'echo': echo,
    if (reverb != 0) 'reverb': reverb,
    if (filter != VoiceFilter.none) 'filter': filter.name,
  };

  @override
  bool operator ==(Object other) =>
      other is VoiceEffect &&
      other.pitch == pitch &&
      other.robot == robot &&
      other.echo == echo &&
      other.reverb == reverb &&
      other.filter == filter;

  @override
  int get hashCode => Object.hash(pitch, robot, echo, reverb, filter);

  @override
  String toString() =>
      'VoiceEffect(pitch: $pitch, robot: $robot, echo: $echo, '
      'reverb: $reverb, filter: ${filter.name})';
}
