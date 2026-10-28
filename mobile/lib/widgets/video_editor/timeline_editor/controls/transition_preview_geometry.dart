// ABOUTME: Geometry for the transition picker's previews of the clock and
// ABOUTME: diagonal wipes and the 3D flip and cube, mirroring the math
// ABOUTME: pro_video_editor's ClipTransitionEffects renders them with.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show ClipTransitionDirection, ClipTransitionType;

/// How far the camera is from a flip or cube, as a multiple of the side that
/// turns. `ClipTransitionEffects.turnDistance` natively.
const _turnDistance = 2.0;

/// How much a flip or cube darkens a face turned edge-on.
/// `ClipTransitionEffects.turnShade` natively.
const _turnShade = 0.4;

/// One face of a flip or cube in a preview: whether it shows the outgoing
/// clip, its corners (top left, top right, bottom right and bottom left of its
/// picture) and how much of its picture's brightness it keeps.
typedef TurnedPreviewFace = ({
  bool outgoing,
  List<Offset> corners,
  double shade,
});

/// The faces a [type] flip or cube shows at [progress] in a frame of [size],
/// farthest first; a face turned away or edge-on is left out.
///
/// A flip's card turns at most [maxFlipTurn] radians from facing the viewer,
/// so a preview frozen halfway still shows a picture where the export shows
/// the card edge-on.
List<TurnedPreviewFace> turnedPreviewFaces({
  required ClipTransitionType type,
  required ClipTransitionDirection direction,
  required Size size,
  required double progress,
  double maxFlipTurn = math.pi / 2,
}) {
  final horizontal =
      direction == ClipTransitionDirection.left ||
      direction == ClipTransitionDirection.right;
  // Left and up turn the far end (right or bottom edge) toward the viewer.
  final sign =
      direction == ClipTransitionDirection.right ||
          direction == ClipTransitionDirection.down
      ? -1.0
      : 1.0;
  final side = horizontal ? size.width : size.height;
  final across = horizontal ? size.height : size.width;
  final cube = type == ClipTransitionType.cube;
  // The faces turn about an axis this far behind the frame.
  final pivot = cube ? side / 2 : 0.0;
  final p = progress;
  final angles = cube
      ? [(true, math.pi / 2 * p), (false, math.pi / 2 * (p - 1))]
      : p < 0.5
      ? [(true, math.min(math.pi * p, maxFlipTurn))]
      : [(false, math.max(math.pi * (p - 1), -maxFlipTurn))];
  // Each corner along the turning side and across it, as offsets from the
  // middle: top left, top right, bottom right, bottom left.
  final offsets = horizontal
      ? [
          (-side / 2, -across / 2),
          (side / 2, -across / 2),
          (side / 2, across / 2),
          (-side / 2, across / 2),
        ]
      : [
          (-side / 2, -across / 2),
          (-side / 2, across / 2),
          (side / 2, across / 2),
          (side / 2, -across / 2),
        ];
  final turned = [
    for (final (_, angle) in angles)
      [
        for (final (along, cross) in offsets)
          (
            along * math.cos(angle) - sign * pivot * math.sin(angle),
            cross,
            sign * along * math.sin(angle) + pivot * math.cos(angle) - pivot,
          ),
      ],
  ];
  final nearest = math.max(
    turned
        .expand((corners) => corners)
        .map((corner) => corner.$3)
        .reduce(
          math.max,
        ),
    0.0,
  );
  final distance = _turnDistance * side;
  final faces = <(TurnedPreviewFace, double)>[];
  for (var i = 0; i < angles.length; i++) {
    final (outgoing, angle) = angles[i];
    final points = [
      for (final (along, cross, depth) in turned[i])
        () {
          final scale = distance / (distance - (depth - nearest));
          final a = side / 2 + along * scale;
          final b = across / 2 + cross * scale;
          return horizontal ? Offset(a, b) : Offset(b, a);
        }(),
    ];
    if (_shoelaceArea(points) <= 1e-3) continue;
    final depth =
        turned[i].map((corner) => corner.$3).reduce((a, b) => a + b) / 4;
    faces.add((
      (
        outgoing: outgoing,
        corners: points,
        shade: 1 - _turnShade * math.sin(angle).abs(),
      ),
      depth,
    ));
  }
  // Equally far, the outgoing face goes first, as natively.
  faces.sort((a, b) {
    if (a.$2 != b.$2) return a.$2.compareTo(b.$2);
    return a.$1.outgoing == b.$1.outgoing ? 0 : (a.$1.outgoing ? -1 : 1);
  });
  return [for (final (face, _) in faces) face];
}

