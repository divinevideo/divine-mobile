// ABOUTME: Android-style zoom ruler shown while pinch-zooming; also draggable
// ABOUTME: Fine ticks scroll under a fixed centre marker; value floats above

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/l10n/l10n.dart';

/// Transient zoom indicator modelled on the native Android camera ruler.
///
/// A horizontal strip of fine tick marks scrolls under a fixed centre
/// accent while the user pinch-zooms, with the live zoom factor floating
/// above it. While visible it is also interactive: a horizontal drag along
/// the ruler scrubs the zoom — dragging toward the higher marks (left) zooms
/// in, mirroring how the ticks scroll under a pinch. The value eases onto the
/// major marks (whole factors and the 0.5× stop) with a soft detent and a
/// haptic tick, matching the pinch's 1× snap. It only accepts pointer events
/// while [VideoRecorderBlocState.showZoomIndicator] is set (during a pinch and
/// for a short hold afterwards) and no preview scale gesture is in progress
/// ([VideoRecorderBlocState.isPinchActive]); the rest of the time it ignores
/// them so the preview keeps its own gestures and a pinch finger landing on
/// the ruler still reaches the preview.
///
/// Renders nothing when the active camera exposes no usable zoom range
/// (single lens / before initialization).
class VideoRecorderZoomIndicator extends StatelessWidget {
  const VideoRecorderZoomIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final (
      :zoomLevel,
      :minZoomLevel,
      :maxZoomLevel,
      :showZoomIndicator,
      :isPinchActive,
    ) = context.select(
      (VideoRecorderBloc b) => (
        zoomLevel: b.state.zoomLevel,
        minZoomLevel: b.state.minZoomLevel,
        maxZoomLevel: b.state.maxZoomLevel,
        showZoomIndicator: b.state.showZoomIndicator,
        isPinchActive: b.state.isPinchActive,
      ),
    );

    // Single lens / no usable zoom range: nothing to indicate.
    if (maxZoomLevel - minZoomLevel <= _zoomRangeEpsilon) {
      return const SizedBox.shrink();
    }

    // Only grab pointer events while the ruler is visible, so the preview
    // keeps its pinch / tap / long-press gestures the rest of the time.
    // While a preview scale gesture is in progress the ruler also lets
    // pointers through — its opaque full-width band would otherwise swallow
    // the second finger of a pinch and break the gesture.
    return IgnorePointer(
      ignoring: !showZoomIndicator || isPinchActive,
      child: ExcludeSemantics(
        excluding: !showZoomIndicator,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: showZoomIndicator ? 1 : 0,
          child: _InteractiveZoomRuler(
            zoom: zoomLevel,
            minZoom: minZoomLevel,
            maxZoom: maxZoomLevel,
          ),
        ),
      ),
    );
  }
}

/// Wraps the [_ZoomRuler] read-out with a horizontal drag scrubber and
/// slider semantics, dispatching [VideoRecorderZoomLevelSet] as the user
/// adjusts the zoom.
class _InteractiveZoomRuler extends StatefulWidget {
  const _InteractiveZoomRuler({
    required this.zoom,
    required this.minZoom,
    required this.maxZoom,
  });

  final double zoom;
  final double minZoom;
  final double maxZoom;

  @override
  State<_InteractiveZoomRuler> createState() => _InteractiveZoomRulerState();
}

class _InteractiveZoomRulerState extends State<_InteractiveZoomRuler> {
  /// Zoom captured at drag start and advanced locally on every update, so a
  /// burst of drag events doesn't compound against a stale [widget.zoom]
  /// between rebuilds. Null while no drag is in progress.
  double? _dragZoom;

  void _onDragStart(DragStartDetails details) => _dragZoom = widget.zoom;

  void _onDragUpdate(DragUpdateDetails details) {
    final current = _dragZoom ?? widget.zoom;
    // The ruler scrolls left as the zoom grows, so dragging left zooms in.
    final next = (current - details.delta.dx / _pxPerZoomUnit).clamp(
      widget.minZoom,
      widget.maxZoom,
    );
    // Tick as the value passes a major mark, mirroring the pinch detent.
    // Flutter's HapticFeedback directly, like the other recorder/editor UI
    // widgets — the UI layer must not import the app's service package.
    if (_crossedMajorMark(current, next)) {
      unawaited(HapticFeedback.lightImpact());
    }
    // [_dragZoom] tracks the raw finger position; the detent is an emit-only
    // transform so the well never traps the accumulator.
    _dragZoom = next;
    _setZoom(_snapToMajor(next));
  }

