// ABOUTME: When and for how long the effects that hit (the shockwave, the
// ABOUTME: subwoofer and the blasts) fire, when they do not follow the beat.

import 'package:equatable/equatable.dart';

/// How the effects that hit play out, beyond their intensity: how long one
/// hit lasts, and, when they do not follow the beat, whether they hit once at
/// the start of their window or again every [interval].
///
/// Stored in the params of their `CustomVideoEffect`; the Dart side turns
/// them into the times the native renderers hit at, and hands them [duration]
/// as [hitParam].
class HitTimingSettings extends Equatable {
  const HitTimingSettings({
    required this.duration,
    required this.interval,
    this.repeats = true,
  });

  /// Reads the settings from a custom effect's [params], falling back to
  /// [defaults] for anything missing and clamping the rest into range.
  factory HitTimingSettings.fromParams(
    Map<String, dynamic> params, {
    required HitTimingSettings defaults,
  }) {
    Duration read(String key, Duration fallback, Duration min, Duration max) {
      final us = (params[key] as num?)?.round();
      if (us == null) return fallback;
      return Duration(
        microseconds: us.clamp(min.inMicroseconds, max.inMicroseconds),
      );
    }

    return HitTimingSettings(
      duration: read(hitParam, defaults.duration, minDuration, maxDuration),
      interval: read(
        intervalParam,
        defaults.interval,
        minInterval,
        maxInterval,
      ),
      repeats: params[repeatParam] as bool? ?? defaults.repeats,
    );
  }

  /// The shortest and the longest a hit may last.
  static const minDuration = Duration(milliseconds: 200);
  static const maxDuration = Duration(seconds: 3);

  /// The shortest and the longest time between two hits. Two hits are never
  /// closer than [minInterval], which also keeps the blasts, which flash,
  /// within three flashes a second on their own.
  static const minInterval = Duration(milliseconds: 400);
  static const maxInterval = Duration(seconds: 4);

  /// The param names. [hitParam] is also what the native renderers read how
  /// long a hit lasts from, in microseconds.
  static const hitParam = 'hitUs';
  static const intervalParam = 'intervalUs';
  static const repeatParam = 'repeat';

  /// How long one hit lasts; its animation is stretched or squeezed to fit.
  final Duration duration;

  /// How long after one hit the next comes, while it [repeats].
  final Duration interval;

  /// Whether the effect hits again every [interval], or once at the start of
  /// its window. Neither applies on the beat, which hits on every beat.
  final bool repeats;

  /// The params to store next to the intensity.
  Map<String, Object> toParams() => {
    hitParam: duration.inMicroseconds,
    intervalParam: interval.inMicroseconds,
    repeatParam: repeats,
  };

  HitTimingSettings copyWith({
    Duration? duration,
    Duration? interval,
    bool? repeats,
  }) {
    return HitTimingSettings(
      duration: duration ?? this.duration,
      interval: interval ?? this.interval,
      repeats: repeats ?? this.repeats,
    );
  }

  @override
  List<Object?> get props => [duration, interval, repeats];
}
