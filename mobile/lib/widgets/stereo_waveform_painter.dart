// ABOUTME: Shared stereo waveform painter for audio visualization.
// ABOUTME: Used by video recorder progress bar and audio timing screen.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

/// Constants for waveform bar rendering.
abstract final class WaveformConstants {
  /// Width of each waveform bar.
  static const barWidth = 3.0;

  /// Spacing between waveform bars.
  static const barSpacing = 2.0;

  /// Total step (width + spacing) for each bar position.
  static const double barStep = barWidth + barSpacing;

  /// Minimum bar height for visibility.
  static const minBarHeight = 1.0;

  /// Bar height when no waveform data is available.
  static const emptyBarHeight = 4.0;

  /// Corner radius for bars.
  static const barRadius = Radius.circular(1.5);

  /// Default waveform widget height.
  static const waveformHeight = 72.0;

  /// Scale factor for waveform amplitude (leaves headroom at edges).
  static const amplitudeScale = 0.9;

  /// Lower bound for the peak the bars are normalized against. Audio whose
  /// loudest sample sits below this stays quiet on screen rather than being
  /// stretched to full scale — the difference between "quiet" and "silent"
  /// survives. Mirrors `TimelineConstants.clipWaveformNormalizerFloor`.
  static const amplitudeNormalizerFloor = 0.2;

  /// Exponent applied to the normalized amplitude. Below 1 it lifts the quiet
  /// body of the signal toward the peaks; 1 would be a linear (near-flat)
  /// band. Mirrors `TimelineConstants.clipWaveformCurve`.
  static const amplitudeCurve = 0.6;

  /// Duration for waveform entrance animation.
  static const animationDuration = Duration(milliseconds: 400);

  /// Curve for waveform entrance animation.
  static const Cubic animationCurve = Curves.easeOutCubic;
}

/// Custom painter for stereo waveform with progress overlay.
///
/// The waveform is scaled to show only [maxDuration] worth of audio:
/// - If audio is longer than maxDuration, only maxDuration is shown starting from [startOffset]
/// - If audio is shorter than maxDuration, waveform fills proportionally
///
/// Supports:
/// - Active/inactive colors based on progress position
/// - Height animation via [heightFactor]
/// - Automatic sample-to-bar mapping
/// - Start offset for displaying a specific audio segment
/// - Amplitude normalization against the source's own peak, so a quietly
///   recorded track fills the band instead of reading as silence
class StereoWaveformPainter extends CustomPainter {
  /// Creates a waveform progress painter.
  StereoWaveformPainter({
    required this.leftChannel,
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
    required this.audioDuration,
    required this.maxDuration,
    this.rightChannel,
    this.activeBackgroundColor,
    this.heightFactor = 1.0,
    this.startOffset = Duration.zero,
    this.barWidth = WaveformConstants.barWidth,
    this.barSpacing = WaveformConstants.barSpacing,
  });

  /// Left channel amplitude data.
  final Float32List leftChannel;

  /// Right channel amplitude data. Falls back to [leftChannel] if null.
  final Float32List? rightChannel;

  /// Progress value (0.0 to 1.0) for active/inactive coloring.
  final double progress;

  /// Color for active (played) portion of waveform.
  final Color activeColor;

  /// Color for inactive (unplayed) portion of waveform.
  final Color inactiveColor;

  /// Optional background color for active region.
  final Color? activeBackgroundColor;

  /// Total audio duration.
  final Duration audioDuration;

  /// Maximum duration to display.
  final Duration maxDuration;

  /// Offset within the audio where display starts.
  /// Default is [Duration.zero] (start from beginning).
  final Duration startOffset;

  /// Multiplier for bar heights (0.0 to 1.0) used for entrance animation.
  final double heightFactor;

  /// Width of each waveform bar.
  final double barWidth;

  /// Spacing between waveform bars.
  final double barSpacing;

  /// Computed step (width + spacing) for each bar.
  double get _barStep => barWidth + barSpacing;

  /// The loudest sample across both channels, floored.
  ///
  /// Real recordings rarely approach full scale, so raw amplitudes mapped
  /// straight onto the half-height draw as a barely-there ripple — a perfectly
  /// audible track reads as silent. Normalizing against the whole source
  /// rather than the visible window keeps a trim from restyling the bars.
  late final double _normalizer = _computeNormalizer();

  double _computeNormalizer() {
    var peak = WaveformConstants.amplitudeNormalizerFloor;
    for (final sample in leftChannel) {
      final amplitude = sample.abs();
      if (amplitude > peak) peak = amplitude;
    }
    for (final sample in rightChannel ?? const <double>[]) {
      final amplitude = sample.abs();
      if (amplitude > peak) peak = amplitude;
    }
    return peak;
  }

  /// Maps a raw sample to its share (0..1) of the available half-height.
  ///
  /// Audio spends most of its time far below its peak, so a linear map reads
  /// as a flat line with occasional spikes. The curve lifts the body without
  /// flattening the transients.
  double _shape(double sample) => math
      .pow(
        (sample.abs() / _normalizer).clamp(0.0, 1.0),
        WaveformConstants.amplitudeCurve,
      )
      .toDouble();

