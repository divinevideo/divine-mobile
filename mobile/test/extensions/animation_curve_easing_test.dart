// ABOUTME: Tests that a transition's progress is eased with the export's own
// ABOUTME: formulas.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/extensions/animation_curve_easing.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show AnimationCurve;

void main() {
  group('AnimationCurveEasing', () {
    group('ease', () {
      test('starts at 0 and ends at 1 on every curve', () {
        for (final curve in AnimationCurve.values) {
          expect(curve.ease(0), closeTo(0, 1e-9), reason: curve.name);
          expect(curve.ease(1), closeTo(1, 1e-9), reason: curve.name);
        }
      });

      test('eases in and out quadratically, as the export does', () {
        // Flutter's Curves.easeInOut is a cubic Bézier, at about 0.09 here.
        expect(AnimationCurve.easeInOut.ease(0.25), closeTo(0.125, 1e-9));
        expect(AnimationCurve.easeInOut.ease(0.75), closeTo(0.875, 1e-9));
      });
    });
  });
}
