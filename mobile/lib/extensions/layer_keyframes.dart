// ABOUTME: Divine's side of layer keyframes: keeps a keyframed motion in place
// ABOUTME: through timeline edits and maps it into the pro_video_editor export.

import 'dart:ui';

import 'package:openvine/extensions/layer_animation_storage.dart';
import 'package:openvine/models/video_editor/detached_clip_layer.dart';
import 'package:openvine/models/video_editor/transition_geometry.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show AnimationCurve, Layer, LayerKeyframe, LayerKeyframeEffect;
import 'package:pro_video_editor/pro_video_editor.dart' as pve;

/// Timeline edits of a keyframed layer.
///
/// [Layer.keyframes] are measured from the layer's start, so moving a layer
/// along the timeline moves its motion with it. Every other edit keeps the
/// motion where it is on the video: a trimmed start or a split rebases the
/// keyframes instead of shifting them. A detached clip's trimmed start is the
/// exception, see [keepsMotionOnStartTrim].
extension LayerKeyframeTimeline on Layer {
  /// Whether a trimmed start leaves the motion where it is on the video, by
  /// rebasing the keyframes onto the new start (see [keyframesFrom]).
  ///
  /// Not for a detached clip: its footage starts over at the new start rather
  /// than losing its head, so its keyframes move with the start too and stay
  /// on the frames they were set on.
  bool get keepsMotionOnStartTrim =>
      !DetachedClipLayerData.isDetachedClipLayer(this);

  /// The keyframes measured from [newStart] instead of the layer's own start,
  /// each staying at its point on the video.
  ///
  /// Keyframes may end up before the new start, which is what keeps the motion
  /// unchanged inside the shorter layer.
  List<LayerKeyframe> keyframesFrom(Duration newStart) {
    final shift = keyframeOrigin - newStart;
    if (shift == Duration.zero) return keyframes;
    return [for (final k in keyframes) k.copyWith(time: k.time + shift)];
  }

  /// The keyframes a part of this layer from [start] to [end] (video time)
  /// keeps, measured from [start].
  ///
  /// Those inside the part, plus the nearest one on either side of it: the
  /// part moves between them exactly as the whole layer did, and the
  /// keyframes further out no longer touch it.
  List<LayerKeyframe> keyframesForPart(Duration start, Duration end) {
    if (keyframes.isEmpty) return keyframes;
    final from = start - keyframeOrigin;
    final to = end - keyframeOrigin;
    var firstInside = keyframes.indexWhere((k) => k.time >= from);
    if (firstInside < 0) firstInside = keyframes.length;
    var lastInside = keyframes.lastIndexWhere((k) => k.time <= to);
    if (lastInside < 0) lastInside = -1;
    final keep = keyframes.sublist(
      (firstInside - 1).clamp(0, keyframes.length),
      (lastInside + 2).clamp(0, keyframes.length),
    );
    return [for (final k in keep) k.copyWith(time: k.time - from)];
  }

  /// The keyframes that sit within the layer's own time range, from 0 to
  /// [duration], as the timeline shows them.
  Iterable<LayerKeyframe> visibleKeyframes(Duration duration) =>
      keyframes.where((k) => k.time >= Duration.zero && k.time <= duration);
}

