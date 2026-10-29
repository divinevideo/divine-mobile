// ABOUTME: Draws a sound credit sticker onto a canvas at one moment of the
// ABOUTME: video, for the editor's live view and the export's frames alike.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:openvine/models/video_editor/social_sticker.dart';
import 'package:openvine/utils/audio_band_energies.dart';
import 'package:openvine/widgets/video_editor/info_sticker/sticker_pill_palette.dart';
import 'package:openvine/widgets/video_editor/social_sticker/social_sticker_marks.dart';

/// How many bars the equalizer design has.
const int soundCreditEqualizerBars = 6;

/// What moves on a sound credit at one moment of the video: a record and a
/// cassette's reels turn with [time], a player's bar stands at [progress],
/// and an equalizer's bars follow [levels].
class SoundCreditMotion {
  const SoundCreditMotion({
    this.time = Duration.zero,
    this.progress = _restingProgress,
    this.levels,
  });

  /// How far into the video the moment is.
  final Duration time;

  /// How far through the video the moment is, from 0 to 1.
  final double progress;

  /// How loud each of [soundCreditEqualizerBars] bands of the sound is, from
  /// 0 to 1, or `null` for the bars at rest.
  final List<double>? levels;

  /// Where a player's bar stands when nothing plays, as in a sample.
  static const double _restingProgress = 0.36;
}

/// The size a sound credit for [data] is laid out at before it is scaled.
Size soundCreditSize(SocialStickerData data) {
  final layout = _SoundCreditLayout(data);
  final size = layout.size;
  layout.dispose();
  return size;
}

/// Paints the sound credit [data] describes into [size] as it looks at
/// [motion]; [overFrames], in its [StickerPillPalette.covering] colors.
void paintSoundCredit(
  Canvas canvas,
  Size size, {
  required SocialStickerData data,
  SoundCreditMotion motion = const SoundCreditMotion(),
  bool overFrames = false,
}) {
  final layout = _SoundCreditLayout(data, overFrames: overFrames);
  final design = layout.size;
  canvas
    ..save()
    ..scale(size.width / design.width, size.height / design.height);
  layout.paint(canvas, motion);
  canvas.restore();
  layout.dispose();
}

/// The levels of [soundCreditEqualizerBars] bars at [time] on the video in
/// [levels], rows of bar levels [audioBandFrameRate] a second, or `null`
/// without any.
List<double>? soundCreditLevelsAt(Float32List? levels, Duration time) {
  if (levels == null || levels.isEmpty) return null;
  const bars = soundCreditEqualizerBars;
  final rows = levels.length ~/ bars;
  final row = (time.inMicroseconds * audioBandFrameRate / 1e6).floor().clamp(
    0,
    rows - 1,
  );
  return levels.sublist(row * bars, row * bars + bars);
}

/// The levels of the equalizer's bars, rows of [soundCreditEqualizerBars]
/// levels a frame, for [energies], the sound's band energies.
Float32List soundCreditLevels(Float32List energies) =>
    audioVisualizerLevels(energies, bandCount: soundCreditEqualizerBars);

/// The turns a second of a record: 33⅓ a minute.
const double _recordTurnsPerSecond = 100 / 3 / 60;

/// The turns a second of a cassette's reels.
const double _reelTurnsPerSecond = 0.5;

const double _paddingX = 32;
const double _paddingY = 16;
const double _radius = 48;
const double _borderWidth = 5;
const double _symbolGap = 24;
const double _lineGap = 4;
const double _lyricGap = 8;
const double _maxTextWidth = 720;
const Size _noteSize = Size.square(56);
const Size _vinylSize = Size.square(112);
const Size _cassetteSize = Size(156, 104);
const Size _equalizerSize = Size(104, 96);
const double _playerMinWidth = 520;
const double _playerGap = 20;
const double _progressHeight = 24;
const double _controlsHeight = 56;

/// The heights of the equalizer's bars at rest, as a share of the whole.
const _restingLevels = [0.45, 0.85, 0.6, 1.0, 0.7, 0.38];

/// The lowest an equalizer's bar falls, so a silent band still shows.
const double _lowestLevel = 0.12;

