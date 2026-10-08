// ABOUTME: Divine's side of layer keyframes: keeps a keyframed motion in place
// ABOUTME: through timeline edits and maps it into the pro_video_editor export.

import 'dart:ui';

import 'package:openvine/constants/video_editor_constants.dart';
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
      for (final keyframe in _exportKeyframes(timelineMap))
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

  /// The keyframes the export moves the layer through: its own, and where a
  /// motion crosses a change in the export's pace, more on that motion.
  ///
  /// On each piece of the timeline the export's clock runs at one pace
  /// against the editor's: as fast outside a clip transition, half as fast
  /// through one, where it plays both clips at once. A linear motion stays
  /// linear on each piece, so a keyframe where it crosses into the next one,
  /// on the motion itself, keeps it exact. An eased motion cut there is none
  /// of the 13 curves any more, so the export follows it through linear
  /// keyframes [VideoEditorConstants.exportedMotionSamplesPerSecond] times a
  /// second instead.
  Iterable<LayerKeyframe> _exportKeyframes(
    TransitionTimelineMap timelineMap,
  ) sync* {
    for (var i = 0; i < keyframes.length; i++) {
      final from = keyframes[i];
      if (i + 1 == keyframes.length) {
        yield from;
        break;
      }
      final start = keyframeOrigin + from.time;
      final end = keyframeOrigin + keyframes[i + 1].time;
      final crossings = _paceChangesWithin(timelineMap, start, end);
      if (crossings.isEmpty) {
        yield from;
      } else if (from.curve == AnimationCurve.linear) {
        yield from;
        for (final crossing in crossings) {
          yield _keyframeAt(crossing);
        }
      } else {
        yield from.copyWith(curve: AnimationCurve.linear);
        yield* _sampledMotion(timelineMap, start, end);
      }
    }
  }

  /// Linear keyframes on the motion from [start] to [end] (video time), on a
  /// fixed grid of the output's time between the two.
  Iterable<LayerKeyframe> _sampledMotion(
    TransitionTimelineMap timelineMap,
    Duration start,
    Duration end,
  ) sync* {
    const rate = VideoEditorConstants.exportedMotionSamplesPerSecond;
    const usPerSecond = Duration.microsecondsPerSecond;
    final outputStartUs = _outputTime(timelineMap, start).inMicroseconds;
    final outputEndUs = _outputTime(timelineMap, end).inMicroseconds;
    for (
      var sample = (outputStartUs * rate / usPerSecond).floor() + 1;
      ;
      sample++
    ) {
      final outputUs = (sample * usPerSecond / rate).round();
      if (outputUs >= outputEndUs) break;
      if (outputUs <= outputStartUs) continue;
      yield _keyframeAt(
        _editorTime(timelineMap, Duration(microseconds: outputUs)),
      );
    }
  }

  /// A linear keyframe holding the placement the keyframes give the layer at
  /// [time] (video time).
  LayerKeyframe _keyframeAt(Duration time) => LayerKeyframe.fromPlacement(
    keyframePlacementAt(time)!,
    time: time - keyframeOrigin,
  );

  /// The [Layer.keyframeEffects] as pro_video_editor loops that repeat only
  /// over their stretch of the output timeline. Empty when there are none.
  ///
  /// The export runs at its own pace on each piece of the timeline (see
  /// [_exportKeyframes]), so an effect that crosses into another piece is
  /// split there. Each part repeats at the pace of its piece and starts at the
  /// phase the editor shows there, so the effect runs on in step and the layer
  /// rests on both keyframes, as in the editor. A part before the video's
  /// start is left out; the first part on the output starts at the phase the
  /// editor shows at 0.
  List<pve.LayerAnimation> divineKeyframeEffectsForExport({
    required TransitionTimelineMap timelineMap,
  }) => [
    for (final effect in keyframeEffects)
      ..._exportedEffect(effect, timelineMap),
  ];
}

/// The editor times strictly between [start] and [end] where the export's
/// pace against the editor changes: the edges of each clip transition.
List<Duration> _paceChangesWithin(
  TransitionTimelineMap timelineMap,
  Duration start,
  Duration end,
) => [
  for (final boundary in timelineMap.clockBoundaries)
    if (boundary > start && boundary < end) boundary,
];

/// [time] on the output timeline as video time, the inverse of [_outputTime].
Duration _editorTime(TransitionTimelineMap timelineMap, Duration time) =>
    time.isNegative ? time : timelineMap.outputToEditor(time);

/// [time] (video time) on the output timeline.
///
/// A keyframe before the video's start, where no transition has shortened
/// anything yet, keeps its time instead of being held at 0, as
/// [TransitionTimelineMap.editorToOutput] would: it still shapes the motion
/// after it, and held at 0 it would hurry the layer to the next keyframe.
Duration _outputTime(TransitionTimelineMap timelineMap, Duration time) =>
    time.isNegative ? time : timelineMap.editorToOutput(time);

/// [effect] as pro_video_editor loops, one for each piece of its stretch on
/// the output timeline that runs at one pace; see
/// [LayerExportKeyframes.divineKeyframeEffectsForExport].
Iterable<pve.LayerAnimation> _exportedEffect(
  LayerKeyframeEffect effect,
  TransitionTimelineMap timelineMap,
) sync* {
  final cycleUs = effect.animation.duration.inMicroseconds;
  if (cycleUs <= 0) return;
  final edges = [
    effect.start,
    // The output starts at 0, where the editor does too.
    if (effect.start.isNegative && effect.end > Duration.zero) Duration.zero,
    ..._paceChangesWithin(timelineMap, effect.start, effect.end),
    effect.end,
  ];
  for (var i = 0; i + 1 < edges.length; i++) {
    final from = edges[i];
    final to = edges[i + 1];
    if (to <= Duration.zero) continue;
    final outputFrom = _outputTime(timelineMap, from);
    final outputTo = _outputTime(timelineMap, to);
    // How much output time an editor microsecond takes on this piece.
    final pace =
        (outputTo - outputFrom).inMicroseconds / (to - from).inMicroseconds;
    final partCycleUs = (cycleUs * pace).round();
    if (partCycleUs <= 0) continue;
    final phaseUs = ((from - effect.start).inMicroseconds % cycleUs * pace)
        .round();
    // The two packages share the animation map; only the timing differs.
    final map = effect.animation.toMap()
      ..remove('slideFrom')
      ..['durationUs'] = partCycleUs
      ..['loopStartUs'] = outputFrom.inMicroseconds
      ..['loopEndUs'] = outputTo.inMicroseconds
      ..['loopPhaseUs'] = phaseUs;
    yield pve.LayerAnimation.fromMap(map);
  }
}

/// The pro_video_editor curve named like [curve]. The packages share the
/// thirteen curves and their names.
pve.AnimationCurve pveCurveOf(AnimationCurve curve) =>
    pve.AnimationCurve.values.byName(curve.name);
