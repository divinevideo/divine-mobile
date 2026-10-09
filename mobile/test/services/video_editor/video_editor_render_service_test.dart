// ABOUTME: Tests VideoEditorRenderService.buildImageLayers and
// ABOUTME: buildColorFilters — the overlay-layer scaling and editor→output
// ABOUTME: timeline mapping applied to layers, tune adjustments and filters at
// ABOUTME: export.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Color, Offset, Size;

import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter/widgets.dart' show SizedBox;
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model;
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/aspect_ratio_extensions.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/models/video_editor/detached_clip_layer.dart';
import 'package:openvine/models/video_editor/editor_video_effect.dart';
import 'package:openvine/models/video_editor/transition_geometry.dart';
import 'package:openvine/services/video_editor/render_cancellation_registry.dart';
import 'package:openvine/services/video_editor/stop_motion_render_service.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
import 'package:pro_image_editor/pro_image_editor.dart' as pie;
import 'package:pro_video_editor/pro_video_editor.dart'
    show
        AnimationPhase,
        ClipTransition,
        ClipTransitionType,
        EditorVideo,
        ImageLayer,
        KeyframeClockPoint,
        LayerAnimationType,
        NativeFailureDetails,
        ProVideoEditor,
        ProgressModel,
        RenderCanceledException,
        RenderEncoderException,
        VideoEffect,
        VideoEffectType,
        VideoQualityConfig,
        VideoRenderData,
        VideoSegment;

