// ABOUTME: One setting of a video effect beyond its intensity: what it is
// ABOUTME: called, where it shows, its range and default, and its param.

import 'package:flutter/foundation.dart';

/// The values of an effect's settings by param name, as stored in the params
/// of its `CustomVideoEffect`.
typedef EffectSettingValues = Map<String, Object>;

/// The card of the effect settings panel a setting shows in, in panel order.
enum EffectSettingGroup {
  /// When and for how long the effect hits.
  timing,

  /// How the effect looks: where, how large, how strong, which colour.
  look,

  /// How the effect moves: how fast, and which way.
  motion,
}

/// What a setting is called, mapped to its localized name by the panel.
///
/// Names are shared between effects wherever they mean the same thing, so a
/// new setting usually needs no new string.
enum EffectSettingLabel {
  duration,
  repeat,
  interval,
  horizontal,
  vertical,
  reach,
  size,
  shake,
  punch,
  fringes,
  color,
  count,
  speed,
  frost,
  shuffle,
  focus,
  width,
  direction,
  spacing,
  angle,
  hue,
  length,
  sensitivity,
  position,
  wind,
  dotSize,
  outline,
  levels,
  pixelSize,
  offset,
  brushSize,
  density,
  grain,
  grid,
  layers,
  shadow,
  firstInk,
  secondInk,
  colors,
  delay,
  frequency,
  distance,
  scanlines,
  grainSize,
  sepia,
  flicker,
  vignette,
  tempo,
  wavelength,

  /// The adjustments of a colour filter.
  brightness,
  contrast,
  saturation,
  exposure,
  fade,
  temperature,
  tint,
  strength,

  /// The options of a [direction].
  horizontalOption,
  verticalOption,
  clockwise,
  anticlockwise,
  zoomIn,
  zoomOut,

  /// The options of [colors].
  originalColors,
  singleColor,

  /// The options of the time warp's [direction]: which way across the picture
  /// leads further back in time.
  down,
  up,
  right,
  left,
}

/// How a slider's value is written, stored and read.
enum EffectSliderUnit {
  /// A share, stored as is and shown out of 100.
  share,

  /// A whole number, stored as an integer and shown as one.
  count,

  /// A length of time in seconds, stored as whole microseconds.
  seconds,

  /// An angle in degrees, stored as is.
  degrees,
}

/// Whether a setting shows for the [values] the picked effect has, while it
/// fires [onBeat] or not.
typedef EffectSettingShownWhen = bool Function(
  EffectSettingValues values, {
  required bool onBeat,
});

/// One setting of an effect beyond its intensity, stored in its params under
/// [key], where the native renderer reads it.
@immutable
sealed class EffectSetting {
  const EffectSetting({
    required this.key,
    required this.label,
    this.group,
    this.shownWhen,
  });

  /// The param the setting is stored under.
  final String key;

  /// What the setting is called.
  final EffectSettingLabel label;

  /// The card an effect's setting shows in; `null` for a setting whose card
  /// is chosen by its owner, as a colour filter's are.
  final EffectSettingGroup? group;

  /// When it shows; `null` for always.
  final EffectSettingShownWhen? shownWhen;

  /// The param a new effect stores.
  Object get defaultParam;

  /// [param] as this setting stores it: in range and of the right type, or
  /// [defaultParam] for a missing or unreadable one.
  Object read(Object? param);

  /// Whether this setting shows for [values], while the effect fires [onBeat]
  /// or not.
  bool isShown(EffectSettingValues values, {required bool onBeat}) =>
      shownWhen?.call(values, onBeat: onBeat) ?? true;
}

/// A setting the user drags along a slider from [min] to [max].
final class EffectSliderSetting extends EffectSetting {
  const EffectSliderSetting({
    required super.key,
    required super.label,
    required this.defaultValue,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.unit = EffectSliderUnit.share,
    super.group,
    super.shownWhen,
  });

  /// The value a new effect starts at, in [unit]s.
  final double defaultValue;

  /// The range of the slider, in [unit]s.
  final double min;
  final double max;

  /// How many steps the slider snaps to; `null` for none.
  final int? divisions;

  /// How the value is written and stored.
  final EffectSliderUnit unit;

  /// The value [param] holds, in [unit]s and in range.
  double valueOf(Object? param) {
    final number = param is num ? param.toDouble() : null;
    final value = switch (unit) {
      EffectSliderUnit.seconds when number != null => number / 1e6,
      _ => number,
    };
    return (value ?? defaultValue).clamp(min, max);
  }

  /// [value], in [unit]s, as it is stored.
  Object paramOf(double value) {
    final clamped = value.clamp(min, max);
    return switch (unit) {
      EffectSliderUnit.share || EffectSliderUnit.degrees => clamped,
      EffectSliderUnit.count => clamped.round(),
      EffectSliderUnit.seconds => (clamped * 1e6).round(),
    };
  }

  @override
  Object get defaultParam => paramOf(defaultValue);

  @override
  Object read(Object? param) => paramOf(valueOf(param));
}

/// A setting the user picks a colour for, stored as an ARGB integer.
final class EffectColorSetting extends EffectSetting {
  const EffectColorSetting({
    required super.key,
    required super.label,
    required this.defaultColor,
    super.group,
    super.shownWhen,
  });

  /// The colour a new effect starts with, as an ARGB integer.
  final int defaultColor;

  @override
  Object get defaultParam => defaultColor;

  @override
  Object read(Object? param) => param is num ? param.toInt() : defaultColor;
}

/// A setting the user turns on or off; [offHint] says what off means, when
/// that needs saying.
final class EffectToggleSetting extends EffectSetting {
  const EffectToggleSetting({
    required super.key,
    required super.label,
    required this.defaultValue,
    this.offHint,
    super.group,
    super.shownWhen,
  });

  /// Whether a new effect starts with it on.
  final bool defaultValue;

  /// A line under the switch while it is off.
  final EffectSettingHint? offHint;

  @override
  Object get defaultParam => defaultValue;

  @override
  Object read(Object? param) => param is bool ? param : defaultValue;
}

/// A line that explains a setting's state, mapped to its localized text by
/// the panel.
enum EffectSettingHint {
  /// The effect hits once, where its bar starts on the timeline.
  once,
}

/// One of the options of an [EffectChoiceSetting]: the [value] it stores and
/// what it is called.
typedef EffectChoice = ({int value, EffectSettingLabel label});

/// A setting the user picks one of its [choices] for, stored as the choice's
/// value.
final class EffectChoiceSetting extends EffectSetting {
  const EffectChoiceSetting({
    required super.key,
    required super.label,
    required this.choices,
    required this.defaultValue,
    super.group,
    super.shownWhen,
  });

  /// The options, in the order they show.
  final List<EffectChoice> choices;

  /// The value of the option a new effect starts with.
  final int defaultValue;

  @override
  Object get defaultParam => defaultValue;

  @override
  Object read(Object? param) {
    final value = param is num ? param.round() : null;
    return choices.any((choice) => choice.value == value)
        ? value!
        : defaultValue;
  }
}

/// A button that gives the effect a new random arrangement, stored as a seed;
/// 0 is the default arrangement.
final class EffectShuffleSetting extends EffectSetting {
  const EffectShuffleSetting({
    required super.key,
    required super.label,
    super.group,
    super.shownWhen,
  });

  @override
  Object get defaultParam => 0;

  @override
  Object read(Object? param) => param is num ? param.round() : 0;
}
