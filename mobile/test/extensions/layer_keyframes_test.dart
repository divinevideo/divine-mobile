// ABOUTME: Tests how layer keyframes stay in place through timeline edits and
// ABOUTME: how they map into the pro_video_editor export.

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model;
import 'package:openvine/extensions/layer_animation_storage.dart';
import 'package:openvine/extensions/layer_keyframes.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/transition_geometry.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show
        AnimationCurve,
        AnimationPhase,
        Layer,
        LayerAnimation,
        LayerAnimationType,
        LayerKeyframe;
import 'package:pro_video_editor/pro_video_editor.dart' as pve;

void main() {
  const ms = Duration(milliseconds: 1);

  LayerKeyframe keyframe(
    int timeMs, {
    Offset offset = Offset.zero,
    double scale = 1,
    double rotation = 0,
    double opacity = 1,
    AnimationCurve curve = AnimationCurve.linear,
  }) => LayerKeyframe(
    time: ms * timeMs,
    offset: offset,
    scale: scale,
    rotation: rotation,
    opacity: opacity,
    curve: curve,
  );

  group('LayerKeyframeTimeline', () {
    group('keyframesFrom', () {
      test('keeps every keyframe at its point on the video', () {
        final layer = Layer(
          startTime: ms * 1000,
          keyframes: [keyframe(0), keyframe(500)],
        );

        final rebased = layer.keyframesFrom(ms * 1300);

        expect(rebased.map((k) => k.time), [ms * -300, ms * 200]);
        // The motion itself is unchanged: the same placement at the same
        // point of the video.
        final moved = Layer(
          startTime: ms * 1300,
          keyframes: [
            keyframe(-300),
            keyframe(200, offset: const Offset(50, 0)),
          ],
        );
        final original = Layer(
          startTime: ms * 1000,
          keyframes: [
            keyframe(0),
            keyframe(500, offset: const Offset(50, 0)),
          ],
        );
        expect(
          moved.keyframePlacementAt(ms * 1400),
          original.keyframePlacementAt(ms * 1400),
        );
      });

      test('hands the keyframes back unchanged for the same start', () {
        final layer = Layer(startTime: ms * 400, keyframes: [keyframe(0)]);

        expect(layer.keyframesFrom(ms * 400), equals(layer.keyframes));
      });
    });

    group('keyframesForPart', () {
      // On the video at 1.0, 1.5, 2.0, 2.5 and 3.0 s.
      final layer = Layer(
        startTime: ms * 1000,
        keyframes: [
          keyframe(0),
          keyframe(500, offset: const Offset(10, 0)),
          keyframe(1000, offset: const Offset(20, 0)),
          keyframe(1500, offset: const Offset(30, 0)),
          keyframe(2000, offset: const Offset(40, 0)),
        ],
      );

      test('keeps those inside and the nearest one on either side', () {
        final part = layer.keyframesForPart(ms * 1700, ms * 2700);

        // 1.5 s before the part, 2.0 and 2.5 s inside it, 3.0 s after it.
        expect(part.map((k) => k.time), [
          ms * -200,
          ms * 300,
          ms * 800,
          ms * 1300,
        ]);
      });

      test('moves the part exactly as the whole layer did', () {
        final part = Layer(
          startTime: ms * 1700,
          keyframes: layer.keyframesForPart(ms * 1700, ms * 2700),
        );

        for (var t = 1700; t <= 2700; t += 100) {
          expect(
            part.keyframePlacementAt(ms * t),
            layer.keyframePlacementAt(ms * t),
          );
        }
      });

      test('keeps the nearest keyframe of a part with none inside', () {
        final part = layer.keyframesForPart(ms * 1600, ms * 1900);

        expect(part.map((k) => k.time), [ms * -100, ms * 400]);
      });

      test('keeps the edge keyframe of a part past every keyframe', () {
        expect(
          layer.keyframesForPart(ms * 3500, ms * 4000).map((k) => k.time),
          [ms * -500],
        );
        expect(
          layer.keyframesForPart(ms * 0, ms * 500).map((k) => k.time),
          [ms * 1000],
        );
      });
    });
  });

  group('LayerExportKeyframes', () {
    const bodySize = Size(400, 800);
    const logicalSize = Size(100, 50);
    final mapping = ExportLayerMapping(
      bodySize: bodySize,
      frameSize: const Size(1080, 2160),
      targetAspectRatio: 0.5,
    );
    final timelineMap = TransitionTimelineMap.fromClips(const []);

    List<pve.TimelineKeyframe> export(
      Layer layer, {
      bool turnedRaster = true,
    }) => layer.divineKeyframesForExport(
      bodySize: bodySize,
      logicalSize: logicalSize,
      mapping: mapping,
      turnedRaster: turnedRaster,
    );

    test('is empty without keyframes', () {
      expect(export(Layer()), isEmpty);
    });

    test('places a keyframe like the layer and times it on the editor', () {
      const anchor = Offset(30, -60);
      final layer = Layer(
        startTime: ms * 1000,
        keyframes: [
          keyframe(250, offset: anchor, opacity: 0.4, curve: .easeInCubic),
        ],
      );

      final exported = export(layer).single;

      expect(exported.time, ms * 1250);
      expect(
        exported.offset,
        exportedLayerTopLeft(
          anchor: anchor,
          bodySize: bodySize,
          logicalSize: logicalSize,
          mapping: mapping,
        ),
      );
      expect(exported.opacity, 0.4);
      expect(exported.curve, pve.AnimationCurve.easeInCubic);
    });

    test('scales and turns relative to the image the layer is drawn as', () {
      final layer = Layer(
        scale: 2,
        rotation: 0.5,
        keyframes: [keyframe(0, scale: 3, rotation: 1.25)],
      );

      final exported = export(layer).single;

      expect(exported.scale, 1.5);
      expect(exported.rotation, closeTo(0.75, 1e-9));
    });

    test('turns a layer mirrored on one axis the other way', () {
      final mirrored = Layer(
        flipX: true,
        keyframes: [keyframe(0, rotation: math.pi / 2)],
      );
      final twice = Layer(
        flipX: true,
        flipY: true,
        keyframes: [keyframe(0, rotation: math.pi / 2)],
      );

      expect(export(mirrored).single.rotation, -math.pi / 2);
      expect(export(twice).single.rotation, math.pi / 2);
    });

    test('keeps the layer own turn for a clip placed upright', () {
      final layer = Layer(
        rotation: 0.5,
        keyframes: [keyframe(0, rotation: 1.25)],
      );

      expect(export(layer, turnedRaster: false).single.rotation, 1.25);
    });

    test('keeps a keyframe before the video start where it is', () {
      // What a trimmed start leaves behind once the layer is dragged to 0.
      final layer = Layer(
        startTime: ms * 500,
        keyframes: [keyframe(-1500), keyframe(1500)],
      );

      // Held at 0 instead, the layer would rush to the next keyframe.
      expect(export(layer).map((k) => k.time), [ms * -1000, ms * 2000]);
    });

    test('keeps the cycles of an effect that starts before the video', () {
      final layer = Layer(
        keyframes: [
          LayerKeyframe(
            time: ms * -1200,
            offset: Offset.zero,
            effects: const [
              LayerAnimation(
                type: LayerAnimationType.bounce,
                phase: AnimationPhase.loop,
                duration: Duration(milliseconds: 700),
              ),
            ],
          ),
          keyframe(2000),
        ],
      );

      final loop = layer
          .divineKeyframeEffectsForExport(timelineMap: timelineMap)
          .single;

      // Five 640 ms hops fill the 3.2 s stretch. The video starts 1.2 s into
      // it, 560 ms into the second hop, so the loop starts there, as the
      // editor shows it, and still ends at rest on the keyframe.
      expect(loop.duration, ms * 640);
      expect(loop.loopStart, Duration.zero);
      expect(loop.loopPhase, ms * 560);
      expect(loop.loopEnd, ms * 2000);
    });
  });

  group('divineKeyframeClockForExport', () {
    DivineVideoClip clip(String id, {pve.ClipTransition? transition}) =>
        DivineVideoClip(
          id: id,
          video: pve.EditorVideo.file('${Directory.systemTemp.path}/$id.mp4'),
          duration: const Duration(seconds: 2),
          recordedAt: DateTime(2026),
          targetAspectRatio: model.AspectRatio.vertical,
          originalAspectRatio: 9 / 16,
          transition: transition,
        );

    // Overlap transitions default to 500 ms.
    const dissolve = pve.ClipTransition(type: pve.ClipTransitionType.dissolve);
    final keyed = Layer(keyframes: [keyframe(0), keyframe(3000)]);

    test('is empty without keyframes', () {
      final timelineMap = TransitionTimelineMap.fromClips([
        clip('a', transition: dissolve),
        clip('b'),
      ]);

      expect(
        Layer().divineKeyframeClockForExport(timelineMap: timelineMap),
        isEmpty,
      );
    });

    test('is empty when the output runs as fast as the editor', () {
      final timelineMap = TransitionTimelineMap.fromClips([
        clip('a'),
        clip('b'),
      ]);

      expect(
        keyed.divineKeyframeClockForExport(timelineMap: timelineMap),
        isEmpty,
      );
    });

    test('maps each edge of a transition to its editor time', () {
      // The editor shows the 500 ms dissolve from 1.5 s to 2.5 s; the output
      // plays it from 1.5 s to 2 s.
      final timelineMap = TransitionTimelineMap.fromClips([
        clip('a', transition: dissolve),
        clip('b'),
      ]);

      expect(keyed.divineKeyframeClockForExport(timelineMap: timelineMap), [
        pve.KeyframeClockPoint(output: ms * 1500, keyframe: ms * 1500),
        pve.KeyframeClockPoint(output: ms * 2000, keyframe: ms * 2500),
      ]);
    });
  });

  group('pveCurveOf', () {
    test('maps every curve by name', () {
      for (final curve in AnimationCurve.values) {
        expect(pveCurveOf(curve).name, curve.name);
      }
    });
  });
}