/// The area of the quad [points], positive when they run clockwise on screen
/// as a face seen from the front does.
double _shoelaceArea(List<Offset> points) {
  var sum = 0.0;
  for (var i = 0; i < points.length; i++) {
    final a = points[i];
    final b = points[(i + 1) % points.length];
    sum += a.dx * b.dy - b.dx * a.dy;
  }
  return sum / 2;
}

/// The projective transform that draws a [size] picture onto the quad
/// [corners] (top left, top right, bottom right, bottom left).
Matrix4 quadTransform(Size size, List<Offset> corners) {
  final [c0, c1, c2, c3] = corners;
  final dx1 = c1.dx - c2.dx;
  final dx2 = c3.dx - c2.dx;
  final dy1 = c1.dy - c2.dy;
  final dy2 = c3.dy - c2.dy;
  final sx = c0.dx - c1.dx + c2.dx - c3.dx;
  final sy = c0.dy - c1.dy + c2.dy - c3.dy;
  final den = dx1 * dy2 - dx2 * dy1;
  final g = (sx * dy2 - dx2 * sy) / den;
  final h = (dx1 * sy - sx * dy1) / den;
  // The unit square onto the quad (Heckbert), after scaling the picture
  // down to that square.
  final a = (c1.dx - c0.dx + g * c1.dx) / size.width;
  final b = (c3.dx - c0.dx + h * c3.dx) / size.height;
  final d = (c1.dy - c0.dy + g * c1.dy) / size.width;
  final e = (c3.dy - c0.dy + h * c3.dy) / size.height;
  // Matrix4 takes its entries column by column.
  return Matrix4(
    a,
    d,
    0,
    g / size.width, //
    b,
    e,
    0,
    h / size.height, //
    0,
    0,
    1,
    0, //
    c0.dx,
    c0.dy,
    0,
    1,
  );
}

/// The part of a [size] frame a clock wipe has revealed at clamped progress
/// [progress]: a sector swept clockwise from twelve o'clock.
Path clockWipePath(Size size, double progress) {
  final center = size.center(Offset.zero);
  final radius = math.sqrt(
    size.width * size.width + size.height * size.height,
  );
  if (progress >= 1) return Path()..addRect(Offset.zero & size);
  return Path()
    ..moveTo(center.dx, center.dy)
    ..arcTo(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
    )
    ..close();
}

/// The part of a [size] frame a diagonal wipe toward the corner a quarter
/// turn clockwise from [direction] has revealed at clamped [progress]: the
/// frame on the near side of an edge parallel to its other diagonal.
Path diagonalWipePath(
  Size size,
  double progress,
  ClipTransitionDirection direction,
) {
  final (targetX, targetY) = switch (direction) {
    ClipTransitionDirection.left => (0.0, 0.0),
    ClipTransitionDirection.up => (1.0, 0.0),
    ClipTransitionDirection.right => (1.0, 1.0),
    ClipTransitionDirection.down => (0.0, 1.0),
  };
  // How far a point lies from the starting corner toward the target, from 0
  // there to 2 at the target.
  double along(Offset point) =>
      (targetX == 0 ? 1 - point.dx / size.width : point.dx / size.width) +
      (targetY == 0 ? 1 - point.dy / size.height : point.dy / size.height);
  final edge = 2 * progress.clamp(0.0, 1.0);
  final frame = [
    Offset.zero,
    Offset(size.width, 0),
    Offset(size.width, size.height),
    Offset(0, size.height),
  ];
  // The frame's corners on the revealed side, and where its sides cross the
  // edge.
  final revealed = <Offset>[];
  for (var i = 0; i < frame.length; i++) {
    final from = frame[i];
    final to = frame[(i + 1) % frame.length];
    final fromIn = along(from) <= edge;
    final toIn = along(to) <= edge;
    if (fromIn) revealed.add(from);
    if (fromIn != toIn) {
      final t = (edge - along(from)) / (along(to) - along(from));
      revealed.add(Offset.lerp(from, to, t)!);
    }
  }
  return revealed.isEmpty ? Path() : (Path()..addPolygon(revealed, true));
}
