// ABOUTME: The split-screen layouts the editor offers and the geometry behind
// ABOUTME: them — where each cell sits in the frame, its shape, what it shows

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// A way to split the frame into cells, each of which shows one clip.
///
/// The layout is rendered into a single clip once it is placed, so a preset
/// decides for good where each clip sits in that clip's frame.
enum SplitScreenLayoutPreset {
  /// Two clips side by side, each half the width.
  sideBySide,

  /// Two clips on top of each other, each half the height.
  stacked,

  /// Two clips side by side, split by a line that leans to the right.
  slantedSideBySide,

  /// Two clips on top of each other, split by a line that rises to the
  /// right.
  slantedStacked,

  /// Three clips side by side in columns.
  threeColumns,

  /// Three clips stacked in rows. On a vertical video each row comes out
  /// close to 16:9, which is what landscape footage wants.
  threeStacked,

  /// Three clips stacked in rows split by two parallel lines that rise to
  /// the right.
  slantedThreeStacked,

  /// One clip across the top half, two side by side underneath.
  oneOverTwo,

  /// Two clips side by side in the top half, one across the bottom.
  twoOverOne,

  /// One clip down the left half, two stacked on the right.
  oneBesideTwo,

  /// Two clips stacked on the left, one down the right half.
  twoBesideOne,

  /// Four clips in a 2×2 grid.
  grid,

  /// Four clips side by side in narrow columns.
  fourColumns,

  /// Four clips stacked in rows, like a film strip.
  fourStacked,

  /// One clip across the top two thirds, three in a row underneath. On a
  /// vertical video each of the three comes out 9:16, the shape of a
  /// vertical clip.
  oneOverThree,

  /// Three clips in a row across the top third, one across the bottom two
  /// thirds.
  threeOverOne,

  /// One clip down the left two thirds, three stacked on the right. On a
  /// vertical video each of the three comes out 9:16.
  oneBesideThree,

  /// Three clips stacked on the left third, one down the right two thirds.
  threeBesideOne,

  /// One clip filling the frame with a small one over its top-left corner.
  pictureInPictureTopLeft,

  /// One clip filling the frame with a small one over its top-right corner.
  pictureInPictureTopRight,

  /// One clip filling the frame with a small one over its bottom-left corner.
  pictureInPictureBottomLeft,

  /// One clip filling the frame with a small one over its bottom-right
  /// corner.
  pictureInPictureBottomRight,

  /// One clip filling the frame with a round one over its top-left corner.
  circleTopLeft,

  /// One clip filling the frame with a round one over its top-right corner.
  circleTopRight,

  /// One clip filling the frame with a round one over its bottom-left
  /// corner.
  circleBottomLeft,

  /// One clip filling the frame with a round one over its bottom-right
  /// corner.
  circleBottomRight,

  /// One clip filling the frame with two round ones along its bottom.
  twoCircles,

  /// One clip filling the frame with three round ones along its bottom.
  threeCircles;

  /// How many clips the layout holds.
  int get cellCount => switch (this) {
    sideBySide ||
    stacked ||
    slantedSideBySide ||
    slantedStacked ||
    pictureInPictureTopLeft ||
    pictureInPictureTopRight ||
    pictureInPictureBottomLeft ||
    pictureInPictureBottomRight ||
    circleTopLeft ||
    circleTopRight ||
    circleBottomLeft ||
    circleBottomRight => 2,
    threeColumns ||
    threeStacked ||
    slantedThreeStacked ||
    oneOverTwo ||
    twoOverOne ||
    oneBesideTwo ||
    twoBesideOne ||
    twoCircles => 3,
    grid ||
    fourColumns ||
    fourStacked ||
    oneOverThree ||
    threeOverOne ||
    oneBesideThree ||
    threeBesideOne ||
    threeCircles => 4,
  };

  /// The corner a picture-in-picture window sits in, or `null` for a layout
  /// without one.
  Alignment? get _pictureInPictureCorner => switch (this) {
    pictureInPictureTopLeft => Alignment.topLeft,
    pictureInPictureTopRight => Alignment.topRight,
    pictureInPictureBottomLeft => Alignment.bottomLeft,
    pictureInPictureBottomRight => Alignment.bottomRight,
    _ => null,
  };

