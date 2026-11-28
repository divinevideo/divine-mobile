import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/editor_video_effect.dart';
import 'package:openvine/models/video_editor/transition_geometry.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

Duration _ms(int value) => Duration(milliseconds: value);

TransitionTimelineMap _timeline(Duration duration) =>
    TransitionTimelineMap.fromClips([
      DivineVideoClip(
        id: 'gray',
        video: EditorVideo.file('${Directory.systemTemp.path}/gray.mp4'),
        duration: duration,
        recordedAt: DateTime(2026),
        targetAspectRatio: model.AspectRatio.vertical,
        originalAspectRatio: 9 / 16,
      ),
    ]);

// Opaque, uniform sRGB gray through the renderer's brightness, invert and
// flash operations, followed by sRGB linearization for relative luminance.
// Counting only flash/invert misses the rise when a dimmed strobe ends.
double _luminance(VideoEffectFrame frame) {
  var channel = 0.7 * (1 + frame.brightness);
  channel += frame.invert * (1 - 2 * channel);
  channel += frame.flash * (1 - channel);
  channel = channel.clamp(0, 1);
  return channel <= 0.04045
      ? channel / 12.92
      : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
}

int _mostLuminanceRises(
  List<VideoEffect> effects,
  Duration loopPoint, {
  required int fps,
  double phase = 0.5,
}) {
  Duration sample(int frame) =>
      Duration(microseconds: (frame + phase) * 1000000 ~/ fps);
  final rises = <Duration>[];
  var previous = _luminance(
    VideoEffect.resolve(effects, loopPoint - const Duration(microseconds: 1)),
  );
  for (var pass = 0; pass < 3; pass++) {
    for (var frame = 0; sample(frame) < loopPoint; frame++) {
      final at = sample(frame);
      final now = _luminance(VideoEffect.resolve(effects, at));
      if (now - previous >= 0.1) rises.add(loopPoint * pass + at);
      previous = now;
    }
  }
  var most = 0;
  for (final start in rises) {
    final count = rises
        .where((at) => at >= start && at - start < const Duration(seconds: 1))
        .length;
    most = math.max(most, count);
  }
  return most;
}

