// ABOUTME: Vertical slider widget for video editor controls.
// ABOUTME: Used for adjusting filter opacity with a custom vertical design.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';

/// A vertical slider with a custom design matching the Figma specs.
///
/// Features:
/// - Vertical track with gradient (active portion colored)
/// - Round thumb with subtle drop shadow
/// - Smooth drag interaction
class VideoEditorVerticalSlider extends StatefulWidget {
  const VideoEditorVerticalSlider({
    required this.value,
    required this.onChanged,
    super.key,
    this.onChangeEnd,
    this.height = 300,
  });

  /// Current value (0.0 - 1.0).
  final double value;

  /// Called during drag with the new value.
  final ValueChanged<double> onChanged;

  /// Called when drag ends.
  final ValueChanged<double>? onChangeEnd;

  /// Total height of the slider.
  final double height;

  @override
  State<VideoEditorVerticalSlider> createState() =>
      _VideoEditorVerticalSliderState();
}

class _VideoEditorVerticalSliderState extends State<VideoEditorVerticalSlider> {
  double _dragValue = 0;
  bool _isDragging = false;

  double get _currentValue => _isDragging ? _dragValue : widget.value;

  void _handleDragStart(DragStartDetails details) {
    _isDragging = true;
    _updateValue(details.localPosition, _getSliderHeight());
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    _updateValue(details.localPosition, _getSliderHeight());
  }

  void _handleDragEnd(DragEndDetails details) {
    widget.onChangeEnd?.call(_dragValue);
    setState(() => _isDragging = false);
  }

  double _getSliderHeight() {
    final renderBox = context.findRenderObject() as RenderBox?;
    return renderBox?.size.height ?? widget.height;
  }

  void _updateValue(Offset localPosition, double height) {
    // Invert because 0 is at bottom, 1 is at top
    final normalizedY = 1 - (localPosition.dy / height).clamp(0.0, 1.0);
    setState(() => _dragValue = normalizedY);
    widget.onChanged(normalizedY);
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Use actual available height, constrained by widget.height
          final actualHeight = constraints.maxHeight.isFinite
              ? constraints.maxHeight.clamp(0.0, widget.height)
              : widget.height;

          return Semantics(
            slider: true,
            label: context.l10n.videoEditorLevelSemanticLabel,
            value: '${(_currentValue * 100).round()}%',
            increasedValue:
                '${((_currentValue + 0.1).clamp(0.0, 1.0) * 100).round()}%',
            decreasedValue:
                '${((_currentValue - 0.1).clamp(0.0, 1.0) * 100).round()}%',
            onIncrease: () {
              final v = (_currentValue + 0.1).clamp(0.0, 1.0);
              widget.onChanged(v);
              widget.onChangeEnd?.call(v);
            },
            onDecrease: () {
              final v = (_currentValue - 0.1).clamp(0.0, 1.0);
              widget.onChanged(v);
              widget.onChangeEnd?.call(v);
            },
            child: _SliderBody(
              height: actualHeight,
              value: _currentValue,
              onDragStart: _handleDragStart,
              onDragUpdate: _handleDragUpdate,
              onDragEnd: _handleDragEnd,
            ),
          );
        },
      ),
    );
  }
}

class _SliderBody extends StatelessWidget {
  const _SliderBody({
    required this.height,
    required this.value,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final double height;
  final double value;
  final GestureDragStartCallback onDragStart;
  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragStart: onDragStart,
      onVerticalDragUpdate: onDragUpdate,
      onVerticalDragEnd: onDragEnd,
      behavior: .opaque,
      child: SizedBox(
        height: height,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            // Extra padding for touch target
            minWidth: kMinInteractiveDimension,
          ),
          child: Stack(
            alignment: .center,
            clipBehavior: .none,
            children: [
              // Track
              _Track(height: height, value: value),
              // Thumb
              _Thumb(value: value, height: height),
            ],
          ),
        ),
      ),
    );
  }
}

/// The vertical track with gradient coloring.
class _Track extends StatelessWidget {
  const _Track({required this.height, required this.value});

