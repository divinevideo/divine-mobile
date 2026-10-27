// ABOUTME: Divine's side of a timeline clip's keyframes: where they put the
// ABOUTME: picture at a frame, and how they follow the clip's file when it changes.

import 'dart:math' as math;

import 'package:flutter/widgets.dart' show Matrix4, Offset, Size;
import 'package:openvine/extensions/animation_curve_easing.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

/// Where a timeline clip's keyframes put its picture at one frame: scaled by
/// [scale] and turned clockwise by [rotation] radians around the frame's
/// center, then shifted by [offset], as shares of the frame's width and
/// height.
typedef ClipMotion = ({Offset offset, double scale, double rotation});

/// The picture where it is: what a clip without keyframes shows.
const ClipMotion stillClipMotion = (offset: Offset.zero, scale: 1, rotation: 0);

/// A timeline clip's keyframes while they are being changed, before the
/// change is written to the clip: shown on the canvas in place of the clip's
/// own.
typedef LiveClipKeyframes = ({String clipId, List<SegmentKeyframe> keyframes});

/// The clip under [position] on the editor timeline and the timestamp in its
/// file of the frame shown there, or `null` without clips.
///
/// A position on a boundary belongs to the clip that starts there, and the
/// last clip holds anything past the end, as [clipAtTimelinePosition] does.
({DivineVideoClip clip, Duration sourceTime})? clipFrameAtTimelinePosition(
  List<DivineVideoClip> clips,
  Duration position,
) {
  var start = Duration.zero;
  for (var i = 0; i < clips.length; i++) {
    final clip = clips[i];
    final end = start + clip.playbackDuration;
    if (position < end || i == clips.length - 1) {
      var offset = position - start;
      if (offset.isNegative) offset = Duration.zero;
      if (offset > clip.playbackDuration) offset = clip.playbackDuration;
      return (clip: clip, sourceTime: clip.sourceTimeAt(offset));
    }
    start = end;
  }
  return null;
}

/// The motion [keyframes] give the frame with source timestamp [time], or
/// `null` when there are none.
///
/// Before the first keyframe the picture holds it, after the last one the last
/// one, and between two the earlier one's curve eases from one to the other.
/// Mirrors how pro_video_editor moves a segment's frames, so the preview shows
/// what the export renders.
ClipMotion? clipMotionAt(List<SegmentKeyframe> keyframes, Duration time) {
  if (keyframes.isEmpty) return null;
  final first = keyframes.first;
  if (time <= first.time) return _motionOf(first);
  final last = keyframes.last;
  if (time >= last.time) return _motionOf(last);
  final index = keyframes.lastIndexWhere((k) => k.time <= time);
  final from = keyframes[index];
  final to = keyframes[index + 1];
  final span = (to.time - from.time).inMicroseconds;
  if (span <= 0) return _motionOf(to);
  final eased = from.curve.ease((time - from.time).inMicroseconds / span);
  double mix(double a, double b) => a + (b - a) * eased;
  return (
    offset: Offset(
      mix(from.offset.dx, to.offset.dx),
      mix(from.offset.dy, to.offset.dy),
    ),
    scale: math.max(0, mix(from.scale, to.scale)),
    rotation: mix(from.rotation, to.rotation),
  );
}

ClipMotion _motionOf(SegmentKeyframe keyframe) => (
  offset: keyframe.offset,
  scale: keyframe.scale,
  rotation: keyframe.rotation,
);

/// The transform that moves a frame of [frameSize] by [motion], in the
/// frame's own coordinates.
Matrix4 clipMotionMatrix(ClipMotion motion, Size frameSize) {
  final center = frameSize.center(Offset.zero);
  return Matrix4.identity()
    ..translateByDouble(
      center.dx + motion.offset.dx * frameSize.width,
      center.dy + motion.offset.dy * frameSize.height,
      0,
      1,
    )
    ..rotateZ(motion.rotation)
    ..scaleByDouble(motion.scale, motion.scale, 1, 1)
    ..translateByDouble(-center.dx, -center.dy, 0, 1);
}

