import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/editor_video_effect.dart';
import 'package:openvine/models/video_editor/transition_geometry.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  group(EditorVideoEffect, () {
    const zoom = VideoEffect.zoomPulse(intensity: 0.5);

    test('stores onBeat only when it is on, and reads it back', () {
      const onBeat = EditorVideoEffect(id: 'zoom', effect: zoom, onBeat: true);
      const continuous = EditorVideoEffect(id: 'zoom', effect: zoom);

      expect(onBeat.toMap()[EditorVideoEffect.onBeatKey], isTrue);
      expect(continuous.toMap(), isNot(contains(EditorVideoEffect.onBeatKey)));
      for (final entry in [onBeat, continuous]) {
        expect(
          EditorVideoEffect.fromMap(entry.toMap(), fallbackId: 'other'),
          entry,
        );
      }
    });

    test('keeps onBeat when it is moved', () {
      const entry = EditorVideoEffect(id: 'zoom', effect: zoom, onBeat: true);

      expect(
        entry
            .retimed(
              startTime: const Duration(seconds: 1),
              endTime: const Duration(seconds: 2),
            )
            .onBeat,
        isTrue,
      );
    });
  });

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
      for (final e in effects) (e.id, e.startTime, e.endTime),
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
      expect(result[1].effect!.type, VideoEffectType.strobe);
    });

    test('keeps both pieces of a cut effect on the beat on the beat', () {
      final result = withoutFlashingOverlaps(
        [
          const EditorVideoEffect(
            id: 'negative',
            effect: VideoEffect(type: .negativeFlash),
            onBeat: true,
          ),
          effect('strobe', .strobe, s(2), s(3)),
        ],
        keepId: 'strobe',
        createId: createId,
      )!;

      expect(windows(result), [
        ('negative', Duration.zero, s(2)),
        ('piece-0', s(3), null),
        ('strobe', s(2), s(3)),
      ]);
      expect([for (final e in result) e.onBeat], [true, true, false]);
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
    DivineVideoClip clip(
      String id, {
      ClipTransition? transition,
      Duration duration = const Duration(seconds: 3),
    }) => DivineVideoClip(
      id: id,
      video: EditorVideo.file('${Directory.systemTemp.path}/$id.mp4'),
      duration: duration,
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
    /// video as it loops, sampled once per renderer frame (24 a second) over
    /// three passes, so flashes on both sides of the loop point count
    /// together.
    int mostFlashesPerSecond(
      List<VideoEffect> onOutput,
      TransitionTimelineMap map,
    ) {
      // The export, and so the loop, is capped at the maximum duration.
      final loopPoint = map.outputDuration < VideoEditorConstants.maxDuration
          ? map.outputDuration
          : VideoEditorConstants.maxDuration;
      Duration frameTime(int frame) =>
          Duration(microseconds: (frame + 0.5) * 1e6 ~/ 24);
      final onsets = <Duration>[];
      var wasOn = false;
      for (var pass = 0; pass < 3; pass++) {
        for (var frame = 0; frameTime(frame) < loopPoint; frame++) {
          final at = frameTime(frame);
          final resolved = VideoEffect.resolve(onOutput, at);
          final on = resolved.flash >= 0.5 || resolved.invert >= 0.5;
          if (on && !wasOn) onsets.add(loopPoint * pass + at);
          wasOn = on;
        }
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

    /// [effects] on the output axis, as the timeline would hold them.
    List<VideoEffect> mapped(
      List<VideoEffect> effects,
      TransitionTimelineMap map,
    ) => videoEffectsOnOutput([
      for (final (index, effect) in effects.indexed)
        EditorVideoEffect(id: 'effect_$index', effect: effect),
    ], map);

    test('starts a flashing effect on the next whole second', () {
      final onOutput = mapped([
        flashing(.strobe, 1, ms(1300), ms(4000)),
        const VideoEffect.glitch(startTime: Duration(milliseconds: 1300)),
      ], plain);

      expect(onOutput.first.startTime, ms(2000));
      expect(onOutput.last.startTime, ms(1300));
    });

    test('leaves out a flashing piece too short to reach a whole second', () {
      expect(
        mapped([flashing(.strobe, 1, ms(1300), ms(1900))], plain),
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
              final onOutput = mapped([
                flashing(type, intensity, Duration.zero, ms(split)),
                flashing(type, intensity, ms(split), ms(6000)),
              ], map);
              expect(
                mostFlashesPerSecond(onOutput, map),
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
              final onOutput = mapped([
                flashing(first, 1, Duration.zero, ms(boundary)),
                flashing(second, 1, ms(boundary), ms(6000)),
              ], map);
              expect(
                mostFlashesPerSecond(onOutput, map),
                lessThanOrEqualTo(3),
                reason: '$first then $second at $boundary ms',
              );
            }
          }
        }
      }
    });

    // #9873: a 5.5 s video with a negative flash flashed at 5.0, 5.25, 5.5
    // and 5.75 s, where it starts over.
    test('keeps flashing effects at three flashes a second or fewer across '
        'the loop point, at any video length', () {
      const kinds = [VideoEffectType.strobe, VideoEffectType.negativeFlash];
      // Up to 7 s: slowed-down clips make the timeline outlast the 6.3 s the
      // export is capped at.
      for (var length = 1000; length <= 7000; length += 50) {
        final map = TransitionTimelineMap.fromClips([
          clip('a', duration: ms(length)),
        ]);
        for (final type in kinds) {
          for (final intensity in [0.3, 0.7, 1.0]) {
            final onOutput = mapped([
              VideoEffect(type: type, intensity: intensity),
            ], map);
            expect(
              mostFlashesPerSecond(onOutput, map),
              lessThanOrEqualTo(3),
              reason: '$type at $intensity on $length ms',
            );
          }
        }
        for (final first in kinds) {
          for (final second in kinds) {
            final onOutput = mapped([
              flashing(first, 1, Duration.zero, ms(1000)),
              VideoEffect(type: second, startTime: ms(1000)),
            ], map);
            expect(
              mostFlashesPerSecond(onOutput, map),
              lessThanOrEqualTo(3),
              reason: '$first then $second on $length ms',
            );
          }
        }
      }
    });

    test('ends flashing effects on the last whole second before the loop '
        'point when the video flashes from its start', () {
      final map = TransitionTimelineMap.fromClips([
        clip('a', duration: ms(5500)),
      ]);

      expect(
        mapped(const [
          VideoEffect.negativeFlash(),
          VideoEffect.glitch(),
        ], map),
        [
          VideoEffect.negativeFlash(endTime: ms(5000)),
          const VideoEffect.glitch(),
        ],
      );
    });

    test('lets a flashing effect run to the loop point when the video does '
        'not flash from its start', () {
      final map = TransitionTimelineMap.fromClips([
        clip('a', duration: ms(5500)),
      ]);

      expect(
        mapped([
          VideoEffect.negativeFlash(startTime: ms(1300)),
        ], map),
        [VideoEffect.negativeFlash(startTime: ms(2000))],
      );
    });

    group('on the beat', () {
      EditorVideoEffect onBeat(
        VideoEffectType type, {
        Duration? start,
        Duration? end,
      }) => EditorVideoEffect(
        id: type.name,
        effect: VideoEffect(type: type, startTime: start, endTime: end),
        onBeat: true,
      );

      /// The most flashes that start within any one second of [onOutput]
      /// looping at [loopPoint]. A flash starts wherever the picture gets
      /// clearly whiter or turns negative, even while the last one is still
      /// fading. Sampled 120 times a second over enough passes to fill a few
      /// seconds, so short loops repeat within the window.
      int mostFlashRisesPerSecond(
        List<VideoEffect> onOutput,
        Duration loopPoint,
      ) {
        Duration step(int i) => Duration(microseconds: (i + 0.5) * 1e6 ~/ 120);
        final passes = 3000000 ~/ loopPoint.inMicroseconds + 3;
        final rises = <Duration>[];
        var lastFlash = 0.0;
        var lastInvert = 0.0;
        for (var pass = 0; pass < passes; pass++) {
          for (var i = 0; step(i) < loopPoint; i++) {
            final frame = VideoEffect.resolve(onOutput, step(i));
            if (frame.flash >= lastFlash + 0.1 ||
                (frame.invert >= 0.5 && lastInvert < 0.5)) {
              rises.add(loopPoint * pass + step(i));
            }
            lastFlash = frame.flash;
            lastInvert = frame.invert;
          }
        }
        var most = 0;
        for (final start in rises) {
          final n = rises
              .where(
                (t) => t >= start && t - start < const Duration(seconds: 1),
              )
              .length;
          if (n > most) most = n;
        }
        return most;
      }

      test('counts a flash on the first frame apart from one still fading '
          'at the loop point', () {
        final map = TransitionTimelineMap.fromClips([
          clip('a', duration: ms(5500)),
        ]);
        final onOutput = videoEffectsOnOutput(
          [onBeat(.strobe)],
          map,
          beats: [ms(0), for (var t = 590; t <= 5420; t += 345) ms(t)],
        );
        expect(
          mostFlashRisesPerSecond(onOutput, map.outputDuration),
          lessThanOrEqualTo(3),
        );
      });

      test('counts the flash of a continuous strobe on the first frame apart '
          'from a beat still fading at the loop point', () {
        final map = TransitionTimelineMap.fromClips([
          clip('a', duration: ms(5500)),
        ]);
        final onOutput = videoEffectsOnOutput(
          [
            const EditorVideoEffect(
              id: 'continuous',
              effect: VideoEffect(
                type: VideoEffectType.strobe,
                endTime: Duration(seconds: 1),
              ),
            ),
            onBeat(.strobe, start: ms(1000)),
          ],
          map,
          beats: [for (var t = 1280; t <= 5420; t += 345) ms(t)],
        );
        expect(
          mostFlashRisesPerSecond(onOutput, map.outputDuration),
          lessThanOrEqualTo(3),
        );
      });

      test(
        'counts a neighbouring flash that starts while a beat still fades',
        () {
          final map = TransitionTimelineMap.fromClips([
            clip('a', duration: ms(5500)),
          ]);
          final onOutput = videoEffectsOnOutput(
            [
              onBeat(.strobe, end: ms(2000)),
              EditorVideoEffect(
                id: 'negative',
                effect: VideoEffect(
                  type: VideoEffectType.negativeFlash,
                  intensity: 0.4,
                  startTime: ms(2000),
                  endTime: ms(3000),
                ),
              ),
              onBeat(.strobe, start: ms(3000)),
            ],
            map,
            beats: [
              for (var t = 540; t <= 1920; t += 345) ms(t),
              for (var t = 3050; t < 5500; t += 345) ms(t),
            ],
          );
          expect(
            mostFlashRisesPerSecond(onOutput, map.outputDuration),
            lessThanOrEqualTo(3),
          );
        },
      );

      test('keeps loops shorter than a second, or than a hit, within three '
          'flashes a second with a beat on the first frame', () {
        for (final (length, beats) in [
          (448, [ms(0), ms(360)]),
          (70, [ms(0)]),
        ]) {
          final map = TransitionTimelineMap.fromClips([
            clip('a', duration: ms(length)),
          ]);
          final onOutput = videoEffectsOnOutput(
            [onBeat(.strobe)],
            map,
            beats: beats,
          );
          expect(
            mostFlashRisesPerSecond(onOutput, map.outputDuration),
            lessThanOrEqualTo(3),
            reason: '$length ms loop',
          );
        }
      });

      /// A beat every 60/[bpm] seconds from [first] until [until].
      List<Duration> beatsAt(
        double bpm, {
        Duration first = Duration.zero,
        Duration until = const Duration(seconds: 7),
      }) => [
        for (
          var t = first.inMicroseconds.toDouble();
          t < until.inMicroseconds;
          t += 60e6 / bpm
        )
          Duration(microseconds: t.round()),
      ];

      /// The most flashes that start within any one second of [onOutput]
      /// looping at [loopPoint], sampled 120 times a second over three passes.
      int mostFlashesPerSecondOnLoop(
        List<VideoEffect> onOutput,
        Duration loopPoint,
      ) {
        Duration step(int index) =>
            Duration(microseconds: (index + 0.5) * 1e6 ~/ 120);
        final onsets = <Duration>[];
        var wasOn = false;
        for (var pass = 0; pass < 3; pass++) {
          for (var i = 0; step(i) < loopPoint; i++) {
            final frame = VideoEffect.resolve(onOutput, step(i));
            final on = frame.flash >= 0.5 || frame.invert >= 0.5;
            if (on && !wasOn) onsets.add(loopPoint * pass + step(i));
            wasOn = on;
          }
        }
        var most = 0;
        for (final start in onsets) {
          final inSecond = onsets
              .where(
                (t) => t >= start && t - start < const Duration(seconds: 1),
              )
              .length;
          if (inSecond > most) most = inSecond;
        }
        return most;
      }

      test('fires on the beats in its window', () {
        final onOutput = videoEffectsOnOutput(
          [onBeat(.zoomPulse, start: ms(1000), end: ms(3000))],
          plain,
          beats: [ms(500), ms(1500), ms(2500), ms(3500)],
        );

        expect(onOutput.single.startTime, ms(1000));
        expect(onOutput.single.endTime, ms(3000));
        expect(onOutput.single.triggers, [ms(1500), ms(2500)]);
      });

      test('is left out without a beat in its window, and does not start a '
          'flash on the whole-second grid', () {
        expect(
          videoEffectsOnOutput([onBeat(.zoomPulse)], plain),
          isEmpty,
        );
        expect(
          videoEffectsOnOutput(
            [onBeat(.strobe, start: ms(1300))],
            plain,
            beats: [ms(1400)],
          ).single.startTime,
          ms(1300),
        );
      });

      test('flashes on every other beat of a song too fast for every one', () {
        final onOutput = videoEffectsOnOutput(
          [onBeat(.strobe)],
          plain,
          beats: beatsAt(200, until: ms(6000)),
        );

        final triggers = onOutput.single.triggers;
        expect(triggers, hasLength(10));
        for (var i = 1; i < triggers.length; i++) {
          expect(triggers[i] - triggers[i - 1], ms(600));
        }
      });

      test('keeps flashing at three flashes a second or fewer across the loop '
          'point, next to a flashing effect that plays all through', () {
        for (var length = 2000; length <= 6300; length += 350) {
          final map = TransitionTimelineMap.fromClips([
            clip('a', duration: ms(length)),
          ]);
          for (var bpm = 100.0; bpm <= 200; bpm += 10) {
            for (final type in [
              VideoEffectType.strobe,
              VideoEffectType.negativeFlash,
            ]) {
              for (final effects in [
                [onBeat(type)],
                [
                  EditorVideoEffect(
                    id: 'continuous',
                    effect: VideoEffect(
                      type: VideoEffectType.negativeFlash,
                      endTime: ms(1000),
                    ),
                  ),
                  onBeat(type, start: ms(1000)),
                ],
              ]) {
                final onOutput = videoEffectsOnOutput(
                  effects,
                  map,
                  beats: beatsAt(bpm, first: ms(130), until: ms(length)),
                );
                expect(
                  mostFlashesPerSecondOnLoop(onOutput, map.outputDuration),
                  lessThanOrEqualTo(3),
                  reason: '$type at $bpm bpm on $length ms, $effects',
                );
              }
            }
          }
        }
      });

      test('leaves a flashing effect on the beat to its beats at the loop '
          'point, rather than ending it on the last whole second', () {
        final map = TransitionTimelineMap.fromClips([
          clip('a', duration: ms(5500)),
        ]);

        final onOutput = videoEffectsOnOutput(
          [onBeat(.strobe)],
          map,
          beats: [ms(500), ms(5200)],
        );

        expect(onOutput.single.endTime, isNull);
        expect(onOutput.single.triggers, [ms(500), ms(5200)]);
      });

      test('limits flashes across every repetition of a sub-second loop', () {
        for (final length in [100, 200, 250, 300, 400, 600]) {
          final map = TransitionTimelineMap.fromClips([
            clip('a', duration: ms(length)),
          ]);
          for (final type in [
            VideoEffectType.strobe,
            VideoEffectType.negativeFlash,
          ]) {
            for (final intensity in [0.1, 1.0]) {
              final effects = videoEffectsOnOutput(
                [
                  EditorVideoEffect(
                    id: 'quiet-flash',
                    effect: VideoEffect(type: type, intensity: intensity),
                    onBeat: true,
                  ),
                ],
                map,
                beats: [ms(50)],
              );
              var flashes = 0;
              var wasOn = false;
              for (var at = 0; at < 1000; at++) {
                final frame = VideoEffect.resolve(effects, ms(at % length));
                final on = frame.flash > 0 || frame.invert > 0;
                if (on && !wasOn) flashes++;
                wasOn = on;
              }
              expect(
                flashes,
                lessThanOrEqualTo(3),
                reason: '$type at $intensity on a $length ms loop',
              );
            }
          }
        }
      });
    });

    group('customVideoEffectsOnOutput', () {
      const echo = CustomVideoEffect(
        id: echoVideoEffectId,
        params: {EditorVideoEffect.intensityParam: 0.6},
        startTime: Duration(seconds: 1),
        endTime: Duration(seconds: 4),
      );

      test('moves the window onto the shorter exported video', () {
        expect(customVideoEffectsOnOutput(const [echo], compressed), [
          CustomVideoEffect(
            id: echoVideoEffectId,
            params: echo.params,
            startTime: ms(1000),
            endTime: ms(3600),
          ),
        ]);
      });

      test('leaves the window alone when no transition shortens the '
          'video', () {
        expect(customVideoEffectsOnOutput(const [echo], plain), const [echo]);
      });

      test('keeps an end that reaches the end of the video open', () {
        const untilTheEnd = CustomVideoEffect(
          id: echoVideoEffectId,
          startTime: Duration(seconds: 1),
        );

        final onOutput = customVideoEffectsOnOutput(const [
          untilTheEnd,
        ], compressed);

        expect(onOutput.single.startTime, ms(1000));
        expect(onOutput.single.endTime, isNull);
      });
    });
  });

  group('EditorVideoEffect custom', () {
    const echo = EditorVideoEffect.custom(
      id: 'echo-1',
      custom: CustomVideoEffect(
        id: echoVideoEffectId,
        params: {EditorVideoEffect.intensityParam: 0.4, 'unrelated': 'kept'},
        startTime: Duration(seconds: 1),
      ),
    );

    test('reads its type, intensity and window from the custom effect', () {
      expect(echo.type, EditorEffectType.echo);
      expect(echo.intensity, 0.4);
      expect(echo.startTime, const Duration(seconds: 1));
      expect(echo.endTime, isNull);
      expect(echo.effect, isNull);
    });

    test('survives toMap and fromMap', () {
      expect(EditorVideoEffect.fromMap(echo.toMap(), fallbackId: 'x'), echo);
    });

    test('rejects a custom effect this build does not know', () {
      final map = {
        EditorVideoEffect.idKey: 'a',
        EditorVideoEffect.customKey: const CustomVideoEffect(
          id: 'someone.else',
        ).toMap(),
      };
      expect(
        () => EditorVideoEffect.fromMap(map, fallbackId: 'x'),
        throwsArgumentError,
      );
    });

    test('keeps its params when retimed', () {
      final moved = echo.retimed(
        startTime: const Duration(seconds: 2),
        endTime: const Duration(seconds: 3),
      );
      expect(moved.custom!.params, echo.custom!.params);
      expect(moved.startTime, const Duration(seconds: 2));
      expect(moved.endTime, const Duration(seconds: 3));
    });

    test('never counts as flashing', () {
      expect(EditorEffectType.echo.isFlashing, isFalse);
      expect(
        withoutFlashingOverlaps(
          [echo],
          keepId: 'echo-1',
          createId: () => 'new',
        ),
        isNull,
      );
    });
  });
}
