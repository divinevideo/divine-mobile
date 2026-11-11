// ABOUTME: The Curve section of the Adjust bar: a tab per tone curve and the
// ABOUTME: picked curve as a graph whose five points are dragged up or down.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/tune_editor/video_editor_tune_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/adjust_color_controls.dart';
import 'package:openvine/widgets/video_editor/tune_editor/tune_labels.dart';
import 'package:openvine/widgets/video_editor/tune_editor/tune_value_changes.dart';

/// The Curve section of the Adjust bar.
///
/// Tabs pick the master curve or the red, green or blue one; the graph below
/// shows the picked curve over the straight line it starts as. Each of its
/// five points, from blacks to whites, is dragged up or down; it snaps back
/// onto the line near it, and a double tap puts it back there.
class VideoEditorTuneCurvePanel extends StatelessWidget {
  const VideoEditorTuneCurvePanel({super.key});

  static const double _channelsHeight = 40;
  static const double _graphHeight = 140;
  static const double _graphBottomPadding = 4;

  /// The panel's height.
  static const double height =
      _channelsHeight + _graphHeight + _graphBottomPadding;

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: .min,
      children: [
        SizedBox(height: _channelsHeight, child: _CurveChannels()),
        Padding(
          padding: .fromLTRB(16, 0, 16, _graphBottomPadding),
          child: SizedBox(height: _graphHeight, child: _CurveGraph()),
        ),
      ],
    );
  }
}

/// How far a point may sit from the straight line and still snap onto it.
const double _snapDistance = 0.02;

/// How far one accessibility increase or decrease moves a point.
const double _semanticsStep = 0.05;

/// The values of [channel]'s points in [state], from blacks to whites.
List<double> _offsetsOf(
  VideoEditorTuneState state,
  AdjustCurveChannel channel,
) => [
  for (final point in AdjustCurvePoint.values)
    state.valueOf(channel.kindOf(point)),
];

/// The colour [channel]'s curve is drawn in.
Color _curveColorOf(BuildContext context, AdjustCurveChannel channel) =>
    switch (channel) {
      .rgb => context.vineColors.onSurface,
      .red => VineTheme.adjustColorBandSwatches[AdjustColorBand.red.index],
      .green => VineTheme.adjustColorBandSwatches[AdjustColorBand.green.index],
      .blue => VineTheme.adjustColorBandSwatches[AdjustColorBand.blue.index],
    };

class _CurveChannels extends StatelessWidget {
  const _CurveChannels();

  @override
  Widget build(BuildContext context) {
    final (selected, values) = context.select(
      (VideoEditorTuneBloc b) => (b.state.curveChannel, b.state.values),
    );
    return Row(
      mainAxisAlignment: .center,
      spacing: 8,
      children: [
        for (final channel in AdjustCurveChannel.values)
          _CurveChannelTab(
            channel: channel,
            isSelected: channel == selected,
            isAdjusted: AdjustCurvePoint.values.any(
              (point) => (values[channel.kindOf(point)] ?? 0) != 0,
            ),
          ),
      ],
    );
  }
}

class _CurveChannelTab extends StatelessWidget {
  const _CurveChannelTab({
    required this.channel,
    required this.isSelected,
    required this.isAdjusted,
  });

  final AdjustCurveChannel channel;
  final bool isSelected;
  final bool isAdjusted;

