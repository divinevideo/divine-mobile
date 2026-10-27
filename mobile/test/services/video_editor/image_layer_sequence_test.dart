import 'dart:typed_data';
import 'dart:ui' show Offset, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/video_editor/image_layer_sequence.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show
        AnimationPhase,
        EditorLayerImage,
        ImageLayer,
        KeyframeClockPoint,
        LayerAnimation,
        LayerAnimationType,
        LayerBlendMode,
        LayerShapeMask,
        LayerShapeMaskShape,
        TimelineKeyframe;

void main() {
  group('imageLayerSequence', () {
    ImageLayer part(int byte, Duration start, Duration? end) => ImageLayer(
      image: EditorLayerImage.memory(Uint8List.fromList([byte])),
      startTime: start,
      endTime: end,
      offset: const Offset(30, 60),
      size: const Size(90, 40),
      animations: const [
        LayerAnimation(
          type: LayerAnimationType.fade,
          phase: AnimationPhase.animateIn,
          duration: Duration(milliseconds: 200),
        ),
      ],
      animationStartTime: const Duration(seconds: 1),
      animationEndTime: const Duration(seconds: 3),
      blendMode: LayerBlendMode.screen,
      keyframes: const [
        TimelineKeyframe(time: Duration(seconds: 2), offset: Offset(50, 70)),
      ],
      keyframeClock: const [
        KeyframeClockPoint(output: Duration.zero, keyframe: Duration.zero),
      ],
      shapeMask: const LayerShapeMask(shape: LayerShapeMaskShape.ellipse),
    );

    test('plays the parts one after the other from one layer', () {
      final sequence = imageLayerSequence([
        part(1, const Duration(seconds: 1), const Duration(milliseconds: 1200)),
        part(2, const Duration(milliseconds: 1200), const Duration(seconds: 2)),
        part(3, const Duration(seconds: 2), const Duration(seconds: 3)),
      ]);

      expect(sequence.frames.map((f) => f.image.byteArray!.single), [1, 2, 3]);
      expect(sequence.frames.map((f) => f.duration).take(2), [
        const Duration(milliseconds: 200),
        const Duration(milliseconds: 800),
      ]);
      // The last part holds until the layer ends.
      expect(sequence.loop, isFalse);
      expect(sequence.startTime, const Duration(seconds: 1));
      expect(sequence.endTime, const Duration(seconds: 3));
      expect(sequence.offset, const Offset(30, 60));
      expect(sequence.size, const Size(90, 40));
      expect(sequence.blendMode, LayerBlendMode.screen);
      expect(sequence.animations, hasLength(1));
      expect(sequence.animationStartTime, const Duration(seconds: 1));
      expect(sequence.animationEndTime, const Duration(seconds: 3));
      expect(sequence.keyframes.single.offset, const Offset(50, 70));
      expect(sequence.keyframeClock, hasLength(1));
      expect(sequence.shapeMask?.shape, LayerShapeMaskShape.ellipse);
    });
  });
}
