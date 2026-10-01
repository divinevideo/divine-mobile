import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/models/content_label.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/editor_video_effect.dart';
import 'package:openvine/models/video_editor/transition_geometry.dart';
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

  group('requiredContentLabelsForEffects', () {
    test('requires the flashing lights warning for a flashing effect', () {
      expect(
        requiredContentLabelsForEffects(const [
          VideoEffect.vignette(),
          VideoEffect.negativeFlash(startTime: Duration(seconds: 2)),
        ]),
        {ContentLabel.flashingLights},
      );
    });

    test('requires nothing without a flashing effect, or with one switched '
        'off', () {
      expect(
        requiredContentLabelsForEffects(const [
          VideoEffect.glitch(),
          VideoEffect.strobe(intensity: 0),
        ]),
        isEmpty,
      );
    });
  });

  group('videoEffectsOnOutput', () {
    DivineVideoClip clip(String id, {ClipTransition? transition}) =>
        DivineVideoClip(
          id: id,
          video: EditorVideo.file('${Directory.systemTemp.path}/$id.mp4'),
          duration: const Duration(seconds: 3),
          recordedAt: DateTime(2026),
          targetAspectRatio: model.AspectRatio.vertical,
          originalAspectRatio: 9 / 16,
          transition: transition,
        );

    // Two 3 s clips, so 6 s of editor timeline.
    final plain = TransitionTimelineMap.fromClips([clip('a'), clip('b')]);
    // The same joined by a 400 ms dissolve: 5.6 s of exported video.
    final compressed = TransitionTimelineMap.fromClips([
      clip(
        'a',
        transition: const ClipTransition(
          type: ClipTransitionType.dissolve,
          duration: Duration(milliseconds: 400),
        ),
      ),
      clip('b'),
    ]);

    Duration ms(int milliseconds) => Duration(milliseconds: milliseconds);

    /// The most flashes that start within any one second of the exported
    /// video, sampled once per renderer frame (24 a second).
    int mostFlashesPerSecond(List<VideoEffect> onOutput) {
      final onsets = <Duration>[];
      var wasOn = false;
      for (var frame = 0; frame < 24 * 7; frame++) {
        final at = Duration(microseconds: (frame + 0.5) * 1e6 ~/ 24);
        final resolved = VideoEffect.resolve(onOutput, at);
        final on = resolved.flash >= 0.5 || resolved.invert >= 0.5;
        if (on && !wasOn) onsets.add(at);
        wasOn = on;
      }
      var most = 0;
      for (final start in onsets) {
        final inWindow = onsets
            .where((t) => t >= start && t - start < const Duration(seconds: 1))
            .length;
        if (inWindow > most) most = inWindow;
      }
      return most;
    }

    VideoEffect flashing(
      VideoEffectType type,
      double intensity,
      Duration start,
      Duration end,
    ) => VideoEffect(
      type: type,
      intensity: intensity,
      startTime: start,
      endTime: end,
    );

    test('starts a flashing effect on the next whole second', () {
      final onOutput = videoEffectsOnOutput([
        flashing(.strobe, 1, ms(1300), ms(4000)),
        const VideoEffect.glitch(startTime: Duration(milliseconds: 1300)),
      ], plain);

      expect(onOutput.first.startTime, ms(2000));
      expect(onOutput.last.startTime, ms(1300));
    });

    test('leaves out a flashing piece too short to reach a whole second', () {
      expect(
        videoEffectsOnOutput([flashing(.strobe, 1, ms(1300), ms(1900))], plain),
        isEmpty,
      );
    });

    // Review finding on #9715: a negative flash split at 1.3 s flashed at
    // 1.0, 1.25, 1.3 and 1.55 s.
    test('keeps a split flashing effect at three flashes a second or fewer, '
        'wherever it is split', () {
      for (final type in [
        VideoEffectType.strobe,
        VideoEffectType.negativeFlash,
      ]) {
        for (final intensity in [0.3, 0.7, 1.0]) {
          for (var split = 50; split < 6000; split += 50) {
            for (final map in [plain, compressed]) {
              final onOutput = videoEffectsOnOutput([
                flashing(type, intensity, Duration.zero, ms(split)),
                flashing(type, intensity, ms(split), ms(6000)),
              ], map);
              expect(
                mostFlashesPerSecond(onOutput),
                lessThanOrEqualTo(3),
                reason: '$type at $intensity split at $split ms',
              );
            }
          }
        }
      }
    });

    test('keeps neighbouring flashing effects of either kind at three flashes '
        'a second or fewer', () {
      const kinds = [VideoEffectType.strobe, VideoEffectType.negativeFlash];
      for (final first in kinds) {
        for (final second in kinds) {
          for (var boundary = 50; boundary < 6000; boundary += 50) {
            for (final map in [plain, compressed]) {
              final onOutput = videoEffectsOnOutput([
                flashing(first, 1, Duration.zero, ms(boundary)),
                flashing(second, 1, ms(boundary), ms(6000)),
              ], map);
              expect(
                mostFlashesPerSecond(onOutput),
                lessThanOrEqualTo(3),
                reason: '$first then $second at $boundary ms',
              );
            }
          }
        }
      }
    });
  });
}