  @override
  Widget build(BuildContext context) {
    final label = tuneCurveChannelLabel(context, channel);
    return Semantics(
      button: true,
      selected: isSelected,
      label: isAdjusted
          ? '$label, ${context.l10n.videoEditorTuneChanged}'
          : label,
      child: GestureDetector(
        behavior: .opaque,
        onTap: () => context.read<VideoEditorTuneBloc>().add(
          VideoEditorTuneCurveChannelSelected(channel),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 40),
          child: Center(
            child: Container(
              padding: const .symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: context.vineColors.surfaceContainer,
                borderRadius: .circular(14),
                border: .all(
                  color: isSelected
                      ? context.vineColors.accentPositive
                      : context.vineColors.outlineMuted,
                  width: 2,
                ),
              ),
              child: ExcludeSemantics(
                child: Row(
                  mainAxisSize: .min,
                  spacing: 4,
                  children: [
                    Text(
                      label,
                      style: VineTheme.bodySmallFont(
                        color: isSelected
                            ? context.vineColors.accentPositive
                            : context.vineColors.onSurface,
                      ),
                    ),
                    if (isAdjusted)
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          shape: .circle,
                          color: context.vineColors.onSurface,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CurveGraph extends StatefulWidget {
  const _CurveGraph();

  @override
  State<_CurveGraph> createState() => _CurveGraphState();
}

class _CurveGraphState extends State<_CurveGraph> {
  /// How far the curve sits inside the graph, so its end points can be
  /// grabbed whole.
  static const double _inset = 10;

  /// The point a drag moves, while one does.
  AdjustCurvePoint? _dragged;

  /// The point a double tap resets.
  AdjustCurvePoint? _doubleTapped;

  /// The value the dragged point has now.
  double _draggedValue = 0;

  /// The point nearest to [position] along the input axis.
  AdjustCurvePoint _pointAt(Offset position, Size size) {
    final x = ((position.dx - _inset) / (size.width - 2 * _inset)).clamp(
      0.0,
      1.0,
    );
    final last = AdjustCurvePoint.values.length - 1;
    return AdjustCurvePoint.values[(x * last).round()];
  }

  /// The value that puts [point] at the output level under [position].
  double _valueAt(AdjustCurvePoint point, Offset position, Size size) {
    final level = 1 - (position.dy - _inset) / (size.height - 2 * _inset);
    final value = (level - point.x).clamp(point.min, point.max);
    return value.abs() < _snapDistance ? 0 : value;
  }

  String _kindOf(AdjustCurvePoint point) =>
      context.read<VideoEditorTuneBloc>().state.curveChannel.kindOf(point);

  void _onPanStart(DragStartDetails details, Size size) {
    final point = _pointAt(details.localPosition, size);
    final value = context.read<VideoEditorTuneBloc>().state.valueOf(
      _kindOf(point),
    );
    setState(() {
      _dragged = point;
      _draggedValue = value;
    });
    TuneValueChanges.start(context, _kindOf(point), value);
  }

  void _onPanUpdate(DragUpdateDetails details, Size size) {
    final point = _dragged;
    if (point == null) return;
    _draggedValue = _valueAt(point, details.localPosition, size);
    TuneValueChanges.update(context, _kindOf(point), _draggedValue);
  }

  void _onPanEnd() {
    final point = _dragged;
    if (point == null) return;
    TuneValueChanges.end(context, _kindOf(point), _draggedValue);
    setState(() => _dragged = null);
  }

  void _onDoubleTap() {
    final point = _doubleTapped;
    if (point == null) return;
    TuneValueChanges.set(context, _kindOf(point), 0);
  }

  /// Moves [point] by [step] for an accessibility action.
  void _step(AdjustCurvePoint point, double step) {
    final kind = _kindOf(point);
    final value = context.read<VideoEditorTuneBloc>().state.valueOf(kind);
    final next = (value + step).clamp(point.min, point.max);
    TuneValueChanges.set(context, kind, next.abs() < _snapDistance ? 0 : next);
  }

  @override
  Widget build(BuildContext context) {
    final (channel, offsets) = context.select(
      (VideoEditorTuneBloc b) => (
        b.state.curveChannel,
        _offsetsOf(b.state, b.state.curveChannel),
      ),
    );
    final l10n = context.l10n;
    final channelLabel = tuneCurveChannelLabel(context, channel);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return Semantics(
          container: true,
          label: '${l10n.videoEditorTuneCurve}, $channelLabel',
          child: GestureDetector(
            behavior: .opaque,
            onPanStart: (details) => _onPanStart(details, size),
            onPanUpdate: (details) => _onPanUpdate(details, size),
            onPanEnd: (_) => _onPanEnd(),
            onPanCancel: _onPanEnd,
            onDoubleTapDown: (details) =>
                _doubleTapped = _pointAt(details.localPosition, size),
            onDoubleTap: _onDoubleTap,
            child: CustomPaint(
              size: size,
              painter: _CurvePainter(
                offsets: offsets,
                inset: _inset,
                dragged: _dragged,
                curveColor: _curveColorOf(context, channel),
                backgroundColor: context.vineColors.surfaceContainer,
                gridColor: context.vineColors.outlineMuted,
                textDirection: Directionality.of(context),
                pointLabels: [
                  for (final point in AdjustCurvePoint.values)
                    tuneCurvePointLabel(context, point),
                ],
                onStep: _step,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Draws a tone curve with its points over a quarter grid and the straight
/// line, and exposes each point to screen readers as an adjustable value.
class _CurvePainter extends CustomPainter {
  _CurvePainter({
    required this.offsets,
    required this.inset,
    required this.dragged,
    required this.curveColor,
    required this.backgroundColor,
    required this.gridColor,
    required this.textDirection,
    required this.pointLabels,
    required this.onStep,
  });

  /// The points' values, from blacks to whites.
  final List<double> offsets;

  final double inset;
  final AdjustCurvePoint? dragged;
  final Color curveColor;
  final Color backgroundColor;
  final Color gridColor;
  final TextDirection textDirection;
  final List<String> pointLabels;
  final void Function(AdjustCurvePoint point, double step) onStep;

  /// How many straight pieces draw the curve.
  static const int _segments = 64;

  Rect _plotOf(Size size) => Rect.fromLTRB(
    inset,
    inset,
    size.width - inset,
    size.height - inset,
  );

  Offset _toCanvas(Rect plot, double x, double level) =>
      Offset(plot.left + x * plot.width, plot.bottom - level * plot.height);

  Offset _pointOffset(Rect plot, AdjustCurvePoint point) => _toCanvas(
    plot,
    point.x,
    (point.x + offsets[point.index]).clamp(0.0, 1.0),
  );

  @override
  void paint(Canvas canvas, Size size) {
    final plot = _plotOf(size);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
      Paint()..color = backgroundColor,
    );

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final f = i / 4;
      canvas
        ..drawLine(
          Offset(plot.left + f * plot.width, plot.top),
          Offset(plot.left + f * plot.width, plot.bottom),
          grid,
        )
        ..drawLine(
          Offset(plot.left, plot.top + f * plot.height),
          Offset(plot.right, plot.top + f * plot.height),
          grid,
        );
    }
    canvas.drawLine(plot.bottomLeft, plot.topRight, grid);

    final curve = Path();
    for (var i = 0; i <= _segments; i++) {
      final x = i / _segments;
      final at = _toCanvas(plot, x, adjustCurveLevel(x, offsets));
      if (i == 0) {
        curve.moveTo(at.dx, at.dy);
      } else {
        curve.lineTo(at.dx, at.dy);
      }
    }
    canvas.drawPath(
      curve,
      Paint()
        ..color = curveColor
        ..style = .stroke
        ..strokeWidth = 2,
    );

    for (final point in AdjustCurvePoint.values) {
      final center = _pointOffset(plot, point);
      final radius = point == dragged ? 8.0 : 6.0;
      canvas
        ..drawCircle(center, radius, Paint()..color = curveColor)
        ..drawCircle(
          center,
          radius,
          Paint()
            ..color = backgroundColor
            ..style = .stroke
            ..strokeWidth = 2,
        );
    }
  }

  String _levelLabel(AdjustCurvePoint point, double value) =>
      '${((point.x + value).clamp(0.0, 1.0) * 100).round()}%';

  @override
  SemanticsBuilderCallback get semanticsBuilder => (size) {
    final plot = _plotOf(size);
    return [
      for (final point in AdjustCurvePoint.values)
        CustomPainterSemantics(
          rect: Rect.fromCircle(center: _pointOffset(plot, point), radius: 20),
          properties: SemanticsProperties(
            slider: true,
            textDirection: textDirection,
            label: pointLabels[point.index],
            value: _levelLabel(point, offsets[point.index]),
            increasedValue: _levelLabel(
              point,
              offsets[point.index] + _semanticsStep,
            ),
            decreasedValue: _levelLabel(
              point,
              offsets[point.index] - _semanticsStep,
            ),
            onIncrease: () => onStep(point, _semanticsStep),
            onDecrease: () => onStep(point, -_semanticsStep),
          ),
        ),
    ];
  };

  @override
  bool shouldRepaint(_CurvePainter oldDelegate) =>
      !listEquals(offsets, oldDelegate.offsets) ||
      dragged != oldDelegate.dragged ||
      curveColor != oldDelegate.curveColor ||
      backgroundColor != oldDelegate.backgroundColor ||
      gridColor != oldDelegate.gridColor;

  @override
  bool shouldRebuildSemantics(_CurvePainter oldDelegate) =>
      !listEquals(offsets, oldDelegate.offsets) ||
      textDirection != oldDelegate.textDirection ||
      !listEquals(pointLabels, oldDelegate.pointLabels);
}