void main() {
  group('strobe boundary flash safety', () {
    test('counts returning from dim footage beside a negative flash', () {
      final map = _timeline(_ms(2000));
      final effects = videoEffectsOnOutput([
        EditorVideoEffect(
          id: 'strobe',
          effect: VideoEffect.strobe(
            endTime: _ms(900),
            params: const {VideoEffectParams.tempo: 0.9},
          ),
        ),
        EditorVideoEffect(
          id: 'negative',
          effect: VideoEffect.negativeFlash(startTime: _ms(1000)),
        ),
      ], map);

      // The negative flash must remain; deleting every effect is not a fix.
      expect(
        effects.any((effect) => effect.type == VideoEffectType.strobe),
        isTrue,
      );
      expect(
        effects.any((effect) => effect.type == VideoEffectType.negativeFlash),
        isTrue,
      );
      expect(effects.first.intensity, 1);
      expect(VideoEffect.resolve(effects, _ms(10)).flash, 1);
      expect(VideoEffect.resolve(effects, _ms(570)).flash, 1);
      expect(VideoEffect.resolve(effects, _ms(1010)).invert, 1);
      for (final fps in [24, 30, 60, 120]) {
        expect(
          _mostLuminanceRises(effects, map.loopPoint, fps: fps),
          lessThanOrEqualTo(3),
          reason: '$fps fps, including the return from dim footage and looping',
        );
      }
    });
    test('preserves safe continuous strobe timing and settings', () {
      final map = _timeline(_ms(6000));
      final strobe = VideoEffect.strobe(
        endTime: _ms(5000),
        intensity: 0.8,
        params: const {VideoEffectParams.tempo: 0.9},
      );
      final effects = videoEffectsOnOutput([
        EditorVideoEffect(id: 'strobe', effect: strobe),
      ], map);

      expect(effects, [strobe]);
      expect(
        _mostLuminanceRises(effects, map.loopPoint, fps: 60),
        lessThanOrEqualTo(3),
      );
    });

    test('keeps window recoveries within the limit at different tempos', () {
      for (final tempo in [null, 0.5, 0.75, 0.9]) {
        for (final duration in [2000, 2300, 5500]) {
          final map = _timeline(_ms(duration));
          for (final end in [300, 450, 650, 900, 1300, 1800]) {
            final negativeStart = ((end + 999) ~/ 1000) * 1000;
            final effects = videoEffectsOnOutput([
              EditorVideoEffect(
                id: 'strobe',
                effect: VideoEffect.strobe(
                  endTime: _ms(end),
                  params: {
                    VideoEffectParams.tempo: ?tempo,
                  },
                ),
              ),
              EditorVideoEffect(
                id: 'negative',
                effect: VideoEffect.negativeFlash(
                  startTime: _ms(negativeStart),
                ),
              ),
            ], map);
            for (final fps in [24, 30, 60, 120]) {
              expect(
                _mostLuminanceRises(effects, map.loopPoint, fps: fps),
                lessThanOrEqualTo(3),
                reason:
                    'tempo $tempo, end $end ms, loop $duration ms, $fps fps',
              );
            }
            for (final effect in effects) {
              expect(
                effect.params,
                effect.type == VideoEffectType.strobe
                    ? {VideoEffectParams.tempo: ?tempo}
                    : isEmpty,
              );
              for (final trigger in effect.triggers) {
                expect(
                  trigger,
                  greaterThanOrEqualTo(effect.startTime ?? Duration.zero),
                );
                if (effect.endTime != null) {
                  expect(trigger, lessThan(effect.endTime!));
                }
              }
            }
          }
        }
      }
    });
    test('reserves the dimming recovery before scheduling custom flashes', () {
      final map = _timeline(_ms(2000));
      final strobe = videoEffectsOnOutput([
        EditorVideoEffect(
          id: 'strobe',
          effect: VideoEffect.strobe(
            endTime: _ms(900),
          ),
        ),
      ], map);
      final lightning = EditorVideoEffect.of(
        id: 'lightning',
        type: EditorEffectType.lightning,
        intensity: 1,
        startTime: _ms(1000),
        onBeat: true,
      ).custom!;

      expect(strobe.single.triggers, isEmpty);
      final strikes = flashStrikesOnOutput(
        [lightning],
        map,
        beats: [_ms(1000), _ms(1400)],
        flashingEffects: strobe,
      )[lightning];

      // Pulses at 0 and 500 ms, recovery at 900 ms: a strike at 1400 ms
      // would make four in the second starting at the second pulse.
      expect(strikes, [_ms(1000)]);
    });
    test('counts a negative echo clipped between sampling ticks', () {
      final map = _timeline(_ms(3120));
      final effects = videoEffectsOnOutput([
        EditorVideoEffect(
          id: 'negative',
          effect: VideoEffect.negativeFlash(
            intensity: 0.7,
            endTime: _ms(253),
            params: const {VideoEffectParams.length: 2.3},
          ),
        ),
        EditorVideoEffect(
          id: 'strobe',
          effect: VideoEffect.strobe(
            intensity: 0.7,
            startTime: _ms(253),
            params: const {VideoEffectParams.tempo: 0.6},
          ),
        ),
      ], map);

      for (final fps in [24, 30, 60, 120]) {
        for (final phase in [0.0, 0.5]) {
          expect(
            _mostLuminanceRises(effects, map.loopPoint, fps: fps, phase: phase),
            lessThanOrEqualTo(3),
            reason: '$fps fps, phase $phase: echo from 250 to 253 ms',
          );
        }
      }
    });
    test('budgets negative returns on bright footage across the loop', () {
      for (final negativeFirst in [true, false]) {
        final map = _timeline(_ms(negativeFirst ? 4004 : 3016));
        final split = _ms(negativeFirst ? 2679 : 189);
        final effects = videoEffectsOnOutput([
          EditorVideoEffect(
            id: 'negative',
            effect: VideoEffect.negativeFlash(
              intensity: negativeFirst ? 0.85 : 0.65,
              startTime: negativeFirst ? null : split,
              endTime: negativeFirst ? split : null,
              params: {VideoEffectParams.length: negativeFirst ? 2.1 : 2.65},
            ),
          ),
          EditorVideoEffect(
            id: 'strobe',
            effect: VideoEffect.strobe(
              intensity: negativeFirst ? 0.85 : 0.65,
              startTime: negativeFirst ? split : null,
              endTime: negativeFirst ? null : split,
              params: {VideoEffectParams.tempo: negativeFirst ? 0.9 : 0.67},
            ),
          ),
        ], map);

        for (final fps in [24, 30, 60, 120]) {
          for (final phase in [0.0, 0.5]) {
            expect(
              _mostLuminanceRises(
                effects,
                map.loopPoint,
                fps: fps,
                phase: phase,
              ),
              lessThanOrEqualTo(3),
              reason: 'negative first $negativeFirst, $fps fps, phase $phase',
            );
          }
        }
      }
    });
    test('reserves negative returns before scheduling custom flashes', () {
      final map = _timeline(_ms(2800));
      final negative = videoEffectsOnOutput([
        EditorVideoEffect(
          id: 'negative',
          effect: VideoEffect.negativeFlash(
            intensity: 0.65,
            startTime: _ms(1000),
            endTime: _ms(2750),
            params: const {VideoEffectParams.length: 2.65},
          ),
        ),
      ], map);
      final lightning = EditorVideoEffect.of(
        id: 'lightning',
        type: EditorEffectType.lightning,
        intensity: 1,
        endTime: _ms(1000),
        onBeat: true,
      ).custom!;

      final strikes = flashStrikesOnOutput(
        [lightning],
        map,
        beats: [Duration.zero, _ms(350)],
        flashingEffects: negative,
      )[lightning];

      // The negative returns near 2208 and 2292 ms. On the next loop, two
      // strikes at 2800 and 3150 ms would crowd that second with four rises.
      expect(strikes, [Duration.zero]);
    });
    test(
      'avoids a tail recovery crowding delayed video frames at the loop',
      () {
        for (final (duration, end, intensity) in [
          (5094, 5054, 0.55),
          (2193, 2074, 0.32),
        ]) {
          final map = _timeline(_ms(duration));
          final effects = videoEffectsOnOutput([
            EditorVideoEffect(
              id: 'strobe',
              effect: VideoEffect.strobe(
                intensity: intensity,
                endTime: _ms(end),
                params: const {VideoEffectParams.tempo: 0.85},
              ),
            ),
          ], map);

          for (final fps in [24, 30, 60, 120]) {
            for (final phase in [0.0, 0.5]) {
              expect(
                _mostLuminanceRises(
                  effects,
                  map.loopPoint,
                  fps: fps,
                  phase: phase,
                ),
                lessThanOrEqualTo(3),
                reason: 'loop $duration ms, $fps fps, phase $phase',
              );
            }
          }
        }
      },
    );
    test('trims only the final dark tail and retains every pulse', () {
      final map = _timeline(_ms(2193));
      final effects = videoEffectsOnOutput([
        EditorVideoEffect(
          id: 'strobe',
          effect: VideoEffect.strobe(
            intensity: 0.55,
            endTime: _ms(2074),
            params: const {VideoEffectParams.tempo: 0.85},
          ),
        ),
      ], map);

      expect(effects.single.intensity, 0.55);
      expect(effects.single.params, {VideoEffectParams.tempo: 0.85});
      expect(effects.single.triggers, isEmpty);
      for (final at in [0, 600, 1200, 1750]) {
        expect(VideoEffect.resolve(effects, _ms(at)).flash, 0.8);
      }
      expect(VideoEffect.resolve(effects, _ms(300)).brightness, -0.275);
      expect(VideoEffect.resolve(effects, _ms(1850)).flash, greaterThan(0));
      expect(VideoEffect.resolve(effects, _ms(1880)), VideoEffectFrame.none);
    });

    test('retains a window ending inside the last flash fade', () {
      final map = _timeline(_ms(2193));
      final strobe = VideoEffect.strobe(
        endTime: _ms(650),
        params: const {VideoEffectParams.tempo: 0.9},
      );
      final effects = videoEffectsOnOutput([
        EditorVideoEffect(id: 'strobe', effect: strobe),
      ], map);

      expect(effects, [strobe]);
      expect(VideoEffect.resolve(effects, _ms(640)).flash, greaterThan(0));
      expect(VideoEffect.resolve(effects, _ms(660)), VideoEffectFrame.none);
    });
  });
}
