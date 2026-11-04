// ABOUTME: Draws an info sticker in its style: a pill (solid, see-through,
// ABOUTME: glowing or outlined), a digital clock or an analog clock face.

import 'dart:async';
import 'dart:math' as math;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/video_editor/info_sticker.dart';
import 'package:openvine/widgets/video_editor/info_sticker/info_sticker_emoji.dart';
import 'package:openvine/widgets/video_editor/info_sticker/info_sticker_format.dart';
import 'package:openvine/widgets/video_editor/info_sticker/rec_timer_painter.dart';
import 'package:openvine/widgets/video_editor/info_sticker/sticker_pill_palette.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';

/// An info sticker as it shows on the video.
///
/// Lays out at its own size; the editor's widget layer scales it to the
/// layer's width with a `FittedBox`.
class InfoStickerView extends StatelessWidget {
  const InfoStickerView({required this.data, super.key});

  final InfoStickerData data;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: InfoStickerFormat.semanticLabel(data),
      excludeSemantics: true,
      // The headless draft rasterizer mounts the sticker without a Material
      // above it, whose fallback text style underlines everything in yellow.
      child: DefaultTextStyle(
        style: VineTheme.bodyMediumFont(color: VineTheme.whiteText),
        child: switch (data.style) {
          _ when data.kind == InfoStickerKind.recTimer => _RecTimer(
            style: data.style,
          ),
          InfoStickerStyle.analog => _AnalogClock(time: data.dateTime),
          InfoStickerStyle.digital => _DigitalClock(
            text: InfoStickerFormat.text(data),
          ),
          InfoStickerStyle.film => _FilmStamp(
            text: InfoStickerFormat.text(data),
          ),
          InfoStickerStyle.camcorder => _Camcorder(
            text: InfoStickerFormat.upperCase(
              data,
              InfoStickerFormat.text(data),
            ),
          ),
          _ => Builder(
            builder: (context) {
              final palette = StickerPillPalette.of(data.style);
              return StickerPill(
                palette: palette,
                child: _LineContent(data: data, palette: palette),
              );
            },
          ),
        },
      ),
    );
  }
}

/// Loads the fonts and the emoji [stickers] draw with, so the headless draft
/// rasterizer does not capture them in a fallback face or without their
/// emoji.
///
/// Times out like the text layer fonts do; a font that did not load costs
/// its look, not the publish, and an emoji that did not load costs itself.
Future<void> preloadInfoStickerContent(Iterable<InfoStickerData> stickers) {
  if (stickers.isEmpty) return Future.value();
  return Future.wait([
    preloadInfoStickerFonts(),
    for (final emoji in {
      for (final data in stickers) ...InfoStickerFormat.emojis(data),
    })
      _precacheEmoji(emoji),
  ]);
}

/// Loads the fonts info and social stickers draw with; see
/// [preloadInfoStickerContent].
Future<void> preloadInfoStickerFonts() async {
  // Each call registers its face with google_fonts; the color only fills the
  // style these calls return and throw away.
  VineTheme.titleLargeFont(color: VineTheme.whiteText);
  VineTheme.codeFont(color: VineTheme.whiteText);
  await GoogleFonts.pendingFonts()
      .timeout(
        VideoEditorConstants.textFontLoadTimeout,
        onTimeout: () => const [],
      )
      .catchError((_) => const <void>[]);
}

/// Puts [emoji] into the image cache, so a sticker mounted afterwards draws
/// it in its first frame. Completes on an error too.
Future<void> _precacheEmoji(InfoStickerEmoji emoji) {
  final completer = Completer<void>();
  final stream = AssetImage(emoji.assetPath).resolve(ImageConfiguration.empty);
  late final ImageStreamListener listener;
  void finish() {
    stream.removeListener(listener);
    if (!completer.isCompleted) completer.complete();
  }

  listener = ImageStreamListener(
    (_, _) => finish(),
    onError: (_, _) => finish(),
  );
  stream.addListener(listener);
  return completer.future;
}

/// One line: an emoji, a flag or a battery, then the text; or, for the sun,
/// each time after its emoji.
class _LineContent extends StatelessWidget {
  const _LineContent({required this.data, required this.palette});

  final InfoStickerData data;
  final StickerPillPalette palette;

  /// How large an emoji is next to the text, as large as an emoji glyph of
  /// the text's size.
  static const double _emojiSize = 56;

  @override
  Widget build(BuildContext context) {
    final style = palette.textStyle();
    if (data.kind == InfoStickerKind.sun) {
      return Row(
        mainAxisSize: .min,
        spacing: 28,
        children: [
          for (final (emoji, time) in InfoStickerFormat.sunTimes(data))
            Row(
              mainAxisSize: .min,
              spacing: 14,
              children: [
                InfoStickerEmojiImage(emoji, size: _emojiSize),
                Text(time, style: style, maxLines: 1),
              ],
            ),
        ],
      );
    }
    final flag =
        data.kind == InfoStickerKind.location &&
            data.placeSymbol == InfoStickerPlaceSymbol.flag
        ? InfoStickerFormat.flag(data.countryCode)
        : null;
    final emoji = InfoStickerFormat.emoji(data);
    final battery = data.batteryLevel;
    return Row(
      mainAxisSize: .min,
      spacing: 14,
      children: [
        if (flag != null)
          Text(flag, style: style)
        else if (emoji != null)
          InfoStickerEmojiImage(emoji, size: _emojiSize),
        if (data.kind == InfoStickerKind.battery && battery != null)
          _BatteryGlyph(level: battery, color: palette.ink),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Text(
            InfoStickerFormat.text(data),
            style: style,
            maxLines: 1,
            overflow: .ellipsis,
          ),
        ),
      ],
    );
  }
}