/// Maps a layer's keyframes into the export.
extension LayerExportKeyframes on Layer {
  /// This layer's keyframes as pro_video_editor [pve.TimelineKeyframe]s, in
  /// the video's pixels and on the output timeline. Empty when it has none.
  ///
  /// [bodySize], [logicalSize] and [mapping] place a keyframe's corner the way
  /// [exportedLayerTopLeft] places the layer's own one, and [timelineMap]
  /// puts its time on the output timeline as it does the layer's window.
  ///
  /// The export draws an image of the layer as it is laid out: at its own
  /// [Layer.scale], and for a raster also turned by [Layer.rotation] and its
  /// flips. A keyframe's scale is therefore relative to [Layer.scale]. When
  /// [turnedRaster] is set, its rotation is relative to [Layer.rotation] too,
  /// and turns the other way when the layer is mirrored on one axis, as the
  /// editor preview turns it; otherwise it is the layer's own rotation.
  List<pve.TimelineKeyframe> divineKeyframesForExport({
    required Size bodySize,
    required Size logicalSize,
    required ExportLayerMapping mapping,
    required TransitionTimelineMap timelineMap,
    bool turnedRaster = true,
  }) {
    if (keyframes.isEmpty) return const [];
    final mirrored = flipX != flipY;
    return [
      for (final keyframe in keyframes)
        pve.TimelineKeyframe(
          time: _outputTime(timelineMap, keyframeOrigin + keyframe.time),
          offset: exportedLayerTopLeft(
            anchor: keyframe.offset,
            bodySize: bodySize,
            logicalSize: logicalSize,
            mapping: mapping,
          ),
          scale: scale == 0 ? 1 : keyframe.scale / scale,
          rotation: turnedRaster
              ? (keyframe.rotation - rotation) * (mirrored ? -1 : 1)
              : keyframe.rotation,
          opacity: keyframe.opacity,
          curve: pveCurveOf(keyframe.curve),
        ),
    ];
  }

  /// The [Layer.keyframeEffects] as pro_video_editor loops that repeat only
  /// over their stretch of the output timeline. Empty when there are none.
  ///
  /// A stretch keeps its number of cycles: where [timelineMap] shortens it at
  /// a clip transition, every cycle shortens with it, so the layer still
  /// comes to rest on both keyframes as it does in the editor.
  List<pve.LayerAnimation> divineKeyframeEffectsForExport({
    required TransitionTimelineMap timelineMap,
  }) => [
    for (final effect in keyframeEffects) ?_exportedEffect(effect, timelineMap),
  ];
}

/// [time] (video time) on the output timeline.
///
/// A keyframe before the video's start, where no transition has shortened
/// anything yet, keeps its time instead of being held at 0, as
/// [TransitionTimelineMap.editorToOutput] would: it still shapes the motion
/// after it, and held at 0 it would hurry the layer to the next keyframe.
Duration _outputTime(TransitionTimelineMap timelineMap, Duration time) =>
    time.isNegative ? time : timelineMap.editorToOutput(time);

/// [effect] as a pro_video_editor loop over its stretch on the output
/// timeline, or `null` when the stretch does not reach into the output.
pve.LayerAnimation? _exportedEffect(
  LayerKeyframeEffect effect,
  TransitionTimelineMap timelineMap,
) {
  final start = _outputTime(timelineMap, effect.start);
  final end = _outputTime(timelineMap, effect.end);
  final cycleUs = (end - start).inMicroseconds ~/ effect.cycles;
  if (cycleUs <= 0) return null;
  // The renderers take a loop start before 0 for none and count the cycles
  // from the layer's start instead, out of step with the keyframes. Starting
  // at the first whole cycle on the output keeps them in step, so the layer
  // still rests on the next keyframe; only the part cycle before it is still.
  var loopStartUs = start.inMicroseconds;
  if (loopStartUs < 0) {
    loopStartUs += (cycleUs - 1 - loopStartUs) ~/ cycleUs * cycleUs;
  }
  if (loopStartUs >= end.inMicroseconds) return null;
  // The two packages share the animation map; only the timing differs.
  final map = effect.animation.toMap()
    ..remove('slideFrom')
    ..['durationUs'] = cycleUs
    ..['loopStartUs'] = loopStartUs
    ..['loopEndUs'] = end.inMicroseconds;
  return pve.LayerAnimation.fromMap(map);
}

/// The pro_video_editor curve named like [curve]. The packages share the
/// thirteen curves and their names.
pve.AnimationCurve pveCurveOf(AnimationCurve curve) =>
    pve.AnimationCurve.values.byName(curve.name);
