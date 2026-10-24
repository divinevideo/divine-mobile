import 'dart:math' as math;
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:loop_alignment_repository/loop_alignment_repository.dart';

import 'helpers/generated_scene.dart';

void main() {
  for (final size in [(160, 96), (96, 160)]) {
    final (w, h) = size;
    for (final endpoint in [
      LoopPose.components(x: 2.4, y: 1),
      LoopPose.components(angle: .018),
      LoopPose.components(logScale: math.log(1.015)),
    ]) {
      test('$w x $h subpixel rotation scale and translation registration', () {
        final frames = <LoopFrame>[], poses = <LoopFrame, LoopPose>{};
        for (var i = 0; i <= 50; i++) {
          final p = LoopPose.interpolate(LoopPose.identity, endpoint, i / 50);
          final f = scene(
            width: w,
            height: h,
            time: Duration(milliseconds: i * 40),
            pose: p,
          );
          frames.add(f);
          poses[f] = p;
        }
        final result = const LoopAlignmentPlanner().plan(
          input: LoopRepairInput(
            clips: [clip('one', width: w, height: h)],
            revision: 'one',
          ),
          firstFrames: frames,
          lastFrames: frames,
          matcher: SceneMatcher(poses),
          limits: const LoopAlignmentLimits(),
        );
        expect(result, isNotNull);
        final start = poses[frames.first]!.then(
          result!.clips.single.correctionAt(frames.first.time),
        );
        final end = poses[frames.last]!.then(
          result.clips.single.correctionAt(frames.last.time),
        );
        expect(
          start.inverse().then(end).maximumCornerDisplacement(w, h),
          lessThan(.5),
        );
      });
    }
    for (final damage in ['exposure', 'occlusion', 'unrelated', 'blank']) {
      test('$w x $h rejects $damage despite supplied geometric fit', () {
        final opening = <LoopFrame>[],
            ending = <LoopFrame>[],
            poses = <LoopFrame, LoopPose>{};
        for (var i = 0; i <= 50; i++) {
          final f = scene(
            width: w,
            height: h,
            time: Duration(milliseconds: i * 40),
            blank: damage == 'blank',
          );
          opening.add(f);
          poses[f] = LoopPose.identity;
          final p = LoopPose.components(x: 2);
          var g = scene(
            width: w,
            height: h,
            time: Duration(milliseconds: i * 40),
            pose: p,
            exposure: damage == 'exposure' ? 50 : 0,
            blank: damage == 'blank',
          );
          if (damage == 'occlusion' || damage == 'unrelated') {
            final bytes = Uint8List.fromList(g.luma);
            for (var y = 0; y < h; y++) {
              for (var x = 0; x < w; x++) {
                if (damage == 'unrelated' ||
                    (x > w * .2 && x < w * .8 && y > h * .2 && y < h * .8))
                  bytes[y * w + x] = (x * 43 + y * 71 + i * 17) % 256;
              }
            }
            g = LoopFrame(time: g.time, width: w, height: h, luma: bytes);
          }
          ending.add(g);
          poses[g] = p;
        }
        expect(
          const LoopAlignmentPlanner().plan(
            input: LoopRepairInput(
              clips: [
                clip('first', width: w, height: h),
                clip('last', width: w, height: h),
              ],
              revision: 'one',
            ),
            firstFrames: opening,
            lastFrames: ending,
            matcher: SceneMatcher(poses),
            limits: const LoopAlignmentLimits(),
          ),
          isNull,
        );
      });
    }
  }
  test(
    'short final shot rejects excessive crop and preserves source cut times',
    () {
      final opening = <LoopFrame>[],
          ending = <LoopFrame>[],
          poses = <LoopFrame, LoopPose>{};
      for (var i = 0; i < 3; i++) {
        final f = scene(
          width: 96,
          height: 160,
          time: Duration(milliseconds: i * 40),
        );
        opening.add(f);
        poses[f] = LoopPose.identity;
        final p = LoopPose.components(
          x: 2.85,
          angle: .034,
          logScale: math.log(1.029),
        );
        final g = scene(
          width: 96,
          height: 160,
          time: Duration(milliseconds: i * 40),
          pose: p,
        );
        ending.add(g);
        poses[g] = p;
      }
      expect(
        const LoopAlignmentPlanner().plan(
          input: LoopRepairInput(
            clips: [
              clip('first', width: 96, height: 160),
              clip(
                'last',
                width: 96,
                height: 160,
                end: const Duration(milliseconds: 120),
              ),
            ],
            revision: 'one',
          ),
          firstFrames: opening,
          lastFrames: ending,
          matcher: SceneMatcher(poses),
          limits: const LoopAlignmentLimits(),
        ),
        isNull,
      );
    },
  );
  test('bilinear resampling preserves identity and samples fractional pixel centers', () {
    final f = LoopFrame(
      time: Duration.zero,
      width: 2,
      height: 2,
      luma: Uint8List.fromList([0, 100, 100, 200]),
    );
    expect(const LoopFrameResampler().sample(f, .5, .5), 100);
    expect(
      const LoopFrameResampler()
          .warp(f, LoopPose.identity, 1, longestEdge: 2)
          .luma,
      orderedEquals(f.luma),
    );
  });
}