/// A battery outline filled up to [level] percent.
class _BatteryGlyph extends StatelessWidget {
  const _BatteryGlyph({required this.level, required this.color});

  final int level;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(84, 42),
      painter: _BatteryPainter(level: level, color: color),
    );
  }
}

class _BatteryPainter extends CustomPainter {
  const _BatteryPainter({required this.level, required this.color});

  final int level;
  final Color color;

  static const double _stroke = 5;
  static const double _capWidth = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final body = Rect.fromLTWH(
      _stroke / 2,
      _stroke / 2,
      size.width - _capWidth - _stroke,
      size.height - _stroke,
    );
    final outline = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke;
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(9)),
      outline,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          body.right + _stroke / 2,
          size.height * 0.32,
          _capWidth,
          size.height * 0.36,
        ),
        const Radius.circular(3),
      ),
      Paint()..color = color,
    );
    final inner = body.deflate(_stroke + 2);
    final fill = Rect.fromLTWH(
      inner.left,
      inner.top,
      // A sliver stays visible at 1 %, the way a phone's own icon shows it.
      math.max(inner.width * level.clamp(0, 100) / 100, _stroke / 2),
      inner.height,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(fill, const Radius.circular(4)),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_BatteryPainter oldDelegate) =>
      oldDelegate.level != level || oldDelegate.color != color;
}

/// Green digits on a dark panel, glowing like an LED clock.
class _DigitalClock extends StatelessWidget {
  const _DigitalClock({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: VineTheme.surfaceBackground,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: VineTheme.vineGreenDark, width: 4),
      ),
      child: Padding(
        padding: const .symmetric(horizontal: 36, vertical: 14),
        child: Text(
          text,
          maxLines: 1,
          style: VineTheme.codeFont(color: VineTheme.vineGreen).copyWith(
            fontSize: 72,
            height: 1.1,
            letterSpacing: 2,
            shadows: [
              Shadow(
                color: VineTheme.vineGreen.withValues(alpha: 0.8),
                blurRadius: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A REC timer running with the playhead in the editor; at rest, at 00:00,
/// anywhere else.
class _RecTimer extends StatelessWidget {
  const _RecTimer({required this.style});

  final InfoStickerStyle style;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: RecTimerPainter.designSize,
        painter: RecTimerPainter(
          style: style,
          playTime: VideoEditorScope.maybeOf(context)?.playTimeNotifier,
        ),
      ),
    );
  }
}

/// Glowing orange digits, like the date a film camera prints on a photo.
class _FilmStamp extends StatelessWidget {
  const _FilmStamp({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      style: VineTheme.codeFont(color: VineTheme.accentOrange).copyWith(
        fontSize: 64,
        height: 1.1,
        letterSpacing: 4,
        shadows: [
          Shadow(
            color: VineTheme.accentOrange.withValues(alpha: 0.8),
            blurRadius: 14,
          ),
        ],
      ),
    );
  }
}

/// A camcorder's viewfinder: a red recording dot, REC, then [text], which
/// comes in capitals.
class _Camcorder extends StatelessWidget {
  const _Camcorder({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final style = VineTheme.codeFont(color: VineTheme.whiteText).copyWith(
      fontSize: 56,
      height: 1.1,
      letterSpacing: 2,
      shadows: const [Shadow(color: VineTheme.scrim50, blurRadius: 10)],
    );
    return Row(
      mainAxisSize: .min,
      spacing: 18,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            color: VineTheme.likeRed,
            shape: BoxShape.circle,
          ),
          child: SizedBox.square(dimension: 26),
        ),
        Text('REC', style: style),
        Text(text, style: style, maxLines: 1),
      ],
    );
  }
}

/// A white clock face with hands at [time].
class _AnalogClock extends StatelessWidget {
  const _AnalogClock({required this.time});

  final DateTime? time;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size.square(240),
      painter: _ClockPainter(time: time),
    );
  }
}

class _ClockPainter extends CustomPainter {
  const _ClockPainter({required this.time});

  final DateTime? time;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    canvas
      ..drawCircle(center, radius, Paint()..color = VineTheme.whiteText)
      ..drawCircle(
        center,
        radius - 4,
        Paint()
          ..color = VineTheme.onPrimary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8,
      );

    final tick = Paint()
      ..color = VineTheme.onPrimary
      ..strokeCap = StrokeCap.round;
    for (var hour = 0; hour < 12; hour++) {
      final angle = hour * math.pi / 6;
      final isQuarter = hour % 3 == 0;
      final direction = Offset(math.sin(angle), -math.cos(angle));
      canvas.drawLine(
        center + direction * (radius - 22),
        center + direction * (radius - (isQuarter ? 46 : 34)),
        tick..strokeWidth = isQuarter ? 9 : 5,
      );
    }

    final time = this.time;
    if (time != null) {
      final minutes = time.minute;
      final hours = time.hour % 12 + minutes / 60;
      _hand(canvas, center, hours * math.pi / 6, radius * 0.5, 14);
      _hand(canvas, center, minutes * math.pi / 30, radius * 0.74, 9);
    }
    // A dark cap the hands grow out of, with a small pin in it.
    canvas
      ..drawCircle(center, 13, Paint()..color = VineTheme.onPrimary)
      ..drawCircle(center, 4, Paint()..color = VineTheme.whiteText);
  }

  void _hand(
    Canvas canvas,
    Offset center,
    double angle,
    double length,
    double width,
  ) {
    canvas.drawLine(
      center,
      center + Offset(math.sin(angle), -math.cos(angle)) * length,
      Paint()
        ..color = VineTheme.onPrimary
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ClockPainter oldDelegate) => oldDelegate.time != time;
}