  void _onDragEnd(DragEndDetails details) => _dragZoom = null;

  /// Whether scrubbing from [from] to [to] reached a major ruler mark — every
  /// whole factor, plus the 0.5× ultra-wide stop — matching the ticks the
  /// painter draws as majors. Catches both crossing a mark mid-drag and
  /// arriving on one pinned to a clamp bound, where the value lands on the mark
  /// from one side and can never cross past it (e.g. the 0.5× stop on an
  /// ultra-wide min, or a 1× min) — the cross-only checks stay silent there.
  bool _crossedMajorMark(double from, double to) {
    if (from == to) return false;
    final crossedWhole = from.floorToDouble() != to.floorToDouble();
    final crossedHalf = (from < 0.5) != (to < 0.5);
    final arrivedAtMark = _isMajorMark(to) && !_isMajorMark(from);
    return crossedWhole || crossedHalf || arrivedAtMark;
  }

  /// Whether [value] sits exactly on a major mark — a whole factor or the 0.5×
  /// stop. Lets [_crossedMajorMark] detect arrival on a mark that coincides
  /// with a clamp bound.
  bool _isMajorMark(double value) =>
      value == 0.5 || value == value.roundToDouble();

  /// Eases [value] toward the nearest major mark within [_snapRadius], using
  /// the same damped gravity-well curve as the pinch's 1× detent, so the
  /// scrubbed value gently clicks onto whole factors and the 0.5× stop.
  double _snapToMajor(double value) {
    // The camera's zoom extremes are reachable stops in their own right. When
    // a bound sits within [_snapRadius] of a major (e.g. maxZoom 2.1 next to
    // the 2× mark), the detent would otherwise pull it inward and the user
    // could never reach the actual min/max — so never snap a bound.
    if (value == widget.minZoom || value == widget.maxZoom) return value;
    final mark = _nearestMajorMark(value);
    final dist = (value - mark).abs();
    if (dist >= _snapRadius) return value;
    final t = dist / _snapRadius;
    final pulled = mark + (value >= mark ? 1.0 : -1.0) * _snapRadius * t * t;
    return pulled.clamp(widget.minZoom, widget.maxZoom);
  }

  double _nearestMajorMark(double value) {
    final whole = value.roundToDouble();
    return (value - 0.5).abs() < (value - whole).abs() ? 0.5 : whole;
  }

  double _nudgedZoom(double delta) =>
      (widget.zoom + delta).clamp(widget.minZoom, widget.maxZoom);

  void _nudge(double delta) => _setZoom(_nudgedZoom(delta));

  void _setZoom(double value) {
    if (value == widget.zoom) return;
    context.read<VideoRecorderBloc>().add(VideoRecorderZoomLevelSet(value));
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      slider: true,
      label: context.l10n.videoRecorderZoomLevelLabel(
        _accessibilityValue(widget.zoom),
      ),
      // Carry the factor on `value` too, so a VoiceOver adjust gesture re-reads
      // the new zoom (iOS re-announces `value`, not `label`, after a nudge).
      value: '${_accessibilityValue(widget.zoom)}×',
      increasedValue: '${_accessibilityValue(_nudgedZoom(_semanticZoomStep))}×',
      decreasedValue:
          '${_accessibilityValue(_nudgedZoom(-_semanticZoomStep))}×',
      onIncrease: () => _nudge(_semanticZoomStep),
      onDecrease: () => _nudge(-_semanticZoomStep),
      // The visual read-out duplicates the slider's label/value, so keep it out
      // of the semantics tree rather than letting it merge into the label.
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: _onDragStart,
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          child: _ZoomRuler(
            zoom: widget.zoom,
            minZoom: widget.minZoom,
            maxZoom: widget.maxZoom,
          ),
        ),
      ),
    );
  }
}

class _ZoomRuler extends StatelessWidget {
  const _ZoomRuler({
    required this.zoom,
    required this.minZoom,
    required this.maxZoom,
  });