/// A sound credit laid out at its own size: the pill, the symbol and the
/// lines of text, as [soundCreditSize] measures it and [paintSoundCredit]
/// draws it.
class _SoundCreditLayout {
  factory _SoundCreditLayout(
    SocialStickerData data, {
    bool overFrames = false,
  }) {
    final look = StickerPillPalette.of(data.style);
    final palette = overFrames ? look.covering : look;
    final detail = palette.textStyle(fontSize: 36);
    final lyric = data.lyric;
    final artist = data.soundArtist;
    return _SoundCreditLayout._(
      data: data,
      palette: palette,
      title: _text(data.soundTitle ?? '', palette.textStyle()),
      artist: artist == null
          ? null
          : _text(
              artist,
              detail.copyWith(color: palette.ink.withValues(alpha: 0.8)),
            ),
      lyric: lyric == null ? null : _text(lyric, detail, maxLines: 2),
    );
  }

  _SoundCreditLayout._({
    required this.data,
    required this.palette,
    required this.title,
    required this.artist,
    required this.lyric,
  });

  final SocialStickerData data;
  final StickerPillPalette palette;
  final TextPainter title;
  final TextPainter? artist;
  final TextPainter? lyric;

  bool get _isPlayer => data.soundDesign == SocialStickerSoundDesign.player;

  /// The size of the symbol in front of the text.
  Size get _symbolSize => switch (data.soundDesign) {
    SocialStickerSoundDesign.note => _noteSize,
    SocialStickerSoundDesign.cassette => _cassetteSize,
    SocialStickerSoundDesign.equalizer => _equalizerSize,
    SocialStickerSoundDesign.vinyl ||
    SocialStickerSoundDesign.player => _vinylSize,
  };

  Size get _linesSize {
    final artist = this.artist;
    final lyric = this.lyric;
    final width = [
      title.width,
      ?artist?.width,
      ?lyric?.width,
    ].reduce(math.max);
    final height =
        title.height +
        (artist == null ? 0 : _lineGap + artist.height) +
        (lyric == null ? 0 : _lineGap + _lyricGap + lyric.height);
    return Size(width, height);
  }

  /// The symbol and the lines of text side by side.
  Size get _rowSize {
    final symbol = _symbolSize;
    final lines = _linesSize;
    return Size(
      symbol.width + _symbolGap + lines.width,
      math.max(symbol.height, lines.height),
    );
  }

  Size get _contentSize {
    final row = _rowSize;
    if (!_isPlayer) return row;
    return Size(
      math.max(_playerMinWidth, row.width),
      row.height + _playerGap + _progressHeight + _playerGap + _controlsHeight,
    );
  }

  Size get size {
    final content = _contentSize;
    return Size(
      content.width + _paddingX * 2,
      content.height + _paddingY * 2,
    );
  }

  void paint(Canvas canvas, SoundCreditMotion motion) {
    final bounds = Offset.zero & size;
    final pill = RRect.fromRectAndRadius(
      bounds,
      const Radius.circular(_radius),
    );
    if (palette.background case final background?) {
      canvas.drawRRect(pill, Paint()..color = background);
    }
    if (palette.border case final border?) {
      canvas.drawRRect(
        pill.deflate(_borderWidth / 2),
        Paint()
          ..color = border
          ..style = PaintingStyle.stroke
          ..strokeWidth = _borderWidth,
      );
    }

    final content = const Offset(_paddingX, _paddingY) & _contentSize;
    final row = Offset(content.left, content.top) & _rowSize;
    _paintRow(canvas, row, motion);
    if (!_isPlayer) return;

    final progressTop = row.bottom + _playerGap;
    _paintProgress(
      canvas,
      Rect.fromLTWH(content.left, progressTop, content.width, _progressHeight),
      ink: palette.ink,
      progress: motion.progress.clamp(0.0, 1.0),
    );
    _paintControls(
      canvas,
      Rect.fromLTWH(
        content.left,
        progressTop + _progressHeight + _playerGap,
        content.width,
        _controlsHeight,
      ),
      ink: palette.ink,
    );
  }

