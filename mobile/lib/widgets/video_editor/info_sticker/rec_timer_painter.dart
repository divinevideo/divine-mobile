// ABOUTME: Paints a REC timer sticker live at the editor's playhead, with the
// ABOUTME: same drawing the export uses once per second of the video.

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:openvine/models/video_editor/info_sticker.dart';
import 'package:openvine/utils/rec_timer_paint.dart';

/// Paints a REC timer showing [elapsed], or the time [playTime] holds while
/// the editor plays.
///
/// Laid out in [designSize] and scaled to whatever it is painted at, so the
/// export can paint the very same timer at the size the layer was captured.
class RecTimerPainter extends CustomPainter {
  RecTimerPainter({
    required this.style,
    this.elapsed = Duration.zero,
    this.playTime,
  }) : super(repaint: playTime);

  /// The size the timer is laid out at before it is scaled.
  static const Size designSize = recTimerDesignSize;

  final InfoStickerStyle style;
  final Duration elapsed;
  final ValueListenable<Duration>? playTime;

  @override
  void paint(Canvas canvas, Size size) => paintRecTimer(
    canvas,
    size,
    style: style,
    elapsed: playTime?.value ?? elapsed,
  );

  @override
  bool shouldRepaint(RecTimerPainter oldDelegate) =>
      oldDelegate.style != style ||
      oldDelegate.elapsed != elapsed ||
      oldDelegate.playTime != playTime;
}
