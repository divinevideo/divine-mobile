import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/extensions/clip_keyframes.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

const _tolerance = Duration(milliseconds: 33);

DivineVideoClip _clip({
  List<SegmentKeyframe> keyframes = const [],
  Duration duration = const Duration(seconds: 4),
  Duration trimStart = Duration.zero,
  double? playbackSpeed,
}) => DivineVideoClip(
  id: 'clip',
  video: EditorVideo.file('/tmp/clip.mp4'),
  duration: duration,
  recordedAt: DateTime(2026),
  targetAspectRatio: model.AspectRatio.vertical,
  originalAspectRatio: 9 / 16,
  trimStart: trimStart,
  playbackSpeed: playbackSpeed,
  keyframes: keyframes,
);

void main() {
  group('clipMotionAt', () {
    const keyframes = [
      SegmentKeyframe(time: Duration(seconds: 1), curve: AnimationCurve.easeIn),
      SegmentKeyframe(
        time: Duration(seconds: 3),
        offset: Offset(0.2, -0.4),
        scale: 3,
        rotation: math.pi,
      ),
    ];

    test('returns null without keyframes', () {
      expect(clipMotionAt(const [], Duration.zero), isNull);
    });

    test('holds the first keyframe before it and the last after it', () {
      expect(clipMotionAt(keyframes, Duration.zero), stillClipMotion);
      expect(clipMotionAt(keyframes, const Duration(seconds: 9))!.scale, 3);
    });

    test('eases between two keyframes along the earlier curve', () {
      final motion = clipMotionAt(keyframes, const Duration(seconds: 2))!;

      // easeIn is t², a quarter of the way at half the time.
      expect(motion.scale, closeTo(1.5, 1e-9));
      expect(motion.rotation, closeTo(math.pi / 4, 1e-9));
      expect(motion.offset.dx, closeTo(0.05, 1e-9));
      expect(motion.offset.dy, closeTo(-0.1, 1e-9));
    });
  });

  group('clipMotionMatrix', () {
    test('zooms and turns around the center, then shifts by shares', () {
      const size = Size(100, 200);
      final matrix = clipMotionMatrix((
        offset: const Offset(0.1, 0.05),
        scale: 2,
        rotation: math.pi / 2,
      ), size);

      // The center only moves by the shift.
      expect(
        MatrixUtils.transformPoint(matrix, const Offset(50, 100)),
        offsetMoreOrLessEquals(const Offset(60, 110)),
      );
      // A point right of the center turns clockwise to below it, twice as far.
      expect(
        MatrixUtils.transformPoint(matrix, const Offset(60, 100)),
        offsetMoreOrLessEquals(const Offset(60, 130)),
      );
    });
  });

  group('ClipKeyframeTimeline', () {
    test('maps a moment on the clip to its frame through the speed', () {
      final clip = _clip(
        trimStart: const Duration(milliseconds: 500),
        playbackSpeed: 2,
      );

      expect(
        clip.sourceTimeAt(const Duration(seconds: 1)),
        const Duration(milliseconds: 2500),
      );
      expect(
        clip.playbackOffsetOf(const Duration(milliseconds: 2500)),
        const Duration(seconds: 1),
      );
    });

    test('keyframesFrom counts the keyframes from a later start', () {
      final clip = _clip(
        keyframes: const [SegmentKeyframe(time: Duration(seconds: 2))],
      );

      expect(
        clip.keyframesFrom(const Duration(milliseconds: 500)).single.time,
        const Duration(milliseconds: 1500),
      );
    });

    test('keyframesReversed shows every frame with the motion of its own', () {
      const start = Duration(milliseconds: 500);
      const end = Duration(milliseconds: 3500);
      final clip = _clip(
        keyframes: const [
          SegmentKeyframe(
            time: Duration(seconds: 1),
            offset: Offset(-0.1, 0),
            curve: AnimationCurve.easeOutCubic,
          ),
          SegmentKeyframe(
            time: Duration(seconds: 2),
            scale: 2,
            curve: AnimationCurve.bounceIn,
          ),
          SegmentKeyframe(time: Duration(seconds: 3), rotation: 1),
        ],
      );

      final reversed = clip.keyframesReversed(start, end);
      // The reversed file opens on the frame a frame before the end.
      final opening = end - const Duration(microseconds: 33333);

      for (var ms = 500; ms < 3500; ms += 100) {
        final source = Duration(milliseconds: ms);
        final forward = clip.motionAt(source);
        final backward = clipMotionAt(reversed, opening - source)!;
        expect(backward.scale, closeTo(forward.scale, 1e-9), reason: '$source');
        expect(backward.rotation, closeTo(forward.rotation, 1e-9));
        expect(backward.offset.dx, closeTo(forward.offset.dx, 1e-9));
      }
    });
  });

  group('ClipKeyframeEditing', () {
    const at1 = Duration(seconds: 1);
    const at2 = Duration(seconds: 2);
    const keyframes = [
      SegmentKeyframe(time: at1, curve: AnimationCurve.easeOut),
      SegmentKeyframe(time: at2, scale: 2),
    ];

    test('toggledAt adds a keyframe holding what the picture shows', () {
      final toggled = keyframes.toggledAt(
        const Duration(milliseconds: 1500),
        tolerance: _tolerance,
      );

      expect(toggled, hasLength(3));
      expect(toggled[1].time, const Duration(milliseconds: 1500));
      expect(
        toggled[1].scale,
        closeTo(clipMotionAt(keyframes, toggled[1].time)!.scale, 1e-9),
      );
      // The motion it lands in keeps easing the same way.
      expect(toggled[1].curve, AnimationCurve.easeOut);
    });

    test('toggledAt removes the keyframe within the tolerance', () {
      final toggled = keyframes.toggledAt(
        at2 + const Duration(milliseconds: 10),
        tolerance: _tolerance,
      );

      expect(toggled, [keyframes.first]);
    });

    test('withMotionAt changes the keyframe there instead of adding one', () {
      final moved = keyframes.withMotionAt(at1, (
        offset: const Offset(0.1, 0),
        scale: 1.5,
        rotation: 0,
      ), tolerance: _tolerance);

      expect(moved, hasLength(2));
      expect(moved.first.scale, 1.5);
      expect(moved.first.curve, AnimationCurve.easeOut);
    });

    test('withCurveAt eases the motion the time is in', () {
      final eased = keyframes.withCurveAt(
        const Duration(milliseconds: 1200),
        AnimationCurve.elasticOut,
        tolerance: _tolerance,
      );

      expect(eased.first.curve, AnimationCurve.elasticOut);
      expect(
        [keyframes.first].withCurveAt(
          at1,
          AnimationCurve.elasticOut,
          tolerance: _tolerance,
        ),
        [keyframes.first],
      );
    });

    test(
      'turnedAndFlipped moves each picture the same way on the new frame',
      () {
        const keyframe = SegmentKeyframe(
          time: at1,
          offset: Offset(0.2, 0.1),
          rotation: 0.3,
        );

        // A quarter turn clockwise: right of the center becomes below it.
        expect(
          [keyframe]
              .turnedAndFlipped(rotateTurns: 1, flipX: false, flipY: false),
          [keyframe.copyWith(offset: const Offset(-0.1, 0.2))],
        );
        // Mirrored once, the shift and the turn go the other way.
        expect(
          [keyframe]
              .turnedAndFlipped(rotateTurns: 0, flipX: true, flipY: false),
          [keyframe.copyWith(offset: const Offset(-0.2, 0.1), rotation: -0.3)],
        );
        // Mirrored both ways is a half turn, which keeps the turn's sense.
        expect(
          [keyframe].turnedAndFlipped(rotateTurns: 2, flipX: true, flipY: true),
          [keyframe],
        );
      },
    );
  });

  group('clampedClipMotion', () {
    test('keeps the picture at its own size or larger', () {
      expect(
        clampedClipMotion((offset: Offset.zero, scale: 0.5, rotation: 0)).scale,
        1,
      );
    });

    test('keeps an unturned picture over the whole frame', () {
      final clamped = clampedClipMotion(
        (offset: const Offset(0.4, -0.4), scale: 1.5, rotation: 0),
        frame: const Size(1, 0.8),
      );

      expect(clamped.offset.dx, closeTo(0.25, 1e-9));
      expect(clamped.offset.dy, closeTo(-0.35, 1e-9));
    });

    test('lets a turned picture go anywhere', () {
      const motion = (offset: Offset(0.4, 0), scale: 1.0, rotation: 0.2);

      expect(clampedClipMotion(motion), motion);
    });
  });

  group('clipFrameAtTimelinePosition', () {
    test('finds the clip and the frame shown at a timeline position', () {
      final first = _clip(duration: const Duration(seconds: 2));
      final second = _clip(
        trimStart: const Duration(seconds: 1),
        playbackSpeed: 2,
      );

      final frame = clipFrameAtTimelinePosition([
        first,
        second,
      ], const Duration(milliseconds: 2500))!;

      expect(frame.clip, same(second));
      expect(frame.sourceTime, const Duration(seconds: 2));
      expect(clipFrameAtTimelinePosition(const [], Duration.zero), isNull);
    });
  });
}
