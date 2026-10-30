// ABOUTME: The link and note marks social stickers draw beside their text, as
// ABOUTME: paths, so a phone's own emoji style never shows in or over a video.

import 'dart:typed_data';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/widgets.dart';

/// A mark a social sticker draws beside its text, where an emoji would look
/// different on every phone: in the editor, in the video and in the sharp
/// copy a viewer's player draws over it.
enum SocialStickerMark {
  /// The link sticker's chain, as `assets/icon/linkSimple.svg` draws it.
  link(
    'M8.44071 16.4436L16.4407 8.44364 '
    'C16.5802 8.30411 16.7459 8.19343 16.9282 8.11792 '
    'C17.1105 8.0424 17.3059 8.00354 17.5032 8.00354 '
    'C17.7005 8.00354 17.8959 8.0424 18.0782 8.11792 '
    'C18.2605 8.19343 18.4262 8.30411 18.5657 8.44364 '
    'C18.7052 8.58317 18.8159 8.74881 18.8914 8.93112 '
    'C18.9669 9.11342 19.0058 9.30881 19.0058 9.50614 '
    'C19.0058 9.70346 18.9669 9.89886 18.8914 10.0812 '
    'C18.8159 10.2635 18.7052 10.4291 18.5657 10.5686L10.5657 18.5686 '
    'C10.2839 18.8504 9.90173 19.0087 9.50321 19.0087 '
    'C9.1047 19.0087 8.7225 18.8504 8.44071 18.5686 '
    'C8.15892 18.2868 8.00061 17.9047 8.00061 17.5061 '
    'C8.00061 17.1076 8.15892 16.7254 8.44071 16.4436ZM24.8157 2.19364 '
    'C23.4078 0.788905 21.5002 0 19.5113 0 '
    'C17.5225 0 15.6149 0.788905 14.207 2.19364L10.442 5.95489 '
    'C10.1602 6.23668 10.0019 6.61887 10.0019 7.01739 '
    'C10.0019 7.21471 10.0407 7.41011 10.1162 7.59241 '
    'C10.1918 7.77471 10.3024 7.94036 10.442 8.07989 '
    'C10.5815 8.21942 10.7471 8.3301 10.9294 8.40561 '
    'C11.1117 8.48112 11.3071 8.51999 11.5045 8.51999 '
    'C11.903 8.51999 12.2852 8.36168 12.567 8.07989L16.3257 4.32239 '
    'C17.1698 3.47817 18.3146 3.00383 19.5084 3.00371 '
    'C20.7022 3.00359 21.8471 3.47771 22.6913 4.32176 '
    'C23.5356 5.16581 24.0099 6.31066 24.01 7.50445 '
    'C24.0101 8.69823 23.536 9.84317 22.692 10.6874L18.9282 14.4436 '
    'C18.7887 14.5832 18.678 14.7488 18.6025 14.9311 '
    'C18.527 15.1134 18.4881 15.3088 18.4881 15.5061 '
    'C18.4881 15.7035 18.527 15.8989 18.6025 16.0812 '
    'C18.678 16.2635 18.7887 16.4291 18.9282 16.5686 '
    'C19.0677 16.7082 19.2334 16.8188 19.4157 16.8944 '
    'C19.598 16.9699 19.7934 17.0087 19.9907 17.0087 '
    'C20.188 17.0087 20.3834 16.9699 20.5657 16.8944 '
    'C20.748 16.8188 20.9137 16.7082 21.0532 16.5686L24.8132 12.8111 '
    'C26.2187 11.4024 27.0077 9.49345 27.007 7.50349 '
    'C27.0063 5.51353 26.2159 3.60517 24.8095 2.19739L24.8157 2.19364Z '
    'M14.4432 18.9286L10.6845 22.6886 '
    'C10.2664 23.1066 9.77021 23.4381 9.22408 23.6642 '
    'C8.67795 23.8904 8.09262 24.0067 7.50152 24.0067 '
    'C6.91042 24.0066 6.32511 23.8901 5.77903 23.6639 '
    'C5.23294 23.4376 4.73677 23.106 4.31884 22.688 '
    'C3.47478 21.8438 3.00067 20.6989 3.00078 19.5051 '
    'C3.0009 18.3113 3.47524 17.1664 4.31946 16.3224L8.07696 12.5636 '
    'C8.21649 12.4241 8.32717 12.2585 8.40268 12.0762 '
    'C8.4782 11.8939 8.51706 11.6985 8.51706 11.5011 '
    'C8.51706 11.3038 8.4782 11.1084 8.40268 10.9261 '
    'C8.32717 10.7438 8.21649 10.5782 8.07696 10.4386 '
    'C7.93743 10.2991 7.77179 10.1884 7.58948 10.1129 '
    'C7.40718 10.0374 7.21179 9.99854 7.01446 9.99854 '
    'C6.81714 9.99854 6.62174 10.0374 6.43944 10.1129 '
    'C6.25714 10.1884 6.09149 10.2991 5.95196 10.4386L2.19696 14.2011 '
    'C1.50038 14.8978 0.947839 15.7248 0.570884 16.635 '
    'C0.193929 17.5452 -5.80236e-05 18.5208 1.30186e-08 19.506 '
    'C0.000117223 21.4956 0.790613 23.4037 2.19759 24.8105 '
    'C3.60456 26.2173 5.51276 27.0076 7.5024 27.0075 '
    'C9.49205 27.0074 11.4002 26.2169 12.807 24.8099L16.5645 21.0511 '
    'C16.8463 20.7693 17.0046 20.3872 17.0046 19.9886 '
    'C17.0046 19.5901 16.8463 19.2079 16.5645 18.9261 '
    'C16.2827 18.6443 15.9005 18.486 15.502 18.486 '
    'C15.1034 18.486 14.7213 18.6443 14.4395 18.9261L14.4432 18.9286Z',
    Offset(2.4965, 2.4962),
  ),