  final double height;
  final double value;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(16, height),
      painter: _TrackPainter(
        value: value,
        activeColor: context.vineColors.onSurface,
        inactiveColor: VineTheme.onSurface.withValues(alpha: 0.5),
      ),
    );
  }
}

class _TrackPainter extends CustomPainter {
  _TrackPainter({
    required this.value,
    required this.activeColor,
    required this.inactiveColor,
  });

  final double value;
  final Color activeColor;
  final Color inactiveColor;

  static const double topWidth = 16;
  static const double bottomWidth = 4;
  static const double borderRadius = 2;

  @override
  void paint(Canvas canvas, Size size) {
    final height = size.height;

    // The split point between active (bottom) and inactive (top)
    // value=1 means thumb at top (all active), value=0 means thumb at bottom
    // (all inactive)
    final splitY = (1 - value) * height;

    // Calculate width at split point (linear interpolation)
    final splitWidth = topWidth - (topWidth - bottomWidth) * (splitY / height);

    // Draw inactive part (above split) - from top to splitY
    if (splitY > 0) {
      final inactivePath = _buildTrapezoidPath(
        top: 0,
        bottom: splitY,
        topWidth: topWidth,
        bottomWidth: splitWidth,
      );
      canvas.drawPath(inactivePath, Paint()..color = inactiveColor);
    }

    // Draw active part (below split) - from splitY to bottom
    if (splitY < height) {
      final activePath = _buildTrapezoidPath(
        top: splitY,
        bottom: height,
        topWidth: splitWidth,
        bottomWidth: bottomWidth,
      );
      canvas.drawPath(activePath, Paint()..color = activeColor);
    }
  }

  Path _buildTrapezoidPath({
    required double top,
    required double bottom,
    required double topWidth,
    required double bottomWidth,
  }) {
    final path = Path();

    // Symmetric funnel: both edges taper toward center
    const center = _TrackPainter.topWidth / 2;

    final topLeft = center - topWidth / 2;
    final topRight = center + topWidth / 2;
    final bottomLeft = center - bottomWidth / 2;
    final bottomRight = center + bottomWidth / 2;

    // Start at top-right, go clockwise
    path
      ..moveTo(topRight - borderRadius, top)
      ..quadraticBezierTo(topRight, top, topRight, top + borderRadius)
      ..lineTo(bottomRight, bottom - borderRadius)
      ..quadraticBezierTo(
        bottomRight,
        bottom,
        bottomRight - borderRadius,
        bottom,
      )
      ..lineTo(bottomLeft + borderRadius, bottom)
      ..quadraticBezierTo(bottomLeft, bottom, bottomLeft, bottom - borderRadius)
      ..lineTo(topLeft, top + borderRadius)
      ..quadraticBezierTo(topLeft, top, topLeft + borderRadius, top)
      ..close();

    return path;
  }

  @override
  bool shouldRepaint(_TrackPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor;
  }
}

/// The draggable thumb with shadow.
class _Thumb extends StatelessWidget {
  const _Thumb({required this.value, required this.height});

  final double value;
  final double height;

  static const double _size = 28;

  @override
  Widget build(BuildContext context) {
    // Position from bottom (0) to top (1)
    final thumbTop = (1 - value) * (height - _size);

    return Positioned(
      top: thumbTop,
      child: SizedBox(
        width: _size,
        height: _size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: _size,
              height: _size,
              decoration: BoxDecoration(
                color: VineTheme.whiteText,
                borderRadius: .circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: VineTheme.innerShadow,
                    offset: Offset(0.4, 0.4),
                    blurRadius: 0.6,
                  ),
                  BoxShadow(
                    color: VineTheme.innerShadow,
                    offset: Offset(1, 1),
                    blurRadius: 1,
                  ),
                ],
              ),
            ),
            Positioned(
              right: _size + 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: Text(
                  (value * 100).toStringAsFixed(0),
                  style: VineTheme.labelMediumFont(
                    // Was inheriting the ambient bodyMedium, i.e. exactly this
                    // token — spelled out so it follows the palette in light.
                    color: context.vineColors.secondaryText,
                    fontFeatures: [const .tabularFigures()],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