  /// The corner a round window sits in, or `null` for a layout without one.
  Alignment? get _circleCorner => switch (this) {
    circleTopLeft => Alignment.topLeft,
    circleTopRight => Alignment.topRight,
    circleBottomLeft => Alignment.bottomLeft,
    circleBottomRight => Alignment.bottomRight,
    _ => null,
  };

  /// How many round windows sit in a row along the bottom.
  int get _circleRow => switch (this) {
    twoCircles => 2,
    threeCircles => 3,
    _ => 0,
  };

  /// The slanted split, or `null` for a layout without one: whether its
  /// cells are stacked in rows or stand side by side, and how many there are.
  ({bool rows, int parts})? get _slant => switch (this) {
    slantedSideBySide => (rows: false, parts: 2),
    slantedStacked => (rows: true, parts: 2),
    slantedThreeStacked => (rows: true, parts: 3),
    _ => null,
  };

  /// The grid cells as fractions of the frame, before any gap, in the order
  /// they are filled and stacked. A window over a clip is not a grid cell and
  /// is added on top of these by [cells]; a slanted split has none.
  List<Rect> get _unitCells => switch (this) {
    sideBySide => const [
      Rect.fromLTRB(0, 0, 0.5, 1),
      Rect.fromLTRB(0.5, 0, 1, 1),
    ],
    stacked => const [Rect.fromLTRB(0, 0, 1, 0.5), Rect.fromLTRB(0, 0.5, 1, 1)],
    threeColumns => const [
      Rect.fromLTRB(0, 0, 1 / 3, 1),
      Rect.fromLTRB(1 / 3, 0, 2 / 3, 1),
      Rect.fromLTRB(2 / 3, 0, 1, 1),
    ],
    threeStacked => const [
      Rect.fromLTRB(0, 0, 1, 1 / 3),
      Rect.fromLTRB(0, 1 / 3, 1, 2 / 3),
      Rect.fromLTRB(0, 2 / 3, 1, 1),
    ],
    oneOverTwo => const [
      Rect.fromLTRB(0, 0, 1, 0.5),
      Rect.fromLTRB(0, 0.5, 0.5, 1),
      Rect.fromLTRB(0.5, 0.5, 1, 1),
    ],
    twoOverOne => const [
      Rect.fromLTRB(0, 0, 0.5, 0.5),
      Rect.fromLTRB(0.5, 0, 1, 0.5),
      Rect.fromLTRB(0, 0.5, 1, 1),
    ],
    oneBesideTwo => const [
      Rect.fromLTRB(0, 0, 0.5, 1),
      Rect.fromLTRB(0.5, 0, 1, 0.5),
      Rect.fromLTRB(0.5, 0.5, 1, 1),
    ],
    twoBesideOne => const [
      Rect.fromLTRB(0, 0, 0.5, 0.5),
      Rect.fromLTRB(0, 0.5, 0.5, 1),
      Rect.fromLTRB(0.5, 0, 1, 1),
    ],
    grid => const [
      Rect.fromLTRB(0, 0, 0.5, 0.5),
      Rect.fromLTRB(0.5, 0, 1, 0.5),
      Rect.fromLTRB(0, 0.5, 0.5, 1),
      Rect.fromLTRB(0.5, 0.5, 1, 1),
    ],
    fourColumns => const [
      Rect.fromLTRB(0, 0, 0.25, 1),
      Rect.fromLTRB(0.25, 0, 0.5, 1),
      Rect.fromLTRB(0.5, 0, 0.75, 1),
      Rect.fromLTRB(0.75, 0, 1, 1),
    ],
    fourStacked => const [
      Rect.fromLTRB(0, 0, 1, 0.25),
      Rect.fromLTRB(0, 0.25, 1, 0.5),
      Rect.fromLTRB(0, 0.5, 1, 0.75),
      Rect.fromLTRB(0, 0.75, 1, 1),
    ],
    oneOverThree => const [
      Rect.fromLTRB(0, 0, 1, 2 / 3),
      Rect.fromLTRB(0, 2 / 3, 1 / 3, 1),
      Rect.fromLTRB(1 / 3, 2 / 3, 2 / 3, 1),
      Rect.fromLTRB(2 / 3, 2 / 3, 1, 1),
    ],
    threeOverOne => const [
      Rect.fromLTRB(0, 0, 1 / 3, 1 / 3),
      Rect.fromLTRB(1 / 3, 0, 2 / 3, 1 / 3),
      Rect.fromLTRB(2 / 3, 0, 1, 1 / 3),
      Rect.fromLTRB(0, 1 / 3, 1, 1),
    ],
    oneBesideThree => const [
      Rect.fromLTRB(0, 0, 2 / 3, 1),
      Rect.fromLTRB(2 / 3, 0, 1, 1 / 3),
      Rect.fromLTRB(2 / 3, 1 / 3, 1, 2 / 3),
      Rect.fromLTRB(2 / 3, 2 / 3, 1, 1),
    ],
    threeBesideOne => const [
      Rect.fromLTRB(0, 0, 1 / 3, 1 / 3),
      Rect.fromLTRB(0, 1 / 3, 1 / 3, 2 / 3),
      Rect.fromLTRB(0, 2 / 3, 1 / 3, 1),
      Rect.fromLTRB(1 / 3, 0, 1, 1),
    ],
    pictureInPictureTopLeft ||
    pictureInPictureTopRight ||
    pictureInPictureBottomLeft ||
    pictureInPictureBottomRight ||
    circleTopLeft ||
    circleTopRight ||
    circleBottomLeft ||
    circleBottomRight ||
    twoCircles ||
    threeCircles => const [Rect.fromLTRB(0, 0, 1, 1)],
    slantedSideBySide || slantedStacked || slantedThreeStacked => const [],
  };

