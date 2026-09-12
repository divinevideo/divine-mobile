// ABOUTME: Translucent waveform band drawn over a timeline clip's thumbnails.
// ABOUTME: Bars grow up from the clip's bottom edge and scale with clip volume.

import 'dart:math' as math;

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/models/video_editor/clip_waveform.dart';

/// The clip's audio waveform, drawn translucently over its thumbnails.
///
/// Sized and positioned by the caller to span the clip's *full source*
/// duration, so the bars stay glued to the frames as the tile is trimmed,
/// zoomed, or scrolled.
class ClipWaveformOverlay extends StatelessWidget {
  const ClipWaveformOverlay({
    required this.waveform,
    required this.clipDuration,
    required this.volume,
    super.key,
  });

  final ClipWaveform waveform;

  /// The clip's own duration — the span the overlay's width represents.
  ///
  /// Not necessarily the source file's length: a trim-based split's start half
  /// is rebased to the split point while still sharing the full-length file.
  final Duration clipDuration;

  /// The clip's volume. Scales the bar heights, so muting flattens the band
  /// to its baseline instead of leaving a misleading loud waveform.
  final double volume;

  @override
  Widget build(BuildContext context) {
    if (waveform.isEmpty) return const SizedBox.shrink();

    return ExcludeSemantics(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size.infinite,
            painter: ClipWaveformPainter(
              waveform: waveform,
              clipDuration: clipDuration,
              volume: volume,
              color: VineTheme.whiteText.withValues(
                alpha: TimelineConstants.clipWaveformOpacity,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints [waveform] as bottom-anchored bars across the full paint width.
@visibleForTesting
class ClipWaveformPainter extends CustomPainter {
  const ClipWaveformPainter({
    required this.waveform,
    required this.clipDuration,
    required this.volume,
    required this.color,
  });

  final ClipWaveform waveform;
  final Duration clipDuration;
  final double volume;
  final Color color;

  static const double _barStep =
      TimelineConstants.clipWaveformBarWidth +
      TimelineConstants.clipWaveformBarSpacing;

  @override
  void paint(Canvas canvas, Size size) {
    final clipMs = clipDuration.inMilliseconds;
    if (waveform.isEmpty || clipMs <= 0 || size.width <= 0) return;

    // Bars map straight from clip time, so the band spans the audio's own
    // length rather than being fitted to the tile. Shorter audio leaves the
    // remainder bare instead of stretching over silence; longer audio — a
    // trim-based split's start half keeps the whole source file — runs past
    // the tile and is culled, instead of squeezing the later halves' sound
    // under these frames.
    final bandWidth = size.width * waveform.duration.inMilliseconds / clipMs;
    final barCount = (bandWidth / _barStep).floor();
    final visibleBarCount = math.min(barCount, (size.width / _barStep).floor());
    if (visibleBarCount <= 0) return;

    final band = math.min(
      TimelineConstants.clipWaveformBandHeight,
      size.height,
    );
    final paint = Paint()..color = color;
    final peaks = waveform.peaks;

    // Normalize against the source file's loudest sample, so a quietly
    // recorded clip still fills the band. The floor keeps near-silence flat
    // instead of amplifying room noise into a convincing-looking waveform.
    //
    // A trim-based split's halves share one file, hence one normalizer: each
    // half is drawn relative to the whole recording rather than to its own
    // loudest moment, so splitting a clip never restyles the bars on either
    // side of the cut.
    final normalizer = math.max(
      waveform.peak,
      TimelineConstants.clipWaveformNormalizerFloor,
    );

    for (var i = 0; i < visibleBarCount; i++) {
      // Peak across every sample the bar covers — averaging (or point
      // sampling) would alias transients away at low zoom, where one bar
      // spans dozens of samples. Indexed against the audio's full bar span,
      // so a bar keeps its timestamp regardless of where the tile ends.
      final from = (i * peaks.length ~/ barCount).clamp(0, peaks.length - 1);
      final to = math.max(from + 1, (i + 1) * peaks.length ~/ barCount);
      var amplitude = 0.0;
      for (var s = from; s < to && s < peaks.length; s++) {
        amplitude = math.max(amplitude, peaks[s]);
      }

      // Compress the normalized amplitude: audio spends most of its time far
      // below its peak, so a linear band reads as a flat line with occasional
      // spikes. The curve lifts the body without flattening the transients.
      final scaled = math.pow(
        (amplitude / normalizer).clamp(0.0, 1.0),
        TimelineConstants.clipWaveformCurve,
      );

      final height =
          (scaled * volume * band * TimelineConstants.clipWaveformGain).clamp(
            TimelineConstants.clipWaveformMinBarHeight,
            band,
          );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            i * _barStep,
            size.height - height,
            TimelineConstants.clipWaveformBarWidth,
            height,
          ),
          const Radius.circular(TimelineConstants.clipWaveformBarWidth / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(ClipWaveformPainter oldDelegate) =>
      oldDelegate.waveform != waveform ||
      oldDelegate.clipDuration != clipDuration ||
      oldDelegate.volume != volume ||
      oldDelegate.color != color;
}
