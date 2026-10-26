// ABOUTME: Keeps a shape mask's keyframed motion in place through timeline
// ABOUTME: edits of the item it masks: a trimmed start, a split, a copy.

import 'package:openvine/extensions/layer_keyframes.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show Layer, LayerMask, LayerMaskKeyframe;

/// Timeline edits of a mask with keyframes.
///
/// [LayerMask.keyframes] are measured from the start of the item they mask,
/// as [Layer.keyframes] are, so moving the item along the timeline moves the
/// mask's motion with it. The edits below keep the motion where it is on the
/// item instead, as [LayerKeyframeTimeline] does for the item's own.
extension LayerMaskKeyframeTimeline on LayerMask {
  /// This mask with its keyframes [shift] later, each staying at its point on
  /// the item when the item's start moves [shift] earlier. Itself when it has
  /// no keyframes or [shift] is zero.
  LayerMask shiftedBy(Duration shift) {
    if (!hasKeyframes || shift == Duration.zero) return this;
    return withKeyframes([
      for (final keyframe in keyframes)
        keyframe.copyWith(time: keyframe.time + shift),
    ]);
  }

  /// This mask for the part of its item from [start] to [end], both measured
  /// like its keyframes, with the keyframes measured from [start].
  ///
  /// The part keeps the keyframes inside it, plus the nearest one on either
  /// side: it changes between them exactly as the whole item's mask did, and
  /// the keyframes further out no longer touch it.
  LayerMask forPart(Duration start, Duration end) {
    if (!hasKeyframes) return this;
    var firstInside = keyframes.indexWhere((k) => k.time >= start);
    if (firstInside < 0) firstInside = keyframes.length;
    final lastInside = keyframes.lastIndexWhere((k) => k.time <= end);
    final keep = keyframes.sublist(
      (firstInside - 1).clamp(0, keyframes.length),
      (lastInside + 2).clamp(0, keyframes.length),
    );
    return withKeyframes([
      for (final LayerMaskKeyframe keyframe in keep)
        keyframe.copyWith(time: keyframe.time - start),
    ]);
  }
}

/// Timeline edits of a layer whose mask has keyframes, beside its own (see
/// [LayerKeyframeTimeline]).
extension LayerMaskTimeline on Layer {
  /// The layer's mask measured from [newStart] (video time) instead of the
  /// layer's own start, each keyframe staying at its point on the video.
  /// `null` when the layer has no mask.
  LayerMask? maskFrom(Duration newStart) =>
      mask?.shiftedBy(keyframeOrigin - newStart);

  /// The mask a part of this layer from [start] to [end] (video time) keeps,
  /// measured from [start]; see [LayerMaskKeyframeTimeline.forPart]. `null`
  /// when the layer has no mask.
  LayerMask? maskForPart(Duration start, Duration end) =>
      mask?.forPart(start - keyframeOrigin, end - keyframeOrigin);
}