  /// Where each cell sits in a frame of [aspectRatio] (width / height), as
  /// fractions of the frame's width and height — see [cells].
  ///
  /// A cell that is not a rectangle is given by the rect around it.
  List<Rect> cellRects({required double aspectRatio, required double gap}) => [
    for (final cell in cells(aspectRatio: aspectRatio, gap: gap)) cell.rect,
  ];

  /// The shape of each cell in its rect of [cellRects] — see [cells].
  List<SplitScreenCellShape> cellShapes({
    required double aspectRatio,
    required double gap,
  }) => [
    for (final cell in cells(aspectRatio: aspectRatio, gap: gap)) cell.shape,
  ];

  /// Every cell of the layout in a frame of [aspectRatio] (width / height):
  /// where it sits, as fractions of the frame's width and height, and its
  /// shape within that rect. Cells are listed in the order they are filled
  /// and stacked.
  ///
  /// [gap] is the space between two cells and between a cell and the frame's
  /// edge, as a fraction of the frame's shorter side, so it is equally thick
  /// horizontally and vertically whatever shape the frame is. Across a
  /// slanted split it is measured square to the line.
  ///
  /// The picture-in-picture window keeps the frame's own shape: it is a
  /// smaller copy of the frame rather than a cell of the grid, and has no
  /// gap to share with the clip under it — its margin to the edges grows with
  /// [gap] instead. A round window is cut out of the clip under it with a
  /// ring [gap] wide, so it sits in a border like every other cell.
  List<SplitScreenCellGeometry> cells({
    required double aspectRatio,
    required double gap,
  }) {
    final frame = Size(aspectRatio, 1);
    final spacing =
        gap.clamp(0.0, SplitScreenLayoutGeometry.maxGap) * frame.shortestSide;

    final slant = _slant;
    final cells = slant != null
        ? _slantedCells(frame, spacing, rows: slant.rows, parts: slant.parts)
        : _gridCells(frame, spacing);
    return [
      for (final cell in cells)
        (
          rect: Rect.fromLTRB(
            cell.rect.left / frame.width,
            cell.rect.top / frame.height,
            cell.rect.right / frame.width,
            cell.rect.bottom / frame.height,
          ),
          // A shape is given in fractions of its own rect, so it survives the
          // step from frame units to fractions of the frame as it is.
          shape: cell.shape,
        ),
    ];
  }

