// ABOUTME: Draws an info sticker in its style: a pill (solid, see-through,
// ABOUTME: glowing or outlined), a digital clock or an analog clock face.

import 'dart:math' as math;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/video_editor/info_sticker.dart';
import 'package:openvine/widgets/video_editor/info_sticker/info_sticker_format.dart';
import 'package:openvine/widgets/video_editor/info_sticker/rec_timer_painter.dart';
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
          _ => _Card(data: data, palette: _Palette.of(data.style)),
        },
      ),
    );
  }
}

/// Loads the fonts info stickers draw with, so the headless draft rasterizer
/// does not capture them in a fallback face.
///
/// Times out like the text layer fonts do; a font that did not load costs
/// its look, not the publish.
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

/// The colors of a pill style.
class _Palette {
  const _Palette({
    required this.ink,
    this.background,
    this.border,
    this.glow,
  });

  factory _Palette.of(InfoStickerStyle style) => switch (style) {
    InfoStickerStyle.dark => const _Palette(
      background: VineTheme.scrim65,
      ink: VineTheme.whiteText,
    ),
    InfoStickerStyle.glass => _Palette(
      background: VineTheme.whiteText.withValues(alpha: 0.24),
      border: VineTheme.whiteText.withValues(alpha: 0.5),
      ink: VineTheme.whiteText,
    ),
    InfoStickerStyle.brand => const _Palette(
      background: VineTheme.vineGreen,
      ink: VineTheme.onPrimary,
    ),
    InfoStickerStyle.highlight => const _Palette(
      background: VineTheme.accentYellow,
      ink: VineTheme.onPrimary,
    ),
    InfoStickerStyle.neon => const _Palette(
      ink: VineTheme.whiteText,
      glow: VineTheme.vineGreen,
    ),
    InfoStickerStyle.plain => const _Palette(ink: VineTheme.whiteText),
    InfoStickerStyle.outline => const _Palette(
      border: VineTheme.whiteText,
      ink: VineTheme.whiteText,
    ),
    _ => const _Palette(
      background: VineTheme.whiteText,
      ink: VineTheme.onPrimary,
    ),
  };

  final Color? background;
  final Color? border;
  final Color ink;

  /// The color the text glows in, for the neon look.
  final Color? glow;

  /// A glow for neon; otherwise, without an opaque background, a shadow so
  /// the ink reads on a light video.
  List<Shadow> get shadows => switch (glow) {
    final glow? => [
      Shadow(color: glow, blurRadius: 6),
      Shadow(color: glow, blurRadius: 18),
      Shadow(color: glow.withValues(alpha: 0.6), blurRadius: 36),
    ],
    null when background == null || background!.a < 1 => const [
      Shadow(color: VineTheme.scrim50, blurRadius: 12),
    ],
    null => const [],
  };
}

/// A pill holding one line: an emoji or a battery, then the text.
class _Card extends StatelessWidget {
  const _Card({required this.data, required this.palette});

  final InfoStickerData data;
  final _Palette palette;

  @override
  Widget build(BuildContext context) {
    final border = palette.border;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(999),
        border: border == null ? null : Border.all(color: border, width: 5),
      ),
      child: Padding(
        padding: const .symmetric(horizontal: 32, vertical: 16),
        child: _LineContent(data: data, palette: palette),
      ),
    );
  }
}

/// One line: an emoji or a battery, then the text.
class _LineContent extends StatelessWidget {
  const _LineContent({required this.data, required this.palette});

  final InfoStickerData data;
  final _Palette palette;

  @override
  Widget build(BuildContext context) {
    final style = VineTheme.titleLargeFont(
      color: palette.ink,
    ).copyWith(fontSize: 48, height: 1.15, shadows: palette.shadows);
    final emoji = InfoStickerFormat.emoji(data);
    final battery = data.batteryLevel;
    return Row(
      mainAxisSize: .min,
      spacing: 14,
      children: [
        if (emoji != null) Text(emoji, style: style),
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
///
/// It shows whole seconds, so it repaints when the second changes rather
/// than on every tick of the playhead.
class _RecTimer extends StatefulWidget {
  const _RecTimer({required this.style});

  final InfoStickerStyle style;

  @override
  State<_RecTimer> createState() => _RecTimerState();
}

class _RecTimerState extends State<_RecTimer> {
  ValueListenable<Duration>? _playTime;
  Duration _shown = Duration.zero;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final playTime = VideoEditorScope.maybeOf(context)?.playTimeNotifier;
    if (playTime == _playTime) return;
    _playTime?.removeListener(_onPlayTime);
    _playTime = playTime?..addListener(_onPlayTime);
    _shown = _wholeSeconds(playTime?.value);
  }

  @override
  void dispose() {
    _playTime?.removeListener(_onPlayTime);
    super.dispose();
  }

  void _onPlayTime() {
    final shown = _wholeSeconds(_playTime?.value);
    if (shown != _shown) setState(() => _shown = shown);
  }

  static Duration _wholeSeconds(Duration? time) =>
      Duration(seconds: time?.inSeconds ?? 0);

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: RecTimerPainter.designSize,
        painter: RecTimerPainter(style: widget.style, elapsed: _shown),
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