  final double zoom;
  final double minZoom;
  final double maxZoom;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _valueLabel(zoom),
            style: VineTheme.titleMediumFont(color: VineTheme.whiteText)
                .copyWith(
                  shadows: const [
                    Shadow(color: VineTheme.scrim70, blurRadius: 6),
                  ],
                ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            height: _rulerHeight,
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _ZoomRulerPainter(
                  zoom: zoom,
                  minZoom: minZoom,
                  maxZoom: maxZoom,
                  labelStyle: VineTheme.labelSmallFont(
                    color: VineTheme.whiteText.withValues(alpha: 0.7),
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

class _ZoomRulerPainter extends CustomPainter {
  _ZoomRulerPainter({
    required this.zoom,
    required this.minZoom,
    required this.maxZoom,
    required this.labelStyle,
  });

  final double zoom;
  final double minZoom;
  final double maxZoom;
  final TextStyle labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final minorPaint = Paint()
      ..color = VineTheme.whiteText.withValues(alpha: 0.45)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final majorPaint = Paint()
      ..color = VineTheme.whiteText.withValues(alpha: 0.85)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    // Walk the ruler in integer steps of [_minorStep] to avoid float drift.
    final first = (minZoom / _minorStep).ceil();
    final last = (maxZoom / _minorStep).floor();
    for (var i = first; i <= last; i++) {
      final value = i * _minorStep;
      final x = centerX + (value - zoom) * _pxPerZoomUnit;
      if (x < 0 || x > size.width) continue;

      // Majors: every whole factor, plus the 0.5× ultra-wide stop.
      final isMajor = i % 10 == 0 || i == 5;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, isMajor ? _majorTickHeight : _minorTickHeight),
        isMajor ? majorPaint : minorPaint,
      );

      if (isMajor) _paintLabel(canvas, x, _majorLabel(value));
    }

    canvas.drawLine(
      Offset(centerX, 0),
      Offset(centerX, _accentHeight),
      Paint()
        ..color = VineTheme.primary
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintLabel(Canvas canvas, double x, String text) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(x - painter.width / 2, _majorTickHeight + 4),
    );
  }

  @override
  bool shouldRepaint(_ZoomRulerPainter old) =>
      old.zoom != zoom ||
      old.minZoom != minZoom ||
      old.maxZoom != maxZoom ||
      old.labelStyle != labelStyle;
}

/// Pixels of horizontal travel per 1.0× of zoom.
const _pxPerZoomUnit = 110.0;

/// Spacing between minor tick marks, in zoom units.
const _minorStep = 0.1;

/// Zoom step applied per screen-reader increase / decrease action.
const _semanticZoomStep = 0.1;

/// Radius (in zoom units) of the soft detent around each major mark while
/// dragging. Matches the pinch gesture's 1× gravity well; kept well below the
/// 0.5× tick spacing so neighbouring wells never overlap.
const _snapRadius = 0.15;

const _minorTickHeight = 9.0;
const _majorTickHeight = 16.0;
const _accentHeight = 20.0;
const _rulerHeight = 36.0;

/// Below this the camera has effectively a single zoom stop, so the ruler
/// is never shown.
const _zoomRangeEpsilon = 0.01;

/// Floating value label, e.g. `0.5×`, `1×`, `2.4×` (drops a trailing `.0`).
String _valueLabel(double zoom) {
  final rounded = (zoom * 10).roundToDouble() / 10;
  if (rounded == rounded.truncateToDouble()) return '${rounded.toInt()}×';
  return '${rounded.toStringAsFixed(1)}×';
}

/// Compact tick label, e.g. `0.5` → `.5`, `1.0` → `1`.
String _majorLabel(double value) {
  if (value == value.truncateToDouble()) return '${value.toInt()}';
  return value.toStringAsFixed(1).replaceFirst('0.', '.');
}

/// Spoken value for screen readers, e.g. `0.5` or `1`.
String _accessibilityValue(double zoom) {
  final rounded = (zoom * 10).roundToDouble() / 10;
  if (rounded == rounded.truncateToDouble()) return '${rounded.toInt()}';
  return rounded.toStringAsFixed(1);
}
