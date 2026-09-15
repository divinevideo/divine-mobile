// ABOUTME: The voice-over recorder's strip of the video: where the recorded
// ABOUTME: takes sit and the take in progress growing over it.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_editor/voice_over/voice_over_cubit.dart';

/// A strip spanning the video the voice-over is laid over.
///
/// Completed takes are drawn where they will land on the video, and the take
/// in progress grows from its start, so the recorder shows how much of the
/// video the takes have covered and where the next one begins. Its end is
/// eased ([_Eased]) so it glides rather than steps.
class VoiceOverVideoTimeline extends StatelessWidget {
  /// Creates the strip.
  const VoiceOverVideoTimeline({super.key});

  /// Height the strip lays itself out at.
  static const double height = 24;

  @override
  Widget build(BuildContext context) {
    // Purely visual: the time readout beside it already announces the
    // recorded length, and the waveform is excluded the same way.
    return ExcludeSemantics(
      child: BlocBuilder<VoiceOverCubit, VoiceOverState>(
        buildWhen: (previous, current) =>
            previous.takes != current.takes ||
            previous.availableDuration != current.availableDuration ||
            previous.currentDuration != current.currentDuration ||
            previous.hasLiveTake != current.hasLiveTake,
        builder: (context, state) {
          final windows = [
            for (final take in state.placedTakes)
              (start: take.startTime, end: take.endTime ?? take.startTime),
          ];
          final available = state.availableDuration;
          // A stopped take stays drawn live until it lands in the takes, so
          // it does not blink out for the moment in between.
          if (!state.hasLiveTake) {
            return _Strip(
              windows: windows,
              liveWindow: null,
              available: available,
            );
          }
          // The recorded length advances one amplitude sample at a time;
          // easing the live take's end over that same interval turns the
          // steps into a steady glide.
          final liveStart = state.nextTakeStart;
          return _Eased(
            value: liveStart + state.currentDuration,
            lag: VoiceOverCubit.amplitudeInterval,
            builder: (liveEnd) => _Strip(
              windows: windows,
              liveWindow: (start: liveStart, end: liveEnd),
              available: available,
            ),
          );
        },
      ),
    );
  }
}

/// Eases a drawn position toward [value] over [lag].
///
/// Retargeted on every rebuild, so the drawn position trails [value] by about
/// [lag] and glides over steps in it. The first build lands on [value]
/// outright, and reduced motion draws it raw.
class _Eased extends StatelessWidget {
  const _Eased({
    required this.value,
    required this.lag,
    required this.builder,
  });

  final Duration value;
  final Duration lag;
  final Widget Function(Duration eased) builder;

  @override
  Widget build(BuildContext context) {
    final target = value.inMicroseconds.toDouble();
    return TweenAnimationBuilder<double>(
      // `begin` only matters for the first build; every rebuild retargets
      // from wherever the animation currently is.
      tween: Tween(begin: target, end: target),
      duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : lag,
      builder: (context, micros, _) =>
          builder(Duration(microseconds: micros.round())),
    );
  }
}

typedef _Window = ({Duration start, Duration end});

class _Strip extends StatelessWidget {
  const _Strip({
    required this.windows,
    required this.liveWindow,
    required this.available,
  });

  final List<_Window> windows;
  final _Window? liveWindow;
  final Duration available;

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    return CustomPaint(
      painter: VoiceOverVideoTimelinePainter(
        windows: windows,
        liveWindow: liveWindow,
        available: available,
        // The on-surface tint at a quarter strength: still visible over dark
        // footage, and quiet under the take segments drawn on it.
        trackColor: colors.disabled,
        takeColor: colors.accentPositive.withValues(alpha: 0.45),
        liveTakeColor: colors.accentPositive,
      ),
      size: Size.infinite,
    );
  }
}

/// Paints the strip: a rounded track for the whole video, a segment per take
/// where it lands, and the take in progress in a stronger color. Everything is
/// clamped to the track, so a take that outgrows the video stops at the edge.
@visibleForTesting
class VoiceOverVideoTimelinePainter extends CustomPainter {
  /// Creates the painter.
  VoiceOverVideoTimelinePainter({
    required this.windows,
    required this.liveWindow,
    required this.available,
    required this.trackColor,
    required this.takeColor,
    required this.liveTakeColor,
  });

  /// Completed takes, as start/end positions on the video.
  final List<({Duration start, Duration end})> windows;

  /// The take being recorded, or `null` between takes.
  final ({Duration start, Duration end})? liveWindow;

  /// Length of the video the strip spans.
  final Duration available;

  /// Color of the track behind the takes.
  final Color trackColor;

  /// Color of a completed take.
  final Color takeColor;

  /// Color of the take being recorded.
  final Color liveTakeColor;

  static const double _trackHeight = 6;

  @override
  void paint(Canvas canvas, Size size) {
    if (available <= Duration.zero) return;
    final centerY = size.height / 2;
    final track = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, centerY - _trackHeight / 2, size.width, _trackHeight),
      const Radius.circular(_trackHeight / 2),
    );
    canvas
      ..drawRRect(track, Paint()..color = trackColor)
      ..save()
      ..clipRRect(track);
    final takePaint = Paint()..color = takeColor;
    for (final window in windows) {
      _paintWindow(canvas, size, window, takePaint);
    }
    final live = liveWindow;
    if (live != null) {
      _paintWindow(canvas, size, live, Paint()..color = liveTakeColor);
    }
    canvas.restore();
  }

  void _paintWindow(
    Canvas canvas,
    Size size,
    ({Duration start, Duration end}) window,
    Paint paint,
  ) {
    final left = xFor(window.start, size.width);
    final right = xFor(window.end, size.width);
    if (right <= left) return;
    canvas.drawRect(Rect.fromLTRB(left, 0, right, size.height), paint);
  }

  /// Maps a video [position] onto a strip [width] pixels wide, clamped to its
  /// edges.
  @visibleForTesting
  double xFor(Duration position, double width) {
    final fraction = position.inMicroseconds / available.inMicroseconds;
    return fraction.clamp(0.0, 1.0) * width;
  }

  @override
  bool shouldRepaint(VoiceOverVideoTimelinePainter oldDelegate) =>
      !listEquals(oldDelegate.windows, windows) ||
      oldDelegate.liveWindow != liveWindow ||
      oldDelegate.available != available ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.takeColor != takeColor ||
      oldDelegate.liveTakeColor != liveTakeColor;
}