void main() {
  DivineVideoClip clip(
    String id,
    Duration duration, {
    ClipTransition? transition,
  }) => DivineVideoClip(
    id: id,
    video: EditorVideo.file('${Directory.systemTemp.path}/$id.mp4'),
    duration: duration,
    recordedAt: DateTime(2026),
    targetAspectRatio: model.AspectRatio.vertical,
    originalAspectRatio: 9 / 16,
    transition: transition,
  );

  pie.ExportedLayer layer({
    Duration? startTime,
    Duration? endTime,
    Offset offset = Offset.zero,
    Size logicalSize = const Size(10, 20),
  }) => pie.ExportedLayer(
    layer: pie.Layer(startTime: startTime, endTime: endTime, offset: offset),
    bytes: Uint8List.fromList(const [1, 2, 3]),
    logicalSize: logicalSize,
  );

  // Two 2s clips joined by a 400ms dissolve: an overlap removes its 400ms
  // blend, so the 4s editor timeline renders to a 3.6s output. The transition
  // is the outgoing transition of clip A (the a→b boundary).
  final overlapClips = [
    clip(
      'a',
      const Duration(seconds: 2),
      transition: const ClipTransition(
        type: ClipTransitionType.dissolve,
        duration: Duration(milliseconds: 400),
      ),
    ),
    clip('b', const Duration(seconds: 2)),
  ];
  final noTransitionClips = [
    clip('a', const Duration(seconds: 2)),
    clip('b', const Duration(seconds: 2)),
  ];

  group('buildImageLayers', () {
    final vertical = model.AspectRatio.vertical.value;

    test('returns null when there are no captured layers', () {
      expect(
        VideoEditorRenderService.buildImageLayers(
          capturedLayers: const [],
          bodySize: const Size(100, 200),
          videoSize: const Size(300, 600),
          targetAspectRatio: vertical,
          timelineMap: TransitionTimelineMap.fromClips(noTransitionClips),
        ),
        isNull,
      );
    });

    test(
      'times a keyframed layer on the editor timeline through its clock',
      () {
        final keyframed = pie.ExportedLayer(
          layer: pie.Layer(
            startTime: const Duration(seconds: 1),
            scale: 2,
            keyframes: const [
              pie.LayerKeyframe(time: Duration.zero, offset: Offset.zero),
              pie.LayerKeyframe(
                // 3.0 s on the editor timeline, past the 400 ms dissolve.
                time: Duration(seconds: 2),
                offset: Offset(10, 0),
                scale: 3,
                opacity: 0.5,
              ),
            ],
          ),
          bytes: Uint8List.fromList(const [1, 2, 3]),
          logicalSize: const Size(10, 20),
        );

        final exported = VideoEditorRenderService.buildImageLayers(
          capturedLayers: [keyframed],
          bodySize: const Size(100, 200),
          videoSize: const Size(300, 600),
          targetAspectRatio: vertical,
          timelineMap: TransitionTimelineMap.fromClips(overlapClips),
        )!.single;

        expect(exported.keyframes.map((k) => k.time), [
          const Duration(seconds: 1),
          const Duration(seconds: 3),
        ]);
        // The editor shows the dissolve from 1.6 s to 2.4 s; the output plays
        // it from 1.6 s to 2.0 s.
        expect(exported.keyframeClock, const [
          KeyframeClockPoint(
            output: Duration(milliseconds: 1600),
            keyframe: Duration(milliseconds: 1600),
          ),
          KeyframeClockPoint(
            output: Duration(milliseconds: 2000),
            keyframe: Duration(milliseconds: 2400),
          ),
        ]);
        // Three times the editor's 100 px wide body.
        expect(exported.keyframes.last.offset.dx - exported.offset!.dx, 30);
        expect(exported.keyframes.last.scale, 1.5);
        expect(exported.keyframes.last.opacity, 0.5);
      },
    );

    /// The time [output] is at on [exported]'s keyframe clock, the way both
    /// renderers read it: linear between two points, and as fast as the
    /// output before the first and after the last.
    Duration clockTime(ImageLayer exported, Duration output) {
      final points = exported.keyframeClock;
      if (points.isEmpty) return output;
      if (output <= points.first.output) {
        return points.first.keyframe + (output - points.first.output);
      }
      for (var i = 1; i < points.length; i++) {
        final to = points[i];
        if (output > to.output) continue;
        final from = points[i - 1];
        final share =
            (output - from.output).inMicroseconds /
            (to.output - from.output).inMicroseconds;
        return from.keyframe +
            Duration(
              microseconds:
                  (share * (to.keyframe - from.keyframe).inMicroseconds)
                      .round(),
            );
      }
      return points.last.keyframe + (output - points.last.output);
    }

    /// The placement the renderer draws at [output], from the exported
    /// keyframes read on their clock: both packages interpolate keyframes
    /// alike.
    pie.LayerPlacement renderedAt(ImageLayer exported, Duration output) =>
        pie.Layer(
          keyframes: [
            for (final keyframe in exported.keyframes)
              pie.LayerKeyframe(
                time: keyframe.time,
                offset: keyframe.offset,
                scale: keyframe.scale,
                rotation: keyframe.rotation,
                opacity: keyframe.opacity,
                curve: pie.AnimationCurve.values.byName(keyframe.curve.name),
              ),
          ],
        ).keyframePlacementAt(clockTime(exported, output))!;

    ImageLayer exportOverOverlap(pie.Layer layer) =>
        VideoEditorRenderService.buildImageLayers(
          capturedLayers: [
            pie.ExportedLayer(
              layer: layer,
              bytes: Uint8List.fromList(const [1, 2, 3]),
              logicalSize: const Size(10, 20),
            ),
          ],
          bodySize: const Size(100, 200),
          videoSize: const Size(300, 600),
          targetAspectRatio: vertical,
          timelineMap: TransitionTimelineMap.fromClips(overlapClips),
        )!.single;

    test('preserves linear placement across an overlap transition', () {
      final source = pie.Layer(
        keyframes: const [
          pie.LayerKeyframe(time: Duration.zero, offset: Offset.zero),
          pie.LayerKeyframe(
            time: Duration(seconds: 4),
            offset: Offset(100, 0),
            scale: 3,
            rotation: 0.6,
            opacity: 0.2,
          ),
        ],
      );
      final timelineMap = TransitionTimelineMap.fromClips(overlapClips);

      final exported = exportOverOverlap(source);

      expect(
        source.keyframePlacementAt(const Duration(seconds: 1))!.offset.dx,
        25,
      );
      for (final milliseconds in [
        0,
        1000,
        1600,
        1800,
        2000,
        2400,
        2800,
        4000,
      ]) {
        final editorTime = Duration(milliseconds: milliseconds);
        final preview = source.keyframePlacementAt(editorTime)!;
        final rendered = renderedAt(
          exported,
          timelineMap.editorToOutput(editorTime),
        );
        expect(
          rendered.offset.dx - exported.keyframes.first.offset.dx,
          closeTo(preview.offset.dx * 3, 1e-9),
          reason: 'editor time $milliseconds ms',
        );
        expect(rendered.scale, closeTo(preview.scale, 1e-9));
        expect(rendered.rotation, closeTo(preview.rotation, 1e-9));
        expect(rendered.opacity, closeTo(preview.opacity, 1e-9));
      }
    });

    // Stretches on the editor timeline over an edge of the 400 ms dissolve,
    // which the editor shows at 1.6–2.4 s and the export plays in half the
    // time: 40 ms over its start, 200 ms over its end, 1 s and 3 s over both.
    for (final (startMs, endMs) in [
      (1580, 1620),
      (2300, 2500),
      (1500, 2500),
      (500, 3500),
    ]) {
      for (final curve in pie.AnimationCurve.values) {
        test('follows a ${curve.name} motion from $startMs to $endMs ms '
            'across an overlap transition', () {
          final source = pie.Layer(
            startTime: Duration(milliseconds: startMs),
            keyframes: [
              pie.LayerKeyframe(
                time: Duration.zero,
                offset: Offset.zero,
                curve: curve,
              ),
              pie.LayerKeyframe(
                time: Duration(milliseconds: endMs - startMs),
                offset: const Offset(100, -60),
                scale: 3,
                rotation: 1.2,
                opacity: 0.2,
              ),
            ],
          );
          final timelineMap = TransitionTimelineMap.fromClips(overlapClips);

          final exported = exportOverOverlap(source);

          final rest = exported.keyframes.first.offset;
          final fromUs = timelineMap
              .editorToOutput(Duration(milliseconds: startMs))
              .inMicroseconds;
          final toUs = timelineMap
              .editorToOutput(Duration(milliseconds: endMs))
              .inMicroseconds;
          for (var us = fromUs; us <= toUs; us += 250) {
            final output = Duration(microseconds: us);
            final preview = source.keyframePlacementAt(
              timelineMap.outputToEditor(output),
            )!;
            final rendered = renderedAt(exported, output);
            // The export draws in three times the editor's 100 px wide body.
            expect(
              (rendered.offset - rest - preview.offset * 3).distance,
              lessThan(1e-9),
              reason: 'output time $output',
            );
            expect(rendered.scale, closeTo(preview.scale, 1e-12));
            expect(rendered.rotation, closeTo(preview.rotation, 1e-12));
            expect(rendered.opacity, closeTo(preview.opacity, 1e-12));
          }
        });
      }
    }

    test('keeps a keyframe effect in step across an overlap transition', () {
      const bounce = pie.LayerAnimation(
        type: pie.LayerAnimationType.bounce,
        phase: pie.AnimationPhase.loop,
        duration: Duration(milliseconds: 700),
      );
      // From 1.0 s to 3.0 s on the editor timeline, over the 400 ms dissolve
      // at 1.6–2.4 s, which the export plays in half the time.
      final source = pie.Layer(
        startTime: const Duration(seconds: 1),
        keyframes: const [
          pie.LayerKeyframe(
            time: Duration.zero,
            offset: Offset.zero,
            effects: [bounce],
          ),
          pie.LayerKeyframe(time: Duration(seconds: 2), offset: Offset.zero),
        ],
      );
      final timelineMap = TransitionTimelineMap.fromClips(overlapClips);
      // The editor fits three 667 ms hops into the 2 s stretch.
      final effect = source.keyframeEffects.single;

      final loops = exportOverOverlap(source).animations;

      // Before, through and after the dissolve.
      expect(loops, hasLength(3));
      expect(loops.first.loopStart, const Duration(seconds: 1));
      expect(loops.last.loopEnd, const Duration(milliseconds: 2600));
      for (final loop in loops) {
        expect(loop.type, LayerAnimationType.bounce);
        expect(loop.phase, AnimationPhase.loop);
      }

      /// How far a loop is through its hop at [elapsedUs] into a [cycleUs]
      /// cycle: 1 at rest, 0 at the top, as both renderers count it.
      double hop(int elapsedUs, int cycleUs) =>
          (1 - 2 * (elapsedUs % cycleUs) / cycleUs).abs();

      final cycleUs = effect.animation.duration.inMicroseconds;
      for (var us = 1000000; us < 2600000; us += 1000) {
        final output = Duration(microseconds: us);
        final editor = timelineMap.outputToEditor(output);
        final preview = hop((editor - effect.start).inMicroseconds, cycleUs);
        final loop = loops.singleWhere(
          (l) => l.loopStart! <= output && output < l.loopEnd!,
        );
        final rendered = hop(
          (output - loop.loopStart!).inMicroseconds +
              (loop.loopPhase ?? Duration.zero).inMicroseconds,
          loop.duration.inMicroseconds,
        );
        expect(rendered, closeTo(preview, 1e-4), reason: 'output $output');
      }
    });

    test('skips a detached clip, which the composition pass renders', () {
      final detachedMeta = DetachedClipLayerData(
        clip: clip('detached', const Duration(seconds: 2)),
        layerId: 'layer-1',
      ).toMeta();
      final detached = pie.ExportedLayer(
        layer: pie.WidgetLayer(
          widget: const SizedBox.shrink(),
          exportConfigs: pie.WidgetLayerExportConfigs(
            id: 'l1',
            meta: detachedMeta,
          ),
        ),
        bytes: Uint8List.fromList(const [1, 2, 3]),
        logicalSize: const Size(10, 20),
      );

      final layers = VideoEditorRenderService.buildImageLayers(
        capturedLayers: [layer(), detached],
        bodySize: const Size(100, 200),
        videoSize: const Size(300, 600),
        targetAspectRatio: vertical,
        timelineMap: TransitionTimelineMap.fromClips(noTransitionClips),
      );

      // Its raster is one frame of a video. Baking it here would freeze the
      // clip *and* double it with the composition pass that plays it.
      expect(layers, hasLength(1));
    });

    test('keeps a partition-rescued detached raster when requested', () {
      final broken = pie.ExportedLayer(
        layer: pie.WidgetLayer(
          widget: const SizedBox.shrink(),
          exportConfigs: const pie.WidgetLayerExportConfigs(
            id: 'broken',
            meta: {
              detachedClipLayerKindKey: detachedClipLayerKind,
              detachedClipLayerClipKey: {'id': 'unreadable'},
            },
          ),
        ),
        bytes: Uint8List.fromList(const [1, 2, 3]),
        logicalSize: const Size(10, 20),
      );

      final layers = VideoEditorRenderService.buildImageLayers(
        capturedLayers: [broken],
        bodySize: const Size(100, 200),
        videoSize: const Size(300, 600),
        targetAspectRatio: vertical,
        timelineMap: TransitionTimelineMap.fromClips(noTransitionClips),
        excludeDetachedClips: false,
      );

      expect(layers, hasLength(1));
    });

    test('returns null when bodySize is null', () {
      expect(
        VideoEditorRenderService.buildImageLayers(
          capturedLayers: [layer()],
          bodySize: null,
          videoSize: const Size(300, 600),
          targetAspectRatio: vertical,
          timelineMap: TransitionTimelineMap.fromClips(noTransitionClips),
        ),
        isNull,
      );
    });

    test('scales offset and size from body space into video pixel space', () {
      // scale = videoWidth / bodyWidth = 300 / 100 = 3.
      final layers = VideoEditorRenderService.buildImageLayers(
        capturedLayers: [layer()],
        bodySize: const Size(100, 200),
        videoSize: const Size(300, 600),
        targetAspectRatio: vertical,
        timelineMap: TransitionTimelineMap.fromClips(noTransitionClips),
      )!;

      final built = layers.single;
      // (bodyW/2 + dx - logicalW/2) * scale = (50 + 0 - 5) * 3 = 135.
      expect(built.offset, const Offset(135, 270));
      expect(built.size, const Size(30, 60));
    });

    // A square session is edited on the recording's 9:16 body. Clips of mixed
    // resolution are cropped one by one before the layers go on, so the frame
    // is already square and the part of the body the editor hid has to come
    // off the offset — scaling by width alone put this layer 420 px too low.
    test('lines a square crop up with the square the editor shows', () {
      final layers = VideoEditorRenderService.buildImageLayers(
        capturedLayers: [layer(logicalSize: const Size(120, 60))],
        bodySize: const Size(360, 640),
        videoSize: const Size(1080, 1080),
        targetAspectRatio: model.AspectRatio.square.value,
        timelineMap: TransitionTimelineMap.fromClips(noTransitionClips),
      )!;

      expect(layers.single.offset, const Offset(360, 450));
      expect(layers.single.size, const Size(360, 180));
    });

    // Clips that share a resolution keep the recording's shape here and are
    // cropped after the layers go on, so the layer sits where the crop keeps it.
    test('places a square layer on an uncropped recording at its crop', () {
      final layers = VideoEditorRenderService.buildImageLayers(
        capturedLayers: [layer(logicalSize: const Size(120, 60))],
        bodySize: const Size(360, 640),
        videoSize: const Size(1080, 1920),
        targetAspectRatio: model.AspectRatio.square.value,
        timelineMap: TransitionTimelineMap.fromClips(noTransitionClips),
      )!;

      // The centred square crop starts at y 420, so this is 450 once cropped.
      expect(layers.single.offset, const Offset(360, 870));
    });

    test('passes layer times through unchanged when there is no overlap '
        'transition', () {
      final layers = VideoEditorRenderService.buildImageLayers(
        capturedLayers: [
          layer(startTime: Duration.zero, endTime: const Duration(seconds: 4)),
        ],
        bodySize: const Size(100, 200),
        videoSize: const Size(300, 600),
        targetAspectRatio: vertical,
        timelineMap: TransitionTimelineMap.fromClips(noTransitionClips),
      )!;

      expect(layers.single.startTime, Duration.zero);
      expect(layers.single.endTime, const Duration(seconds: 4));
    });

    test('maps a full-length layer end onto the shorter output axis when an '
        'overlap transition compresses the timeline', () {
      final map = TransitionTimelineMap.fromClips(overlapClips);
      // Sanity: the overlap removes its 400ms blend from the 4s editor total.
      expect(map.outputDuration, const Duration(milliseconds: 3600));

      final layers = VideoEditorRenderService.buildImageLayers(
        capturedLayers: [
          // A full-length layer whose leave animation is anchored to the
          // editor-timeline end (4s).
          layer(startTime: Duration.zero, endTime: const Duration(seconds: 4)),
        ],
        bodySize: const Size(100, 200),
        videoSize: const Size(300, 600),
        targetAspectRatio: vertical,
        timelineMap: map,
      )!;

      // The end must land on the real (shorter) video end, not 4s past it.
      expect(layers.single.startTime, Duration.zero);
      expect(layers.single.endTime, const Duration(milliseconds: 3600));
    });

    test('leaves null start/end times un-anchored', () {
      final layers = VideoEditorRenderService.buildImageLayers(
        capturedLayers: [layer()],
        bodySize: const Size(100, 200),
        videoSize: const Size(300, 600),
        targetAspectRatio: vertical,
        timelineMap: TransitionTimelineMap.fromClips(overlapClips),
      )!;

      expect(layers.single.startTime, isNull);
      expect(layers.single.endTime, isNull);
    });

    test('hides an area with a censor layer in its place, on the output '
        'timeline', () {
      final censor = pie.ExportedLayer(
        layer: pie.PaintLayer(
          item: pie.PaintedModel(
            mode: pie.PaintMode.pixelate,
            offsets: const [Offset.zero, Offset(40, 20)],
            erasedOffsets: const [],
            color: const Color(0xFFFFFFFF),
            strokeWidth: 1,
            opacity: 1,
          ),
          rawSize: const Size(40, 20),
          opacity: 1,
          startTime: const Duration(seconds: 1),
          endTime: const Duration(seconds: 4),
        ),
        // A backdrop filter captures as an empty image; the export does not
        // read it.
        bytes: Uint8List(0),
        logicalSize: const Size(40, 20),
      );

      final layers = VideoEditorRenderService.buildImageLayers(
        capturedLayers: [layer(), censor, layer()],
        bodySize: const Size(100, 200),
        videoSize: const Size(300, 600),
        targetAspectRatio: vertical,
        timelineMap: TransitionTimelineMap.fromClips(overlapClips),
      )!;

      expect(layers.map((l) => l.censor != null), [false, true, false]);
      final built = layers[1];
      expect(built.offset, const Offset(90, 270));
      expect(built.size, const Size(120, 60));
      expect(built.endTime, const Duration(milliseconds: 3600));
    });

    group('word-highlighted captions', () {
      pie.ExportedLayer karaoke() => pie.ExportedLayer(
        layer: pie.TextLayer(
          text: 'Hello world',
          startTime: const Duration(seconds: 1),
          endTime: const Duration(seconds: 3),
          animations: [
            const pie.LayerAnimation(
              type: pie.LayerAnimationType.fade,
              phase: pie.AnimationPhase.animateIn,
              duration: Duration(milliseconds: 200),
            ),
            const pie.LayerAnimation(
              type: pie.LayerAnimationType.fade,
              phase: pie.AnimationPhase.animateOut,
              duration: Duration(milliseconds: 200),
            ),
          ],
          highlights: const [
            pie.TextHighlight(
              start: 0,
              end: 5,
              startTime: Duration(milliseconds: 500),
              endTime: Duration(seconds: 1),
            ),
            pie.TextHighlight(
              start: 6,
              end: 11,
              startTime: Duration(seconds: 1),
              endTime: Duration(seconds: 2),
            ),
          ],
        ),
        bytes: Uint8List.fromList(const [0]),
        logicalSize: const Size(10, 20),
        highlightBytes: {
          0: Uint8List.fromList(const [1]),
          1: Uint8List.fromList(const [2]),
        },
      );

      // Both renderers treat an overlay's window as closed, so each frame but
      // the last ends one tick before the next begins: a video frame landing
      // exactly on a word change would otherwise draw two captions at once.
      Duration justBefore(int ms) =>
          Duration(milliseconds: ms) - const Duration(microseconds: 1);

      test('become one overlay per lit word at the same place', () {
        final layers = VideoEditorRenderService.buildImageLayers(
          capturedLayers: [karaoke()],
          bodySize: const Size(100, 200),
          videoSize: const Size(300, 600),
          targetAspectRatio: vertical,
          timelineMap: TransitionTimelineMap.fromClips(noTransitionClips),
        )!;

        expect(
          layers.map(
            (l) => (
              l.image.byteArray!.single,
              l.startTime,
              l.endTime,
            ),
          ),
          [
            (0, const Duration(seconds: 1), justBefore(1500)),
            (1, const Duration(milliseconds: 1500), justBefore(2000)),
            (2, const Duration(seconds: 2), const Duration(seconds: 3)),
          ],
        );
        expect(layers.map((l) => l.offset).toSet(), hasLength(1));
        expect(layers.map((l) => l.size).toSet(), hasLength(1));
      });

      // Each frame carries every animation and counts it from the layer's own
      // range, so a fade or a wiggle runs on across the words instead of being
      // cut off at the first frame or restarting at each one.
      test('play every animation over the whole layer on every frame', () {
        final layers = VideoEditorRenderService.buildImageLayers(
          capturedLayers: [karaoke()],
          bodySize: const Size(100, 200),
          videoSize: const Size(300, 600),
          targetAspectRatio: vertical,
          timelineMap: TransitionTimelineMap.fromClips(noTransitionClips),
        )!;

        expect(layers, hasLength(3));
        for (final layer in layers) {
          expect(layer.animations.map((a) => a.phase.name), [
            'animateIn',
            'animateOut',
          ]);
          expect(layer.animationStartTime, const Duration(seconds: 1));
          expect(layer.animationEndTime, const Duration(seconds: 3));
        }
      });

      test('leave the range unset on a layer that is not split', () {
        final layers = VideoEditorRenderService.buildImageLayers(
          capturedLayers: [
            pie.ExportedLayer(
              layer: pie.TextLayer(
                text: 'Hello',
                startTime: const Duration(seconds: 1),
                endTime: const Duration(seconds: 3),
              ),
              bytes: Uint8List.fromList(const [0]),
              logicalSize: const Size(10, 20),
            ),
          ],
          bodySize: const Size(100, 200),
          videoSize: const Size(300, 600),
          targetAspectRatio: vertical,
          timelineMap: TransitionTimelineMap.fromClips(noTransitionClips),
        )!;

        expect(layers.single.animationStartTime, isNull);
        expect(layers.single.animationEndTime, isNull);
      });

      test('count a reveal from the video start when the layer has none', () {
        final layers = VideoEditorRenderService.buildImageLayers(
          capturedLayers: [
            pie.ExportedLayer(
              layer: pie.TextLayer(
                text: 'Hello world',
                endTime: const Duration(seconds: 3),
                animations: const [
                  pie.LayerAnimation(
                    type: pie.LayerAnimationType.typewriter,
                    phase: pie.AnimationPhase.animateIn,
                    duration: Duration(seconds: 1),
                  ),
                ],
              ),
              bytes: Uint8List.fromList(const [0]),
              logicalSize: const Size(10, 20),
              revealBytes: {
                const pie.ExportedTextState(revealedLength: 0):
                    Uint8List.fromList(const [1]),
              },
            ),
          ],
          bodySize: const Size(100, 200),
          videoSize: const Size(300, 600),
          targetAspectRatio: vertical,
          timelineMap: TransitionTimelineMap.fromClips(noTransitionClips),
        )!;

        // The reveal becomes one overlay per step, and a null layer start
        // means "begins with the video": every step counts its animations
        // from the output origin, not from its own start, or a fade or a
        // loop would restart at each step.
        expect(layers.length, greaterThan(1));
        for (final layer in layers) {
          expect(layer.animationStartTime, Duration.zero);
        }
      });

      test('anchor a leave to the output end when the layer has none', () {
        final timelineMap = TransitionTimelineMap.fromClips(noTransitionClips);
        final layers = VideoEditorRenderService.buildImageLayers(
          capturedLayers: [
            pie.ExportedLayer(
              layer: pie.TextLayer(
                text: 'Hello world',
                animations: const [
                  pie.LayerAnimation(
                    type: pie.LayerAnimationType.typewriter,
                    phase: pie.AnimationPhase.animateIn,
                    duration: Duration(seconds: 1),
                  ),
                  pie.LayerAnimation(
                    type: pie.LayerAnimationType.fade,
                    phase: pie.AnimationPhase.animateOut,
                    duration: Duration(milliseconds: 300),
                  ),
                ],
              ),
              bytes: Uint8List.fromList(const [0]),
              logicalSize: const Size(10, 20),
              revealBytes: {
                const pie.ExportedTextState(revealedLength: 0):
                    Uint8List.fromList(const [1]),
              },
            ),
          ],
          bodySize: const Size(100, 200),
          videoSize: const Size(300, 600),
          targetAspectRatio: vertical,
          timelineMap: timelineMap,
        )!;

        // A null layer end means "lasts until the video ends": every step
        // anchors its leave to the output end, never to its own end, which
        // would play the leave at the end of each reveal step.
        expect(layers.length, greaterThan(1));
        for (final layer in layers) {
          expect(layer.animationEndTime, timelineMap.outputDuration);
        }
      });
    });
  });

  group('layerFrameSize', () {
    test('is the first segment when no later one is larger', () {
      expect(
        VideoEditorRenderService.layerFrameSize(const [
          Size(1080, 1080),
          Size(720, 720),
        ]),
        const Size(1080, 1080),
      );
    });

    // A square video starting with a saved classic Vine: the camera clip after
    // it is the frame the segments are composited into, not the Vine.
    test('is a larger segment that comes later', () {
      expect(
        VideoEditorRenderService.layerFrameSize(const [
          Size(480, 480),
          Size(1080, 1080),
          Size(720, 720),
        ]),
        const Size(1080, 1080),
      );
    });

    // Larger on one axis is enough: a landscape clip after a portrait one
    // replaces it although it is shorter.
    test('is a later segment that is only wider', () {
      expect(
        VideoEditorRenderService.layerFrameSize(const [
          Size(1080, 1920),
          Size(1920, 1080),
        ]),
        const Size(1920, 1080),
      );
    });
  });

  group('buildVideoEffects', () {
    test('keeps a whole-video effect open at both ends', () {
      final effects = VideoEditorRenderService.buildVideoEffects(
        effects: const [
          EditorVideoEffect(
            id: 'pixelate',
            effect: VideoEffect.pixelate(intensity: 0.3),
          ),
        ],
        timelineMap: TransitionTimelineMap.fromClips(overlapClips),
      );

      expect(effects, const [VideoEffect.pixelate(intensity: 0.3)]);
    });

    test('maps an effect window onto the shorter output axis when an overlap '
        'transition compresses the timeline', () {
      final effects = VideoEditorRenderService.buildVideoEffects(
        effects: const [
          EditorVideoEffect(
            id: 'glitch',
            effect: VideoEffect.glitch(
              intensity: 0.8,
              startTime: Duration.zero,
              endTime: Duration(seconds: 4),
            ),
          ),
        ],
        timelineMap: TransitionTimelineMap.fromClips(overlapClips),
      );

      expect(effects.single.type, VideoEffectType.glitch);
      expect(effects.single.intensity, 0.8);
      expect(effects.single.startTime, Duration.zero);
      expect(effects.single.endTime, const Duration(milliseconds: 3600));
    });
  });

  group('buildColorFilters', () {
    pie.TuneAdjustmentMatrix tune({Duration? startTime, Duration? endTime}) =>
        pie.TuneAdjustmentMatrix(
          id: 'brightness',
          value: 0.5,
          matrix: const [1, 0, 0],
          startTime: startTime,
          endTime: endTime,
        );

    test('returns an empty list when there are no adjustments or filters', () {
      expect(
        VideoEditorRenderService.buildColorFilters(
          tuneAdjustments: const [],
          filterStates: const [],
          timelineMap: TransitionTimelineMap.fromClips(noTransitionClips),
        ),
        isEmpty,
      );
    });

    test('passes tune times through unchanged when there is no overlap '
        'transition', () {
      final filters = VideoEditorRenderService.buildColorFilters(
        tuneAdjustments: [
          tune(startTime: Duration.zero, endTime: const Duration(seconds: 4)),
        ],
        filterStates: const [],
        timelineMap: TransitionTimelineMap.fromClips(noTransitionClips),
      );

      expect(filters.single.matrix, const [1, 0, 0]);
      expect(filters.single.startTime, Duration.zero);
      expect(filters.single.endTime, const Duration(seconds: 4));
    });

    test('maps a full-length tune window onto the shorter output axis when an '
        'overlap transition compresses the timeline', () {
      final filters = VideoEditorRenderService.buildColorFilters(
        tuneAdjustments: [
          tune(startTime: Duration.zero, endTime: const Duration(seconds: 4)),
        ],
        filterStates: const [],
        timelineMap: TransitionTimelineMap.fromClips(overlapClips),
      );

      expect(filters.single.startTime, Duration.zero);
      expect(filters.single.endTime, const Duration(milliseconds: 3600));
    });

    test('emits one filter per matrix and maps each window onto the output '
        'axis', () {
      final filters = VideoEditorRenderService.buildColorFilters(
        tuneAdjustments: const [],
        filterStates: [
          pie.FilterState(
            name: 'sepia',
            matrices: const [
              [1, 0, 0],
              [0, 1, 0],
            ],
            startTime: Duration.zero,
            endTime: const Duration(seconds: 4),
          ),
        ],
        timelineMap: TransitionTimelineMap.fromClips(overlapClips),
      );

      expect(filters, hasLength(2));
      expect(filters.map((f) => f.matrix), [
        const [1, 0, 0],
        const [0, 1, 0],
      ]);
      for (final filter in filters) {
        expect(filter.startTime, Duration.zero);
        expect(filter.endTime, const Duration(milliseconds: 3600));
      }
    });

    test('leaves null tune times un-anchored', () {
      final filters = VideoEditorRenderService.buildColorFilters(
        tuneAdjustments: [tune()],
        filterStates: const [],
        timelineMap: TransitionTimelineMap.fromClips(overlapClips),
      );

      expect(filters.single.startTime, isNull);
      expect(filters.single.endTime, isNull);
    });
  });

  group('renderWithEncoderFallback', () {
    tearDown(VideoEditorRenderService.resetActiveNativeTaskIdsForTesting);

    const aspectRatio = model.AspectRatio.vertical;
    final baseResolution = VideoEditorConstants.quality
        .resolutionForAspectRatio(aspectRatio);
    final fallbackResolution = VideoEditorConstants.encoderFallbackQuality
        .resolutionForAspectRatio(aspectRatio);

    VideoRenderData baseTask({
      String id = 'render-task',
      bool trimToCommonTrackEnd = false,
    }) => VideoRenderData(
      id: id,
      videoSegments: [
        VideoSegment(
          video: EditorVideo.file('${Directory.systemTemp.path}/a.mp4'),
        ),
      ],
      trimToCommonTrackEnd: trimToCommonTrackEnd,
      qualityConfig: VideoQualityConfig.custom(
        bitrate: VideoEditorConstants.quality.bitrate,
        resolution: baseResolution,
      ),
    );

    /// An encode that throws [RenderEncoderException] for its first
    /// [failuresBeforeSuccess] calls, then succeeds, recording every task it
    /// was handed.
    ({
      Future<void> Function(VideoRenderData) encode,
      List<VideoRenderData> calls,
    })
    flakyEncoder({required int failuresBeforeSuccess}) {
      final calls = <VideoRenderData>[];
      Future<void> encode(VideoRenderData task) async {
        calls.add(task);
        if (calls.length <= failuresBeforeSuccess) {
          throw const RenderEncoderException('encoder init failed');
        }
      }

      return (encode: encode, calls: calls);
    }

    test('encodes once at full resolution when the first attempt '
        'succeeds', () async {
      final harness = flakyEncoder(failuresBeforeSuccess: 0);

      await VideoEditorRenderService.renderWithEncoderFallback(
        baseTask: baseTask(),
        encode: harness.encode,
        fallbackAspectRatio: aspectRatio,
        settleDelay: Duration.zero,
      );

      expect(harness.calls, hasLength(1));
      expect(harness.calls.single.qualityConfig?.resolution, baseResolution);
    });

    test('retries at full resolution after a single encoder failure', () async {
      final harness = flakyEncoder(failuresBeforeSuccess: 1);

      await VideoEditorRenderService.renderWithEncoderFallback(
        baseTask: baseTask(),
        encode: harness.encode,
        fallbackAspectRatio: aspectRatio,
        settleDelay: Duration.zero,
      );

      expect(harness.calls, hasLength(2));
      expect(
        harness.calls.map((t) => t.qualityConfig?.resolution),
        everyElement(baseResolution),
      );
    });

    test('falls back to the reduced resolution on the third attempt', () async {
      final harness = flakyEncoder(failuresBeforeSuccess: 2);

      await VideoEditorRenderService.renderWithEncoderFallback(
        baseTask: baseTask(),
        encode: harness.encode,
        fallbackAspectRatio: aspectRatio,
        settleDelay: Duration.zero,
      );

      expect(harness.calls, hasLength(3));
      expect(harness.calls[0].qualityConfig?.resolution, baseResolution);
      expect(harness.calls[1].qualityConfig?.resolution, baseResolution);
      expect(harness.calls[2].qualityConfig?.resolution, fallbackResolution);
      expect(
        harness.calls[2].qualityConfig?.bitrate,
        VideoEditorConstants.encoderFallbackQuality.bitrate,
      );
    });

    test('rethrows after every attempt fails', () async {
      final harness = flakyEncoder(failuresBeforeSuccess: 3);

      await expectLater(
        VideoEditorRenderService.renderWithEncoderFallback(
          baseTask: baseTask(),
          encode: harness.encode,
          fallbackAspectRatio: aspectRatio,
          settleDelay: Duration.zero,
        ),
        throwsA(isA<RenderEncoderException>()),
      );

      expect(harness.calls, hasLength(3));
    });

    test('does not retry non-encoder failures', () async {
      var calls = 0;
      Future<void> encode(VideoRenderData task) async {
        calls++;
        throw const RenderCanceledException();
      }

      await expectLater(
        VideoEditorRenderService.renderWithEncoderFallback(
          baseTask: baseTask(),
          encode: encode,
          fallbackAspectRatio: aspectRatio,
          settleDelay: Duration.zero,
        ),
        throwsA(isA<RenderCanceledException>()),
      );

      expect(calls, 1);
    });

    test(
      'uses only the settle retry when reduced fallback is disabled',
      () async {
        final harness = flakyEncoder(failuresBeforeSuccess: 2);

        await expectLater(
          VideoEditorRenderService.renderWithEncoderFallback(
            baseTask: baseTask(),
            encode: harness.encode,
            settleDelay: Duration.zero,
          ),
          throwsA(isA<RenderEncoderException>()),
        );

        expect(harness.calls, hasLength(2));
        expect(
          harness.calls.map((t) => t.qualityConfig?.resolution),
          everyElement(baseResolution),
        );
      },
    );

    test('honors cancellation recorded during the settle window', () {
      fakeAsync((async) {
        const settle = VideoEditorConstants.encoderRetrySettleDelay;
        final harness = flakyEncoder(failuresBeforeSuccess: 1);
        Object? caught;

        unawaited(
          VideoEditorRenderService.renderWithEncoderFallback(
            baseTask: baseTask(),
            encode: harness.encode,
            fallbackAspectRatio: aspectRatio,
          ).catchError((Object error) {
            caught = error;
          }),
        );

        async.flushMicrotasks();
        expect(harness.calls, hasLength(1));

        unawaited(VideoEditorRenderService.cancelTask('render-task'));
        expect(
          VideoEditorRenderService.isTaskCancellationRequestedForTesting(
            'render-task',
          ),
          isTrue,
        );

        async.elapse(settle);
        async.flushMicrotasks();

        expect(caught, isA<RenderCanceledException>());
        expect(harness.calls, hasLength(1));
        expect(
          VideoEditorRenderService.isTaskCancellationRequestedForTesting(
            'render-task',
          ),
          isFalse,
        );
      });
    });

    test(
      'honors cancellation recorded before the encode loop starts',
      () async {
        final token = RenderCancellationRegistry.start('render-task');
        await VideoEditorRenderService.cancelTask('render-task');
        var calls = 0;

        await expectLater(
          VideoEditorRenderService.renderWithEncoderFallback(
            baseTask: baseTask(),
            encode: (_) async {
              calls++;
            },
            fallbackAspectRatio: aspectRatio,
            settleDelay: Duration.zero,
          ),
          throwsA(isA<RenderCanceledException>()),
        );

        expect(calls, 0);
        RenderCancellationRegistry.finish('render-task', token);
      },
    );

    test('honors cancellation recorded while encode is running', () async {
      var calls = 0;

      await expectLater(
        VideoEditorRenderService.renderWithEncoderFallback(
          baseTask: baseTask(),
          encode: (task) async {
            calls++;
            unawaited(VideoEditorRenderService.cancelTask(task.id));
          },
          fallbackAspectRatio: aspectRatio,
          settleDelay: Duration.zero,
        ),
        throwsA(isA<RenderCanceledException>()),
      );

      expect(calls, 1);
      expect(
        VideoEditorRenderService.isTaskCancellationRequestedForTesting(
          'render-task',
        ),
        isFalse,
      );
    });

    test('runs the first attempt immediately and waits settleDelay '
        'before each retry', () {
      fakeAsync((async) {
        const settle = VideoEditorConstants.encoderRetrySettleDelay;
        final harness = flakyEncoder(failuresBeforeSuccess: 2);

        unawaited(
          VideoEditorRenderService.renderWithEncoderFallback(
            baseTask: baseTask(),
            encode: harness.encode,
            fallbackAspectRatio: aspectRatio,
          ),
        );

        // First attempt pays no delay.
        async.flushMicrotasks();
        expect(harness.calls, hasLength(1));

        // The retry waits out the full settle window before firing.
        async.elapse(settle - const Duration(milliseconds: 1));
        expect(harness.calls, hasLength(1));
        async.elapse(const Duration(milliseconds: 1));
        expect(harness.calls, hasLength(2));

        // The reduced-resolution attempt waits another settle window.
        async.elapse(settle - const Duration(milliseconds: 1));
        expect(harness.calls, hasLength(2));
        async.elapse(const Duration(milliseconds: 1));
        expect(harness.calls, hasLength(3));
      });
    });

    // An intermediate pass (clip normalization) renders under an id of its
    // own, while the user's Cancel targets the export's id. Without
    // [ownerTaskId] the retry loop cannot see that cancel at all, so it
    // settles, retries, and finishes work nobody is waiting for (#7833/#7834).
    test("honors the owning export's cancellation during the settle "
        'window', () {
      fakeAsync((async) {
        const settle = VideoEditorConstants.encoderRetrySettleDelay;
        final harness = flakyEncoder(failuresBeforeSuccess: 1);
        // renderVideoToClip owns this generation in production.
        final ownerToken = RenderCancellationRegistry.start('export-task');
        Object? caught;

        unawaited(
          VideoEditorRenderService.renderWithEncoderFallback(
            baseTask: baseTask(id: 'clip-a_normalized'),
            encode: harness.encode,
            ownerTaskId: 'export-task',
          ).catchError((Object error) {
            caught = error;
          }),
        );

        async.flushMicrotasks();
        expect(harness.calls, hasLength(1));

        RenderCancellationRegistry.cancel('export-task');

        async.elapse(settle);
        async.flushMicrotasks();

        expect(caught, isA<RenderCanceledException>());
        expect(harness.calls, hasLength(1));
        RenderCancellationRegistry.finish('export-task', ownerToken);
      });
    });

    test('stops after the running attempt when the owning export is '
        'cancelled', () async {
      final ownerToken = RenderCancellationRegistry.start('export-task');
      var calls = 0;

      await expectLater(
        VideoEditorRenderService.renderWithEncoderFallback(
          baseTask: baseTask(id: 'clip-a_normalized'),
          encode: (_) async {
            calls++;
            RenderCancellationRegistry.cancel('export-task');
          },
          ownerTaskId: 'export-task',
          settleDelay: Duration.zero,
        ),
        throwsA(isA<RenderCanceledException>()),
      );

      expect(calls, 1);
      RenderCancellationRegistry.finish('export-task', ownerToken);
    });

    // The reduced-resolution attempt is rebuilt with copyWith. Rebuilding it
    // with the constructor instead would silently reset every field the
    // rebuild does not name, including trimToCommonTrackEnd (#7788).
    test('carries non-quality task fields into the reduced-resolution '
        'attempt', () async {
      final harness = flakyEncoder(failuresBeforeSuccess: 2);

      await VideoEditorRenderService.renderWithEncoderFallback(
        baseTask: baseTask(trimToCommonTrackEnd: true),
        encode: harness.encode,
        fallbackAspectRatio: aspectRatio,
        settleDelay: Duration.zero,
      );

      expect(harness.calls, hasLength(3));
      expect(
        harness.calls.map((t) => t.trimToCommonTrackEnd),
        everyElement(isTrue),
      );
      expect(harness.calls[2].qualityConfig?.resolution, fallbackResolution);
    });
  });

  group('render failure reporting (#7125)', () {
    late ProVideoEditor originalProVideoEditor;

    setUp(() {
      originalProVideoEditor = ProVideoEditor.instance;
      ProVideoEditor.instance = _StubProVideoEditor();
    });

    tearDown(() {
      ProVideoEditor.instance = originalProVideoEditor;
      VideoEditorRenderService.renderVideoOverride = null;
      StopMotionRenderService.assembleOverride = null;
    });

    test('renderVideoToClip names an empty clip list as the reason', () async {
      await expectLater(
        VideoEditorRenderService.renderVideoToClip(
          clips: const [],
          editorStateHistory: const {},
        ),
        throwsA(
          isA<VideoRenderFailedException>().having(
            (e) => e.reason,
            'reason',
            VideoRenderFailureReason.emptyClips,
          ),
        ),
      );
    });

    test('renderVideoToClip maps a cancelled stop-motion assembly to canceled, '
        'not stop_motion_assembly', () async {
      StopMotionRenderService.assembleOverride = ({
        required frames,
        required aspectRatio,
        frameRate = StopMotionRenderService.defaultFrameRate,
        String? taskId,
      }) async => throw const RenderCanceledException();

      final stopMotionClip = DivineVideoClip(
        id: 'sm-clip',
        stopMotionFrames: const [
          StopMotionClipFrame(
            path: '/frames/f0.jpg',
            duration: Duration(milliseconds: 83),
          ),
        ],
        duration: const Duration(milliseconds: 83),
        recordedAt: DateTime(2026),
        targetAspectRatio: model.AspectRatio.vertical,
        originalAspectRatio: 9 / 16,
      );

      await expectLater(
        VideoEditorRenderService.renderVideoToClip(
          clips: [stopMotionClip],
          editorStateHistory: const {},
        ),
        throwsA(
          isA<VideoRenderFailedException>()
              .having(
                (e) => e.reason,
                'reason',
                VideoRenderFailureReason.canceled,
              )
              .having((e) => e.cause, 'cause', isA<RenderCanceledException>()),
        ),
      );
    });

    test('renderVideo keeps returning null so callers that only need the '
        'path are unaffected', () async {
      VideoEditorRenderService.renderVideoOverride = ({
        required clips,
        required usePersistentStorage,
        aspectRatio,
        parameters,
        taskId,
        maxOutputDuration,
      }) async => null;

      expect(
        await VideoEditorRenderService.renderVideo(
          clips: [clip('a', const Duration(seconds: 1))],
        ),
        isNull,
      );
    });

    test('traceValue carries the cause type, never its message', () {
      const failure = VideoRenderFailedException(
        VideoRenderFailureReason.nativeRender,
        cause: FormatException('/var/mobile/Containers/Data/x/clip.mp4'),
      );

      expect(failure.traceValue, 'native_render:FormatException');
      expect(failure.toString(), contains('/var/mobile'));
    });
  });

  // The invisibility #7125 reports: the native pipeline signals its failures as
  // PlatformException, which is not an `Error`, so the old `e is Error` gate
  // dropped the entire population before it reached Crashlytics. Widening it
  // for the export must not drag in the recoverable callers of renderVideo —
  // a failing transition seam falls back to a hard cut and is re-attempted on
  // every timeline change, so reporting each attempt would bury the export
  // failures this is meant to surface.
  group('crash reporting gate (#7125)', () {
    late List<Object> reported;
    late ProVideoEditor originalProVideoEditor;

    setUp(() {
      reported = [];
      originalProVideoEditor = ProVideoEditor.instance;
      ProVideoEditor.instance = _StubProVideoEditor();
      VideoEditorRenderService.crashReporterOverride = (error, _) =>
          reported.add(error);
    });

    tearDown(() {
      ProVideoEditor.instance = originalProVideoEditor;
      VideoEditorRenderService.crashReporterOverride = null;
      VideoEditorRenderService.renderVideoOverride = null;
    });

    void failRenderWith(Object error) {
      VideoEditorRenderService.renderVideoOverride = ({
        required clips,
        required usePersistentStorage,
        aspectRatio,
        parameters,
        taskId,
        maxOutputDuration,
      }) async => throw error;
    }

    Future<void> exportClip() => expectLater(
      VideoEditorRenderService.renderVideoToClip(
        clips: [clip('a', const Duration(seconds: 1))],
        editorStateHistory: const {},
      ),
      throwsA(isA<VideoRenderFailedException>()),
    );

    Future<String?> renderClipPath() => VideoEditorRenderService.renderVideo(
      clips: [clip('a', const Duration(seconds: 1))],
    );

    test('the export reports a native failure that is not an Error', () async {
      final failure = PlatformException(code: 'RENDER_ERROR');
      failRenderWith(failure);

      await exportClip();

      expect(reported, [same(failure)]);
    });

    test('the export classifies a full disk as insufficientStorage and still '
        'reports it (#7125)', () async {
      final failure = PlatformException(
        code: 'RENDER_ERROR',
        message: 'Disk Full',
        details: <Object?, Object?>{
          'domain': 'AVFoundationErrorDomain',
          'code': NativeFailureDetails.avErrorDiskFull,
        },
      );
      failRenderWith(failure);

      await expectLater(
        VideoEditorRenderService.renderVideoToClip(
          clips: [clip('a', const Duration(seconds: 1))],
          editorStateHistory: const {},
        ),
        throwsA(
          isA<VideoRenderFailedException>()
              .having(
                (e) => e.reason,
                'reason',
                VideoRenderFailureReason.insufficientStorage,
              )
              .having((e) => e.cause, 'cause', same(failure)),
        ),
      );
      expect(reported, [same(failure)]);
    });

    test('a recoverable caller does not report a native failure', () async {
      failRenderWith(PlatformException(code: 'RENDER_ERROR'));

      expect(await renderClipPath(), isNull);
      expect(
        reported,
        isEmpty,
        reason:
            'a seam re-attempted on every timeline change would flood the '
            'dashboard',
      );
    });

    test('a recoverable caller still reports a programming-invariant '
        'violation', () async {
      final failure = StateError('boom');
      failRenderWith(failure);

      expect(await renderClipPath(), isNull);
      expect(reported, [same(failure)]);
    });

    test('a cancellation is never reported', () async {
      failRenderWith(const RenderCanceledException());

      await exportClip();

      expect(reported, isEmpty);
    });
  });
}

/// Satisfies the composite-progress subscription that
/// [VideoEditorRenderService.renderVideoToClip] opens; the render itself is
/// stubbed out through `renderVideoOverride`.
class _StubProVideoEditor extends ProVideoEditor {
  @override
  void initializeStream() {}

  @override
  Stream<ProgressModel> progressStreamById(String taskId) =>
      const Stream<ProgressModel>.empty();
}