  /// The symbol and, beside it, the title, artist and line of lyrics, both
  /// centred on the row.
  void _paintRow(Canvas canvas, Rect row, SoundCreditMotion motion) {
    final symbol = _symbolSize;
    final symbolRect = Rect.fromLTWH(
      row.left,
      row.center.dy - symbol.height / 2,
      symbol.width,
      symbol.height,
    );
    final seconds = motion.time.inMicroseconds / Duration.microsecondsPerSecond;
    switch (data.soundDesign) {
      case SocialStickerSoundDesign.note:
        paintSocialStickerMark(
          canvas,
          symbolRect,
          SocialStickerMark.note,
          ink: palette.ink,
          shadows: palette.shadows,
        );
      case SocialStickerSoundDesign.vinyl || SocialStickerSoundDesign.player:
        _paintVinyl(
          canvas,
          symbolRect,
          rim: palette.ink,
          turn: seconds * _recordTurnsPerSecond * 2 * math.pi,
        );
      case SocialStickerSoundDesign.cassette:
        _paintCassette(
          canvas,
          symbolRect,
          ink: palette.ink,
          turn: seconds * _reelTurnsPerSecond * 2 * math.pi,
        );
      case SocialStickerSoundDesign.equalizer:
        _paintEqualizer(
          canvas,
          symbolRect,
          ink: palette.ink,
          levels: motion.levels ?? _restingLevels,
        );
    }

    final lines = _linesSize;
    var y = row.center.dy - lines.height / 2;
    final x = symbolRect.right + _symbolGap;
    title.paint(canvas, Offset(x, y));
    y += title.height;
    final artist = this.artist;
    if (artist != null) {
      artist.paint(canvas, Offset(x, y + _lineGap));
      y += _lineGap + artist.height;
    }
    lyric?.paint(canvas, Offset(x, y + _lineGap + _lyricGap));
  }

  void dispose() {
    title.dispose();
    artist?.dispose();
    lyric?.dispose();
  }

  static TextPainter _text(String text, TextStyle style, {int maxLines = 1}) =>
      TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        maxLines: maxLines,
        ellipsis: '…',
      )..layout(maxWidth: _maxTextWidth);
}

/// A black vinyl record in [rect], turned by [turn] radians: grooves, a
/// Divine green label with a stripe that shows it turning, a light that
/// stays where it is, and a [rim] that keeps it apart from a dark pill.
void _paintVinyl(
  Canvas canvas,
  Rect rect, {
  required Color rim,
  required double turn,
}) {
  final center = rect.center;
  final radius = rect.shortestSide / 2;
  canvas.drawCircle(
    center,
    radius,
    Paint()..color = VineTheme.surfaceBackground,
  );
  final groove = Paint()
    ..color = VineTheme.whiteText.withValues(alpha: 0.18)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  for (final factor in const [0.86, 0.74, 0.62]) {
    canvas.drawCircle(center, radius * factor, groove);
  }
  // A light catching the grooves; it stays put while the record turns.
  canvas
    ..drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.8),
      -math.pi * 0.85,
      math.pi * 0.35,
      false,
      Paint()
        ..color = VineTheme.whiteText.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    )
    ..drawCircle(center, radius * 0.36, Paint()..color = VineTheme.vineGreen);
  // Lines of print on the label, which show the record turning.
  final print = Paint()
    ..color = VineTheme.onPrimary.withValues(alpha: 0.55)
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round;
  canvas
    ..save()
    ..translate(center.dx, center.dy)
    ..rotate(turn)
    ..drawLine(
      Offset(-radius * 0.2, -radius * 0.18),
      Offset(radius * 0.2, -radius * 0.18),
      print,
    )
    ..drawLine(
      Offset(-radius * 0.12, radius * 0.18),
      Offset(radius * 0.12, radius * 0.18),
      print,
    )
    ..restore()
    ..drawCircle(
      center,
      radius * 0.07,
      Paint()..color = VineTheme.surfaceBackground,
    )
    ..drawCircle(
      center,
      radius - 1.5,
      Paint()
        ..color = rim.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
}

