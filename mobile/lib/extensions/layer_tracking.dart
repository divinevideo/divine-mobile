// ABOUTME: Turns the path of a tracked object into a layer's keyframes, so the
// ABOUTME: layer follows the object it was pinned to (#9848).

import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/video_editor/layer_track_target.dart';
import 'package:openvine/models/video_editor/track_frame_mapping.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show Layer, LayerKeyframe, LayerPlacement;
import 'package:pro_video_editor/pro_video_editor.dart'
    show ObjectTrackSample, VideoObjectTrack;

/// Where a layer following a tracked object is at one moment.
@visibleForTesting
typedef TrackedPose = ({
  Duration time,
  Offset offset,
  double scale,
  double rotation,
  double opacity,
});

/// The keyframes that pin [layer] to the object [track] followed through
/// [target], or `null` when the track covers less than two frames of the
/// stretch the layer follows it for.
///
/// The layer keeps where it sits against the object at the marked moment:
/// a label above someone's head stays above it, and grows and shrinks with
/// them as they come closer or walk away. Its turn and its opacity stay what
/// [placementAt] gives at each moment, so a keyframed fade or spin plays on,
/// and its size is that size times how much the object grew. [placementAt]
/// is where the layer shows at an editor time without the track: its
/// keyframes, or its own placement when it has none.
///
/// The path is cut down to as few keyframes as keep the layer within
/// [tolerance] canvas pixels of it (see [simplifyTrackedPoses]); they ease
/// linearly, since between two of them a straight line is what the track
/// found. Keyframes
/// the layer had inside the tracked stretch give way to the track's; those
/// outside it stay, and the layer moves between them and the track as
/// between any two keyframes. Before and after the stretch the layer holds
/// the track's first and last place, as a layer holds still before its first
/// keyframe and after its last.
List<LayerKeyframe>? trackedLayerKeyframes({
  required Layer layer,
  required VideoObjectTrack track,
  required LayerTrackTarget target,
  required TrackFrameMapping mapping,
  required LayerPlacement Function(Duration editorTime) placementAt,
  double tolerance = VideoEditorConstants.trackingKeyframeTolerance,
  double referenceSize = VideoEditorConstants.trackingKeyframeReferenceSize,
}) {
  final marked = track.anchor ?? _closestTo(track.samples, track.anchorTime);
  if (marked == null) return null;
  final anchorPlacement = placementAt(target.editorTimeAt(marked.time));
  final objectAtAnchor = mapping.layerOffsetOf(marked.center);
  final fromObject = anchorPlacement.offset - objectAtAnchor;

  final poses = <TrackedPose>[];
  for (final sample in track.samples) {
    final time = target.editorTimeAt(sample.time);
    if (time < target.start || time > target.end) continue;
    if (poses.isNotEmpty && time <= poses.last.time) continue;
    final own = placementAt(time);
    poses.add((
      time: time,
      offset: mapping.layerOffsetOf(sample.center) + fromObject * sample.scale,
      scale: own.scale * sample.scale,
      rotation: own.rotation,
      opacity: own.opacity,
    ));
  }
  if (poses.length < 2) return null;

  final kept = simplifyTrackedPoses(
    poses,
    tolerance: tolerance,
    referenceSize: referenceSize,
  );
  final origin = layer.keyframeOrigin;
  final from = poses.first.time - VideoEditorConstants.keyframeTolerance;
  final to = poses.last.time + VideoEditorConstants.keyframeTolerance;
  return [
    for (final keyframe in layer.keyframes)
      if (origin + keyframe.time < from || origin + keyframe.time > to)
        keyframe,
    for (final pose in kept)
      LayerKeyframe(
        time: pose.time - origin,
        offset: pose.offset,
        scale: pose.scale,
        rotation: pose.rotation,
        opacity: pose.opacity,
      ),
  ]..sort((a, b) => a.time.compareTo(b.time));
}

/// The fewest of [poses] that a layer moving in straight lines between them
/// keeps within [tolerance] of every pose (Ramer–Douglas–Peucker, on time).
///
/// The first and last pose always stay. A pose is measured against the line
/// between the two kept poses around it: by how far apart the two places are
/// in canvas pixels, plus the scale, turn and opacity differences, each
/// weighed as [referenceSize] pixels per whole unit.
@visibleForTesting
List<TrackedPose> simplifyTrackedPoses(
  List<TrackedPose> poses, {
  required double tolerance,
  required double referenceSize,
}) {
  if (poses.length <= 2) return poses;
  final keep = List<bool>.filled(poses.length, false);
  keep[0] = true;
  keep[poses.length - 1] = true;
  final stretches = <(int, int)>[(0, poses.length - 1)];
  while (stretches.isNotEmpty) {
    final (first, last) = stretches.removeLast();
    if (last - first < 2) continue;
    final a = poses[first];
    final b = poses[last];
    final span = (b.time - a.time).inMicroseconds;
    var worst = -1;
    var worstError = tolerance;
    for (var i = first + 1; i < last; i++) {
      final p = poses[i];
      final t = span == 0 ? 0.0 : (p.time - a.time).inMicroseconds / span;
      final offset = Offset.lerp(a.offset, b.offset, t)!;
      final error =
          (p.offset - offset).distance +
          referenceSize *
              ((p.scale - _lerp(a.scale, b.scale, t)).abs() +
                  (p.rotation - _lerp(a.rotation, b.rotation, t)).abs() +
                  (p.opacity - _lerp(a.opacity, b.opacity, t)).abs());
      if (error > worstError) {
        worstError = error;
        worst = i;
      }
    }
    if (worst < 0) continue;
    keep[worst] = true;
    stretches
      ..add((first, worst))
      ..add((worst, last));
  }
  return [
    for (var i = 0; i < poses.length; i++)
      if (keep[i]) poses[i],
  ];
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

ObjectTrackSample? _closestTo(List<ObjectTrackSample> samples, Duration time) {
  ObjectTrackSample? closest;
  var distance = 0;
  for (final sample in samples) {
    final d = (sample.time - time).inMicroseconds.abs();
    if (closest == null || d < distance) {
      closest = sample;
      distance = d;
    }
  }
  return closest;
}