  /// The grid cells and any window over them, in frame units.
  List<SplitScreenCellGeometry> _gridCells(Size frame, double spacing) {
    final grid = [for (final unit in _unitCells) _inset(unit, frame, spacing)];
    final pictureInPicture = _pictureInPictureCorner;
    if (pictureInPicture != null) {
      return [
        for (final rect in grid) (rect: rect, shape: .rectangle),
        (
          rect: _pictureInPictureWindow(frame, spacing, pictureInPicture),
          shape: .rectangle,
        ),
      ];
    }
    final circleCorner = _circleCorner;
    final circles = circleCorner != null
        ? [_circleWindow(frame, spacing, circleCorner)]
        : _circleRowWindows(frame, spacing, _circleRow);
    if (circles.isEmpty) {
      return [for (final rect in grid) (rect: rect, shape: .rectangle)];
    }
    final [under] = grid;
    return [
      (
        rect: under,
        shape: spacing <= 0
            ? SplitScreenCellShape.rectangle
            : SplitScreenCellShape.withHoles([
                for (final circle in circles)
                  _fractionOf(circle.inflate(spacing), under),
              ]),
      ),
      for (final circle in circles) (rect: circle, shape: .oval),
    ];
  }

  /// [rect] as fractions of [outer], both in the same units.
  static Rect _fractionOf(Rect rect, Rect outer) => Rect.fromLTRB(
    (rect.left - outer.left) / outer.width,
    (rect.top - outer.top) / outer.height,
    (rect.right - outer.left) / outer.width,
    (rect.bottom - outer.top) / outer.height,
  );

  /// The cells of a slanted split in frame units: [parts] rows when [rows],
  /// else [parts] columns, each divider crossing the frame at a slope of
  /// [SplitScreenLayoutGeometry.slant].
  static List<SplitScreenCellGeometry> _slantedCells(
    Size frame,
    double spacing, {
    required bool rows,
    required int parts,
  }) {
    final inner = [
      Offset(spacing, spacing),
      Offset(frame.width - spacing, spacing),
      Offset(frame.width - spacing, frame.height - spacing),
      Offset(spacing, frame.height - spacing),
    ];
    // The length being split, and how far a divider drifts along it from one
    // side of the frame to the other.
    final along = rows ? frame.height : frame.width;
    final drift = SplitScreenLayoutGeometry.slant * along;
    // Square to every divider, pointing to the next cell. A row divider rises
    // to the right; a column divider leans right towards the top.
    final normal = rows
        ? Offset(drift, frame.width)
        : Offset(frame.height, drift);
    final unit = normal / normal.distance;
    double dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;
    // Where divider [index] crosses the middle of the frame: halfway across
    // the gap between two cells, as [_inset] places a straight one.
    Offset through(int index) {
      final level = index / parts * (along - spacing) + spacing / 2;
      return rows
          ? Offset(frame.width / 2, level)
          : Offset(level, frame.height / 2);
    }

    return [
      for (var part = 0; part < parts; part++)
        _polygonCell(
          _keepBelow(
            _keepBelow(
              inner,
              -unit,
              part == 0
                  ? double.infinity
                  : -dot(unit, through(part)) - spacing / 2,
            ),
            unit,
            part == parts - 1
                ? double.infinity
                : dot(unit, through(part + 1)) - spacing / 2,
          ),
        ),
    ];
  }

  /// The part of the convex [polygon] where `normal · point <= limit`.
  static List<Offset> _keepBelow(
    List<Offset> polygon,
    Offset normal,
    double limit,
  ) {
    if (limit == double.infinity) return polygon;
    double distance(Offset point) =>
        normal.dx * point.dx + normal.dy * point.dy - limit;
    return [
      for (final (index, from) in polygon.indexed) ...[
        if (distance(from) <= 0) from,
        if (polygon[(index + 1) % polygon.length] case final to
            when (distance(from) < 0) != (distance(to) < 0) &&
                distance(from) != 0 &&
                distance(to) != 0)
          Offset.lerp(
            from,
            to,
            distance(from) / (distance(from) - distance(to)),
          )!,
      ],
    ];
  }

