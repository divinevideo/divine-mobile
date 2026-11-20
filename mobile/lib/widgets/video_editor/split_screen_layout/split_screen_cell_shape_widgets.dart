// ABOUTME: Draws a split-screen cell that is not a plain rectangle: cuts it to
// ABOUTME: its shape, outlines it, and finds room inside it for a badge

import 'package:flutter/widgets.dart';
import 'package:openvine/models/video_editor/split_screen_layout.dart';

/// Cuts [child] to a cell's [shape], a rectangle's corners rounded by
/// [borderRadius]. Outside the shape the cell is neither drawn nor hit, so a
/// tap there reaches the cell underneath.
class SplitScreenCellClip extends StatelessWidget {
  const SplitScreenCellClip({
    required this.shape,
    required this.child,
    this.borderRadius = BorderRadius.zero,
    super.key,
  });

  final SplitScreenCellShape shape;
  final BorderRadius borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // One clip widget for every shape: switching between a rectangle and a
    // circle then keeps the subtree, a live video in it included, instead of
    // building it again.
    return ClipPath(
      clipper: _ShapeClipper(shape, borderRadius),
      child: child,
    );
  }
}

class _ShapeClipper extends CustomClipper<Path> {
  const _ShapeClipper(this.shape, this.borderRadius);

  final SplitScreenCellShape shape;
  final BorderRadius borderRadius;

  @override
  Path getClip(Size size) =>
      shape.pathIn(Offset.zero & size, borderRadius: borderRadius);

  @override
  bool shouldReclip(_ShapeClipper oldClipper) =>
      oldClipper.shape != shape || oldClipper.borderRadius != borderRadius;
}

/// A line [width] wide just inside a cell's [shape], such as the ring of the
/// selected cell.
class SplitScreenCellOutline extends StatelessWidget {
  const SplitScreenCellOutline({
    required this.shape,
    required this.color,
    required this.width,
    this.borderRadius = BorderRadius.zero,
    super.key,
  });

  final SplitScreenCellShape shape;
  final Color color;
  final double width;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _OutlinePainter(
          shape: shape,
          color: color,
          width: width,
          borderRadius: borderRadius,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _OutlinePainter extends CustomPainter {
  const _OutlinePainter({
    required this.shape,
    required this.color,
    required this.width,
    required this.borderRadius,
  });

  final SplitScreenCellShape shape;
  final Color color;
  final double width;
  final BorderRadius borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final path = shape.pathIn(Offset.zero & size, borderRadius: borderRadius);
    // A stroke centred on the edge, half of it clipped away, keeps the whole
    // line inside the cell the way a box border is.
    canvas
      ..save()
      ..clipPath(path)
      ..drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width * 2
          ..color = color,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_OutlinePainter oldDelegate) =>
      oldDelegate.shape != shape ||
      oldDelegate.color != color ||
      oldDelegate.width != width ||
      oldDelegate.borderRadius != borderRadius;
}

/// Where the top-left of a badge of [badge] size goes in a cell of [cell]
/// size: [inset] from its [corner] where that is wholly inside the cell's
/// [shape] and clear of [covered] — the outlines of the cells on top of it, in
/// the cell's own coordinates — and otherwise as little towards the middle
/// as it takes.
///
/// Also returns how far the badge had to move from the corner, for a caller
/// choosing between corners.
({Offset offset, double moved}) splitScreenBadgeOffset({
  required SplitScreenCellShape shape,
  required Size cell,
  required Size badge,
  required Alignment corner,
  List<Path> covered = const [],
  double inset = 6,
}) {
  final start = Offset(
    corner.x < 0 ? inset : cell.width - inset - badge.width,
    corner.y < 0 ? inset : cell.height - inset - badge.height,
  );
  if (shape.isRectangle && covered.isEmpty) {
    return (offset: start, moved: 0);
  }
  final outline = shape.pathIn(Offset.zero & cell);
  bool clear(Offset point) =>
      outline.contains(point) && !covered.any((above) => above.contains(point));
  final middle = Offset(
    (cell.width - badge.width) / 2,
    (cell.height - badge.height) / 2,
  );
  for (var step = 0; step <= _badgeSteps; step++) {
    final at = Offset.lerp(start, middle, step / _badgeSteps)!;
    final box = at & badge;
    if (clear(box.topLeft) &&
        clear(box.topRight) &&
        clear(box.bottomLeft) &&
        clear(box.bottomRight)) {
      return (offset: at, moved: (at - start).distance);
    }
  }
  return (offset: middle, moved: (middle - start).distance);
}

/// How many places between a corner and the middle a badge tries.
const _badgeSteps = 24;
