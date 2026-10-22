// ABOUTME: Settings of the drops video effect beyond its intensity, and where
// ABOUTME: its drops are at a moment, as the native renderers place them.

import 'dart:math' as math;

import 'package:equatable/equatable.dart';

/// How the drops effect looks beyond its intensity, stored in the params of
/// its `CustomVideoEffect` and read by the native `DropsVideoEffect`.
///
/// Every value but [count] and [seed] runs from 0 to 1; 0.5 is the default
/// look.
class DropsEffectSettings extends Equatable {
  const DropsEffectSettings({
    this.count = defaultCount,
    this.size = 0.5,
    this.speed = 0.5,
    this.frost = 0.5,
    this.fringes = 0.5,
    this.seed = 0,
  });

  /// Reads the settings from a custom effect's [params], falling back to the
  /// default for anything missing and clamping the rest into range.
  factory DropsEffectSettings.fromParams(Map<String, dynamic> params) {
    double unit(String key) =>
        ((params[key] as num?)?.toDouble() ?? 0.5).clamp(0.0, 1.0);
    return DropsEffectSettings(
      count: ((params[countParam] as num?)?.round() ?? defaultCount).clamp(
        minCount,
        maxCount,
      ),
      size: unit(sizeParam),
      speed: unit(speedParam),
      frost: unit(frostParam),
      fringes: unit(fringesParam),
      seed: (params[seedParam] as num?)?.round() ?? 0,
    );
  }

  /// The fewest drops the effect draws.
  static const minCount = 1;

  /// The most drops the effect draws.
  static const maxCount = 5;

  /// How many drops a new effect starts with.
  static const defaultCount = 3;

  /// The param names, as the native renderers read them.
  static const countParam = 'count';
  static const sizeParam = 'size';
  static const speedParam = 'speed';
  static const frostParam = 'frost';
  static const fringesParam = 'fringes';
  static const seedParam = 'seed';

  /// How many drops show, [minCount] to [maxCount].
  final int count;

  /// How large the drops are.
  final double size;

  /// How fast they drift; 0 holds them still.
  final double speed;

  /// How frosted the glass is.
  final double frost;

  /// How strongly red and blue part at the drops' rims.
  final double fringes;

  /// Which arrangement and paths the drops take; 0 is the default one.
  final int seed;

  /// The params to store next to the intensity.
  Map<String, Object> toParams() => {
    countParam: count,
    sizeParam: size,
    speedParam: speed,
    frostParam: frost,
    fringesParam: fringes,
    seedParam: seed,
  };

  DropsEffectSettings copyWith({
    int? count,
    double? size,
    double? speed,
    double? frost,
    double? fringes,
    int? seed,
  }) => DropsEffectSettings(
    count: (count ?? this.count).clamp(minCount, maxCount),
    size: (size ?? this.size).clamp(0.0, 1.0),
    speed: (speed ?? this.speed).clamp(0.0, 1.0),
    frost: (frost ?? this.frost).clamp(0.0, 1.0),
    fringes: (fringes ?? this.fringes).clamp(0.0, 1.0),
    seed: seed ?? this.seed,
  );

  @override
  List<Object?> get props => [count, size, speed, frost, fringes, seed];
}

/// A drop: its centre as fractions of the frame's width and height, up from
/// the bottom left, and its radius as a fraction of the shorter side.
typedef DropPlacement = ({double x, double y, double radius});

/// Every one of [DropsEffectSettings.maxCount] drops [seconds] into the
/// effect. The ones past the settings' count sit far outside the frame with
/// no size, so a shader can always take all of them.
///
/// Each drop follows a path of its own, `0.5 + a · sin(f · t + phase)` along
/// each axis, where `t` is [seconds] times twice the speed. The seed shifts
/// every phase, which rearranges the drops and when they meet without
/// changing how they move. Mirrors `DropsLayout` in the Android and Swift
/// `DropsVideoEffect`.
List<DropPlacement> dropsLayout(
  DropsEffectSettings settings, {
  required double seconds,
}) {
  final t = seconds * 2 * settings.speed;
  final seed = settings.seed.toDouble();
  return [
    for (final (i, path) in _dropPaths.indexed)
      if (i >= settings.count)
        (x: -100.0, y: -100.0, radius: 0.0)
      else
        (
          x:
              0.5 +
              path.ax *
                  math.sin(path.fx * t + path.px + seed * 2.399963 * (i + 1)),
          y:
              0.5 +
              path.ay *
                  math.sin(path.fy * t + path.py + seed * 1.618034 * (i + 1)),
          radius: path.radius * dropsScale(settings),
        ),
  ];
}

/// How much larger than at the default size the drops, and everything around
/// their rims, are drawn.
double dropsScale(DropsEffectSettings settings) => 0.5 + settings.size;

/// Per drop: frequency, phase and amplitude across, the same up, and the
/// radius at the default size.
const List<
  ({
    double fx,
    double px,
    double ax,
    double fy,
    double py,
    double ay,
    double radius,
  })
>
_dropPaths = [
  (fx: 0.53, px: 0.0, ax: 0.24, fy: 0.41, py: 1.570796, ay: 0.17, radius: 0.17),
  (fx: 0.37, px: 2.1, ax: 0.26, fy: 0.29, py: 0.7, ay: 0.21, radius: 0.13),
  (fx: 0.45, px: 5.570796, ax: 0.20, fy: 0.51, py: 3.3, ay: 0.19, radius: 0.15),
  (fx: 0.31, px: 5.2, ax: 0.22, fy: 0.47, py: 1.9, ay: 0.23, radius: 0.11),
  (fx: 0.59, px: 0.4, ax: 0.18, fy: 0.33, py: 4.6, ay: 0.16, radius: 0.14),
];
