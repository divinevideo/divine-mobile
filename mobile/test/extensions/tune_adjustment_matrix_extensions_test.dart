// ABOUTME: Tests for the tune-set extension getters and TuneSet helpers.
// ABOUTME: Covers set-id/kind fallbacks, id/meta builders, and session seeding.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/tune_adjustment_matrix_extensions.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show TuneAdjustmentMatrix;

TuneAdjustmentMatrix _member(
  String kind,
  double value, {
  required String setId,
}) => TuneAdjustmentMatrix(
  id: TuneSet.memberId(kind: kind, setId: setId),
  value: value,
  matrix: const [],
  meta: TuneSet.metaFor(setId: setId, kind: kind),
);

void main() {
  group('TuneAdjustmentMatrixTuneSet', () {
    test('tuneSetId / tuneKind read from meta', () {
      final m = _member('brightness', 0.2, setId: 'set-1');
      expect(m.tuneSetId, 'set-1');
      expect(m.tuneKind, 'brightness');
    });

    test('tuneSetId / tuneKind fall back to the id for legacy matrices', () {
      final legacy = TuneAdjustmentMatrix(
        id: 'brightness',
        value: 0.2,
        matrix: const [],
      );
      expect(legacy.tuneSetId, 'brightness');
      expect(legacy.tuneKind, 'brightness');
    });
  });

  group('TuneSet', () {
    test('newId is prefixed and unique across calls', () {
      final a = TuneSet.newId();
      final b = TuneSet.newId();
      expect(a, startsWith('set_'));
      expect(a, isNot(b));
    });

    test('newId stays unique when called within one microsecond', () {
      // Back-to-back calls land in the same microsecond most of the time, so
      // a clock-only id made the test above fail at random.
      final ids = {for (var i = 0; i < 1000; i++) TuneSet.newId()};
      expect(ids, hasLength(1000));
    });

    test('memberId combines kind and set id', () {
      expect(
        TuneSet.memberId(kind: 'contrast', setId: 'set-9'),
        'contrast__set-9',
      );
    });

    test('metaFor records both the set id and kind', () {
      final meta = TuneSet.metaFor(setId: 'set-2', kind: 'hue');
      expect(meta[VideoEditorConstants.tuneSetIdMetaKey], 'set-2');
      expect(meta[VideoEditorConstants.tuneKindMetaKey], 'hue');
    });

    group('sessionSeed', () {
      test('returns empty for a new session (null set id)', () {
        expect(TuneSet.sessionSeed(const [], null), isEmpty);
      });

      test('re-keys the edited set members to their preset kind', () {
        final active = [
          _member('brightness', 0.2, setId: 'set-1'),
          _member('contrast', -0.1, setId: 'set-1'),
          _member('hue', 0.3, setId: 'set-2'),
        ];

        final seed = TuneSet.sessionSeed(active, 'set-1');

        expect(seed, hasLength(2));
        expect(seed.map((m) => m.id), containsAll(['brightness', 'contrast']));
        expect(
          seed.firstWhere((m) => m.id == 'brightness').value,
          0.2,
        );
        // Members of other sets are excluded.
        expect(seed.any((m) => m.id == 'hue'), isFalse);
      });
    });
  });
}
