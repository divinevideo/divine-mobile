// ABOUTME: How a recorded voice-over take is changed: its pitch, how robotic
// ABOUTME: it sounds and how much it echoes, in combinable steps.

import 'package:meta/meta.dart';

/// How a recorded voice-over take is changed.
///
/// The three changes combine — a deep robot with an echo is one value — and
/// [none] is the voice as recorded. Each is a whole number, so a value
/// persists exactly and names the file it was rendered into.
@immutable
class VoiceEffect {
  /// Creates a voice effect, clamping every change to its range.
  const VoiceEffect({int pitch = 0, int robot = 0, int echo = 0})
    : pitch = pitch < minPitch
          ? minPitch
          : (pitch > maxPitch ? maxPitch : pitch),
      robot = robot < 0 ? 0 : (robot > maxAmount ? maxAmount : robot),
      echo = echo < 0 ? 0 : (echo > maxAmount ? maxAmount : echo);

  /// Reads a value [toJson] wrote. Missing changes are zero.
  factory VoiceEffect.fromJson(Map<String, dynamic> json) => VoiceEffect(
    pitch: (json['pitch'] as num?)?.round() ?? 0,
    robot: (json['robot'] as num?)?.round() ?? 0,
    echo: (json['echo'] as num?)?.round() ?? 0,
  );

  /// The voice as recorded.
  static const none = VoiceEffect();

  /// Lowest [pitch], an octave down.
  static const minPitch = -12;

  /// Highest [pitch], an octave up.
  static const maxPitch = 12;

  /// Highest [robot] and [echo].
  static const maxAmount = 100;

  /// Semitones the voice moves, from [minPitch] to [maxPitch].
  final int pitch;

  /// How much of a monotone robot replaces the voice, in percent.
  final int robot;

  /// How strongly the voice echoes, in percent.
  final int echo;

  /// Whether this leaves the voice as recorded.
  bool get isNone => pitch == 0 && robot == 0 && echo == 0;

  /// Creates a copy with the given changes replaced.
  VoiceEffect copyWith({int? pitch, int? robot, int? echo}) => VoiceEffect(
    pitch: pitch ?? this.pitch,
    robot: robot ?? this.robot,
    echo: echo ?? this.echo,
  );

  /// The changes that are not zero.
  Map<String, dynamic> toJson() => {
    if (pitch != 0) 'pitch': pitch,
    if (robot != 0) 'robot': robot,
    if (echo != 0) 'echo': echo,
  };

  @override
  bool operator ==(Object other) =>
      other is VoiceEffect &&
      other.pitch == pitch &&
      other.robot == robot &&
      other.echo == echo;

  @override
  int get hashCode => Object.hash(pitch, robot, echo);

  @override
  String toString() => 'VoiceEffect(pitch: $pitch, robot: $robot, echo: $echo)';
}
