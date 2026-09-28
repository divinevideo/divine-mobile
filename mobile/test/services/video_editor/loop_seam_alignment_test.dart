import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/video_editor/loop_seam_alignment.dart';

import 'loop_seam_test_scene.dart';

void main() {
  group('estimateLoopSeamAlignment', () {
    final scene = TestScene();
    final first = scene.frame();

    test('recovers a pure camera shift', () {
      final last = scene.frame(dx: 5, dy: -8);

      final estimate = estimateLoopSeamAlignment(last: last, first: first);

      expect(estimate.isUsable, isTrue, reason: '${estimate.rejection}');
      expect(estimate.alignment.dx * first.width, closeTo(5, 0.6));
      expect(estimate.alignment.dy * first.height, closeTo(-8, 0.6));
      expect(estimate.alignment.scale, closeTo(1, 0.004));
    });

    test('recovers a zoom combined with a shift', () {
      final last = scene.frame(scale: 1.03, dx: -3, dy: 4);

      final estimate = estimateLoopSeamAlignment(last: last, first: first);

      expect(estimate.isUsable, isTrue, reason: '${estimate.rejection}');
      expect(estimate.alignment.scale, closeTo(1.03, 0.004));
      expect(estimate.alignment.dx * first.width, closeTo(-3, 0.8));
      expect(estimate.alignment.dy * first.height, closeTo(4, 0.8));
    });

    test('removes most of the seam mismatch it finds', () {
      final last = scene.frame(dx: 4, dy: 6);

      final estimate = estimateLoopSeamAlignment(last: last, first: first);

      expect(estimate.alignment.improvement, greaterThan(0.8));
    });

    test('ignores an exposure change between the two ends', () {
      final darker = _scaledBrightness(scene.frame(dx: 4, dy: 3), 0.6);

      final estimate = estimateLoopSeamAlignment(last: darker, first: first);

      expect(estimate.isUsable, isTrue, reason: '${estimate.rejection}');
      expect(estimate.alignment.dx * first.width, closeTo(4, 0.6));
      expect(estimate.alignment.dy * first.height, closeTo(3, 0.6));
    });

    test('reports frames that already match as seamless', () {
      final estimate = estimateLoopSeamAlignment(
        last: scene.frame(),
        first: first,
      );

      expect(estimate.rejection, LoopSeamRejection.alreadySeamless);
    });

    test('rejects two unrelated shots', () {
      final other = TestScene(seed: 99).frame();

      final estimate = estimateLoopSeamAlignment(last: other, first: first);

      expect(estimate.isUsable, isFalse);
      expect(
        estimate.rejection,
        anyOf(
          LoopSeamRejection.unrelatedFrames,
          LoopSeamRejection.noImprovement,
          LoopSeamRejection.searchBoundary,
        ),
      );
    });

    test('rejects a move larger than a small zoom can hide', () {
      // 9% of the height: inside the search window, past the apply limit.
      final last = scene.frame(dy: 17);

      final estimate = estimateLoopSeamAlignment(last: last, first: first);

      expect(estimate.rejection, LoopSeamRejection.tooLarge);
      expect(estimate.alignment.dy * first.height, closeTo(17, 0.8));
    });
  });

  group(GrayFrame, () {
    test('normalises to zero mean and unit variance', () {
      final frame = TestScene().frame();
      final n = frame.luma.length;
      final mean = frame.luma.reduce((a, b) => a + b) / n;
      final variance =
          frame.luma
              .map((v) => (v - mean) * (v - mean))
              .reduce((a, b) => a + b) /
          n;

      expect(mean, closeTo(0, 1e-3));
      expect(variance, closeTo(1, 1e-3));
    });

    test('keeps a flat frame at zero instead of amplifying noise', () {
      final rgba = Uint8List(4 * 4 * 4)..fillRange(0, 64, 40);

      final frame = GrayFrame.fromRgba(4, 4, rgba);

      expect(frame.luma, everyElement(0));
    });

    test('halves both dimensions when downsampled', () {
      final frame = TestScene().frame();

      final half = frame.downsampled();

      expect(half.width, frame.width ~/ 2);
      expect(half.height, frame.height ~/ 2);
    });
  });
}

/// [frame] with its contrast scaled by [factor], as a darker exposure does
/// after normalisation strips the offset.
GrayFrame _scaledBrightness(GrayFrame frame, double factor) {
  final rgba = Uint8List(frame.width * frame.height * 4);
  for (var i = 0; i < frame.luma.length; i++) {
    final v = (100 + frame.luma[i] * 40 * factor).round().clamp(0, 255);
    rgba
      ..[i * 4] = v
      ..[i * 4 + 1] = v
      ..[i * 4 + 2] = v
      ..[i * 4 + 3] = 255;
  }
  return GrayFrame.fromRgba(frame.width, frame.height, rgba);
}