/// The curve that eases a stretch played backwards through the values [curve]
/// eases it through forwards: the in and out halves swap, and the symmetric
/// curves are their own mirror.
AnimationCurve mirroredAnimationCurve(AnimationCurve curve) => switch (curve) {
  AnimationCurve.easeIn => AnimationCurve.easeOut,
  AnimationCurve.easeOut => AnimationCurve.easeIn,
  AnimationCurve.easeInCubic => AnimationCurve.easeOutCubic,
  AnimationCurve.easeOutCubic => AnimationCurve.easeInCubic,
  AnimationCurve.bounceIn => AnimationCurve.bounceOut,
  AnimationCurve.bounceOut => AnimationCurve.bounceIn,
  AnimationCurve.elasticIn => AnimationCurve.elasticOut,
  AnimationCurve.elasticOut => AnimationCurve.elasticIn,
  _ => curve,
};

/// How the keyframes of a timeline clip follow its file.
extension ClipKeyframeTimeline on DivineVideoClip {
  /// The frame a reversed render opens on lies about one frame before the
  /// end of what it reverses; at 30 fps, which a recording or a render of one
  /// has, that is close enough for a motion that eases over many frames.
  static const _nominalFrame = Duration(microseconds: 33333);

  /// Whether the clip's picture moves.
  bool get hasKeyframes => keyframes.isNotEmpty;

  /// The timestamp in [DivineVideoClip.video] of the frame [playbackOffset]
  /// into the clip on the timeline, through its speed.
  Duration sourceTimeAt(Duration playbackOffset) =>
      trimStart + playbackOffsetToSourceOffset(playbackOffset);

  /// Where on the clip's own timeline the frame at [sourceTime] plays; the
  /// inverse of [sourceTimeAt].
  Duration playbackOffsetOf(Duration sourceTime) =>
      sourceOffsetToPlaybackOffset(sourceTime - trimStart);

  /// Where the keyframes put the picture of the frame at [sourceTime].
  ClipMotion motionAt(Duration sourceTime) =>
      clipMotionAt(keyframes, sourceTime) ?? stillClipMotion;

  /// The keyframes of a file that holds this clip's file from [start] on: a
  /// render of part of it, whose timestamps count from there.
  List<SegmentKeyframe> keyframesFrom(Duration start) => [
    for (final keyframe in keyframes)
      keyframe.copyWith(time: keyframe.time - start),
  ];

  /// The keyframes of a file that holds this clip's file from [start] to
  /// [end] played backwards.
  ///
  /// Each frame keeps the motion of its own frame: a keyframe at `t` lands on
  /// the reversed file's frame that shows it, and each stretch between two is
  /// eased along the mirror of its curve, so the picture passes through the
  /// same placements backwards.
  List<SegmentKeyframe> keyframesReversed(Duration start, Duration end) {
    if (keyframes.isEmpty) return keyframes;
    final opening = end - _nominalFrame;
    final last = keyframes.length - 1;
    return [
      for (var i = last; i >= 0; i--)
        keyframes[i].copyWith(
          time: opening - keyframes[i].time,
          // The stretch after this keyframe played backwards is the one
          // before it in the file, eased by the keyframe that starts it there.
          curve: i > 0
              ? mirroredAnimationCurve(keyframes[i - 1].curve)
              : AnimationCurve.linear,
        ),
    ];
  }
}

/// Editing a timeline clip's keyframes, each at a timestamp in its file.
///
/// A keyframe within [tolerance] of a time is the one at that time: a seek
/// lands on the frame the player delivers, a few milliseconds off the time
/// asked for.
extension ClipKeyframeEditing on List<SegmentKeyframe> {
  /// The index of the keyframe at [time], or -1.
  int indexAt(Duration time, {required Duration tolerance}) =>
      indexWhere((keyframe) => (keyframe.time - time).abs() <= tolerance);

  /// These keyframes with one at [time] holding [motion]: the one there
  /// changed, or a new one added in order, which keeps the curve of the
  /// motion it lands in.
  List<SegmentKeyframe> withMotionAt(
    Duration time,
    ClipMotion motion, {
    required Duration tolerance,
  }) {
    final index = indexAt(time, tolerance: tolerance);
    if (index >= 0) {
      return [
        for (var i = 0; i < length; i++)
          if (i == index)
            this[i].copyWith(
              offset: motion.offset,
              scale: motion.scale,
              rotation: motion.rotation,
            )
          else
            this[i],
      ];
    }
    final before = lastIndexWhere((keyframe) => keyframe.time < time);
    return [
      ...take(before + 1),
      SegmentKeyframe(
        time: time,
        offset: motion.offset,
        scale: motion.scale,
        rotation: motion.rotation,
        curve: before >= 0 ? this[before].curve : AnimationCurve.linear,
      ),
      ...skip(before + 1),
    ];
  }

