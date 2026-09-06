// ABOUTME: Visual waveform widget displayed during recording with audio
// ABOUTME: Shows animated bars, playback progress, and position text

import 'dart:math' as math;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

/// A visual waveform widget that displays audio playback progress.
///
/// This widget is used during "lip sync" recording mode to show:
/// - Animated waveform bars that respond to playback
/// - Progress indicator showing current position
/// - Position text (e.g., "0:03 / 0:06")
///
/// Example usage:
/// ```dart
/// AudioWaveform(
///   duration: Duration(seconds: 6),
///   position: Duration(seconds: 3),
///   isPlaying: true,
/// )
/// ```
class AudioWaveform extends StatefulWidget {
  /// Creates an AudioWaveform widget.
  const AudioWaveform({
    super.key,
    this.duration,
    this.position = Duration.zero,
    this.isPlaying = false,
    this.height = 40,
    this.color,
    this.backgroundColor,
    this.barCount = 30,
    this.showPositionText = true,
  });

  /// Total duration of the audio. Null if not loaded.
  final Duration? duration;

  /// Current playback position.
  final Duration position;

  /// Whether audio is currently playing.
  final bool isPlaying;

  /// Height of the waveform widget.
  final double height;

  /// Color of the waveform bars. Defaults to [VineTheme.vineGreen].
  final Color? color;

  /// Background color behind the waveform. Defaults to transparent.
  final Color? backgroundColor;

  /// Number of bars in the waveform visualization.
  final int barCount;

  /// Whether to display the position text below the waveform.
  final bool showPositionText;

  @override
  State<AudioWaveform> createState() => _AudioWaveformState();
}

class _AudioWaveformState extends State<AudioWaveform>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  /// Pre-generated bar heights (0.0-1.0) for consistent waveform shape.
  late List<double> _barHeights;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _generateBarHeights();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(AudioWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isPlaying != oldWidget.isPlaying) {
      _syncAnimation();
    }

    // Regenerate bar heights if bar count changed
    if (widget.barCount != oldWidget.barCount) {
      _generateBarHeights();
    }
  }

  void _syncAnimation() {
    if (!widget.isPlaying || MediaQuery.disableAnimationsOf(context)) {
      _animationController.stop();
      _animationController.value = 0;
    } else if (!_animationController.isAnimating) {
      _animationController.repeat(reverse: true);
    }
  }

  /// Generates pseudo-random bar heights for a natural waveform look.
  void _generateBarHeights() {
    final random = math.Random(42); // Fixed seed for consistent appearance
    _barHeights = List.generate(widget.barCount, (index) {
      // Create a wave-like pattern with some randomness
      final baseHeight = 0.3 + 0.4 * math.sin(index * 0.5).abs();
      final randomVariation = random.nextDouble() * 0.3;
      return (baseHeight + randomVariation).clamp(0.2, 1.0);
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Calculates progress as a value between 0.0 and 1.0.
  double get _progress {
    if (widget.duration == null || widget.duration!.inMilliseconds == 0) {
      return 0.0;
    }
    final progress =
        widget.position.inMilliseconds / widget.duration!.inMilliseconds;
    return progress.clamp(0.0, 1.0);
  }

  /// Formats a duration as "M:SS" (e.g., "0:03", "1:45").
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Spacing between waveform and position text.
  static const double _spacing = 8.0;

  /// Height of the position text line.
  static const double _textHeight = 16.0;

  @override
  Widget build(BuildContext context) {
    final waveformColor = widget.color ?? VineTheme.vineGreen;
    final bgColor = widget.backgroundColor ?? VineTheme.transparent;
    // Total height: waveform + optional spacing + text
    final totalHeight = widget.showPositionText
        ? widget.height + _spacing + _textHeight
        : widget.height;

    return Semantics(
      identifier: 'audio_waveform',
      label: 'Audio waveform visualization',
      value: widget.duration != null
          ? '${_formatDuration(widget.position)} of ${_formatDuration(widget.duration!)}'
          : 'Loading',
      child: Container(
        height: totalHeight,
        color: bgColor,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Waveform visualization
            SizedBox(
              height: widget.height,
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _WaveformPainter(
                      barHeights: _barHeights,
                      progress: _progress,
                      animationValue: _animationController.value,
                      isPlaying: widget.isPlaying,
                      activeColor: waveformColor,
                      inactiveColor: waveformColor.withValues(alpha: 0.3),
                    ),
                    size: Size.infinite,
                  );
                },
              ),
            ),
            if (widget.showPositionText) ...[
              const SizedBox(height: _spacing),
              // Position text
              SizedBox(height: _textHeight, child: _buildPositionText()),
            ],
          ],
        ),
      ),
    );
  }

  /// Builds the position text display (e.g., "0:03 / 0:06").
  Widget _buildPositionText() {
    if (widget.duration == null) {
      return Text(
        '--:-- / --:--',
        style: TextStyle(
          color: context.vineColors.mutedText,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    final positionText = _formatDuration(widget.position);
    final durationText = _formatDuration(widget.duration!);

    return Text(
      '$positionText / $durationText',
      style: TextStyle(
        color: context.vineColors.primaryText,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

/// Custom painter for rendering the waveform bars.
class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.barHeights,
    required this.progress,
    required this.animationValue,
    required this.isPlaying,
    required this.activeColor,
    required this.inactiveColor,
  });

  final List<double> barHeights;
  final double progress;
  final double animationValue;
  final bool isPlaying;
  final Color activeColor;
  final Color inactiveColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (barHeights.isEmpty) return;

    final barCount = barHeights.length;
    const barSpacing = 2.0;
    final availableWidth = size.width - (barSpacing * (barCount - 1));
    final barWidth = availableWidth / barCount;

    // Calculate which bar index represents the progress point
    final progressBarIndex = (progress * barCount).floor();

    for (var i = 0; i < barCount; i++) {
      final x = i * (barWidth + barSpacing);
      final isPast = i < progressBarIndex;
      final isCurrent = i == progressBarIndex;

      // Determine bar height with animation
      var heightMultiplier = barHeights[i];
      if (isPlaying) {
        // Add subtle animation to bars when playing
        final animOffset =
            math.sin(
              (i / barCount) * math.pi * 2 + animationValue * math.pi * 2,
            ) *
            0.15;
        heightMultiplier = (heightMultiplier + animOffset).clamp(0.2, 1.0);
      }

      final barHeight = size.height * heightMultiplier;
      final y = (size.height - barHeight) / 2;

      // Determine color based on progress
      Color barColor;
      if (isPast || isCurrent) {
        barColor = activeColor;
      } else {
        barColor = inactiveColor;
      }

      // Draw the bar with rounded corners
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        const Radius.circular(2),
      );

      final paint = Paint()
        ..color = barColor
        ..style = PaintingStyle.fill;

      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.animationValue != animationValue ||
        oldDelegate.isPlaying != isPlaying ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor;
  }
}
