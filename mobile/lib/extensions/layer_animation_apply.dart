// ABOUTME: Writes a chosen enter/leave animation onto a pro_image_editor
// ABOUTME: Layer: animations, custom slide points, and the end time a leave
// ABOUTME: animation needs. Shared by the animation sheet and title styles.

import 'dart:ui';

import 'package:openvine/extensions/layer_animation_storage.dart';
import 'package:openvine/models/video_editor/layer_slide_point.dart';
import 'package:pro_image_editor/core/models/layers/layer.dart' show Layer;
import 'package:pro_video_editor/pro_video_editor.dart'
    show AnimationPhase, LayerAnimation, LayerAnimationType;

/// Resolves the [Layer.endTime] needed for a leave (animateOut) animation to
/// have a window to play in.
///
/// The leave phase renders only when the layer has a non-null `endTime` — both
/// the in-editor preview ([Layer.animations] timeline visibility) and the
/// native export skip the animateOut branch when `endTime` is null.
///
/// Only a *real trim* — an end strictly inside the video — is treated as user
/// intent worth preserving. An end at or after [totalDuration] is not a trim:
/// it's either a stale anchor a previously-set (now-removed) leave animation
/// left behind, or a no-op full-length end. Treating it as `null` keeps an
/// untrimmed layer untrimmed, so it follows later duration changes (e.g. the
/// video being extended) instead of staying pinned to a stale end.
///
/// [totalDuration] must be the true total video duration, independent of the
/// layer's own [Layer.endTime]. Passing the layer's clamped timeline end (which
/// equals its [Layer.endTime]) would make `currentEndTime < totalDuration` false
/// for every trim, so genuine trims would read as full-length and be dropped.
///
/// [startTime] is the layer's own start. The returned end is never at or before
/// it: a stale or transient-zero [totalDuration] (e.g. read before the player
/// has reported its length) must not anchor the leave window at `<= startTime`,
/// which would collapse the layer to a zero-length window and drop it from the
/// timeline entirely. In that degenerate case the layer's existing end is kept
/// (when still valid) or the end is left un-anchored — the layer stays visible
/// either way.
///
/// With [hasLeaveAnimation] true the end is anchored to that trim, or to
/// [totalDuration] when there is no real trim — never beyond the video, never
/// at or before [startTime]. Without a leave animation a real trim is preserved
/// and everything else collapses to `null`.
Duration? resolveLayerEndTime({
  required Duration? currentEndTime,
  required Duration startTime,
  required Duration totalDuration,
  required bool hasLeaveAnimation,
}) {
  final trim = currentEndTime != null && currentEndTime < totalDuration
      ? currentEndTime
      : null;
  if (!hasLeaveAnimation) return trim;

  final anchor = trim ?? totalDuration;
  if (anchor > startTime) return anchor;
  if (currentEndTime != null && currentEndTime > startTime) {
    return currentEndTime;
  }
  return null;
}

/// Applies a chosen enter/leave animation to a [Layer].
extension LayerAnimationApply on Layer {
  /// A copy of this layer carrying [enter] and [leave] as its animations,
  /// [points] as its custom slide points, and the end time the leave phase
  /// needs — the whole write the animation sheet performs on confirm.
  ///
  /// Animations of any other phase (e.g. `animateInOut`) that the layer
  /// already carries are kept, so editing one phase cannot silently drop
  /// them. A custom point is only kept for a phase that still slides: a point
  /// nothing reads is dropped rather than stored.
  ///
  /// [canvasSize] is the canvas the points are resolved against for the
  /// in-editor preview; [totalDuration] is the true total video duration (see
  /// [resolveLayerEndTime]).
  ///
  /// The legacy fade fields and custom transition builder are cleared so
  /// [Layer.effectiveAnimations] cannot fall back to a stale fade when the
  /// animation list is empty. `endTime` is set through the mutable field
  /// rather than `copyWith`, which resolves it as `endTime ?? this.endTime`
  /// and so can never clear a stale end back to `null`.
  Layer withDivineAnimations({
    required List<LayerAnimation> enter,
    required List<LayerAnimation> leave,
    required LayerSlidePoints points,
    required Size canvasSize,
    required Duration totalDuration,
  }) {
    final preserved = [
      for (final animation in divineAnimations)
        if (animation.phase != AnimationPhase.animateIn &&
            animation.phase != AnimationPhase.animateOut)
          animation,
    ];
    final animations = <LayerAnimation>[...enter, ...leave, ...preserved];

    final resolvedEndTime = resolveLayerEndTime(
      currentEndTime: endTime,
      startTime: startTime ?? Duration.zero,
      totalDuration: totalDuration,
      hasLeaveAnimation: leave.isNotEmpty,
    );

    final slidePoints = LayerSlidePoints(
      enter: _slidePointFor(enter, points.enter),
      leave: _slidePointFor(leave, points.leave),
    );

    return copyWith(
        // The points ride along on the animations as well, in canvas pixels,
        // so the editor's own preview slides the way the export will.
        animations: animations.toLayerAnimations(
          points: slidePoints,
          canvasSize: canvasSize,
        ),
        meta: slidePoints.applyTo(meta),
      )
      ..endTime = resolvedEndTime
      ..enterDuration = null
      ..exitDuration = null
      ..enterCurve = null
      ..exitCurve = null
      ..transitionBuilder = null;
  }
}

/// The point to store for a phase, or `null` when the phase has no slide to
/// apply it to.
Offset? _slidePointFor(List<LayerAnimation> animations, Offset? point) {
  if (point == null) return null;
  return animations.any((a) => a.type == LayerAnimationType.slide)
      ? point
      : null;
}
