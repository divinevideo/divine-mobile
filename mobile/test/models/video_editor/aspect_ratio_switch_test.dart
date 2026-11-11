// ABOUTME: Tests switching a video between square and 9:16: every clip takes
// ABOUTME: the new shape, and layers the new frame would cut off move onto it.

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' as model;
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/aspect_ratio_switch.dart';
import 'package:openvine/models/video_editor/editor_mask.dart';
import 'package:openvine/models/video_editor/social_sticker.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

void main() {
  // A 9:16 canvas: its square frame runs from 70 to 250, 90 above and below
  // the centre the layer offsets are measured from.
  const body = Size(180, 320);
  final square = model.AspectRatio.square.value;
  final vertical = model.AspectRatio.vertical.value;

  DivineVideoClip clip(String id, {LayerMask? mask}) => DivineVideoClip(
    id: id,
    video: EditorVideo.file('${Directory.systemTemp.path}/$id.mp4'),
    duration: const Duration(seconds: 2),
    recordedAt: DateTime(2026),
    targetAspectRatio: model.AspectRatio.vertical,
    originalAspectRatio: 9 / 16,
    mask: mask,
  );

  WidgetLayer sticker({required Offset offset}) =>
      WidgetLayer(widget: const SizedBox(), offset: offset);

  group('switchedAspectRatio', () {
    test('switches 9:16 to square and square to 9:16', () {
      expect(
        switchedAspectRatio(model.AspectRatio.vertical),
        model.AspectRatio.square,
      );
      expect(
        switchedAspectRatio(model.AspectRatio.square),
        model.AspectRatio.vertical,
      );
    });
  });

  group('clipsWithAspectRatio', () {
    test('gives every clip the new shape', () {
      final clips = clipsWithAspectRatio([
        clip('a'),
        clip('b'),
      ], model.AspectRatio.square);

      expect(
        clips.map((c) => c.targetAspectRatio),
        everyElement(model.AspectRatio.square),
      );
      expect(clips.map((c) => c.id), ['a', 'b']);
    });

    test("moves a clip's shape mask onto the new frame", () {
      const circle = LayerMask(
        shape: LayerMaskShape.ellipse,
        size: Size(0.5, 0.28125),
      );

      final switched = clipsWithAspectRatio([
        clip('a', mask: circle),
      ], model.AspectRatio.square).single;

      expect(
        switched.mask,
        maskForAspectRatioSwitch(
          circle,
          videoAspectRatio: 9 / 16,
          from: vertical,
          to: square,
        ),
      );
      // Round on the square frame too, rather than stretched to an oval.
      expect(switched.mask!.size.width, closeTo(0.5, 1e-9));
      expect(switched.mask!.size.height, closeTo(0.5, 1e-9));
    });

    test('leaves an empty video empty', () {
      expect(clipsWithAspectRatio(const [], model.AspectRatio.square), isEmpty);
    });
  });

  group('placeLayerForAspectRatioSwitch', () {
    test('leaves a layer inside the new frame where it is', () {
      final layer = sticker(offset: const Offset(10, 20));

      placeLayerForAspectRatioSwitch(
        layer,
        size: const Size(100, 40),
        bodySize: body,
        from: vertical,
        to: square,
      );

      expect(layer.offset, const Offset(10, 20));
    });

    test('moves a layer the square frame would cut off onto its edge', () {
      final layer = sticker(offset: const Offset(0, -120));

      placeLayerForAspectRatioSwitch(
        layer,
        size: const Size(60, 40),
        bodySize: body,
        from: vertical,
        to: square,
      );

      // Its top edge now rests on the frame's, 90 above the centre.
      expect(layer.offset.dx, 0);
      expect(layer.offset.dy, closeTo(-70, 1e-6));
    });

    test('measures a turned layer by the box it covers', () {
      final layer = sticker(offset: const Offset(0, -80))
        ..rotation = math.pi / 2;

      placeLayerForAspectRatioSwitch(
        layer,
        size: const Size(100, 20),
        bodySize: body,
        from: vertical,
        to: square,
      );

      // Turned upright it stands 100 high, 50 above its centre.
      expect(layer.offset.dy, closeTo(-40, 1e-6));
    });

    test('keeps a layer peeking in from an edge peeking in as far', () {
      // 30 of its 40 hang above the 9:16 frame.
      final layer = sticker(offset: const Offset(0, -170));

      placeLayerForAspectRatioSwitch(
        layer,
        size: const Size(60, 40),
        bodySize: body,
        from: vertical,
        to: square,
      );

      // 30 hang above the square frame, whose top is 90 above the centre.
      expect(layer.offset.dy, closeTo(-100, 1e-6));
    });

    test('moves nothing when the frame grows to 9:16', () {
      final layer = sticker(offset: const Offset(0, -80));

      placeLayerForAspectRatioSwitch(
        layer,
        size: const Size(60, 40),
        bodySize: body,
        from: square,
        to: vertical,
      );

      expect(layer.offset, const Offset(0, -80));
    });

    test('keeps a layer covering the whole frame where it is', () {
      final layer = sticker(offset: Offset.zero);

      placeLayerForAspectRatioSwitch(
        layer,
        size: body,
        bodySize: body,
        from: vertical,
        to: square,
      );

      expect(layer.offset, Offset.zero);
    });

    test('keeps the centre on the frame while the size is unknown', () {
      final layer = sticker(offset: const Offset(0, 150));

      placeLayerForAspectRatioSwitch(
        layer,
        size: null,
        bodySize: body,
        from: vertical,
        to: square,
      );

      expect(layer.offset.dy, closeTo(90, 1e-6));
    });

    test('moves a layer with keyframes and its keyframes together', () {
      final layer = sticker(offset: const Offset(0, -140))
        ..keyframes = const [
          LayerKeyframe(time: Duration.zero, offset: Offset(0, -140)),
          LayerKeyframe(time: Duration(seconds: 1), offset: Offset(0, -100)),
        ];

      placeLayerForAspectRatioSwitch(
        layer,
        size: const Size(20, 20),
        bodySize: body,
        from: vertical,
        to: square,
      );

      // The motion keeps its length and starts on the frame's top edge.
      expect(layer.keyframes.map((k) => k.offset.dy), [
        closeTo(-80, 1e-6),
        closeTo(-40, 1e-6),
      ]);
      expect(layer.offset.dy, closeTo(-80, 1e-6));
    });

    test('keeps a caption at the same share of the frame, both ways', () {
      final caption = TextLayer(
        text: 'Hello',
        offset: const Offset(0, 320 * 0.32),
        meta: {VideoEditorConstants.captionCueMetaKey: true},
      );

      placeLayerForAspectRatioSwitch(
        caption,
        size: const Size(80, 20),
        bodySize: body,
        from: vertical,
        to: square,
      );
      expect(caption.offset.dy, closeTo(180 * 0.32, 1e-6));

      placeLayerForAspectRatioSwitch(
        caption,
        size: const Size(80, 20),
        bodySize: body,
        from: square,
        to: vertical,
      );
      expect(caption.offset.dy, closeTo(320 * 0.32, 1e-6));
    });

    test('keeps a hidden area on what it hides', () {
      final censor = PaintLayer(
        item: PaintedModel(
          mode: PaintMode.blur,
          offsets: const [Offset.zero, Offset(40, 20)],
          erasedOffsets: const [],
          color: const Color(0xFFFFFFFF),
          strokeWidth: 1,
          opacity: 1,
        ),
        rawSize: const Size(40, 20),
        opacity: 1,
        offset: const Offset(0, -150),
      );

      placeLayerForAspectRatioSwitch(
        censor,
        size: const Size(40, 20),
        bodySize: body,
        from: vertical,
        to: square,
      );

      expect(censor.offset, const Offset(0, -150));
    });

    test('leaves an interactive card to its own placement', () {
      final meta = const SocialStickerData(
        kind: SocialStickerKind.poll,
        pollQuestion: 'Which one?',
        pollOptions: ['Red', 'Blue'],
      ).toMeta();
      final card = WidgetLayer(
        widget: const SizedBox(),
        offset: const Offset(0, -140),
        meta: meta,
      );

      placeLayerForAspectRatioSwitch(
        card,
        size: const Size(60, 40),
        bodySize: body,
        from: vertical,
        to: square,
      );

      expect(card.offset, const Offset(0, -140));
    });
  });

  group('aspectRatioSwitchShift', () {
    test(
      'lets a layer larger than the frame cover as much of it as it can',
      () {
        final shift = aspectRatioSwitchShift(
          bounds: const Rect.fromLTRB(0, 0, 180, 200),
          from: const Rect.fromLTRB(0, 0, 180, 320),
          to: const Rect.fromLTRB(0, 70, 180, 250),
        );

        expect(shift.dx, 0);
        expect(shift.dy, closeTo(50, 1e-6));
      },
    );
  });
}
