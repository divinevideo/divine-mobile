import 'dart:io';
import 'dart:typed_data';

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

  group('withoutFlashingOverlaps with lightning', () {
    Duration s(num seconds) => Duration(milliseconds: (seconds * 1000).round());

    EditorVideoEffect lightning({
      Duration? start,
      Duration? end,
      bool onBeat = false,
    }) => EditorVideoEffect.of(
      id: 'lightning',
      type: EditorEffectType.lightning,
      intensity: 0.4,
      startTime: start,
      endTime: end,
      onBeat: onBeat,
    );

    test('cuts a strobe out of the window of lightning, and leaves disco '
        'alone', () {
      final disco = EditorVideoEffect.of(
        id: 'disco',
        type: EditorEffectType.disco,
        intensity: 0.7,
      );

      final result = withoutFlashingOverlaps(
        [
          const EditorVideoEffect(id: 'strobe', effect: VideoEffect.strobe()),
          lightning(start: s(2), end: s(4)),
          disco,
        ],
        keepId: 'lightning',
        createId: () => 'piece',
      );

      expect(
        [for (final e in result!) (e.id, e.startTime, e.endTime)],
        [
          ('strobe', Duration.zero, s(2)),
          ('piece', s(4), null),
          ('lightning', s(2), s(4)),
          ('disco', null, null),
        ],
      );
    });

    test('cuts lightning out of the window of a strobe, keeping its '
        'strength and its beat', () {
      final result = withoutFlashingOverlaps(
        [
          EditorVideoEffect(
            id: 'strobe',
            effect: VideoEffect.strobe(startTime: s(1), endTime: s(3)),
          ),
          lightning(onBeat: true),
        ],
        keepId: 'strobe',
        createId: () => 'piece',
      );

      expect(
        [for (final e in result!) (e.id, e.startTime, e.endTime)],
        [
          ('strobe', s(1), s(3)),
          ('lightning', Duration.zero, s(1)),
          ('piece', s(3), null),
        ],
      );
      expect(
        [for (final e in result.skip(1)) (e.type, e.intensity, e.onBeat)],
        [
          (EditorEffectType.lightning, 0.4, true),
          (EditorEffectType.lightning, 0.4, true),
        ],
      );
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

    test('requires the flashing lights warning for lightning', () {
      expect(
        requiredContentLabelsForEffects(
          const [VideoEffect.vignette()],
          customEffects: [
            EditorVideoEffect.of(
              id: 'lightning',
              type: EditorEffectType.lightning,
              intensity: 0.5,
            ).custom!,
          ],
        ),
        {ContentLabel.flashingLights},
      );
    });

    test('requires nothing for lightning switched off, or for disco and '
        'laser on the beat', () {
      expect(
        requiredContentLabelsForEffects(
          const [],
          customEffects: [
            for (final (type, intensity) in [
              (EditorEffectType.lightning, 0.0),
              (EditorEffectType.disco, 1.0),
              (EditorEffectType.laser, 1.0),
            ])
              EditorVideoEffect.of(
                id: type.name,
                type: type,
                intensity: intensity,
                onBeat: true,
              ).custom!,
          ],
        ),
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

      test('counts a flash transition toward three flashes a second', () {
        // A 200 ms flash between the two 3 s clips starts at 2.87 s.
        final map = TransitionTimelineMap.fromClips([
          clip(
            'a',
            transition: const ClipTransition(
              type: ClipTransitionType.flash,
              duration: Duration(milliseconds: 200),
            ),
          ),
          clip('b'),
        ]);
        final beats = [ms(2400), ms(2750), ms(3100), ms(3450)];
        expect(map.flashes, [const Duration(microseconds: 2870711)]);

        final alone = videoEffectsOnOutput(
          [onBeat(.strobe)],
          plain,
          beats: beats,
        );
        final beside = videoEffectsOnOutput(
          [onBeat(.strobe)],
          map,
          beats: beats,
        );

        expect(alone.single.triggers, beats);
        final kept = beside.single.triggers;
        expect(kept.length, lessThan(beats.length));
        final flashes = [...kept, ...map.flashes]..sort();
        for (final start in flashes) {
          expect(
            flashes.where(
              (t) => t >= start && t - start < const Duration(seconds: 1),
            ),
            hasLength(lessThanOrEqualTo(3)),
            reason: 'from $start in $flashes',
          );
        }
      });

      test('counts a capped transition against beats on the next pass', () {
        final map = TransitionTimelineMap.fromClips([
          clip(
            'a',
            duration: ms(6800),
            transition: const ClipTransition(
              type: ClipTransitionType.flash,
              duration: Duration(seconds: 1),
            ),
          ),
          clip('b'),
        ]);
        final beats = [ms(0), ms(350), ms(700)];

        expect(map.flashes, [const Duration(microseconds: 6153553)]);
        final output = videoEffectsOnOutput(
          [onBeat(.strobe)],
          map,
          beats: beats,
        );

        // One transition before the cap plus these three next-pass beats
        // would otherwise put four flashes into the same looping second.
        expect(output.single.triggers.length, lessThan(beats.length));
      });

      test('counts a flash transition from where it starts, like a beat', () {
        // A 2 s flash from 3 s starts at 3.71 s, where it reaches a quarter
        // of white, and peaks at 4 s. The first beat's second holds the
        // start but not the peak.
        final map = TransitionTimelineMap.fromClips([
          clip(
            'a',
            duration: const Duration(seconds: 5),
            transition: const ClipTransition(
              type: ClipTransitionType.flash,
              duration: Duration(seconds: 2),
            ),
          ),
          clip('b', duration: const Duration(seconds: 5)),
        ]);
        final beats = [ms(2807), ms(3157), ms(3507)];

        final onOutput = videoEffectsOnOutput(
          [onBeat(.strobe)],
          map,
          beats: beats,
        );

        expect(onOutput.single.triggers, [ms(2807), ms(3157)]);
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

      group('on the beat', () {
        final zoomBlur = EditorVideoEffect.of(
          id: 'zoom',
          type: EditorEffectType.zoomBlur,
          intensity: 0.8,
          startTime: const Duration(seconds: 1),
          endTime: const Duration(seconds: 4),
          onBeat: true,
        ).custom!;

        test('fires on the beats in its window, counted from its start on '
            'the exported video', () {
          final onOutput = customVideoEffectsOnOutput(
            [zoomBlur],
            compressed,
            beats: [ms(3000), ms(500), ms(1500), ms(3600), ms(4000)],
          );

          expect(onOutput.single.startTime, ms(1000));
          expect(onOutput.single.endTime, ms(3600));
          expect(onOutput.single.params, {
            ...zoomBlur.params,
            EditorVideoEffect.beatsParam: [500000, 2000000],
          });
        });

        test('is left out without a beat in its window', () {
          expect(
            customVideoEffectsOnOutput(
              [zoomBlur, echo],
              compressed,
              beats: [ms(500), ms(4000)],
            ).map((effect) => effect.id),
            [echoVideoEffectId],
          );
        });

        test('leaves an effect that plays all through without beats', () {
          expect(
            customVideoEffectsOnOutput(const [echo], plain, beats: [ms(2000)]),
            const [echo],
          );
        });

        test('counts the beats on the player when one maps the timeline', () {
          Duration slowed(Duration editorTime) => editorTime * 2;

          final params = customVideoEffectRenderParams(
            zoomBlur,
            plain,
            [ms(2000)],
            toPlayer: slowed,
          );

          expect(params?[EditorVideoEffect.beatsParam], [2000000]);
        });

        test('keeps the beats of disco and laser a third of a second apart, '
            'and every beat of the zoom blur', () {
          final beats = [ms(1150), ms(1000), ms(1300), ms(1450), ms(1650)];
          CustomVideoEffect onBeat(EditorEffectType type) =>
              EditorVideoEffect.of(
                id: type.name,
                type: type,
                intensity: 0.8,
                onBeat: true,
              ).custom!;

          for (final type in [EditorEffectType.disco, EditorEffectType.laser]) {
            expect(
              customVideoEffectRenderParams(
                onBeat(type),
                plain,
                beats,
              )?[EditorVideoEffect.beatsParam],
              [1000000, 1450000],
              reason: type.name,
            );
          }
          expect(
            customVideoEffectRenderParams(
              onBeat(EditorEffectType.zoomBlur),
              plain,
              beats,
            )?[EditorVideoEffect.beatsParam],
            [1000000, 1150000, 1300000, 1450000, 1650000],
          );
        });
      });
    });

    group('lightningStrikesOnOutput', () {
      CustomVideoEffect lightning({
        Duration? start,
        Duration? end,
        bool onBeat = false,
      }) => EditorVideoEffect.of(
        id: 'lightning',
        type: EditorEffectType.lightning,
        intensity: 0.7,
        startTime: start,
        endTime: end,
        onBeat: onBeat,
      ).custom!;

      /// The most flashes that start within any one second of [map]'s video
      /// as it loops: [strikes], the flash transitions, and where the
      /// built-in [onOutput] turn the frame clearly white, sampled once per
      /// renderer frame (24 a second), over three passes.
      int mostFlashesPerSecondWith(
        List<Duration> strikes,
        TransitionTimelineMap map, {
        List<VideoEffect> onOutput = const [],
      }) {
        final loopPoint = map.loopPoint;
        Duration frameTime(int frame) =>
            Duration(microseconds: (frame + 0.5) * 1e6 ~/ 24);
        final onsets = <Duration>[];
        for (var pass = 0; pass < 3; pass++) {
          var wasOn = false;
          for (var frame = 0; frameTime(frame) < loopPoint; frame++) {
            final at = frameTime(frame);
            final on = VideoEffect.resolve(onOutput, at).flash >= 0.5;
            if (on && !wasOn) onsets.add(loopPoint * pass + at);
            wasOn = on;
          }
          for (final at in [...strikes, ...map.flashes]) {
            onsets.add(loopPoint * pass + at);
          }
        }
        var most = 0;
        for (final start in onsets) {
          final inWindow = onsets
              .where(
                (t) => t >= start && t - start < const Duration(seconds: 1),
              )
              .length;
          if (inWindow > most) most = inWindow;
        }
        return most;
      }

      test('strikes at irregular intervals all through its window', () {
        final effect = lightning();

        expect(lightningStrikesOnOutput([effect], plain)[effect], [
          ms(300),
          ms(1700),
          ms(2500),
          ms(4600),
          ms(5700),
        ]);
      });

      test('counts its strikes from the start of its window on the shorter '
          'exported video', () {
        final effect = lightning(
          start: const Duration(seconds: 1),
          end: const Duration(seconds: 4),
        );

        expect(lightningStrikesOnOutput([effect], compressed)[effect], [
          ms(1300),
          ms(2700),
          ms(3500),
        ]);
      });

      test('strikes on the beats in its window, skipping those under a '
          'third of a second after the one before', () {
        final effect = lightning(onBeat: true);

        expect(
          lightningStrikesOnOutput(
            [effect],
            plain,
            beats: [ms(1000), ms(1200), ms(1500), ms(2000), ms(6500)],
          )[effect],
          [ms(1000), ms(1500), ms(2000)],
        );
      });

      test('drops the strikes that would crowd a second with a flash '
          'transition', () {
        // A 200 ms flash between the two 3 s clips starts at 2.87 s.
        final map = TransitionTimelineMap.fromClips([
          clip(
            'a',
            transition: const ClipTransition(
              type: ClipTransitionType.flash,
              duration: Duration(milliseconds: 200),
            ),
          ),
          clip('b'),
        ]);
        final beats = [ms(2400), ms(2750), ms(3100), ms(3450)];
        final effect = lightning(onBeat: true);

        final alone = lightningStrikesOnOutput(
          [effect],
          plain,
          beats: beats,
        )[effect]!;
        final beside = lightningStrikesOnOutput(
          [effect],
          map,
          beats: beats,
        )[effect]!;

        expect(alone, beats);
        expect(beside, [ms(2400), ms(2750), ms(3450)]);
        expect(mostFlashesPerSecondWith(beside, map), 3);
      });

      test('drops the strikes that would crowd a second with a built-in '
          'flashing effect next to it', () {
        final strobe = videoEffectsOnOutput([
          EditorVideoEffect(
            id: 'strobe',
            effect: VideoEffect.strobe(endTime: ms(2300)),
          ),
        ], plain);
        final beats = [ms(2300), ms(2640), ms(2980), ms(3320)];
        final effect = lightning(start: ms(2300), onBeat: true);

        final strikes = lightningStrikesOnOutput(
          [effect],
          plain,
          beats: beats,
          flashingEffects: strobe,
        )[effect]!;

        expect(strikes.length, lessThan(beats.length));
        expect(
          mostFlashesPerSecondWith(strikes, plain, onOutput: strobe),
          lessThanOrEqualTo(3),
        );
      });

      test('keeps the strikes of one lightning clear of those of another', () {
        final first = lightning(end: ms(3000), onBeat: true);
        final second = lightning(start: ms(3000), onBeat: true);
        // 170 beats a minute: one every 353 ms.
        final beats = [for (var t = 0; t < 6000; t += 353) ms(t)];

        final strikes = lightningStrikesOnOutput(
          [first, second],
          plain,
          beats: beats,
        );

        expect(
          mostFlashesPerSecondWith([
            ...strikes[first]!,
            ...strikes[second]!,
          ], plain),
          lessThanOrEqualTo(3),
        );
      });

      test('hands the renderer its strikes, counted from the start of its '
          'window, and a bolt for each', () {
        final effect = lightning(
          start: const Duration(seconds: 1),
          end: const Duration(seconds: 4),
        );

        final params = customVideoEffectRenderParams(effect, plain, const []);

        expect(params?[EditorVideoEffect.strikesParam], [
          300000,
          1700000,
          2500000,
        ]);
        expect(params?[EditorVideoEffect.boltsParam], [
          ...lightningBolt(0),
          ...lightningBolt(1),
          ...lightningBolt(2),
        ]);
        expect(params, isNot(contains(EditorVideoEffect.beatsParam)));
      });

      test('counts its strikes on the player when one maps the timeline', () {
        Duration slowed(Duration editorTime) => editorTime * 2;

        final params = customVideoEffectRenderParams(
          lightning(start: ms(1000)),
          plain,
          const [],
          toPlayer: slowed,
        );

        expect(
          (params?[EditorVideoEffect.strikesParam] as List?)?.first,
          600000,
        );
      });

      test('is left out without a strike in its window', () {
        expect(
          customVideoEffectsOnOutput(
            [
              lightning(start: ms(1000), end: ms(1200)),
              lightning(onBeat: true),
            ],
            plain,
            beats: [ms(7000)],
          ),
          isEmpty,
        );
      });
    });

    group('lightningBolt', () {
      test('describes each bolt within the frame, ending 55% to 85% of the '
          'way down', () {
        for (var index = 0; index < 50; index++) {
          final bolt = lightningBolt(index);

          expect(bolt, hasLength(lightningBoltValueCount));
          expect(bolt, everyElement(inInclusiveRange(0.0, 1.0)));
          expect(bolt[1], inInclusiveRange(0.15, 0.45));
          expect(bolt.last, anyOf(0.0, 1.0));
        }
      });

      test('gives each strike its own bolt, the same every time', () {
        expect(lightningBolt(3), lightningBolt(3));
        expect(lightningBolt(3), isNot(lightningBolt(4)));
      });
    });

    group('tunnelStepDuration', () {
      test('takes 1.2 s for a copy half the size of the picture', () {
        expect(tunnelStepDuration(0.875), const Duration(milliseconds: 1200));
      });

      test('takes longer for a smaller copy, so the zoom looks equally '
          'fast', () {
        expect(tunnelStepDuration(0.2), greaterThan(tunnelStepDuration(0.9)));
      });
    });

    group('tunnelPeriodUs', () {
      CustomVideoEffect tunnel({
        EditorEffectType type = EditorEffectType.tunnel,
        Duration? startTime,
        Duration? endTime,
        bool onBeat = false,
      }) => EditorVideoEffect.of(
        id: 'tunnel',
        type: type,
        intensity: 0.7,
        startTime: startTime,
        endTime: endTime,
        onBeat: onBeat,
      ).custom!;

      test('fits a whole number of steps into a tunnel over the whole '
          'video, so it zooms on across the loop', () {
        // 6 s hold 4.1 natural steps of 1.46 s, so 4 steps of 1.5 s.
        expect(tunnelPeriodUs(tunnel(), plain), 1500000);
        // 5.6 s of exported video hold 3.8, so 4 steps of 1.4 s.
        expect(tunnelPeriodUs(tunnel(), compressed), 1400000);
      });

      test('fits the steps into a window on the exported video', () {
        final period = tunnelPeriodUs(
          tunnel(startTime: ms(1000), endTime: ms(4000)),
          compressed,
        );

        // 1 s to 3.6 s on the exported video: 2 steps of 1.3 s.
        expect(period, 1300000);
      });

      test('stops counting at the loop point of a timeline longer than the '
          'export', () {
        final long = TransitionTimelineMap.fromClips([
          clip('a', duration: ms(6800)),
        ]);

        // The export stops at 6.3 s, which holds 4.3 steps: 4 of 1.575 s.
        expect(tunnelPeriodUs(tunnel(), long), 1575000);
        expect(tunnelPeriodUs(tunnel(endTime: ms(6800)), long), 1575000);
      });

      test('keeps the natural step in a window shorter than half of it', () {
        expect(
          tunnelPeriodUs(tunnel(endTime: ms(500)), plain),
          tunnelStepDuration(0.7).inMicroseconds,
        );
      });

      test('counts the steps on the player when one maps the timeline', () {
        Duration slowed(Duration editorTime) => editorTime * 2;

        final params = customVideoEffectRenderParams(
          tunnel(),
          compressed,
          const [],
          toPlayer: slowed,
        );

        // 5.6 s of exported video hold 4 steps; on the player the window
        // runs to the 6 s editor end, doubled.
        expect(params?[EditorVideoEffect.periodParam], 3000000);
      });

      test('is what both tunnels playing all through are rendered with', () {
        for (final type in [
          EditorEffectType.tunnel,
          EditorEffectType.spiralTunnel,
        ]) {
          final rendered = customVideoEffectsOnOutput([
            tunnel(type: type),
          ], plain).single;

          expect(
            rendered.params[EditorVideoEffect.periodParam],
            1500000,
            reason: type.name,
          );
          expect(
            rendered.params[EditorVideoEffect.intensityParam],
            0.7,
            reason: type.name,
          );
        }
      });

      test('is left out of a tunnel on the beat, which steps on the '
          'beats', () {
        final rendered = customVideoEffectsOnOutput(
          [tunnel(onBeat: true)],
          plain,
          beats: [ms(2000), ms(4000)],
        ).single;

        expect(rendered.params[EditorVideoEffect.beatsParam], [
          2000000,
          4000000,
        ]);
        expect(
          rendered.params.containsKey(EditorVideoEffect.periodParam),
          isFalse,
        );
      });
    });

    group('introOutroDurationUs', () {
      CustomVideoEffect introOutro(
        EditorEffectType type, {
        Duration? startTime,
        Duration? endTime,
      }) => EditorVideoEffect.of(
        id: type.name,
        type: type,
        intensity: 1,
        startTime: startTime,
        endTime: endTime,
      ).custom!;

      test('is the length of an intro over its own window', () {
        expect(
          introOutroDurationUs(
            introOutro(
              EditorEffectType.introFade,
              startTime: Duration.zero,
              endTime: ms(1000),
            ),
            plain,
          ),
          1000000,
        );
      });

      test('runs an outro left open at its end to where the exported '
          'video loops', () {
        // 5 s on the editor timeline is 4.6 s on the exported video, which
        // ends at 5.6 s.
        expect(
          introOutroDurationUs(
            introOutro(EditorEffectType.outroCircle, startTime: ms(5000)),
            compressed,
          ),
          1000000,
        );
      });

      test('stops at the loop point of a timeline longer than the export', () {
        final long = TransitionTimelineMap.fromClips([
          clip('a', duration: ms(6800)),
        ]);

        expect(
          introOutroDurationUs(
            introOutro(
              EditorEffectType.outroCurtain,
              startTime: ms(5800),
              endTime: ms(6800),
            ),
            long,
          ),
          500000,
        );
      });

      test('counts on the player when one maps the timeline', () {
        Duration slowed(Duration editorTime) => editorTime * 2;

        final params = customVideoEffectRenderParams(
          introOutro(
            EditorEffectType.introFocus,
            startTime: Duration.zero,
            endTime: ms(1000),
          ),
          plain,
          const [],
          toPlayer: slowed,
        );

        expect(params?[EditorVideoEffect.durationParam], 2000000);
      });

      test('is what every intro and outro is rendered with, next to its '
          'intensity', () {
        for (final type in EditorEffectType.values.where(
          (type) => type.isIntroOutro,
        )) {
          final rendered = customVideoEffectsOnOutput([
            introOutro(type, startTime: ms(2000), endTime: ms(3500)),
          ], plain).single;

          expect(rendered.params, {
            EditorVideoEffect.intensityParam: 1.0,
            EditorVideoEffect.durationParam: 1500000,
          }, reason: type.name);
        }
      });

      test('is not added to an effect that plays all through its window', () {
        final snow = EditorVideoEffect.of(
          id: 'snow',
          type: EditorEffectType.snow,
          intensity: 0.7,
        ).custom!;

        expect(customVideoEffectsOnOutput([snow], plain).single.params, {
          EditorVideoEffect.intensityParam: 0.7,
        });
      });
    });

    group('customVideoEffectsInRenderOrder', () {
      CustomVideoEffect effect(String id) => CustomVideoEffect(id: id);

      test('runs the effects that read earlier frames first and the looks '
          'last, keeping the order within each', () {
        expect(
          customVideoEffectsInRenderOrder([
            effect(silverLookId),
            effect(comicVideoEffectId),
            effect(stutterVideoEffectId),
            effect(tealOrangeLookId),
            effect(snowVideoEffectId),
            effect(echoVideoEffectId),
          ]).map((effect) => effect.id),
          [
            stutterVideoEffectId,
            echoVideoEffectId,
            comicVideoEffectId,
            snowVideoEffectId,
            silverLookId,
            tealOrangeLookId,
          ],
        );
      });

      test('leaves a list already in that order as it is', () {
        final effects = [
          effect(timeWarpVideoEffectId),
          effect(snowVideoEffectId),
          effect(matteLookId),
        ];
        expect(customVideoEffectsInRenderOrder(effects), effects);
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

    test('reads a saved fisheye back as the fisheye', () {
      const fisheye = EditorVideoEffect.custom(
        id: 'fisheye-1',
        custom: CustomVideoEffect(
          id: fisheyeVideoEffectId,
          params: {EditorVideoEffect.intensityParam: 0.8},
        ),
      );

      final read = EditorVideoEffect.fromMap(fisheye.toMap(), fallbackId: 'x');

      expect(read, fisheye);
      expect(read.type, EditorEffectType.fisheye);
      expect(read.intensity, 0.8);
    });

    test('reads saved drops back as the drops, settings included', () {
      final drops = EditorVideoEffect.of(
        id: 'drops-1',
        type: EditorEffectType.drops,
        intensity: 0.8,
        settings: const {'count': 4, 'seed': 7},
      );

      final read = EditorVideoEffect.fromMap(drops.toMap(), fallbackId: 'x');

      expect(read, drops);
      expect(read.type, EditorEffectType.drops);
      expect(read.intensity, 0.8);
      expect(read.custom!.params, {
        'count': 4,
        'seed': 7,
        EditorVideoEffect.intensityParam: 0.8,
      });
    });

    test('keeps its intensity over a setting of the same name', () {
      final drops = EditorVideoEffect.of(
        id: 'drops-1',
        type: EditorEffectType.drops,
        intensity: 0.3,
        settings: const {EditorVideoEffect.intensityParam: 1},
      );

      expect(drops.intensity, 0.3);
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

    test('reads every custom type back as itself', () {
      final custom = [
        for (final type in EditorEffectType.values)
          if (type.customId != null) type,
      ];
      expect(custom, hasLength(77));
      for (final type in custom) {
        final effect = EditorVideoEffect.of(
          id: 'x',
          type: type,
          intensity: 0.5,
        );
        expect(
          EditorVideoEffect.fromMap(effect.toMap(), fallbackId: 'y').type,
          type,
        );
      }
    });

    test('only the zoom blur, the spin blur, the time split, the stutter, the '
        'tunnels, disco, laser and lightning of the custom effects fire on '
        'the beat', () {
      for (final type in [
        EditorEffectType.zoomBlur,
        EditorEffectType.timeSplit,
        EditorEffectType.stutter,
        EditorEffectType.tunnel,
        EditorEffectType.spiralTunnel,
        EditorEffectType.disco,
        EditorEffectType.laser,
        EditorEffectType.lightning,
      ]) {
        expect(type.supportsOnBeat, isTrue, reason: type.name);
      }
      final spinBlur = EditorVideoEffect.of(
        id: 'spin',
        type: EditorEffectType.spinBlur,
        intensity: 0.5,
        onBeat: true,
      );
      expect(spinBlur.onBeat, isTrue);
      expect(spinBlur.custom!.params[EditorVideoEffect.onBeatParam], isTrue);
      for (final type in [
        EditorEffectType.echo,
        EditorEffectType.longExposure,
        EditorEffectType.motionOnly,
        EditorEffectType.timeWarp,
        EditorEffectType.drops,
        EditorEffectType.lightLeak,
        EditorEffectType.confetti,
        EditorEffectType.comic,
      ]) {
        expect(type.supportsOnBeat, isFalse, reason: type.name);
        expect(
          EditorVideoEffect.of(
            id: 'x',
            type: type,
            intensity: 0.5,
            onBeat: true,
          ).onBeat,
          isFalse,
          reason: type.name,
        );
      }
    });

    test('keeps onBeat in its params, through toMap, fromMap and a move', () {
      final zoomBlur = EditorVideoEffect.of(
        id: 'zoom',
        type: EditorEffectType.zoomBlur,
        intensity: 0.5,
        onBeat: true,
      );

      expect(zoomBlur.custom!.params[EditorVideoEffect.onBeatParam], isTrue);
      final read = EditorVideoEffect.fromMap(zoomBlur.toMap(), fallbackId: 'x');
      expect(read, zoomBlur);
      expect(read.onBeat, isTrue);
      expect(
        read
            .retimed(
              startTime: const Duration(seconds: 1),
              endTime: const Duration(seconds: 2),
            )
            .onBeat,
        isTrue,
      );
      expect(
        EditorVideoEffect.of(
          id: 'zoom',
          type: EditorEffectType.zoomBlur,
          intensity: 0.5,
        ).custom!.params,
        isNot(contains(EditorVideoEffect.onBeatParam)),
      );
    });

    test('counts lightning as flashing, but not disco or laser', () {
      expect(EditorEffectType.lightning.isFlashing, isTrue);
      expect(EditorEffectType.disco.isFlashing, isFalse);
      expect(EditorEffectType.laser.isFlashing, isFalse);
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

  group(EditorEffectCategory, () {
    test('lists every type the picker offers under exactly one category, and '
        'leaves no category empty', () {
      expect(
        [for (final category in EditorEffectCategory.values) ...category.types],
        unorderedEquals(EditorEffectType.values),
      );
      for (final category in EditorEffectCategory.values) {
        expect(category.types, isNotEmpty, reason: category.name);
      }
    });

    test('lists the echo and the other effects built on earlier frames '
        'under time, and only those read earlier frames', () {
      expect(EditorEffectCategory.time.types, [
        EditorEffectType.echo,
        EditorEffectType.timeSplit,
        EditorEffectType.longExposure,
        EditorEffectType.motionOnly,
        EditorEffectType.stutter,
        EditorEffectType.timeWarp,
      ]);
      expect(
        [
          for (final type in EditorEffectType.values)
            if (type.readsEarlierFrames) type,
        ],
        EditorEffectCategory.time.types,
      );
      expect(
        EditorEffectCategory.values.indexOf(EditorEffectCategory.time),
        EditorEffectCategory.values.indexOf(EditorEffectCategory.motion) + 1,
      );
    });

    test('lists the swirl, ripple, fluted glass and the tunnels under '
        'distort, after the tilt-shift', () {
      expect(EditorEffectCategory.distort.types, [
        const EditorEffectType.builtIn(VideoEffectType.mirror),
        const EditorEffectType.builtIn(VideoEffectType.kaleidoscope),
        const EditorEffectType.builtIn(VideoEffectType.splitScreen),
        const EditorEffectType.builtIn(VideoEffectType.wave),
        EditorEffectType.fisheye,
        EditorEffectType.drops,
        EditorEffectType.tiltShift,
        EditorEffectType.swirl,
        EditorEffectType.ripple,
        EditorEffectType.flutedGlass,
        EditorEffectType.tunnel,
        EditorEffectType.spiralTunnel,
      ]);
    });

    test('lists the light rays, anamorphic, prism, window light, spotlight, '
        'disco, laser and lightning under light, after the light leak', () {
      expect(EditorEffectCategory.light.types, [
        const EditorEffectType.builtIn(VideoEffectType.strobe),
        const EditorEffectType.builtIn(VideoEffectType.negativeFlash),
        const EditorEffectType.builtIn(VideoEffectType.vignette),
        const EditorEffectType.builtIn(VideoEffectType.glow),
        EditorEffectType.lightLeak,
        EditorEffectType.lightRays,
        EditorEffectType.anamorphic,
        EditorEffectType.prism,
        EditorEffectType.windowLight,
        EditorEffectType.spotlight,
        EditorEffectType.disco,
        EditorEffectType.laser,
        EditorEffectType.lightning,
      ]);
    });

    test('lists every colour-graded look under looks, each with its own '
        'table', () {
      final looks = EditorEffectCategory.looks.types;
      expect(looks, [
        EditorEffectType.tealOrange,
        EditorEffectType.warmFilm,
        EditorEffectType.slideFilm,
        EditorEffectType.coolFilm,
        EditorEffectType.matte,
        EditorEffectType.bleachBypass,
        EditorEffectType.crossProcess,
        EditorEffectType.goldenHour,
        EditorEffectType.moonlight,
        EditorEffectType.silver,
      ]);
      expect(
        lookTableAssets.keys,
        unorderedEquals(looks.map((type) => type.customId)),
      );
      expect(lookTableAssets.values.toSet(), hasLength(looks.length));
      for (final type in looks) {
        expect(type.supportsOnBeat, isFalse, reason: type.name);
        expect(type.isFlashing, isFalse, reason: type.name);
      }
    });

    test("ships each look's table as the 1089x33 strip the renderers "
        'read', () {
      for (final asset in lookTableAssets.values) {
        final bytes = File(asset).readAsBytesSync();
        // The PNG's IHDR: width and height, 8-bit RGB.
        final header = ByteData.sublistView(bytes, 16, 26);
        expect(header.getUint32(0), 33 * 33, reason: asset);
        expect(header.getUint32(4), 33, reason: asset);
        expect(header.getUint8(8), 8, reason: asset);
        expect(header.getUint8(9), 2, reason: asset);
      }
    });

    test('lists the tape, film, screen, game and 3D looks under retro, the '
        'ones Divine draws after the built-in ones', () {
      expect(EditorEffectCategory.retro.types, [
        const EditorEffectType.builtIn(VideoEffectType.vhs),
        const EditorEffectType.builtIn(VideoEffectType.tvStatic),
        const EditorEffectType.builtIn(VideoEffectType.oldFilm),
        const EditorEffectType.builtIn(VideoEffectType.filmGrain),
        const EditorEffectType.builtIn(VideoEffectType.signalInterference),
        const EditorEffectType.builtIn(VideoEffectType.crt),
        EditorEffectType.eightBit,
        EditorEffectType.anaglyph,
      ]);
    });

    test('lists the intros under intro and the outros under outro, last, '
        'each look in the same order', () {
      expect(EditorEffectCategory.values.sublist(9), [
        EditorEffectCategory.intro,
        EditorEffectCategory.outro,
      ]);
      expect(EditorEffectCategory.intro.types, [
        EditorEffectType.introFade,
        EditorEffectType.introCircle,
        EditorEffectType.introCinema,
        EditorEffectType.introCurtain,
        EditorEffectType.introFocus,
      ]);
      expect(EditorEffectCategory.outro.types, [
        EditorEffectType.outroFade,
        EditorEffectType.outroCircle,
        EditorEffectType.outroCinema,
        EditorEffectType.outroCurtain,
        EditorEffectType.outroFocus,
      ]);
      for (final category in [
        EditorEffectCategory.intro,
        EditorEffectCategory.outro,
      ]) {
        expect(
          category.types.map((type) => type.introOutroLook),
          IntroOutroLook.values,
          reason: category.name,
        );
        for (final type in category.types) {
          expect(type.supportsOnBeat, isFalse, reason: type.name);
          expect(type.isFlashing, isFalse, reason: type.name);
          expect(EditorEffectType.byName(type.name), type, reason: type.name);
        }
      }
    });

    test('lists the paintings, drawing, prints, crafts, neon, characters and '
        'camera views under art, right after retro', () {
      expect(EditorEffectCategory.values.indexOf(EditorEffectCategory.art), 1);
      expect(EditorEffectCategory.art.types, [
        EditorEffectType.watercolor,
        EditorEffectType.oilPaint,
        EditorEffectType.pencilSketch,
        EditorEffectType.comic,
        EditorEffectType.riso,
        EditorEffectType.popArt,
        EditorEffectType.paperCut,
        EditorEffectType.crossStitch,
        EditorEffectType.bricks,
        EditorEffectType.stainedGlass,
        EditorEffectType.neonEdges,
        EditorEffectType.ascii,
        EditorEffectType.thermal,
        EditorEffectType.nightVision,
        EditorEffectType.xRay,
      ]);
      for (final type in EditorEffectCategory.art.types) {
        expect(type.supportsOnBeat, isFalse, reason: type.name);
        expect(type.isFlashing, isFalse, reason: type.name);
        expect(EditorEffectType.byName(type.name), type, reason: type.name);
      }
    });

    test('ships the ASCII glyphs as the 240x24 strip the renderers read, '
        'each glyph inked more than the one before', () {
      final bytes = File(asciiGlyphsAsset).readAsBytesSync();
      // The PNG's IHDR: width and height, 8-bit RGB.
      final header = ByteData.sublistView(bytes, 16, 26);
      const width = 10 * 24;
      expect(header.getUint32(0), width);
      expect(header.getUint32(4), 24);
      expect(header.getUint8(8), 8);
      expect(header.getUint8(9), 2);

      // The generator writes every row unfiltered, so the inflated data is
      // each row's filter byte, 0, and its pixels.
      final compressed = <int>[];
      for (var at = 8; at < bytes.length;) {
        final length = ByteData.sublistView(bytes, at, at + 4).getUint32(0);
        final type = String.fromCharCodes(bytes, at + 4, at + 8);
        if (type == 'IDAT') {
          compressed.addAll(bytes.sublist(at + 8, at + 8 + length));
        }
        at += 12 + length;
      }
      final rows = ZLibDecoder().convert(compressed);
      expect(rows, hasLength(24 * (1 + width * 3)));
      final ink = List<int>.filled(10, 0);
      for (var y = 0; y < 24; y++) {
        final row = y * (1 + width * 3);
        expect(rows[row], 0, reason: 'row $y filter');
        for (var x = 0; x < width; x++) {
          ink[x ~/ 24] += rows[row + 1 + x * 3];
        }
      }
      expect(ink.first, 0);
      for (var glyph = 1; glyph < 10; glyph++) {
        expect(ink[glyph], greaterThan(ink[glyph - 1]), reason: '$glyph');
      }
    });
  });

  group(EditorEffectPlacement, () {
    test('places the intros at the start and the outros at the end, and '
        'every other effect over the whole video', () {
      final intros = [
        EditorEffectType.introFade,
        EditorEffectType.introCircle,
        EditorEffectType.introCinema,
        EditorEffectType.introCurtain,
        EditorEffectType.introFocus,
      ];
      final outros = [
        EditorEffectType.outroFade,
        EditorEffectType.outroCircle,
        EditorEffectType.outroCinema,
        EditorEffectType.outroCurtain,
        EditorEffectType.outroFocus,
      ];
      for (final type in EditorEffectType.values) {
        expect(
          type.placement,
          intros.contains(type)
              ? EditorEffectPlacement.opening
              : outros.contains(type)
              ? EditorEffectPlacement.ending
              : EditorEffectPlacement.wholeVideo,
          reason: type.name,
        );
        expect(
          type.isIntroOutro,
          type.category == EditorEffectCategory.intro ||
              type.category == EditorEffectCategory.outro,
          reason: type.name,
        );
        expect(
          type.introOutroLook != null,
          type.isIntroOutro,
          reason: type.name,
        );
      }
    });
  });

  group('introOutroCoverage', () {
    test('covers an intro at its start and an outro at its end, halfway in '
        'the middle', () {
      for (final (ending, start, end) in [
        (false, 1.0, 0.0),
        (true, 0.0, 1.0),
      ]) {
        expect(introOutroCoverage(0, ending: ending), start);
        expect(introOutroCoverage(0.5, ending: ending), 0.5);
        expect(introOutroCoverage(1, ending: ending), end);
        expect(introOutroCoverage(1.4, ending: ending), end);
      }
    });

    test('eases out of and into rest without a jolt', () {
      // Smootherstep: the first step moves less than smoothstep's 3 p².
      const step = 0.01;
      expect(introOutroCoverage(step, ending: true), lessThan(3 * step * step));
      expect(
        1 - introOutroCoverage(1 - step, ending: true),
        lessThan(3 * step * step),
      );
    });
  });

  group('introOutroSwing', () {
    test('rests at both ends of the window', () {
      for (final ending in [false, true]) {
        expect(introOutroSwing(0, ending: ending), 0);
        expect(introOutroSwing(1, ending: ending), 0);
      }
    });

    test("trails behind a closing outro's motion and ahead of an opening "
        "intro's", () {
      expect(introOutroSwing(0.4, ending: true), greaterThan(0.5));
      expect(
        introOutroSwing(0.4, ending: false),
        -introOutroSwing(0.4, ending: true),
      );
    });

    test('swings a little past as the curtain stops', () {
      final late = introOutroSwing(0.85, ending: true);

      expect(late, lessThan(0));
      expect(late, greaterThan(-0.3));
    });
  });

  group('defaultVideoEffectWindow', () {
    const end = Duration(milliseconds: 6300);

    test('leaves an effect over the whole video open at both ends', () {
      expect(
        defaultVideoEffectWindow(EditorEffectType.snow, timelineEnd: end),
        (startTime: null, endTime: null),
      );
    });

    test('places an intro over the first second', () {
      expect(
        defaultVideoEffectWindow(EditorEffectType.introFade, timelineEnd: end),
        (startTime: Duration.zero, endTime: introOutroEffectDuration),
      );
    });

    test('places an outro over the last second, open to the end', () {
      expect(
        defaultVideoEffectWindow(EditorEffectType.outroFade, timelineEnd: end),
        (startTime: const Duration(milliseconds: 5300), endTime: null),
      );
    });

    test('keeps an intro or outro within a video shorter than a second', () {
      const short = Duration(milliseconds: 600);

      expect(
        defaultVideoEffectWindow(
          EditorEffectType.introCircle,
          timelineEnd: short,
        ),
        (startTime: Duration.zero, endTime: short),
      );
      expect(
        defaultVideoEffectWindow(
          EditorEffectType.outroCircle,
          timelineEnd: short,
        ),
        (startTime: Duration.zero, endTime: null),
      );
    });

    test('places an intro over the first second and an outro over the '
        'whole video while the end of the video is unknown', () {
      expect(
        defaultVideoEffectWindow(EditorEffectType.introCurtain),
        (startTime: Duration.zero, endTime: introOutroEffectDuration),
      );
      expect(
        defaultVideoEffectWindow(EditorEffectType.outroCurtain),
        (startTime: null, endTime: null),
      );
    });
  });
}
