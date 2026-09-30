// ABOUTME: BT.601 chroma projection of a chroma-key colour, for the preview
// ABOUTME: shader's uniforms. Mirrors pro_video_editor's ChromaKeyMath so the
// ABOUTME: editor preview and the exported render key on the same numbers.

import 'dart:math' as math;
import 'dart:ui';

import 'package:pro_video_editor/pro_video_editor.dart' show ChromaKeyDetector;

/// The key colour's position and direction in the BT.601 Cb/Cr chroma plane.
///
/// The keyer measures distance in this plane. Note it is a *position*, not a
/// pure hue: Cb and Cr scale with brightness, so a dimly lit patch of the
/// screen sits closer to neutral and therefore further from the key point.
class ChromaKeyProjection {
  const ChromaKeyProjection({
    required this.cb,
    required this.cr,
    required this.directionCb,
    required this.directionCr,
    required this.lumaWeight,
  });

  /// Projects [color] into the chroma plane.
  ///
  /// [color]'s channels are gamma-encoded sRGB in `0..1`, which is the space
  /// the renderer evaluates the key in — deliberately not linearised.
  factory ChromaKeyProjection.of(Color color) {
    final r = color.r;
    final g = color.g;
    final b = color.b;
    final cb = -0.168736 * r - 0.331264 * g + 0.5 * b;
    final cr = 0.5 * r - 0.418688 * g - 0.081312 * b;

    // Unit vector from neutral toward the key hue, used to pull the key's cast
    // back out during spill suppression. Zero for a neutral (gray) key colour,
    // which disables despill rather than dividing by zero.
    final length = math.sqrt(cb * cb + cr * cr);
    final hasHue = length > 1e-5;

    return ChromaKeyProjection(
      cb: cb,
      cr: cr,
      directionCb: hasHue ? cb / length : 0,
      directionCr: hasHue ? cr / length : 0,
      lumaWeight: ChromaKeyDetector.lumaWeightOf(cb, cr),
    );
  }

  /// Cb of the key colour.
  final double cb;

  /// Cr of the key colour.
  final double cr;

  /// Cb of the unit vector pointing from neutral toward the key hue.
  final double directionCb;

  /// Cr of the unit vector pointing from neutral toward the key hue.
  final double directionCr;

  /// How much brightness counts toward the matte: 0 for a saturated key, 1 for
  /// a neutral one (`ChromaKeyDetector.lumaWeightOf`).
  final double lumaWeight;

  /// The despill strength the renderers apply for [spill].
  ///
  /// They scale it by `1 - lumaWeight`, so a near-white key whose faint tint
  /// still gives it a direction does not strip that tint from the subject.
  double effectiveSpill(double spill) => spill * (1 - lumaWeight);

  @override
  String toString() =>
      'ChromaKeyProjection(cb: $cb, cr: $cr, '
      'directionCb: $directionCb, directionCr: $directionCr, '
      'lumaWeight: $lumaWeight)';
}