  /// A cell cut to [polygon], in frame units: the rect around it, and its
  /// corners as fractions of that rect.
  static SplitScreenCellGeometry _polygonCell(List<Offset> polygon) {
    final rect = Rect.fromLTRB(
      polygon.map((point) => point.dx).reduce(math.min),
      polygon.map((point) => point.dy).reduce(math.min),
      polygon.map((point) => point.dx).reduce(math.max),
      polygon.map((point) => point.dy).reduce(math.max),
    );
    return (
      rect: rect,
      shape: SplitScreenCellShape.polygon([
        for (final point in polygon)
          Offset(
            (point.dx - rect.left) / rect.width,
            (point.dy - rect.top) / rect.height,
          ),
      ]),
    );
  }

  /// The round window [corner] of the frame, in frame units.
  ///
  /// It keeps twice the gap from the edges, so the ring cut around it stays
  /// inside the clip under it.
  static Rect _circleWindow(Size frame, double spacing, Alignment corner) {
    final margin = _circleMargin(frame, spacing);
    final diameter =
        SplitScreenLayoutGeometry.circleWindowDiameter * frame.shortestSide;
    return Rect.fromLTWH(
      corner.x < 0 ? margin : frame.width - margin - diameter,
      corner.y < 0 ? margin : frame.height - margin - diameter,
      diameter,
      diameter,
    );
  }

  /// [count] round windows spread along the bottom of the frame, in frame
  /// units — none for a [count] of 0.
  ///
  /// Neighbours keep the same distance as from the edges, so their rings
  /// never touch; on a wide gap the windows shrink to keep it.
  static List<Rect> _circleRowWindows(Size frame, double spacing, int count) {
    if (count == 0) return const [];
    final margin = _circleMargin(frame, spacing);
    final diameter = math.min(
      SplitScreenLayoutGeometry.circleRowDiameter(count) * frame.shortestSide,
      (frame.width - (count + 1) * margin) / count,
    );
    final step = count == 1
        ? 0.0
        : (frame.width - 2 * margin - diameter) / (count - 1);
    return [
      for (var index = 0; index < count; index++)
        Rect.fromLTWH(
          margin + index * step,
          frame.height - margin - diameter,
          diameter,
          diameter,
        ),
    ];
  }

  /// How far a round window keeps from the frame's edges.
  static double _circleMargin(Size frame, double spacing) =>
      SplitScreenLayoutGeometry.pictureInPictureMargin * frame.shortestSide +
      2 * spacing;

  /// [unit] scaled into [frame] with [spacing] between two neighbours and
  /// between a cell and the frame's edge.
  ///
  /// Every cell gives up the same [spacing], whichever of its edges are
  /// shared, so cells that take the same share of the frame come out the
  /// same size: the three columns of a three-way split are equally wide.
  static Rect _inset(Rect unit, Size frame, double spacing) => Rect.fromLTRB(
    unit.left * (frame.width - spacing) + spacing,
    unit.top * (frame.height - spacing) + spacing,
    unit.right * (frame.width - spacing),
    unit.bottom * (frame.height - spacing),
  );

  /// The picture-in-picture window, [corner] of the frame.
  static Rect _pictureInPictureWindow(
    Size frame,
    double spacing,
    Alignment corner,
  ) {
    final margin =
        SplitScreenLayoutGeometry.pictureInPictureMargin * frame.shortestSide +
        spacing;
    final width = frame.width * SplitScreenLayoutGeometry.pictureInPictureWidth;
    final height = width / frame.aspectRatio;
    return Rect.fromLTWH(
      corner.x < 0 ? margin : frame.width - margin - width,
      corner.y < 0 ? margin : frame.height - margin - height,
      width,
      height,
    );
  }
}

/// One cell of a layout: the rect it sits in and its shape within it.
typedef SplitScreenCellGeometry = ({Rect rect, SplitScreenCellShape shape});

