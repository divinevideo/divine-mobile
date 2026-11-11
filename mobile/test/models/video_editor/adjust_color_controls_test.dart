// ABOUTME: Tests for Adjust's Color and Curve sections: the kinds the native
// ABOUTME: effect reads, the curve points' ranges, and the curve it draws.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_editor/adjust_color_controls.dart';

void main() {
  group('adjustColorKinds', () {
    test('names each band with its hue, saturation and lightness', () {
      // Drafts store these names, and the native effect reads them.
      expect(adjustColorKinds, hasLength(24));
      expect(adjustColorKinds.take(3), [
        'redHue',
        'redSaturation',
        'redLightness',
      ]);
      expect(adjustColorKinds.last, 'magentaLightness');
    });
  });

  group('adjustCurveKinds', () {
    test('names each curve with its five points', () {
      expect(adjustCurveKinds, hasLength(20));
      expect(adjustCurveKinds.take(5), [
        'curveRgbBlacks',
        'curveRgbShadows',
        'curveRgbMidtones',
        'curveRgbHighlights',
        'curveRgbWhites',
      ]);
      expect(adjustCurveKinds.last, 'curveBlueWhites');
    });
  });

  group(AdjustCurvePoint, () {
    test('reaches from black to white from its input level', () {
      expect(AdjustCurvePoint.shadows.x, 0.25);
      expect(AdjustCurvePoint.shadows.min, -0.25);
      expect(AdjustCurvePoint.shadows.max, 0.75);
      expect(AdjustCurvePoint.whites.max, 0);
      expect(AdjustCurvePoint.blacks.min, 0);
    });
  });

  group('adjustCurveLevel', () {
    const levels = [0.0, 0.1, 0.25, 0.37, 0.5, 0.62, 0.75, 0.9, 1.0];

    test('leaves every level as it is when no point moved', () {
      for (final x in levels) {
        expect(adjustCurveLevel(x, const [0, 0, 0, 0, 0]), closeTo(x, 1e-9));
      }
    });

    test('runs through each moved point', () {
      const offsets = [0.1, 0.15, -0.1, 0.05, -0.2];

      for (final point in AdjustCurvePoint.values) {
        expect(
          adjustCurveLevel(point.x, offsets),
          closeTo(point.x + offsets[point.index], 1e-9),
        );
      }
    });

    test('never overshoots the points between them', () {
      // A steep S curve: an unconstrained spline would dip below black
      // before the shadows and swing above white after the highlights.
      const offsets = [0.0, -0.25, 0.0, 0.25, 0.0];
      var previous = -1.0;
      for (var i = 0; i <= 400; i++) {
        final level = adjustCurveLevel(i / 400, offsets);
        expect(level, greaterThanOrEqualTo(previous));
        previous = level;
      }
    });

    test('flattens where two neighbouring points sit level', () {
      // The shadows and midtones points both at 0.5.
      const offsets = [0.0, 0.25, 0.0, 0.0, 0.0];

      expect(adjustCurveLevel(0.3, offsets), closeTo(0.5, 1e-9));
      expect(adjustCurveLevel(0.45, offsets), closeTo(0.5, 1e-9));
    });
  });
}
