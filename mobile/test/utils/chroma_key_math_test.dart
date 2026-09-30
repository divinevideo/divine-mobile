import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/chroma_key_math.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show ChromaKey;

/// The preview shader keys on these numbers and the exported render keys on
/// pro_video_editor's own copy of the same formula. If they drift apart the
/// editor stops showing what it exports, so the anchors below are the values
/// the plugin documents for its own presets and calibration examples.
void main() {
  group(ChromaKeyProjection, () {
    /// Re-derives Cb/Cr straight from the BT.601 definition, so a typo in the
    /// implementation's coefficients cannot be mirrored by the expectation.
    ({double cb, double cr}) reference(Color color) => (
      cb: -0.168736 * color.r - 0.331264 * color.g + 0.5 * color.b,
      cr: 0.5 * color.r - 0.418688 * color.g - 0.081312 * color.b,
    );

    test('projects SMPTE chroma-key green onto the plugin defaults', () {
      final green = const ChromaKey.greenScreen().color;
      final projection = ChromaKeyProjection.of(green);
      final expected = reference(green);

      expect(projection.cb, closeTo(expected.cb, 1e-12));
      expect(projection.cr, closeTo(expected.cr, 1e-12));

      // The plugin documents green's chroma magnitude as 0.33; that is the
      // scale every `similarity` anchor in its docs is calibrated against.
      final magnitude = math.sqrt(
        projection.cb * projection.cb + projection.cr * projection.cr,
      );
      expect(magnitude, closeTo(0.33, 0.005));
    });

    test('projects SMPTE blue onto a stronger chroma than digital blue', () {
      final blue = const ChromaKey.blueScreen().color;
      final projection = ChromaKeyProjection.of(blue);
      final magnitude = math.sqrt(
        projection.cb * projection.cb + projection.cr * projection.cr,
      );

      // 0.33 for SMPTE blue versus 0.25 for the darker "digital blue" the
      // plugin warns against — the reason the blue preset is usable at all.
      expect(magnitude, closeTo(0.33, 0.01));
    });

    test('direction is a unit vector pointing at the key hue', () {
      final projection = ChromaKeyProjection.of(
        const ChromaKey.greenScreen().color,
      );

      final length = math.sqrt(
        projection.directionCb * projection.directionCb +
            projection.directionCr * projection.directionCr,
      );
      expect(length, closeTo(1, 1e-12));

      // Same orientation as the key point itself: despill has to pull *toward*
      // the key, never away from it.
      final dot =
          projection.cb * projection.directionCb +
          projection.cr * projection.directionCr;
      expect(dot, greaterThan(0));
    });

    test('gives a neutral key no direction, which disables despill', () {
      // A gray key has no hue to pull out. Normalising it would divide by ~0
      // and smear the subject's colour, so the direction collapses to zero.
      for (final gray in [
        const Color(0xFF000000),
        const Color(0xFF808080),
        const Color(0xFFFFFFFF),
      ]) {
        final projection = ChromaKeyProjection.of(gray);
        expect(projection.directionCb, 0, reason: '$gray');
        expect(projection.directionCr, 0, reason: '$gray');
      }
    });

    test('places skin far enough from green to survive the default key', () {
      // The plugin's calibration: skin sits 0.38–0.42 from SMPTE green, which
      // is what makes the 0.20 default safe for faces. If the coefficients
      // regress, this margin is the first thing that collapses.
      final key = ChromaKeyProjection.of(const ChromaKey.greenScreen().color);
      const skinTones = [
        Color(0xFFF0C8A0),
        Color(0xFFC68642),
        Color(0xFF8D5524),
      ];

      for (final skin in skinTones) {
        final tone = ChromaKeyProjection.of(skin);
        final distance = math.sqrt(
          math.pow(tone.cb - key.cb, 2) + math.pow(tone.cr - key.cr, 2),
        );
        expect(
          distance,
          greaterThan(const ChromaKey.greenScreen().similarity),
          reason: '$skin would be keyed away by the default similarity',
        );
      }
    });

    group('effectiveSpill', () {
      test('keeps the full spill for a saturated key', () {
        final projection = ChromaKeyProjection.of(
          const ChromaKey.greenScreen().color,
        );

        expect(projection.lumaWeight, 0);
        expect(projection.effectiveSpill(0.5), closeTo(0.5, 1e-12));
      });

      test('drops despill for a tinted white wall, as the renderers do', () {
        // A white wall is never exactly neutral, so its key still has a hue
        // direction. pro_video_editor 2.19.0 despills at spill * (1 - weight),
        // so the export leaves that faint tint on the subject; the preview has
        // to as well, or it shows a colour cast the export does not.
        final projection = ChromaKeyProjection.of(const Color(0xFFF4F0E8));

        expect(projection.directionCb, isNot(0));
        expect(projection.lumaWeight, 1);
        expect(projection.effectiveSpill(0.5), 0);
      });

      test('scales spill down for a pale key between the two', () {
        final projection = ChromaKeyProjection.of(const Color(0xFFC8E6C8));

        expect(projection.lumaWeight, inExclusiveRange(0, 1));
        expect(
          projection.effectiveSpill(0.5),
          closeTo(0.5 * (1 - projection.lumaWeight), 1e-12),
        );
      });
    });
  });
}
