// ABOUTME: Full-screen tool to frame the object a layer should follow: a box
// ABOUTME: dragged and resized over the video, before tracking starts (#9848).

import 'dart:math' as math;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/track_frame_mapping.dart';
import 'package:openvine/utils/mounted_post_frame.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/layer_slide_point_picker.dart';

/// Radius of the handles on the corners of the box.
const double _handleRadius = 9;

/// Side of the square that catches a touch on a corner handle.
const double _handleTouchSize = 48;

/// Opens the region picker over the live editor canvas and returns the
/// region the creator framed, as fractions of the frame of a clip shaped
/// [videoAspectRatio] and cut to [targetAspectRatio] (see
/// [TrackFrameMapping]).
///
/// The box starts on [layerCenter], where the layer shows in the frame on
/// screen, which is often right on the object it is meant to follow.
///
/// Returns `null` when the picker was cancelled or there is no canvas to
/// frame anything on. Like the slide point picker, the editor hands over the
/// whole screen while it is open and playback pauses so the frame holds
/// still; it resumes afterwards only when the picker was cancelled, since a
/// confirmed region starts tracking.
Future<Rect?> pickLayerTrackRegion(
  BuildContext context, {
  required Offset Function() layerCenter,
  required double videoAspectRatio,
  required double targetAspectRatio,
}) async {
  final scope = VideoEditorScope.of(context);
  if (canvasProjectionOf(scope) == null) return null;

  final mainBloc = context.read<VideoEditorMainBloc>();
  final wasPlaying = mainBloc.state.isPlaying;
  if (wasPlaying) {
    mainBloc.add(const VideoEditorExternalPauseRequested(isPaused: true));
  }
  mainBloc.add(const VideoEditorTrackRegionMarkingChanged(isMarking: true));

  final picked = await Navigator.of(context).push<Rect>(
    PageRouteBuilder<Rect>(
      opaque: false,
      barrierColor: VineTheme.transparent,
      settings: const RouteSettings(name: 'layer_track_region_picker'),
      transitionDuration: const Duration(milliseconds: 150),
      reverseTransitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (_, _, _) => LayerTrackRegionPickerView(
        resolveProjection: () => canvasProjectionOf(scope),
        resolveMapping: () => TrackFrameMapping(
          canvasSize: scope.canvasGeometry.renderSize,
          videoAspectRatio: videoAspectRatio,
          targetAspectRatio: targetAspectRatio,
        ),
        // The canvas resizes as the timeline collapses, and the editor
        // rescales every layer with it, so the picker follows both.
        canvasChanges: Listenable.merge([
          scope.bodySizeNotifier,
          scope.zoomMatrixNotifier,
        ]),
        layerCenter: layerCenter,
      ),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );

  // Guarded on the bloc rather than on `context.mounted`, as in the slide
  // point picker: the editor giving up the screen is what this restores.
  if (!mainBloc.isClosed) {
    mainBloc.add(const VideoEditorTrackRegionMarkingChanged(isMarking: false));
    if (wasPlaying && picked == null) {
      mainBloc.add(const VideoEditorExternalPauseRequested(isPaused: false));
    }
  }
  return picked;
}

/// The picker itself: the editor shows through, a drag moves the box, a pinch
/// or a corner handle resizes it, and the top bar cancels or confirms it.
///
/// The box is kept in fractions of the frame, so it stays on the same part of
/// the picture however the canvas resizes or zooms meanwhile.
@visibleForTesting
class LayerTrackRegionPickerView extends StatefulWidget {
  /// Creates a [LayerTrackRegionPickerView].
  const LayerTrackRegionPickerView({
    required this.resolveProjection,
    required this.resolveMapping,
    required this.canvasChanges,
    required this.layerCenter,
    super.key,
  });

  /// Reads the canvas as it sits on screen right now.
  final LayerCanvasProjection? Function() resolveProjection;

  /// Reads how the frame lies on the canvas right now.
  final TrackFrameMapping Function() resolveMapping;

  /// Fires whenever the canvas moves, resizes or zooms.
  final Listenable canvasChanges;

  /// Where the layer shows on the marked frame, in layer coordinates; read
  /// once, when the box is first placed.
  final Offset Function() layerCenter;

  @override
  State<LayerTrackRegionPickerView> createState() =>
      _LayerTrackRegionPickerViewState();
}

class _LayerTrackRegionPickerViewState
    extends State<LayerTrackRegionPickerView> {
  /// The box, in fractions of the frame; placed on the first frame the canvas
  /// can be measured on.
  Rect? _region;

  /// The box as a gesture found it, so a pinch scales from where it began.
  Rect? _gestureStart;

  bool _refreshScheduled = false;

  @override
  void initState() {
    super.initState();
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

  void _scheduleRefresh() {
    if (_refreshScheduled) return;
    _refreshScheduled = true;
    addPostFrameCallbackIfMounted(() {
      _refreshScheduled = false;
      setState(() {});
    });
  }

  /// The smallest box side on each axis, in fractions of the frame.
  Size _minSize(TrackFrameMapping mapping) {
    final side =
        VideoEditorConstants.trackingMinRegionShare * _shortestSide(mapping);
    return Size(
      side / mapping.layerPixelsPerFrameWidth,
      side / mapping.layerPixelsPerFrameHeight,
    );
  }

  /// The shorter side of the visible frame, in layer pixels.
  static double _shortestSide(TrackFrameMapping mapping) => math.min(
    mapping.visibleFrame.width * mapping.layerPixelsPerFrameWidth,
    mapping.visibleFrame.height * mapping.layerPixelsPerFrameHeight,
  );

  Rect _initialRegion(TrackFrameMapping mapping) {
    final side =
        VideoEditorConstants.trackingDefaultRegionShare *
        _shortestSide(mapping);
    return _clamp(
      Rect.fromCenter(
        center: mapping.fractionOf(widget.layerCenter()),
        width: side / mapping.layerPixelsPerFrameWidth,
        height: side / mapping.layerPixelsPerFrameHeight,
      ),
      mapping,
    );
  }

  /// [region] no smaller than [_minSize], no larger than the visible frame,
  /// and moved inside it.
  Rect _clamp(Rect region, TrackFrameMapping mapping) {
    final visible = mapping.visibleFrame;
    final min = _minSize(mapping);
    final width = region.width.clamp(min.width, visible.width);
    final height = region.height.clamp(min.height, visible.height);
    final left = region.center.dx - width / 2;
    final top = region.center.dy - height / 2;
    return Rect.fromLTWH(
      left.clamp(visible.left, visible.right - width),
      top.clamp(visible.top, visible.bottom - height),
      width,
      height,
    );
  }

  /// A drag of [screenDelta] on screen, in fractions of the frame.
  static Offset _fractionDelta(
    Offset screenDelta,
    LayerCanvasProjection projection,
    TrackFrameMapping mapping,
  ) {
    final layerDelta = screenDelta / projection.screenPixelsPerLayerPixel;
    return Offset(
      layerDelta.dx / mapping.layerPixelsPerFrameWidth,
      layerDelta.dy / mapping.layerPixelsPerFrameHeight,
    );
  }

  void _onScaleUpdate(
    ScaleUpdateDetails details,
    LayerCanvasProjection projection,
    TrackFrameMapping mapping,
  ) {
    final start = _gestureStart;
    final region = _region;
    if (start == null || region == null) return;
    final delta = _fractionDelta(details.focalPointDelta, projection, mapping);
    setState(() {
      _region = _clamp(
        Rect.fromCenter(
          center: region.center + delta,
          width: start.width * details.scale,
          height: start.height * details.scale,
        ),
        mapping,
      );
    });
  }

  /// Drags the corner of the box at [corner] (`(-1, -1)` is the top left)
  /// by [screenDelta], keeping the opposite corner where it is.
  void _onCornerDrag(
    Offset corner,
    Offset screenDelta,
    LayerCanvasProjection projection,
    TrackFrameMapping mapping,
  ) {
    final region = _region;
    if (region == null) return;
    final delta = _fractionDelta(screenDelta, projection, mapping);
    final min = _minSize(mapping);
    var left = region.left;
    var top = region.top;
    var right = region.right;
    var bottom = region.bottom;
    if (corner.dx < 0) {
      left = math.min(left + delta.dx, right - min.width);
    } else {
      right = math.max(right + delta.dx, left + min.width);
    }
    if (corner.dy < 0) {
      top = math.min(top + delta.dy, bottom - min.height);
    } else {
      bottom = math.max(bottom + delta.dy, top + min.height);
    }
    final visible = mapping.visibleFrame;
    setState(() {
      _region = _clamp(
        Rect.fromLTRB(
          math.max(left, visible.left),
          math.max(top, visible.top),
          math.min(right, visible.right),
          math.min(bottom, visible.bottom),
        ),
        mapping,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hint = l10n.videoEditorTrackRegionHint;
    final projection = widget.resolveProjection();
    final mapping = projection == null ? null : widget.resolveMapping();
    if (mapping != null && _region == null) {
      _region = _initialRegion(mapping);
    }
    final region = _region;
    final screenBox = projection == null || mapping == null || region == null
        ? null
        : Rect.fromPoints(
            projection.toScreen(mapping.layerOffsetOf(region.topLeft)),
            projection.toScreen(mapping.layerOffsetOf(region.bottomRight)),
          );

    return Scaffold(
      backgroundColor: VineTheme.transparent,
      body: Stack(
        fit: .expand,
        children: [
          Semantics(
            label: hint,
            child: GestureDetector(
              behavior: .opaque,
              onScaleStart: (_) => _gestureStart = _region,
              onScaleUpdate: projection == null || mapping == null
                  ? null
                  : (details) => _onScaleUpdate(details, projection, mapping),
              onScaleEnd: (_) => _gestureStart = null,
            ),
          ),
          if (screenBox != null) ...[
            IgnorePointer(
              child: CustomPaint(
                painter: _RegionPainter(
                  box: screenBox,
                  scrimColor: VineTheme.scrim50,
                  lineColor: VineTheme.whiteText,
                  handleColor: context.vineColors.accentBrand,
                ),
                child: const SizedBox.expand(),
              ),
            ),
            for (final corner in const [
              Offset(-1, -1),
              Offset(1, -1),
              Offset(-1, 1),
              Offset(1, 1),
            ])
              Positioned(
                left:
                    (corner.dx < 0 ? screenBox.left : screenBox.right) -
                    _handleTouchSize / 2,
                top:
                    (corner.dy < 0 ? screenBox.top : screenBox.bottom) -
                    _handleTouchSize / 2,
                width: _handleTouchSize,
                height: _handleTouchSize,
                child: Semantics(
                  label: l10n.videoEditorTrackRegionResizeSemanticLabel,
                  child: GestureDetector(
                    behavior: .opaque,
                    onPanUpdate: (details) => _onCornerDrag(
                      corner,
                      details.delta,
                      projection!,
                      mapping!,
                    ),
                  ),
                ),
              ),
          ],
          Align(
            alignment: .topCenter,
            child: _PickerToolbar(
              onCancel: () => Navigator.of(context).pop(),
              onDone: region == null
                  ? null
                  : () => Navigator.of(context).pop(region),
            ),
          ),
          Align(
            alignment: .bottomCenter,
            // Excluded from semantics: the gesture area underneath already
            // carries the same text as its label.
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const .fromSTEB(24, 0, 24, 24),
                    child: _HintPill(text: hint),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cancel on the left, start tracking on the right.
class _PickerToolbar extends StatelessWidget {
  const _PickerToolbar({required this.onCancel, required this.onDone});

  final VoidCallback onCancel;

  /// `null` until the box is placed, which disables the confirm button.
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
              semanticLabel: l10n.videoEditorTrackStartSemanticLabel,
              size: .small,
              onPressed: onDone,
            ),
          ],
        ),
      ),
    );
  }
}

/// The instruction shown while the box is placed.
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

/// Dims everything but the box, outlines it and marks its corners.
class _RegionPainter extends CustomPainter {
  const _RegionPainter({
    required this.box,
    required this.scrimColor,
    required this.lineColor,
    required this.handleColor,
  });

  final Rect box;
  final Color scrimColor;
  final Color lineColor;
  final Color handleColor;

  @override
  void paint(Canvas canvas, Size size) {
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRect(box);
    canvas
      ..drawPath(outside, Paint()..color = scrimColor)
      ..drawRect(
        box,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = lineColor,
      );
    for (final corner in [
      box.topLeft,
      box.topRight,
      box.bottomLeft,
      box.bottomRight,
    ]) {
      canvas
        ..drawCircle(corner, _handleRadius, Paint()..color = handleColor)
        ..drawCircle(
          corner,
          _handleRadius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = lineColor,
        );
    }
  }

  @override
  bool shouldRepaint(_RegionPainter oldDelegate) =>
      oldDelegate.box != box ||
      oldDelegate.scrimColor != scrimColor ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.handleColor != handleColor;
}
