import 'dart:async';
import 'dart:math';

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';

/// Custom circular progress spinner.
/// Animates like a clock from 0 to 360 degrees based on progress.
/// Uses implicit animation for smooth transitions between progress values.
class PartialCircleSpinner extends StatefulWidget {
  /// Creates a partial circle spinner.
  const PartialCircleSpinner({
    required this.progress,
    this.size = 24,
    this.backgroundColor = const Color(0xFF737778),
    this.progressColor = VineTheme.whiteText,
    super.key,
  });

  /// The progress value between 0.0 and 1.0.
  final double progress;

  /// The size of the spinner (width and height).
  final double size;

  /// The background color of the spinner.
  final Color backgroundColor;

  /// The color of the progress arc.
  ///
  /// Fixed rather than palette-driven: it is drawn on [backgroundColor],
  /// itself a fixed mid-grey, so the pair has to keep its own contrast
  /// independently of the appearance mode.
  final Color progressColor;

  @override
  State<PartialCircleSpinner> createState() => _PartialCircleSpinnerState();
}

class _PartialCircleSpinnerState extends State<PartialCircleSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, value: widget.progress);
  }

  @override
  void didUpdateWidget(PartialCircleSpinner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.progress != oldWidget.progress) {
      _controller
          .animateTo(
            widget.progress,
            duration: const Duration(milliseconds: 200),
          )
          .ignore();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _PartialCirclePainter(
              progress: _controller.value,
              backgroundColor: widget.backgroundColor,
              progressColor: widget.progressColor,
            ),
          ),
        );
      },
    );
  }
}

class _PartialCirclePainter extends CustomPainter {
  _PartialCirclePainter({
    required this.progress,
    required this.backgroundColor,
    required this.progressColor,
  });

  final double progress;
  final Color backgroundColor;
  final Color progressColor;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2;
    final center = Offset(radius, radius);

    // Background circle - the empty/remaining area
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, backgroundPaint);

    // Progress pie slice - filled from center to edge like a clock
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.fill;

    // Draw filled pie slice from 0 to progress, starting from top (12 o'clock)
    const startAngle = -pi / 2;
    final sweepAngle = pi * 2 * progress.clamp(0.0, 1.0);

    if (sweepAngle > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true, // true = connect to center, creates filled pie slice
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_PartialCirclePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.progressColor != progressColor;
  }
}