  /// The note sound credit's note, as `assets/icon/music_note.svg` draws it.
  note(
    'M19.1899 2.68041L10.4399 0.0554131 '
    'C10.2439 -0.00340803 10.0369 -0.0156037 9.83539 0.0197998 '
    'C9.63388 0.0552033 9.44344 0.137226 9.27927 0.259319 '
    'C9.1151 0.381412 8.98174 0.540194 8.88985 0.722991 '
    'C8.79795 0.905788 8.75006 1.10754 8.75001 1.31213V12.2737 '
    'C7.68561 11.5935 6.42508 11.2871 5.16723 11.4026 '
    'C3.90937 11.5182 2.72578 12.0492 1.80311 12.9119 '
    'C0.880451 13.7746 0.271228 14.9198 0.071533 16.1671 '
    'C-0.128162 17.4144 0.0930339 18.6926 0.700235 19.8003 '
    'C1.30744 20.9079 2.26609 21.7819 3.42499 22.2844 '
    'C4.58389 22.7869 5.87709 22.8893 7.10064 22.5754 '
    'C8.32418 22.2616 9.40842 21.5493 10.1824 20.5511 '
    'C10.9563 19.5528 11.3759 18.3253 11.375 17.0621V8.32635 '
    'L18.4352 10.4438C18.6311 10.5027 18.8381 10.5149 19.0396 10.4795 '
    'C19.2411 10.4441 19.4316 10.362 19.5957 10.2399 '
    'C19.7599 10.1179 19.8933 9.95907 19.9852 9.77627 '
    'C20.0771 9.59348 20.125 9.39173 20.125 9.18713V3.93713 '
    'C20.1249 3.65496 20.0339 3.38033 19.8655 3.15396 '
    'C19.697 2.92759 19.4601 2.76154 19.1899 2.68041ZM5.68751 20.1246 '
    'C5.0818 20.1246 4.4897 19.945 3.98607 19.6085 '
    'C3.48245 19.272 3.08992 18.7937 2.85813 18.2341 '
    'C2.62633 17.6745 2.56569 17.0587 2.68385 16.4647 '
    'C2.80202 15.8706 3.09369 15.3249 3.52199 14.8966 '
    'C3.95029 14.4683 4.49598 14.1766 5.09004 14.0585 '
    'C5.68411 13.9403 6.29988 14.001 6.85947 14.2327 '
    'C7.41907 14.4645 7.89737 14.8571 8.23388 15.3607 '
    'C8.57039 15.8643 8.75001 16.4564 8.75001 17.0621 '
    'C8.75001 17.8744 8.42735 18.6533 7.85302 19.2276 '
    'C7.27869 19.802 6.49973 20.1246 5.68751 20.1246ZM17.5 7.42291 '
    'L11.375 5.58541V3.07635L17.5 4.91385V7.42291Z',
    Offset(5.9375, 4.6231),
  );

