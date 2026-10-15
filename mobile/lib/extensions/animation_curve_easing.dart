// ABOUTME: Eases a transition's progress with the formulas pro_video_editor
// ABOUTME: renders it with, so the app can follow a blend the way the export does.

import 'dart:math' as math;

import 'package:pro_video_editor/pro_video_editor.dart' show AnimationCurve;

/// The export's own easing of a curve, which is not Flutter's: its
/// [AnimationCurve.easeInOut], for one, is quadratic, where Flutter's
/// `Curves.easeInOut` is a cubic Bézier.
extension AnimationCurveEasing on AnimationCurve {
  /// How far along the curve is at [t], from 0 at its start to 1 at its end,
  /// as `pro_video_editor` eases a transition on both platforms. The bounce
  /// and elastic curves overshoot on the way.
  double ease(double t) => switch (this) {
    AnimationCurve.linear => t,
    AnimationCurve.easeIn => t * t,
    AnimationCurve.easeOut => t * (2 - t),
    AnimationCurve.easeInOut => t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t,
    AnimationCurve.easeInCubic => t * t * t,
    AnimationCurve.easeOutCubic => 1 - math.pow(1 - t, 3).toDouble(),
    AnimationCurve.easeInOutCubic =>
      t < 0.5 ? 4 * t * t * t : 1 - math.pow(-2 * t + 2, 3) / 2,
    AnimationCurve.bounceIn => 1 - _bounceOut(1 - t),
    AnimationCurve.bounceOut => _bounceOut(t),
    AnimationCurve.bounceInOut =>
      t < 0.5
          ? (1 - _bounceOut(1 - 2 * t)) / 2
          : (1 + _bounceOut(2 * t - 1)) / 2,
    AnimationCurve.elasticIn => 1 - _elasticOut(1 - t),
    AnimationCurve.elasticOut => _elasticOut(t),
    AnimationCurve.elasticInOut =>
      t < 0.5
          ? (1 - _elasticOut(1 - 2 * t)) / 2
          : (1 + _elasticOut(2 * t - 1)) / 2,
  };
}

double _bounceOut(double t) {
  if (t < 1 / 2.75) return 7.5625 * t * t;
  if (t < 2 / 2.75) {
    final t2 = t - 1.5 / 2.75;
    return 7.5625 * t2 * t2 + 0.75;
  }
  if (t < 2.5 / 2.75) {
    final t2 = t - 2.25 / 2.75;
    return 7.5625 * t2 * t2 + 0.9375;
  }
  final t2 = t - 2.625 / 2.75;
  return 7.5625 * t2 * t2 + 0.984375;
}

double _elasticOut(double t) {
  if (t == 0 || t == 1) return t;
  return math.pow(2, -10 * t) * math.sin((t - 0.075) * 2 * math.pi / 0.3) + 1;
}
