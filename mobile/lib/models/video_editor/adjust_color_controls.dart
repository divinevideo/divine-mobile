// ABOUTME: Adjust's Color and Curve sections: the eight colour bands and the
// ABOUTME: tone curve's channels and points, and the adjustment kinds they set.

import 'dart:math' as math;

/// One of the eight colour ranges whose hue, saturation and lightness the
/// Color section of Adjust changes on its own, in hue order.
///
/// The native `divine.adjust` effect centres them on these hues: red 0°,
/// orange 30°, yellow 60°, green 120°, aqua 180°, blue 240°, purple 270° and
/// magenta 300°, and blends each into its neighbours.
enum AdjustColorBand {
  red,
  orange,
  yellow,
  green,
  aqua,
  blue,
  purple,
  magenta;

  /// The hue the band is centred on, in degrees.
  double get centre =>
      const <double>[0, 30, 60, 120, 180, 240, 270, 300][index];

  /// The adjustment kind of [property] for this band, like `redHue`.
  String kindOf(AdjustColorProperty property) => '$name${property.kindSuffix}';
}

/// What the Color section changes about a colour band.
enum AdjustColorProperty {
  /// Turns the band towards its neighbouring colours: below 0 towards the
  /// one before it, above 0 towards the one after it, by up to 30°.
  hue('Hue'),

  /// Mutes the band (down to grey at -1) or strengthens it (twice as strong
  /// at 1).
  saturation('Saturation'),

  /// Darkens or lightens the band, more the more colourful a pixel is, so
  /// greys stay as they are.
  lightness('Lightness');

  const AdjustColorProperty(this.kindSuffix);

  /// What follows the band in the adjustment kind.
  final String kindSuffix;
}

/// A curve of the tone curve: the master curve over all three channels, or
/// one of them on its own, which runs after the master curve.
enum AdjustCurveChannel {
  rgb('Rgb'),
  red('Red'),
  green('Green'),
  blue('Blue');

  const AdjustCurveChannel(this.kindInfix);

  /// What follows `curve` in the adjustment kind.
  final String kindInfix;

  /// The adjustment kind of [point] on this curve, like `curveRgbShadows`.
  String kindOf(AdjustCurvePoint point) => 'curve$kindInfix${point.kindSuffix}';
}

/// One of the five points of a tone curve, each fixed at its input level
/// [x] and moved up or down only.
///
/// A point's adjustment value is how far its output sits above the input
/// ([x]), so 0 leaves the curve straight; it can reach from black to white.
enum AdjustCurvePoint {
  blacks('Blacks'),
  shadows('Shadows'),
  midtones('Midtones'),
  highlights('Highlights'),
  whites('Whites');

  const AdjustCurvePoint(this.kindSuffix);

  /// What follows the channel in the adjustment kind.
  final String kindSuffix;

  /// The input level the point sits at, from 0 (black) to 1 (white).
  double get x => index / (values.length - 1);

  /// The lowest value: the point's output at black.
  double get min => -x;

  /// The highest value: the point's output at white.
  double get max => 1 - x;
}

/// The adjustment kinds of the Color section, band by band, each band's hue,
/// saturation and lightness in turn.
final List<String> adjustColorKinds = [
  for (final band in AdjustColorBand.values)
    for (final property in AdjustColorProperty.values) band.kindOf(property),
];

/// The adjustment kinds of the Curve section, curve by curve, each curve's
/// points from black to white.
final List<String> adjustCurveKinds = [
  for (final channel in AdjustCurveChannel.values)
    for (final point in AdjustCurvePoint.values) channel.kindOf(point),
];

/// The output level of [x] (0 to 1) through a tone curve whose points, from
/// black to white, sit [offsets] above their input levels.
///
/// This is the curve the native `divine.adjust` effect maps a channel
/// through: a cubic through the points whose slopes follow Steffen's method,
/// so between two points it never rises above or falls below both. Missing
/// offsets are 0.
double adjustCurveLevel(double x, List<double> offsets) {
  const last = 4;
  double y(int point) {
    final offset = point < offsets.length ? offsets[point] : 0.0;
    return (point / last + offset).clamp(0.0, 1.0);
  }

  double slope(double before, double after) =>
      (before.sign + after.sign) *
      math.min(
        math.min(before.abs(), after.abs()),
        0.25 * (before + after).abs(),
      );

  final ys = [for (var point = 0; point <= last; point++) y(point)];
  final secants = [
    for (var i = 0; i < last; i++) last * (ys[i + 1] - ys[i]),
  ];
  final slopes = [
    secants.first,
    for (var i = 1; i < last; i++) slope(secants[i - 1], secants[i]),
    secants.last,
  ];
  final s = x.clamp(0.0, 1.0) * last;
  final k = s.floor().clamp(0, last - 1);
  final t = s - k;
  final t2 = t * t;
  final t3 = t2 * t;
  final level =
      (2 * t3 - 3 * t2 + 1) * ys[k] +
      (t3 - 2 * t2 + t) * slopes[k] / last +
      (3 * t2 - 2 * t3) * ys[k + 1] +
      (t3 - t2) * slopes[k + 1] / last;
  return level.clamp(0.0, 1.0);
}