  @override
  void paint(Canvas canvas, Size size) {
    final halfHeight = size.height / 2;
    final progressX = size.width * progress;

    // If no waveform data, draw empty placeholder bars across entire width
    if (leftChannel.isEmpty) {
      _drawEmptyBars(
        canvas: canvas,
        startX: 0,
        endX: size.width,
        centerY: halfHeight,
        progressX: progressX,
      );
      return;
    }

    // Calculate visible duration and ratios
    final audioMs = audioDuration.inMilliseconds.toDouble();
    final maxMs = maxDuration.inMilliseconds.toDouble();
    final offsetMs = startOffset.inMilliseconds.toDouble();

    // Guard against invalid audio duration
    if (audioMs <= 0 || maxMs <= 0) {
      _drawEmptyBars(
        canvas: canvas,
        startX: 0,
        endX: size.width,
        centerY: halfHeight,
        progressX: progressX,
      );
      return;
    }

    // Calculate available audio after offset
    final availableMs = (audioMs - offsetMs).clamp(0.0, audioMs);
    final visibleMs = availableMs.clamp(0.0, maxMs);

    // How much of the bar should be filled with waveform
    // (1.0 if available audio >= maxDuration, less if shorter)
    final barFillRatio = visibleMs / maxMs;

    // Calculate sample offset and visible sample count
    final sampleOffset = ((offsetMs / audioMs) * leftChannel.length).floor();
    final visibleSampleCount = ((visibleMs / audioMs) * leftChannel.length)
        .ceil();

    final waveformWidth = size.width * barFillRatio;

    // Draw active background if provided
    if (activeBackgroundColor != null && progressX > 0) {
      final bgPaint = Paint()
        ..color = activeBackgroundColor!
        ..style = PaintingStyle.fill;
      canvas.drawRect(Rect.fromLTWH(0, 0, progressX, size.height), bgPaint);
    }

    // Draw both channels as connected bars (no gap in center)
    final rightSamples = rightChannel ?? leftChannel;
    _drawStereoWaveform(
      canvas: canvas,
      leftSamples: leftChannel,
      rightSamples: rightSamples,
      centerY: halfHeight,
      halfHeight: halfHeight,
      waveformWidth: waveformWidth,
      visibleSampleCount: visibleSampleCount,
      sampleOffset: sampleOffset,
      progressX: progressX,
    );

    // Draw placeholder bars for remaining empty space (if audio < maxDuration)
    if (barFillRatio < 1.0) {
      final waveformBarCount = (waveformWidth / _barStep).floor();
      final emptyStartX = waveformBarCount * _barStep;

      _drawEmptyBars(
        canvas: canvas,
        startX: emptyStartX,
        endX: size.width,
        centerY: halfHeight,
        progressX: progressX,
      );
    }
  }

  /// Draws minimal amplitude bars in the empty area where no waveform data.
  void _drawEmptyBars({
    required Canvas canvas,
    required double startX,
    required double endX,
    required double centerY,
    required double progressX,
  }) {
    const totalHeight = WaveformConstants.minBarHeight * 2;

    var x = startX;
    while (x < endX) {
      final isActive = x <= progressX;
      final paint = Paint()
        ..color = isActive ? activeColor : inactiveColor
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            x,
            centerY - WaveformConstants.minBarHeight,
            barWidth,
            totalHeight,
          ),
          WaveformConstants.barRadius,
        ),
        paint,
      );
      x += _barStep;
    }
  }

  /// Draws both channels as connected vertical bars (no gap in center).
  void _drawStereoWaveform({
    required Canvas canvas,
    required Float32List leftSamples,
    required Float32List rightSamples,
    required double centerY,
    required double halfHeight,
    required double waveformWidth,
    required int visibleSampleCount,
    required int sampleOffset,
    required double progressX,
  }) {
    final barCount = (waveformWidth / _barStep).floor();

    if (barCount <= 0 || visibleSampleCount <= 0) return;

    final scaledHalfHeight =
        halfHeight * WaveformConstants.amplitudeScale * heightFactor;

    for (var i = 0; i < barCount; i++) {
      final x = i * _barStep;

      // Map bar position to sample index within visible samples, offset by startOffset
      final sampleIndex =
          sampleOffset + ((i / barCount) * visibleSampleCount).floor();

      // Normalize and curve the raw samples into 0.0-1.0 display amplitudes.
      final leftAmp = sampleIndex < leftSamples.length
          ? _shape(leftSamples[sampleIndex])
          : 0.0;
      final rightAmp = sampleIndex < rightSamples.length
          ? _shape(rightSamples[sampleIndex])
          : 0.0;

      // Calculate bar heights (minimum for visibility), scaled by animation
      final topHeight = (leftAmp * scaledHalfHeight).clamp(
        WaveformConstants.minBarHeight,
        halfHeight,
      );
      final bottomHeight = (rightAmp * scaledHalfHeight).clamp(
        WaveformConstants.minBarHeight,
        halfHeight,
      );

      // Total height spans from top of left channel to bottom of right channel
      final totalHeight = topHeight + bottomHeight;
      final topY = centerY - topHeight;

      // Determine color based on progress
      final isActive = x <= progressX;
      final paint = Paint()
        ..color = isActive ? activeColor : inactiveColor
        ..style = PaintingStyle.fill;

      // Draw single connected bar spanning both channels
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, topY, barWidth, totalHeight),
          WaveformConstants.barRadius,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(StereoWaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor ||
        oldDelegate.leftChannel != leftChannel ||
        oldDelegate.rightChannel != rightChannel ||
        oldDelegate.audioDuration != audioDuration ||
        oldDelegate.maxDuration != maxDuration ||
        oldDelegate.heightFactor != heightFactor ||
        oldDelegate.startOffset != startOffset ||
        oldDelegate.barWidth != barWidth ||
        oldDelegate.barSpacing != barSpacing;
  }
}
