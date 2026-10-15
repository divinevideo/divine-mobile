// ABOUTME: Eases a transition's progress with the formulas pro_video_editor
// ABOUTME: renders it with, so the app can follow a blend the way the export does.

import 'package:pro_image_editor/core/models/layers/layer_animation.dart'
    as image_editor
    show AnimationCurve;
import 'package:pro_image_editor/shared/utils/layer_animation_progress.dart'
    show applyLayerAnimationCurve;
import 'package:pro_video_editor/pro_video_editor.dart' show AnimationCurve;

/// The export's own easing of a curve, which is not Flutter's: its
/// [AnimationCurve.easeInOut], for one, is quadratic, where Flutter's
/// `Curves.easeInOut` is a cubic Bézier.
extension AnimationCurveEasing on AnimationCurve {
  /// How far along the curve is at [t], from 0 at its start to 1 at its end,
  /// as `pro_video_editor` eases a transition on both platforms. The bounce
  /// and elastic curves overshoot on the way.
  ///
  /// pro_image_editor keeps the one Dart copy of the native easing, under the
  /// same curve names.
  double ease(double t) => applyLayerAnimationCurve(
    image_editor.AnimationCurve.values.byName(name),
    t,
  );
}