  const SocialStickerMark(this._pathData, this._origin);

  /// The SVG path data, in absolute commands only.
  final String _pathData;

  /// Where the SVG places [_pathData] in its 32 by 32 box.
  final Offset _origin;

  /// The side of the box [path] is drawn in.
  static const double box = 32;

  static final Map<SocialStickerMark, Path> _paths = {};

  /// The mark in a [box] by [box] square.
  Path get path => _paths[this] ??= _pathFrom(_pathData).shift(_origin);
}

/// Paints [mark] into [rect] in [ink], over [shadows] as the sticker's text
/// casts them.
void paintSocialStickerMark(
  Canvas canvas,
  Rect rect,
  SocialStickerMark mark, {
  required Color ink,
  List<Shadow> shadows = const [],
}) {
  final scale = rect.shortestSide / SocialStickerMark.box;
  final left = rect.center.dx - SocialStickerMark.box * scale / 2;
  final top = rect.center.dy - SocialStickerMark.box * scale / 2;
  final path = mark.path.transform(
    Float64List.fromList([
      scale, 0, 0, 0, //
      0, scale, 0, 0,
      0, 0, 1, 0,
      left, top, 0, 1,
    ]),
  );
  for (final shadow in shadows) {
    canvas.drawPath(path.shift(shadow.offset), shadow.toPaint());
  }
  canvas.drawPath(path, Paint()..color = ink);
}

/// [mark] drawn [size] logical pixels square, as [paintSocialStickerMark]
/// paints it.
class SocialStickerMarkView extends StatelessWidget {
  const SocialStickerMarkView({
    required this.mark,
    required this.size,
    required this.ink,
    this.shadows = const [],
    super.key,
  });

  final SocialStickerMark mark;
  final double size;
  final Color ink;
  final List<Shadow> shadows;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _MarkPainter(mark: mark, ink: ink, shadows: shadows),
    );
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter({
    required this.mark,
    required this.ink,
    required this.shadows,
  });

  final SocialStickerMark mark;
  final Color ink;
  final List<Shadow> shadows;

  @override
  void paint(Canvas canvas, Size size) => paintSocialStickerMark(
    canvas,
    Offset.zero & size,
    mark,
    ink: ink,
    shadows: shadows,
  );

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) =>
      oldDelegate.mark != mark ||
      oldDelegate.ink != ink ||
      !listEquals(oldDelegate.shadows, shadows);
}

/// [data], SVG path data of absolute `M`, `L`, `H`, `V`, `C` and `Z`
/// commands, as a [Path].
Path _pathFrom(String data) {
  final tokens = RegExp(r'[MLHVCZ]|-?\d*\.?\d+(?:e-?\d+)?')
      .allMatches(data)
      .map((match) => match[0]!)
      .toList();
  final path = Path();
  var index = 0;
  var command = 'M';
  var current = Offset.zero;
  double next() => double.parse(tokens[index++]);
  while (index < tokens.length) {
    final token = tokens[index];
    if (RegExp('[MLHVCZ]').hasMatch(token)) {
      command = token;
      index++;
      if (command == 'Z') path.close();
      continue;
    }
    switch (command) {
      case 'M':
        current = Offset(next(), next());
        path.moveTo(current.dx, current.dy);
        // Further pairs after a move are lines.
        command = 'L';
      case 'L':
        current = Offset(next(), next());
        path.lineTo(current.dx, current.dy);
      case 'H':
        current = Offset(next(), current.dy);
        path.lineTo(current.dx, current.dy);
      case 'V':
        current = Offset(current.dx, next());
        path.lineTo(current.dx, current.dy);
      case 'C':
        final x1 = next();
        final y1 = next();
        final x2 = next();
        final y2 = next();
        current = Offset(next(), next());
        path.cubicTo(x1, y1, x2, y2, current.dx, current.dy);
      default:
        throw FormatException('Unsupported path command $command', data);
    }
  }
  return path;
}
