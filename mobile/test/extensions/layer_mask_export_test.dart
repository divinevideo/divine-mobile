// ABOUTME: Tests how a shape mask with keyframes maps into the pro_video_editor
// ABOUTME: export, placed in the image a layer is captured into.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model;
import 'package:openvine/extensions/layer_keyframes.dart';
import 'package:openvine/extensions/layer_mask_export.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/transition_geometry.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show AnimationCurve, Layer, LayerMask, LayerMaskKeyframe, LayerMaskShape;
import 'package:pro_video_editor/pro_video_editor.dart' as pve;

void main() {
  const ms = Duration(milliseconds: 1);

  /// Two two-second clips with a dissolve between them, whose output runs at
  /// another pace than the editor through it.
  final timelineMap = TransitionTimelineMap.fromClips([
    for (final id in ['a', 'b'])
      DivineVideoClip(
        id: id,
        video: pve.EditorVideo.file('${Directory.systemTemp.path}/$id.mp4'),
        duration: const Duration(seconds: 2),
        recordedAt: DateTime(2026),
        targetAspectRatio: model.AspectRatio.vertical,
        originalAspectRatio: 9 / 16,
        transition: id == 'a'
            ? const pve.ClipTransition(type: pve.ClipTransitionType.dissolve)
            : null,
      ),
  ]);

  group('LayerMaskExport', () {
    final mask =
        const LayerMask(
          shape: LayerMaskShape.star,
          center: Offset(0.3, 0.4),
          size: Size(0.3, 0.5),
          rotation: 0.4,
          feather: 0.05,
          cornerRadius: 0.2,
          invert: true,
        ).withKeyframes([
          const LayerMaskKeyframe(
            time: Duration.zero,
            center: Offset(0.2, 0.3),
            size: Size(0.1, 0.1),
            curve: AnimationCurve.easeOutCubic,
          ),
          const LayerMaskKeyframe(
            time: Duration(seconds: 1),
            center: Offset(0.6, 0.7),
            size: Size(0.8, 0.6),
            rotation: 1,
            feather: 0.1,
          ),
        ]);

    test('keeps the mask as it is in its own box and places the keyframes '
        'on the editor timeline', () {
      final exported = mask.divineShapeMaskForExport(origin: ms * 1500);

      expect(exported.shape, pve.LayerShapeMaskShape.star);
      expect(exported.center, mask.center);
      expect(exported.size, mask.size);
      expect(exported.rotation, mask.rotation);
      expect(exported.feather, mask.feather);
      expect(exported.cornerRadius, mask.cornerRadius);
      expect(exported.invert, isTrue);
      expect(exported.mirrored, isFalse);
      expect(exported.keyframes.map((k) => k.time), [ms * 1500, ms * 2500]);
      expect(exported.keyframes.first.curve, pve.AnimationCurve.easeOutCubic);
      expect(exported.keyframes.last.center, const Offset(0.6, 0.7));
      expect(exported.keyframes.last.feather, 0.1);
    });

    group('in a turned and flipped image', () {
      const box = Size(120, 60);

      /// The box turned by [rotation]: the size of the image a capture of it
      /// takes, as `Layer.captureAllLayers` reports it.
      Size turned(double rotation) {
        final cos = math.cos(rotation).abs();
        final sin = math.sin(rotation).abs();
        // Whole pixels: a hair above them, as a cosine of a quarter turn
        // leaves it, would round the mask's image up a pixel past the
        // capture's.
        return Size(
          (box.width * cos + box.height * sin).roundToDouble(),
          (box.width * sin + box.height * cos).roundToDouble(),
        );
      }

      /// The alpha of every pixel of [image].
      Future<Uint8List> alphas(ui.Image image) async {
        final rgba = (await image.toByteData())!.buffer.asUint8List();
        return Uint8List.fromList([
          for (var i = 3; i < rgba.length; i += 4) rgba[i],
        ]);
      }

      /// [mask] drawn in the box and then turned and flipped into an image of
      /// [imageSize], as `Layer.captureAsPng` turns a captured layer.
      Future<ui.Image> capturedMask(
        LayerMask mask,
        Size imageSize, {
        required double rotation,
        required bool flipX,
        required bool flipY,
      }) async {
        final inBox = await mask.toImage(box);
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder)
          ..translate(imageSize.width / 2, imageSize.height / 2);
        if (flipX) canvas.scale(-1, 1);
        if (flipY) canvas.scale(1, -1);
        canvas
          ..rotate(rotation)
          ..translate(-box.width / 2, -box.height / 2)
          ..drawImage(inBox, Offset.zero, ui.Paint());
        inBox.dispose();
        final picture = recorder.endRecording();
        final image = await picture.toImage(
          imageSize.width.round(),
          imageSize.height.round(),
        );
        picture.dispose();
        return image;
      }

      /// [exported] drawn straight into an image of [imageSize]: a mirrored
      /// shape is the same shape with its box turned inside out on the x
      /// axis, which `LayerMask` mirrors it for.
      Future<ui.Image> placedMask(
        pve.LayerShapeMask exported,
        Size imageSize,
      ) {
        final width = exported.mirrored
            ? -exported.size.width
            : exported.size.width;
        return LayerMask(
          shape: LayerMaskShape.values.byName(exported.shape.name),
          center: exported.center,
          size: Size(width, exported.size.height),
          rotation: exported.rotation,
          feather: exported.feather,
          cornerRadius: exported.cornerRadius,
          invert: exported.invert,
        ).toImage(imageSize);
      }

      for (final rotation in [0.0, math.pi / 2, math.pi]) {
        for (final (flipX, flipY) in [
          (false, false),
          (true, false),
          (false, true),
          (true, true),
        ]) {
          testWidgets('lands where the capture puts the mask, turned by '
              '${rotation.toStringAsFixed(2)} with flipX $flipX and flipY '
              '$flipY', (tester) async {
            // A heart and a triangle are not symmetric top to bottom, so a
            // flip that went the wrong way would show.
            const still = LayerMask(
              shape: LayerMaskShape.heart,
              center: Offset(0.3, 0.4),
              size: Size(0.35, 0.6),
              rotation: 0.4,
            );
            final imageSize = turned(rotation);

            final mismatches = await tester.runAsync(() async {
              final expected = await alphas(
                await capturedMask(
                  still,
                  imageSize,
                  rotation: rotation,
                  flipX: flipX,
                  flipY: flipY,
                ),
              );
              final exported = still
                  .withKeyframeAt(Duration.zero)
                  .divineShapeMaskForExport(
                    origin: Duration.zero,
                    placement: ExportMaskPlacement(
                      boxSize: box,
                      imageSize: imageSize,
                      rotation: rotation,
                      flipX: flipX,
                      flipY: flipY,
                    ),
                  );
              final keyframe = exported.keyframes.single;
              final actual = await alphas(
                await placedMask(
                  exported.copyWith(
                    center: keyframe.center,
                    size: keyframe.size,
                    rotation: keyframe.rotation,
                    feather: keyframe.feather,
                  ),
                  imageSize,
                ),
              );
              var count = 0;
              for (var i = 0; i < expected.length; i++) {
                if ((expected[i] - actual[i]).abs() > 128) count++;
              }
              return count;
            });

            // Anti-aliasing along the edge may round either way.
            expect(
              mismatches,
              lessThan(imageSize.width * imageSize.height * 0.01),
            );
          });
        }
      }

      test('keeps the softness as long in pixels', () {
        final exported = mask.divineShapeMaskForExport(
          origin: Duration.zero,
          placement: ExportMaskPlacement(
            boxSize: box,
            imageSize: turned(0.5),
            rotation: 0.5,
          ),
        );

        expect(
          exported.feather * turned(0.5).shortestSide,
          closeTo(mask.feather * box.shortestSide, 1e-9),
        );
      });

      test('mirrors the shape for one flip and not for two', () {
        ExportMaskPlacement placement({
          bool flipX = false,
          bool flipY = false,
        }) => ExportMaskPlacement(
          boxSize: box,
          imageSize: box,
          flipX: flipX,
          flipY: flipY,
        );

        expect(
          mask
              .divineShapeMaskForExport(
                origin: Duration.zero,
                placement: placement(flipX: true),
              )
              .mirrored,
          isTrue,
        );
        expect(
          mask
              .divineShapeMaskForExport(
                origin: Duration.zero,
                placement: placement(flipX: true, flipY: true),
              )
              .mirrored,
          isFalse,
        );
      });
    });
  });

  group('divineKeyframeClock', () {
    test('maps the edges of every clip transition onto the output', () {
      final clock = divineKeyframeClock(timelineMap);

      expect(clock, isNotEmpty);
      for (final point in clock) {
        expect(point.output, timelineMap.editorToOutput(point.keyframe));
      }
    });
  });

  group('Layer.divineKeyframeClockForExport', () {
    test('gives a layer whose mask alone has keyframes the clock too', () {
      const still = LayerMask(shape: LayerMaskShape.ellipse);

      expect(
        Layer(
          mask: still.withKeyframeAt(Duration.zero),
        ).divineKeyframeClockForExport(timelineMap: timelineMap),
        divineKeyframeClock(timelineMap),
      );
      expect(
        Layer(mask: still).divineKeyframeClockForExport(
          timelineMap: timelineMap,
        ),
        isEmpty,
      );
    });
  });
}
