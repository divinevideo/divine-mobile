// ABOUTME: The ready-made gradients and the directions the text editor offers
// ABOUTME: for filling the letters of a text with a color gradient (#10398).

import 'dart:math' as math;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:pro_image_editor/pro_image_editor.dart' show TextGradient;

/// A ready-made gradient in the brand's accent colors.
enum TextGradientPreset {
  sunset([
    VineTheme.accentYellow,
    VineTheme.accentOrange,
    VineTheme.accentPink,
  ]),
  ocean([VineTheme.accentBlue, VineTheme.accentPurple]),
  rainbow([
    VineTheme.accentPink,
    VineTheme.accentOrange,
    VineTheme.accentYellow,
    VineTheme.accentLime,
    VineTheme.accentBlue,
    VineTheme.accentPurple,
  ]),
  mint([VineTheme.vineGreen, VineTheme.accentLime]),
  candy([VineTheme.accentPink, VineTheme.accentViolet]),
  aurora([VineTheme.vineGreen, VineTheme.accentBlue, VineTheme.accentPurple]);

  const TextGradientPreset(this.colors);

  /// The colors the gradient runs through, from its start to its end.
  final List<Color> colors;

  /// The gradient a text gets when the user picks it before any other:
  /// [sunset], from left to right.
  static TextGradient get initial => sunset.withAngle(0);

  /// The gradient through [colors], running in the direction of [angle]
  /// (see `TextGradient.angle`).
  TextGradient withAngle(double angle) =>
      TextGradient(colors: colors, angle: angle);

  /// Whether [gradient] runs through this preset's colors, in whichever
  /// direction.
  bool matches(TextGradient? gradient) =>
      gradient != null &&
      gradient.stops == null &&
      listEquals(gradient.colors, colors);
}

/// How a [TextGradient] shows on a round swatch.
extension TextGradientSwatch on TextGradient {
  /// This gradient across a swatch, turned about its middle as it runs
  /// across a text.
  LinearGradient get swatch => LinearGradient(
    colors: colors,
    stops: stops,
    transform: GradientRotation(angle),
  );
}

/// A direction a text gradient runs in, in steps of 45 degrees clockwise
/// from left to right.
enum TextGradientDirection {
  leftToRight,
  topLeftToBottomRight,
  topToBottom,
  topRightToBottomLeft,
  rightToLeft,
  bottomRightToTopLeft,
  bottomToTop,
  bottomLeftToTopRight;

  /// The `TextGradient.angle` of this direction, in radians.
  double get angle => index * math.pi / 4;

  /// The direction [angle] points in, or `null` when it is not one of the
  /// eight, as a gradient made elsewhere may run.
  static TextGradientDirection? of(double angle) {
    final steps = angle / (math.pi / 4);
    final step = steps.round();
    if ((steps - step).abs() > 1e-6) return null;
    return values[step % values.length];
  }
}
