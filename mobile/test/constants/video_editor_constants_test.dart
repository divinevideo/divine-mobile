// ABOUTME: Pins the invariants VideoEditorConstants values depend on.
// ABOUTME: Clip speed presets must be stops the speed slider can reach.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/constants/video_editor_constants.dart';

void main() {
  group(VideoEditorConstants, () {
    group('clipSpeedPresets', () {
      test('every preset lies within the clip speed range', () {
        for (final preset in VideoEditorConstants.clipSpeedPresets) {
          expect(
            preset,
            inInclusiveRange(
              VideoEditorConstants.clipSpeedMin,
              VideoEditorConstants.clipSpeedMax,
            ),
          );
        }
      });

      test('every preset sits on a slider step', () {
        for (final preset in VideoEditorConstants.clipSpeedPresets) {
          final steps =
              (preset - VideoEditorConstants.clipSpeedMin) /
              VideoEditorConstants.clipSpeedStep;
          expect(
            steps,
            closeTo(steps.roundToDouble(), 1e-9),
            reason: '$preset',
          );
        }
      });

      test('offers normal speed so a clip can be reset in one tap', () {
        expect(VideoEditorConstants.clipSpeedPresets, contains(1.0));
      });
    });
  });
}