/// A cassette tape in [ink] lines in [rect]: the shell, the label, two reels
/// turned by [turn] radians in their window, and the slot at the bottom.
void _paintCassette(
  Canvas canvas,
  Rect rect, {
  required Color ink,
  required double turn,
}) {
  final line = Paint()
    ..color = ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = 6
    ..strokeJoin = StrokeJoin.round;
  final body = rect.deflate(3);
  canvas.drawRRect(
    RRect.fromRectAndRadius(body, const Radius.circular(12)),
    line,
  );
  final label = Rect.fromLTRB(
    body.left + 16,
    body.top + 14,
    body.right - 16,
    body.top + body.height * 0.62,
  );
  line.strokeWidth = 4;
  canvas.drawRRect(
    RRect.fromRectAndRadius(label, const Radius.circular(6)),
    line,
  );
  final reelY = label.center.dy + 4;
  final reelRadius = label.height * 0.22;
  final hub = Paint()..color = ink;
  final spoke = Paint()
    ..color = ink
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round;
  for (final x in [
    label.left + label.width * 0.27,
    label.right - label.width * 0.27,
  ]) {
    final center = Offset(x, reelY);
    canvas
      ..drawCircle(center, reelRadius, line)
      ..drawCircle(center, reelRadius * 0.3, hub);
    for (var i = 0; i < 3; i++) {
      final angle = turn + i * 2 * math.pi / 3;
      final direction = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        center + direction * reelRadius * 0.3,
        center + direction * reelRadius * 0.75,
        spoke,
      );
    }
  }
  // The slot the tape runs past, wider at the shell's edge.
  canvas.drawPath(
    Path()
      ..moveTo(body.left + body.width * 0.22, body.bottom)
      ..lineTo(body.left + body.width * 0.3, body.bottom - 18)
      ..lineTo(body.right - body.width * 0.3, body.bottom - 18)
      ..lineTo(body.right - body.width * 0.22, body.bottom),
    line,
  );
}

/// Equalizer bars in [ink] in [rect], as high as [levels].
void _paintEqualizer(
  Canvas canvas,
  Rect rect, {
  required Color ink,
  required List<double> levels,
}) {
  final paint = Paint()..color = ink;
  final count = levels.length;
  final gap = rect.width / (count * 3 - 1);
  final barWidth = gap * 2;
  for (var i = 0; i < count; i++) {
    final level = levels[i].clamp(_lowestLevel, 1.0);
    final height = rect.height * level;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          rect.left + i * (barWidth + gap),
          rect.bottom - height,
          barWidth,
          height,
        ),
        Radius.circular(barWidth / 2),
      ),
      paint,
    );
  }
}

/// A player's progress bar in [ink] across [rect], [progress] of the way
/// through.
void _paintProgress(
  Canvas canvas,
  Rect rect, {
  required Color ink,
  required double progress,
}) {
  final y = rect.center.dy;
  final track = Paint()
    ..color = ink.withValues(alpha: 0.3)
    ..strokeWidth = 8
    ..strokeCap = StrokeCap.round;
  final knobX = rect.left + 4 + (rect.width - 8) * progress;
  canvas
    ..drawLine(Offset(rect.left + 4, y), Offset(rect.right - 4, y), track)
    ..drawLine(Offset(rect.left + 4, y), Offset(knobX, y), track..color = ink)
    ..drawCircle(Offset(knobX, y), rect.height / 2, Paint()..color = ink);
}

/// A player's buttons in [ink] across [rect]: back, pause and forward,
/// centred.
void _paintControls(Canvas canvas, Rect rect, {required Color ink}) {
  final paint = Paint()..color = ink;
  final h = rect.height;
  final center = rect.center;
  final spacing = h * 2.6;

  // Pause: two bars.
  final barWidth = h * 0.22;
  for (final x in [center.dx - barWidth * 1.4, center.dx + barWidth * 0.4]) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, rect.top, barWidth, h),
        Radius.circular(barWidth / 3),
      ),
      paint,
    );
  }
  _paintSkip(canvas, center.translate(-spacing, 0), h * 0.62, -1, paint);
  _paintSkip(canvas, center.translate(spacing, 0), h * 0.62, 1, paint);
}

/// A triangle against a bar, pointing back ([direction] -1) or forward (1).
void _paintSkip(
  Canvas canvas,
  Offset center,
  double height,
  int direction,
  Paint paint,
) {
  final half = height / 2;
  final tip = center.dx + direction * half;
  final base = center.dx - direction * half;
  final barEdge = tip + direction * height * 0.18;
  canvas
    ..drawPath(
      Path()
        ..moveTo(base, center.dy - half)
        ..lineTo(tip, center.dy)
        ..lineTo(base, center.dy + half)
        ..close(),
      paint,
    )
    ..drawRect(
      Rect.fromLTRB(
        math.min(tip, barEdge),
        center.dy - half,
        math.max(tip, barEdge),
        center.dy + half,
      ),
      paint,
    );
}