/// The part of its rect a cell shows: all of it, the oval inside it, or a
/// polygon — less any round windows cut out of it.
///
/// Corners and holes are fractions of the cell's rect, so the same shape fits
/// the rect however large it is drawn.
@immutable
final class SplitScreenCellShape {
  const SplitScreenCellShape._({
    bool isOval = false,
    this.corners,
    this.holes = const [],
  }) : _isOval = isOval;

  /// The whole rect less [holes].
  const SplitScreenCellShape.withHoles(List<Rect> holes) : this._(holes: holes);

  /// The polygon through [corners], in order.
  const SplitScreenCellShape.polygon(List<Offset> corners)
    : this._(corners: corners);

  /// The whole rect.
  static const rectangle = SplitScreenCellShape._();

  /// The oval inside the rect: a circle when the rect is square.
  static const oval = SplitScreenCellShape._(isOval: true);

  final bool _isOval;

  /// The polygon's corners, or `null` for a rectangle or an oval.
  final List<Offset>? corners;

  /// Ovals cut out of the rect, each the window of a cell on top of it plus
  /// the border ring around that window.
  final List<Rect> holes;

  /// Whether the cell shows its whole rect, so needs no cutting.
  bool get isRectangle => !_isOval && corners == null && holes.isEmpty;

  /// Whether the cell is the oval inside its rect.
  bool get isOval => _isOval;

  /// The shape fitted to [rect]. A rectangle's corners are rounded by
  /// [borderRadius].
  Path pathIn(Rect rect, {BorderRadius borderRadius = BorderRadius.zero}) {
    Offset at(Offset fraction) => Offset(
      rect.left + fraction.dx * rect.width,
      rect.top + fraction.dy * rect.height,
    );
    final path = Path()..fillType = PathFillType.evenOdd;
    final corners = this.corners;
    if (corners != null) {
      path.addPolygon([for (final corner in corners) at(corner)], true);
    } else if (_isOval) {
      path.addOval(rect);
    } else if (borderRadius == BorderRadius.zero) {
      path.addRect(rect);
    } else {
      path.addRRect(borderRadius.toRRect(rect));
    }
    // Holes sit inside the rect and never overlap, so the even-odd rule cuts
    // each of them out.
    for (final hole in holes) {
      path.addOval(Rect.fromPoints(at(hole.topLeft), at(hole.bottomRight)));
    }
    return path;
  }

  @override
  bool operator ==(Object other) =>
      other is SplitScreenCellShape &&
      other._isOval == _isOval &&
      listEquals(other.corners, corners) &&
      listEquals(other.holes, holes);

  @override
  int get hashCode => Object.hash(
    _isOval,
    corners == null ? null : Object.hashAll(corners!),
    Object.hashAll(holes),
  );
}

/// Sizes the split-screen geometry is built from.
abstract final class SplitScreenLayoutGeometry {
  /// The largest gap the slider offers, as a fraction of the frame's shorter
  /// side. Wider than this and the cells start to read as thumbnails on a
  /// coloured card rather than a split screen.
  static const double maxGap = 0.08;

  /// Width of the picture-in-picture window as a fraction of the frame's.
  static const double pictureInPictureWidth = 0.38;

  /// Distance of the picture-in-picture window from the frame's edges with no
  /// gap, as a fraction of the frame's shorter side. A round window keeps the
  /// same distance.
  static const double pictureInPictureMargin = 0.04;

  /// Diameter of a round window in a corner, as a fraction of the frame's
  /// shorter side.
  static const double circleWindowDiameter = 0.42;

  /// Diameter of each of [count] round windows in a row along the bottom, as
  /// a fraction of the frame's shorter side.
  static double circleRowDiameter(int count) => count <= 2 ? 0.36 : 0.28;

  /// How far a slanted divider drifts from one side of the frame to the
  /// other, as a fraction of the length it splits.
  static const double slant = 0.12;

  /// The furthest a pinch zooms into a cell's clip. Past this the footage is
  /// blown up far beyond the pixels it has.
  static const double maxZoom = 4;
}

