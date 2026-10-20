// ABOUTME: Rolling live waveform for a microphone recording: the newest level
// ABOUTME: enters on the right and the strip glides left one bar per sample.

import 'package:material_ui/material_ui.dart';

/// Draws the levels a recorder streams while it records, newest at the right
/// edge.
///
/// Shared by the voice-over recorder and the library's sound recorder. Each
/// new list of [bars] is one new sample: while [isRecording], the strip
/// glides one bar to the left over [sampleInterval] and parks if the next
/// sample is late, so it never runs off-screen. Under the reduced-motion
/// preference new bars appear in place instead.
class LiveAmplitudeWaveform extends StatefulWidget {
  /// Creates a live waveform.
  const LiveAmplitudeWaveform({
    required this.bars,
    required this.isRecording,
    required this.color,
    required this.sampleInterval,
    super.key,
  });

  /// Normalized (`0.0`–`1.0`) levels, oldest first.
  final List<double> bars;

  /// Whether samples are still arriving.
  final bool isRecording;

  /// Bar color.
  final Color color;

  /// Time between two samples; one glide spans exactly this long.
  final Duration sampleInterval;

  @override
  State<LiveAmplitudeWaveform> createState() => _LiveAmplitudeWaveformState();
}

class _LiveAmplitudeWaveformState extends State<LiveAmplitudeWaveform>
    with SingleTickerProviderStateMixin {
  // Phase-locked 0->1 scroll fraction between two samples. Restarted on every
  // new sample so the strip glides one bar to the left and parks (clamped at
  // 1) if the next sample is late.
  late final AnimationController _scroll;

  @override
  void initState() {
    super.initState();
    _scroll = AnimationController(vsync: this, duration: widget.sampleInterval);
  }

  @override
  void didUpdateWidget(LiveAmplitudeWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scroll.duration = widget.sampleInterval;
    final newSample = !identical(oldWidget.bars, widget.bars);
    if (!newSample && oldWidget.isRecording == widget.isRecording) return;
    if (widget.isRecording && !MediaQuery.disableAnimationsOf(context)) {
      _scroll.forward(from: 0);
    } else {
      _scroll
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        painter: _LiveAmplitudeWaveformPainter(
          bars: widget.bars,
          color: widget.color,
          scroll: _scroll,
        ),
        size: Size.infinite,
      ),
    );
  }
}

/// Paints the rolling amplitude buffer as centered vertical bars.
///
/// Unlike `StereoWaveformPainter` (which renders a fully-extracted file's
/// channels), this draws the most recent [bars] streamed from a recorder.
/// Bars are positioned **relative to the buffer** — the newest sits at the
/// right edge — so the strip never runs off-screen once the buffer hits its
/// cap. [scroll] is a `0->1` fraction that slides every bar left by one step
/// between samples for smooth motion.
class _LiveAmplitudeWaveformPainter extends CustomPainter {
  _LiveAmplitudeWaveformPainter({
    required this.bars,
    required this.color,
    required this.scroll,
  }) : super(repaint: scroll);

  final List<double> bars;
  final Color color;
  final Animation<double> scroll;

  static const _barWidth = 3.0;
  static const _gap = 3.0;
  static const _minBarHeight = 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;

    final centerY = size.height / 2;
    const step = _barWidth + _gap;
    final fraction = scroll.value;
    final paint = Paint()
      ..color = color
      ..strokeWidth = _barWidth
      ..strokeCap = StrokeCap.round;

    // Walk from the newest bar (right edge) toward older ones (left). Each
    // bar sits `(fromRight + fraction)` steps left of the right edge, so the
    // whole strip glides left as `fraction` runs 0 -> 1.
    final lastIndex = bars.length - 1;
    for (var i = lastIndex; i >= 0; i--) {
      final fromRight = lastIndex - i;
      final x = size.width - (fromRight + fraction) * step - _barWidth / 2;
      if (x < -_barWidth) break;
      final amplitude = bars[i].clamp(0.0, 1.0);
      final barHeight =
          _minBarHeight + amplitude * (size.height - _minBarHeight);
      final half = barHeight / 2;
      canvas.drawLine(
        Offset(x, centerY - half),
        Offset(x, centerY + half),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_LiveAmplitudeWaveformPainter oldDelegate) =>
      oldDelegate.bars != bars ||
      oldDelegate.color != color ||
      oldDelegate.scroll != scroll;
}
