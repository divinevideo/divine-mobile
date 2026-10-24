// ABOUTME: Tests for the native Adjust effect built from Adjust sets — which
// ABOUTME: values it carries, over which window, and what the preview shows.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/extensions/tune_adjustment_matrix_extensions.dart';
import 'package:openvine/models/video_editor/adjust_video_effect.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show CustomVideoEffect;

TuneAdjustmentMatrix _member(
  String kind,
  double value, {
  String setId = 'set_1',
  Duration? startTime,
  Duration? endTime,
}) => TuneAdjustmentMatrix(
  id: TuneSet.memberId(kind: kind, setId: setId),
  value: value,
  matrix: const [],
  startTime: startTime,
  endTime: endTime,
  meta: TuneSet.metaFor(setId: setId, kind: kind),
);

void main() {
  group('adjustVideoEffect', () {
    test('carries only the adjustments a colour matrix cannot draw', () {
      expect(
        adjustVideoEffect(
          const {
            'brightness': 0.3,
            'shadows': 0.5,
            'vibrance': 0,
            'sharpen': 1,
          },
          startTime: const Duration(seconds: 1),
          endTime: const Duration(seconds: 2),
        ),
        const CustomVideoEffect(
          id: adjustVideoEffectId,
          params: {'shadows': 0.5, 'sharpen': 1.0},
          startTime: Duration(seconds: 1),
          endTime: Duration(seconds: 2),
        ),
      );
    });

    test('is null when none of them is set', () {
      expect(
        adjustVideoEffect(const {'contrast': 0.2, 'highlights': 0}),
        isNull,
      );
    });
  });

  group('adjustVideoEffectsOf', () {
    test('draws each set over its own window, in the order of the sets', () {
      final effects = adjustVideoEffectsOf([
        _member('highlights', -0.4, endTime: const Duration(seconds: 2)),
        _member('brightness', 0.1, setId: 'set_2'),
        _member(
          'vibrance',
          0.6,
          setId: 'set_3',
          startTime: const Duration(seconds: 2),
          endTime: const Duration(seconds: 5),
        ),
        _member('sharpen', 0.3, endTime: const Duration(seconds: 2)),
      ]);

      expect(effects, const [
        CustomVideoEffect(
          id: adjustVideoEffectId,
          params: {'highlights': -0.4, 'sharpen': 0.3},
          endTime: Duration(seconds: 2),
        ),
        CustomVideoEffect(
          id: adjustVideoEffectId,
          params: {'vibrance': 0.6},
          startTime: Duration(seconds: 2),
          endTime: Duration(seconds: 5),
        ),
      ]);
    });
  });

  group('previewAdjustVideoEffects', () {
    final applied = [
      _member('shadows', 0.5, endTime: const Duration(seconds: 3)),
    ];

    test('shows the applied sets while the Adjust editor is closed', () {
      expect(
        previewAdjustVideoEffects(applied: applied),
        adjustVideoEffectsOf(applied),
      );
    });

    test('shows only the open session, over the whole video', () {
      expect(
        previewAdjustVideoEffects(
          applied: applied,
          session: const {'sharpen': 0.8, 'contrast': 0.1},
        ),
        const [
          CustomVideoEffect(id: adjustVideoEffectId, params: {'sharpen': 0.8}),
        ],
      );
    });
  });
}