/// The aspect ratio (width / height) of [cell], a rect in fractions of a
/// frame of [frameAspectRatio].
double splitScreenCellAspectRatio(Rect cell, double frameAspectRatio) =>
    cell.width * frameAspectRatio / cell.height;

/// Where a clip's whole frame is drawn so that a cell of [cellSize] shows the
/// part the user framed, in the cell's coordinates.
///
/// At [zoom] 1 the frame just covers the cell, the way [BoxFit.cover] places
/// an image; a larger [zoom] grows it around that. [alignment] slides it
/// wherever it overhangs the cell: -1 puts the frame's left (top) edge on the
/// cell's, 1 its right (bottom) edge. Both are clamped, so a stale gesture can
/// never leave part of the cell uncovered.
Rect splitScreenFootageRect({
  required Size cellSize,
  required double sourceAspectRatio,
  Alignment alignment = Alignment.center,
  double zoom = 1,
}) {
  final scale = zoom.clamp(1.0, SplitScreenLayoutGeometry.maxZoom);
  final height =
      math.max(cellSize.width / sourceAspectRatio, cellSize.height) * scale;
  final width = height * sourceAspectRatio;
  return Rect.fromLTWH(
    -(width - cellSize.width) * (alignment.x.clamp(-1.0, 1.0) + 1) / 2,
    -(height - cellSize.height) * (alignment.y.clamp(-1.0, 1.0) + 1) / 2,
    width,
    height,
  );
}

/// The part of a clip's frame a cell of [cellAspectRatio] shows, as fractions
/// of the frame's width and height — see [splitScreenFootageRect].
Rect splitScreenCropRect({
  required double sourceAspectRatio,
  required double cellAspectRatio,
  Alignment alignment = Alignment.center,
  double zoom = 1,
}) {
  final footage = splitScreenFootageRect(
    cellSize: Size(cellAspectRatio, 1),
    sourceAspectRatio: sourceAspectRatio,
    alignment: alignment,
    zoom: zoom,
  );
  return Rect.fromLTWH(
    -footage.left / footage.width,
    -footage.top / footage.height,
    cellAspectRatio / footage.width,
    1 / footage.height,
  );
}

/// The framing of a cell after one step of a pan or pinch.
///
/// The fingers were at [focalPoint] in the cell and moved by [delta], while
/// the pinch asks for [targetZoom]. The point of the footage that was under
/// the fingers stays under them, so a pinch zooms into what the user touches
/// and a one-finger drag moves the footage with the finger — until an edge of
/// the footage meets the cell's edge. An axis with nothing overhanging keeps
/// its alignment, as there is nothing to move.
({Alignment alignment, double zoom}) splitScreenReframed({
  required Alignment alignment,
  required double zoom,
  required double targetZoom,
  required Offset focalPoint,
  required Offset delta,
  required Size cellSize,
  required double sourceAspectRatio,
}) {
  if (cellSize.isEmpty || sourceAspectRatio <= 0) {
    return (alignment: alignment, zoom: zoom);
  }
  final nextZoom = targetZoom.clamp(1.0, SplitScreenLayoutGeometry.maxZoom);
  final before = splitScreenFootageRect(
    cellSize: cellSize,
    sourceAspectRatio: sourceAspectRatio,
    alignment: alignment,
    zoom: zoom,
  );
  final after = splitScreenFootageRect(
    cellSize: cellSize,
    sourceAspectRatio: sourceAspectRatio,
    zoom: nextZoom,
  );
  final grip = Offset(
    (focalPoint.dx - before.left) / before.width,
    (focalPoint.dy - before.top) / before.height,
  );
  final left = focalPoint.dx + delta.dx - grip.dx * after.width;
  final top = focalPoint.dy + delta.dy - grip.dy * after.height;

  double align(double current, double start, double overhang) =>
      overhang <= 0 ? current : (-2 * start / overhang - 1).clamp(-1.0, 1.0);
  return (
    alignment: Alignment(
      align(alignment.x, left, after.width - cellSize.width),
      align(alignment.y, top, after.height - cellSize.height),
    ),
    zoom: nextZoom,
  );
}
