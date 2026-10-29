// ABOUTME: Draws a REC timer sticker onto a canvas, for the editor's live
// ABOUTME: view and for the frames the export renders, alike.

import 'dart:math' as math;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:openvine/models/video_editor/info_sticker.dart';

/// The size a REC timer is laid out at before it is scaled.
const Size recTimerDesignSize = Size(460, 120);

/// How long a REC timer has been running, in seconds and hundredths such as
/// `03:42`: a video runs for a few seconds, so minutes would stay at zero.
String recTimerText(Duration elapsed) {
  final hundredths = elapsed.inMilliseconds ~/ 10;
  final seconds = (hundredths ~/ 100).toString().padLeft(2, '0');
  return '$seconds:${(hundredths % 100).toString().padLeft(2, '0')}';
}

/// Paints a REC timer in [style] showing [elapsed] into [size].
void paintRecTimer(
  Canvas canvas,
  Size size, {
  required InfoStickerStyle style,
  required Duration elapsed,
}) {
  const design = recTimerDesignSize;
  canvas
    ..save()
    ..scale(size.width / design.width, size.height / design.height);
  final panel = RRect.fromRectAndRadius(
    Offset.zero & design,
    const Radius.circular(28),
  );
  switch (style) {
    case InfoStickerStyle.dark:
      canvas.drawRRect(panel, Paint()..color = VineTheme.scrim65);
    case InfoStickerStyle.digital:
      canvas
        ..drawRRect(panel, Paint()..color = VineTheme.surfaceBackground)
        ..drawRRect(
          panel.deflate(2),
          Paint()
            ..color = VineTheme.vineGreenDark
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4,
        );
    default:
      break;
  }

  final ink = switch (style) {
    InfoStickerStyle.digital => VineTheme.vineGreen,
    InfoStickerStyle.film => VineTheme.accentOrange,
    _ => VineTheme.whiteText,
  };
  final shadows = switch (style) {
    InfoStickerStyle.digital || InfoStickerStyle.film => [
      Shadow(color: ink.withValues(alpha: 0.8), blurRadius: 16),
    ],
    _ => const [Shadow(color: VineTheme.scrim50, blurRadius: 10)],
  };
  final textStyle = VineTheme.codeFont(
    color: ink,
  ).copyWith(fontSize: 64, height: 1, letterSpacing: 2, shadows: shadows);
  final showsDot = style != InfoStickerStyle.film;
  final showsLabel =
      style == InfoStickerStyle.camcorder || style == InfoStickerStyle.dark;
  final label = showsLabel ? _layout('REC', textStyle) : null;
  final time = _layout(recTimerText(elapsed), textStyle);

  const dotRadius = 14.0;
  const gap = 18.0;
  final width =
      (showsDot ? dotRadius * 2 + gap : 0) +
      (label == null ? 0 : label.width + gap) +
      time.width;
  // Scaled down rather than cut off if a font runs wider than planned.
  final fit = math.min(1, (design.width - 48) / width).toDouble();
  canvas
    ..translate(design.width / 2, design.height / 2)
    ..scale(fit)
    ..translate(-width / 2, 0);
  var x = 0.0;
  if (showsDot) {
    canvas.drawCircle(
      Offset(x + dotRadius, 0),
      dotRadius,
      Paint()..color = VineTheme.likeRed,
    );
    x += dotRadius * 2 + gap;
  }
  if (label != null) {
    label.paint(canvas, Offset(x, -label.height / 2));
    x += label.width + gap;
  }
  time.paint(canvas, Offset(x, -time.height / 2));
  label?.dispose();
  time.dispose();
  canvas.restore();
}

TextPainter _layout(String text, TextStyle style) => TextPainter(
  text: TextSpan(text: text, style: style),
  textDirection: TextDirection.ltr,
  maxLines: 1,
)..layout();
