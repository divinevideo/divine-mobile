import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_editor/editor_video_effect.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  group('withoutFlashingOverlaps', () {
    Duration s(num seconds) => Duration(milliseconds: (seconds * 1000).round());

    EditorVideoEffect effect(
      String id,
      VideoEffectType type, [
      Duration? start,
      Duration? end,
    ]) => EditorVideoEffect(
      id: id,
      effect: VideoEffect(type: type, startTime: start, endTime: end),
    );

    List<(String, Duration?, Duration?)> windows(
      List<EditorVideoEffect> effects,
    ) => [
      for (final e in effects) (e.id, e.effect.startTime, e.effect.endTime),
    ];

    var created = 0;
    String createId() => 'piece-${created++}';

    setUp(() => created = 0);

    test('leaves effects alone when the kept one does not flash', () {
      final effects = [
        effect('glitch', .glitch),
        effect('strobe', .strobe),
      ];

      expect(
        withoutFlashingOverlaps(
          effects,
          keepId: 'glitch',
          createId: createId,
        ),
        isNull,
      );
    });

    test('leaves effects alone when no other flashing effect overlaps', () {
      final effects = [
        effect('strobe', .strobe, s(0), s(2)),
        effect('negative', .negativeFlash, s(2), s(4)),
        effect('vignette', .vignette),
      ];

      expect(
        withoutFlashingOverlaps(
          effects,
          keepId: 'strobe',
          createId: createId,
        ),
        isNull,
      );
    });

    test('a whole-video flashing effect replaces every other one', () {
      final effects = [
        effect('negative', .negativeFlash, s(1), s(3)),
        effect('vignette', .vignette),
        effect('strobe', .strobe),
      ];

      final result = withoutFlashingOverlaps(
        effects,
        keepId: 'strobe',
        createId: createId,
      )!;

      expect(result.map((e) => e.id), ['vignette', 'strobe']);
    });

    test('cuts the other effect around the kept window and keeps its open '
        'end', () {
      final effects = [
        effect('strobe', .strobe, s(0)),
        effect('negative', .negativeFlash, s(2), s(3)),
      ];

      final result = withoutFlashingOverlaps(
        effects,
        keepId: 'negative',
        createId: createId,
      )!;

      expect(windows(result), [
        ('strobe', s(0), s(2)),
        ('piece-0', s(3), null),
        ('negative', s(2), s(3)),
      ]);
      expect(result[1].effect.type, VideoEffectType.strobe);
    });

    test('drops a leftover piece too short to see', () {
      final effects = [
        effect('strobe', .strobe, s(0.95), s(3.05)),
        effect('negative', .negativeFlash, s(1), s(3)),
      ];

      final result = withoutFlashingOverlaps(
        effects,
        keepId: 'negative',
        createId: createId,
      )!;

      expect(result.map((e) => e.id), ['negative']);
    });
  });
}
