// ABOUTME: Full-screen tool to place a layer's slide start/end point by tapping
// ABOUTME: the video where the motion should begin or end

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/layer_slide_point.dart';
import 'package:openvine/utils/mounted_post_frame.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:pro_image_editor/core/models/layers/layer.dart' show Layer;
import 'package:pro_video_editor/pro_video_editor.dart' show AnimationPhase;

/// Radius of the dot marking the placed point.
const double _pointRadius = 9;

/// Radius of the ring marking where the layer comes to rest.
const double _anchorRadius = 14;

/// Opens the point picker over the live editor canvas and returns the point the
/// creator settled on, as a canvas fraction (see [LayerSlidePoints]).
///
/// Returns `null` when the picker was cancelled, or when there is no canvas to
/// place a point on — in both cases the layer keeps whatever slide origin it
/// already had.
///
/// The editor keeps rendering underneath, so the point is placed against the
/// frame that is actually on screen with the layer itself in place. For the
/// duration the editor hands over the whole screen — timeline and actions step
/// aside, which also makes the video as large as it gets — and playback pauses
/// so the frame holds still, resuming afterwards only if it was running.
Future<Offset?> pickLayerSlidePoint(
  BuildContext context, {
  required Layer layer,
  required AnimationPhase phase,
  Offset? initialFraction,
}) async {
  final scope = VideoEditorScope.of(context);
  if (canvasProjectionOf(scope) == null) return null;

  final mainBloc = context.read<VideoEditorMainBloc>();
  final wasPlaying = mainBloc.state.isPlaying;
  if (wasPlaying) {
    mainBloc.add(const VideoEditorExternalPauseRequested(isPaused: true));
  }
  mainBloc.add(const VideoEditorSlidePointPlacementChanged(isPlacing: true));

  // The canvas resizes as the timeline collapses, and the editor rescales
  // every layer with it, so the picker follows both rather than measuring once.
  final canvasChanges = Listenable.merge([
    scope.bodySizeNotifier,
    scope.zoomMatrixNotifier,
  ]);

  final picked = await Navigator.of(context).push<Offset>(
    PageRouteBuilder<Offset>(
      opaque: false,
      barrierColor: VineTheme.transparent,
      settings: const RouteSettings(name: 'layer_slide_point_picker'),
      transitionDuration: const Duration(milliseconds: 150),
      reverseTransitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (_, _, _) => LayerSlidePointPickerView(
        resolveProjection: () => canvasProjectionOf(scope),
        canvasChanges: canvasChanges,
        layer: layer,
        phase: phase,
        initialFraction: initialFraction,
      ),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );

  mainBloc.add(const VideoEditorSlidePointPlacementChanged(isPlacing: false));
  if (wasPlaying) {
    mainBloc.add(const VideoEditorExternalPauseRequested(isPaused: false));
  }
  return picked;
}

/// The canvas as it currently sits on screen, or `null` when it is not mounted
/// or not measurable.
@visibleForTesting
LayerCanvasProjection? canvasProjectionOf(VideoEditorScope scope) {
  final bodyRect = scope.canvasBodyRect;
  if (bodyRect == null) return null;
  final projection = LayerCanvasProjection(
    bodyRect: bodyRect,
    canvasSize: scope.canvasRenderSize,
    coverScale: scope.fittedBoxScale,
    zoom: scope.zoomMatrixNotifier.value,
  );
  return projection.isUsable ? projection : null;
}

/// Maps between layer coordinates and the screen the canvas is drawn on.
///
/// Layer coordinates are the space [Layer.offset] lives in: pixels measured
/// from the centre of the canvas surface, before the canvas is fitted into the
/// body and before the editor's own zoom. Getting from there to a touch takes
/// both transforms, in this order:
///
/// 1. the editor's [zoom] (scale and translation, in canvas pixels),
/// 2. the cover-fit of the canvas into the body ([coverScale]), centred in
///    [bodyRect].
///
/// The same pair, inverted, turns a touch back into a layer coordinate.
@immutable
class LayerCanvasProjection {
  /// Creates a [LayerCanvasProjection].
  const LayerCanvasProjection({
    required this.bodyRect,
    required this.canvasSize,
    required this.coverScale,
    required this.zoom,
  });

  /// The canvas body's rectangle on screen.
  final Rect bodyRect;

  /// The unscaled canvas surface layers are laid out on.
  final Size canvasSize;

  /// Scale the canvas is cover-fitted into the body with.
  final double coverScale;

  /// The editor's current zoom transform (identity when not zoomed).
  final Matrix4 zoom;

  /// Whether the projection can map anything — a zero-sized canvas has no
  /// usable mapping.
  bool get isUsable => !canvasSize.isEmpty && coverScale > 0;

  double get _zoomScale {
    final scale = zoom.getMaxScaleOnAxis();
    return scale.isFinite && scale != 0 ? scale : 1;
  }

  Offset get _zoomTranslation {
    final translation = zoom.getTranslation();
    return Offset(translation.x, translation.y);
  }

  /// Where the canvas surface's own origin (top-left) lands inside [bodyRect].
  Offset get _canvasOrigin => Offset(
    (bodyRect.width - coverScale * canvasSize.width) / 2,
    (bodyRect.height - coverScale * canvasSize.height) / 2,
  );

  /// [point] — a layer coordinate — as a point on screen.
  Offset toScreen(Offset point) {
    final absolute = Offset(
      canvasSize.width / 2 + point.dx,
      canvasSize.height / 2 + point.dy,
    );
    final zoomed = Offset(
      _zoomScale * absolute.dx + _zoomTranslation.dx,
      _zoomScale * absolute.dy + _zoomTranslation.dy,
    );
    return bodyRect.topLeft + _canvasOrigin + zoomed * coverScale;
  }

  /// [point] — a point on screen — as a canvas fraction.
  Offset? toFraction(Offset point) {
    final local = point - bodyRect.topLeft - _canvasOrigin;
    final zoomed = local / coverScale;
    final absolute = Offset(
      (zoomed.dx - _zoomTranslation.dx) / _zoomScale,
      (zoomed.dy - _zoomTranslation.dy) / _zoomScale,
    );
    return LayerSlidePoints.fractionOf(
      Offset(
        absolute.dx - canvasSize.width / 2,
        absolute.dy - canvasSize.height / 2,
      ),
      canvasSize,
    );
  }

  /// [fraction] of the canvas as a point on screen.
  Offset screenOfFraction(Offset fraction) => toScreen(
    Offset(fraction.dx * canvasSize.width, fraction.dy * canvasSize.height),
  );
}

/// The picker itself: the editor shows through, a touch places the point, and
/// the top bar cancels or confirms it.
@visibleForTesting
class LayerSlidePointPickerView extends StatefulWidget {
  /// Creates a [LayerSlidePointPickerView].
  const LayerSlidePointPickerView({
    required this.resolveProjection,
    required this.canvasChanges,
    required this.layer,
    required this.phase,
    this.initialFraction,
    super.key,
  });

  /// Reads the canvas as it sits on screen right now.
  final LayerCanvasProjection? Function() resolveProjection;

  /// Fires whenever the canvas moves, resizes or zooms.
  final Listenable canvasChanges;

  /// The layer being animated. Its offset is read live, because the editor
  /// rescales layers when the canvas resizes.
  final Layer layer;

  /// Which end of the layer's life is being placed.
  final AnimationPhase phase;

  /// The point to start from, as a canvas fraction.
  final Offset? initialFraction;

  @override
  State<LayerSlidePointPickerView> createState() =>
      _LayerSlidePointPickerViewState();
}

class _LayerSlidePointPickerViewState extends State<LayerSlidePointPickerView> {
  Offset? _fraction;
  bool _refreshScheduled = false;

  @override
  void initState() {
    super.initState();
    _fraction = widget.initialFraction;
    widget.canvasChanges.addListener(_scheduleRefresh);
    // The canvas is mid-resize when the picker opens: the timeline is still
    // collapsing, so the first measurable frame comes after this one.
    addPostFrameCallbackIfMounted(() => setState(() {}));
  }

  @override
  void dispose() {
    widget.canvasChanges.removeListener(_scheduleRefresh);
    super.dispose();
  }

  /// Redraws after the frame the canvas changed in.
  ///
  /// The notification arrives while the canvas is laying itself out, which is
  /// too late to rebuild in the same frame and too early to measure it.
  void _scheduleRefresh() {
    if (_refreshScheduled) return;
    _refreshScheduled = true;
    addPostFrameCallbackIfMounted(() {
      _refreshScheduled = false;
      setState(() {});
    });
  }

  void _placeAt(Offset globalPosition, LayerCanvasProjection projection) {
    final fraction = projection.toFraction(globalPosition);
    if (fraction == null) return;
    setState(() => _fraction = fraction);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hint = widget.phase == AnimationPhase.animateOut
        ? l10n.videoEditorLayerAnimationPointLeaveHint
        : l10n.videoEditorLayerAnimationPointEnterHint;
    final projection = widget.resolveProjection();
    final fraction = _fraction;

    return Scaffold(
      backgroundColor: VineTheme.transparent,
      body: Stack(
        fit: .expand,
        children: [
          Semantics(
            label: hint,
            button: true,
            child: GestureDetector(
              behavior: .opaque,
              onTapDown: projection == null
                  ? null
                  : (details) => _placeAt(details.globalPosition, projection),
              onPanStart: projection == null
                  ? null
                  : (details) => _placeAt(details.globalPosition, projection),
              onPanUpdate: projection == null
                  ? null
                  : (details) => _placeAt(details.globalPosition, projection),
            ),
          ),
          if (projection != null)
            IgnorePointer(
              child: CustomPaint(
                painter: _SlidePointPainter(
                  anchor: projection.toScreen(widget.layer.offset),
                  point: fraction == null
                      ? null
                      : projection.screenOfFraction(fraction),
                  accentColor: context.vineColors.accentBrand,
                  markerColor: VineTheme.whiteText,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          Align(
            alignment: .topCenter,
            child: _PickerToolbar(
              onCancel: () => Navigator.of(context).pop(),
              onDone: fraction == null
                  ? null
                  : () => Navigator.of(context).pop(fraction),
            ),
          ),
          Align(
            alignment: .bottomCenter,
            // Never in the way of a touch: the hint sits over the frame the
            // point is placed on.
            child: IgnorePointer(
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const .fromSTEB(24, 0, 24, 24),
                  child: _HintPill(text: hint),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cancel on the left, confirm on the right — the editor's usual top bar, minus
/// the hero tags, which belong to the toolbar this one stands in for.
class _PickerToolbar extends StatelessWidget {
  const _PickerToolbar({required this.onCancel, required this.onDone});

  final VoidCallback onCancel;

  /// `null` until a point has been placed, which disables the confirm button.
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const .fromSTEB(16, 12, 16, 0),
        child: Row(
          spacing: 12,
          mainAxisAlignment: .spaceBetween,
          children: [
            DivineIconButton(
              icon: .x,
              semanticLabel: l10n.commonCancel,
              size: .small,
              type: .ghostSecondary,
              onPressed: onCancel,
            ),
            DivineIconButton(
              icon: .check,
              semanticLabel: l10n.videoEditorDoneLabel,
              size: .small,
              onPressed: onDone,
            ),
          ],
        ),
      ),
    );
  }
}

/// The instruction shown while the point is being placed.
class _HintPill extends StatelessWidget {
  const _HintPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: VineTheme.scrim65,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const .symmetric(horizontal: 16, vertical: 10),
        child: Text(
          text,
          textAlign: .center,
          style: VineTheme.labelMediumFont(color: VineTheme.whiteText),
        ),
      ),
    );
  }
}

/// Draws the placed point, the layer's resting place, and the path the layer
/// travels between them.
class _SlidePointPainter extends CustomPainter {
  const _SlidePointPainter({
    required this.anchor,
    required this.point,
    required this.accentColor,
    required this.markerColor,
  });

  final Offset anchor;
  final Offset? point;
  final Color accentColor;
  final Color markerColor;

  @override
  void paint(Canvas canvas, Size size) {
    final target = point;
    if (target != null) _paintTravelPath(canvas, target);

    // The resting place stays a hollow ring: the layer itself is on screen
    // there, so the ring points at it rather than covering it.
    canvas.drawCircle(
      anchor,
      _anchorRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = markerColor,
    );

    if (target != null) {
      canvas
        ..drawCircle(target, _pointRadius, Paint()..color = accentColor)
        ..drawCircle(
          target,
          _pointRadius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = markerColor,
        );
    }
  }

  /// A dashed line from the placed point to the resting place — the distance
  /// the layer covers, which is the whole point of choosing an origin.
  void _paintTravelPath(Canvas canvas, Offset target) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = markerColor;
    const dash = 8.0;
    const gap = 6.0;
    final delta = anchor - target;
    final length = delta.distance;
    if (length <= dash) return;
    final step = delta / length;
    for (var travelled = 0.0; travelled < length; travelled += dash + gap) {
      final end = (travelled + dash).clamp(0.0, length);
      canvas.drawLine(target + step * travelled, target + step * end, paint);
    }
  }

  @override
  bool shouldRepaint(_SlidePointPainter oldDelegate) =>
      oldDelegate.anchor != anchor ||
      oldDelegate.point != point ||
      oldDelegate.accentColor != accentColor ||
      oldDelegate.markerColor != markerColor;
}
