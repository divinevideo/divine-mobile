// ABOUTME: Custom start/end points for a layer's slide animation, stored on
// ABOUTME: Layer.meta as canvas fractions so they survive a draft round-trip

import 'dart:ui';

import 'package:flutter/foundation.dart' show immutable;
import 'package:pro_image_editor/core/models/layers/layer.dart' show Layer;
import 'package:pro_video_editor/pro_video_editor.dart' show AnimationPhase;

/// Key under which [LayerSlidePoints] is written into [Layer.meta].
const String layerSlidePointsMetaKey = 'divine.slidePoints';

/// Sub-key holding the enter phase's point.
const String layerSlidePointEnterKey = 'animateIn';

/// Sub-key holding the leave phase's point.
const String layerSlidePointLeaveKey = 'animateOut';

/// Where a layer's slide animation starts (enter) or ends (leave), when the
/// creator picked a point on the canvas instead of one of the four edges.
///
/// ### Why this lives on `Layer.meta`
///
/// Both packages model the point as `LayerAnimation.slideFrom`, and the layer's
/// own animation carries a copy of it for the in-editor preview. That copy is
/// not the source of truth: it is measured in canvas pixels from the canvas
/// centre, while pro_video_editor measures its own `slideFrom` in video pixels
/// from the frame's top-left, so the export cannot pass it through and has to
/// resolve the point against the layer geometry it exports with.
/// `Layer.meta` is a plain map the editor carries through untouched, so the
/// value kept here survives history, duplication and a draft reload, and is
/// what the export reads. The preview copy is kept in step by pro_image_editor
/// itself, which rescales it with the layer's offset whenever the canvas
/// changes size.
///
/// ### Coordinates
///
/// A point is stored as a **fraction of the canvas**, measured from its centre
/// — the same origin [Layer.offset] uses, divided by the canvas size. Fractions
/// rather than pixels for the same reason: a layer offset rescales with the
/// canvas, so only a value expressed relative to the canvas keeps naming the
/// same place.
@immutable
class LayerSlidePoints {
  /// Creates a [LayerSlidePoints].
  const LayerSlidePoints({this.enter, this.leave});

  /// Reads the points [meta] carries, if any.
  ///
  /// Unreadable entries are treated as absent: the layer then slides from its
  /// edge, which is what it did before a point was ever set.
  factory LayerSlidePoints.fromMeta(Map<String, dynamic>? meta) {
    final raw = meta?[layerSlidePointsMetaKey];
    if (raw is! Map) return const LayerSlidePoints();
    return LayerSlidePoints(
      enter: _fractionFromMap(raw[layerSlidePointEnterKey]),
      leave: _fractionFromMap(raw[layerSlidePointLeaveKey]),
    );
  }

  /// Reads the points stored on [layer].
  factory LayerSlidePoints.of(Layer layer) =>
      LayerSlidePoints.fromMeta(layer.meta);

  /// Start point of the enter (`animateIn`) slide, as a canvas fraction.
  final Offset? enter;

  /// End point of the leave (`animateOut`) slide, as a canvas fraction.
  final Offset? leave;

  /// Whether no phase carries a custom point.
  bool get isEmpty => enter == null && leave == null;

  /// The fraction stored for [phase], or `null` when that phase slides from an
  /// edge.
  ///
  /// [AnimationPhase.animateInOut] plays the same motion at both ends, so it
  /// reads whichever point is set, preferring the enter one.
  Offset? fractionFor(AnimationPhase phase) => switch (phase) {
    AnimationPhase.animateIn => enter,
    AnimationPhase.animateOut => leave,
    AnimationPhase.animateInOut => enter ?? leave,
  };

  /// [phase]'s point in canvas coordinates for a canvas of [canvasSize],
  /// measured from its centre like [Layer.offset].
  ///
  /// Returns `null` when the phase has no point or [canvasSize] is degenerate.
  Offset? resolve(AnimationPhase phase, Size canvasSize) {
    final fraction = fractionFor(phase);
    if (fraction == null || canvasSize.isEmpty) return null;
    return Offset(
      fraction.dx * canvasSize.width,
      fraction.dy * canvasSize.height,
    );
  }

  /// [meta] with these points written into it, ready for `Layer.copyWith`.
  ///
  /// Every other key is carried through untouched — a sticker keeps its
  /// [Layer.meta] payload, a caption its cue marker. An empty set removes the
  /// key rather than writing an empty map, so a layer that never had a custom
  /// point is byte-identical to one whose point was cleared.
  Map<String, dynamic>? applyTo(Map<String, dynamic>? meta) {
    if (isEmpty) {
      if (meta == null || !meta.containsKey(layerSlidePointsMetaKey)) {
        return meta;
      }
      return Map<String, dynamic>.from(meta)..remove(layerSlidePointsMetaKey);
    }
    return <String, dynamic>{
      ...?meta,
      layerSlidePointsMetaKey: <String, dynamic>{
        if (enter case final point?) layerSlidePointEnterKey: _toMap(point),
        if (leave case final point?) layerSlidePointLeaveKey: _toMap(point),
      },
    };
  }

  /// [canvasPoint] — centre-relative, in canvas coordinates — as the fraction
  /// this class stores.
  ///
  /// Returns `null` for a degenerate [canvasSize], where no fraction can be
  /// derived.
  static Offset? fractionOf(Offset canvasPoint, Size canvasSize) {
    if (canvasSize.isEmpty) return null;
    return Offset(
      canvasPoint.dx / canvasSize.width,
      canvasPoint.dy / canvasSize.height,
    );
  }

  static Map<String, dynamic> _toMap(Offset fraction) => <String, dynamic>{
    'dx': fraction.dx,
    'dy': fraction.dy,
  };

  static Offset? _fractionFromMap(Object? raw) {
    if (raw is! Map) return null;
    final dx = raw['dx'];
    final dy = raw['dy'];
    if (dx is! num || dy is! num) return null;
    if (!dx.isFinite || !dy.isFinite) return null;
    return Offset(dx.toDouble(), dy.toDouble());
  }

  @override
  bool operator ==(Object other) =>
      other is LayerSlidePoints && other.enter == enter && other.leave == leave;

  @override
  int get hashCode => Object.hash(enter, leave);

  @override
  String toString() => 'LayerSlidePoints(enter: $enter, leave: $leave)';
}