  /// These keyframes with one added at [time], holding what the picture
  /// shows there, or with the one there removed.
  List<SegmentKeyframe> toggledAt(
    Duration time, {
    required Duration tolerance,
  }) {
    final index = indexAt(time, tolerance: tolerance);
    if (index >= 0) return [...take(index), ...skip(index + 1)];
    return withMotionAt(
      time,
      clipMotionAt(this, time) ?? stillClipMotion,
      tolerance: tolerance,
    );
  }

  /// These keyframes on a file whose frames are this one's turned
  /// [rotateTurns] quarter turns clockwise and then mirrored by [flipX] and
  /// [flipY], as a transform bakes them: each picture moves the same way on
  /// the turned frame as it did on the old one.
  ///
  /// A crop keeps the shares as they are, so the motion stays as large on
  /// the frame it leaves.
  List<SegmentKeyframe> turnedAndFlipped({
    required int rotateTurns,
    required bool flipX,
    required bool flipY,
  }) {
    final turns = rotateTurns % 4;
    if (turns == 0 && !flipX && !flipY) return this;
    final mirrored = flipX != flipY;
    return [
      for (final keyframe in this)
        keyframe.copyWith(
          offset: _flipped(_turned(keyframe.offset, turns), flipX, flipY),
          rotation: mirrored ? -keyframe.rotation : keyframe.rotation,
        ),
    ];
  }

  /// The index of the keyframe whose curve eases the motion at [time]: the
  /// last one at or before it, held between the first and the second to
  /// last. `null` with fewer than two keyframes, which leave no motion.
  int? segmentIndexAt(Duration time, {required Duration tolerance}) {
    if (length < 2) return null;
    final atOrBefore = lastIndexWhere(
      (keyframe) => keyframe.time <= time + tolerance,
    );
    return atOrBefore.clamp(0, length - 2);
  }

  /// These keyframes with the motion at [time] eased along [curve].
  List<SegmentKeyframe> withCurveAt(
    Duration time,
    AnimationCurve curve, {
    required Duration tolerance,
  }) {
    final index = segmentIndexAt(time, tolerance: tolerance);
    if (index == null) return this;
    return [
      for (var i = 0; i < length; i++)
        if (i == index) this[i].copyWith(curve: curve) else this[i],
    ];
  }
}

/// [offset], a shift as shares of a frame, on that frame turned [turns]
/// quarter turns clockwise: the frame's width and height swap with each turn,
/// so a share right of the center lands a share below it.
Offset _turned(Offset offset, int turns) => switch (turns) {
  1 => Offset(-offset.dy, offset.dx),
  2 => -offset,
  3 => Offset(offset.dy, -offset.dx),
  _ => offset,
};

Offset _flipped(Offset offset, bool flipX, bool flipY) =>
    Offset(flipX ? -offset.dx : offset.dx, flipY ? -offset.dy : offset.dy);

/// [motion] kept at or above the clip's own size, and when it is not turned,
/// shifted no further than keeps [frame] filled: [frame] is the share of the
/// clip's frame the export keeps, each side as a share of the clip's.
///
/// A turned picture shows black corners however it is placed, as a shape
/// mask covers what it hides; it is only kept at its size.
ClipMotion clampedClipMotion(
  ClipMotion motion, {
  Size frame = const Size(1, 1),
}) {
  final scale = math.max(1.0, motion.scale);
  if (motion.rotation != 0) {
    return (offset: motion.offset, scale: scale, rotation: motion.rotation);
  }
  final maxX = (scale - frame.width) / 2;
  final maxY = (scale - frame.height) / 2;
  return (
    offset: Offset(
      motion.offset.dx.clamp(-maxX, maxX),
      motion.offset.dy.clamp(-maxY, maxY),
    ),
    scale: scale,
    rotation: 0,
  );
}
