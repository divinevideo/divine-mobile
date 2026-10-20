// ABOUTME: The split-screen layouts the editor offers and the geometry behind
// ABOUTME: them — where each cell sits in the frame and what of a clip it shows

import 'dart:math' as math;

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

  /// Three clips side by side in columns.
  threeColumns,

  /// Three clips stacked in rows. On a vertical video each row comes out
  /// close to 16:9, which is what landscape footage wants.
  threeStacked,

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

  /// One clip across the top two thirds, three in a row underneath. On a
  /// vertical video each of the three comes out 9:16, the shape of a
  /// vertical clip.
  oneOverThree,

  /// One clip filling the frame with a small one over its top-left corner.
  pictureInPictureTopLeft,

  /// One clip filling the frame with a small one over its top-right corner.
  pictureInPictureTopRight,

  /// One clip filling the frame with a small one over its bottom-left corner.
  pictureInPictureBottomLeft,

  /// One clip filling the frame with a small one over its bottom-right
  /// corner.
  pictureInPictureBottomRight;

  /// How many clips the layout holds.
  int get cellCount => switch (this) {
    sideBySide ||
    stacked ||
    pictureInPictureTopLeft ||
    pictureInPictureTopRight ||
    pictureInPictureBottomLeft ||
    pictureInPictureBottomRight => 2,
    threeColumns ||
    threeStacked ||
    oneOverTwo ||
    twoOverOne ||
    oneBesideTwo ||
    twoBesideOne => 3,
    grid || oneOverThree => 4,
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

  /// The grid cells as fractions of the frame, before any gap, in the order
  /// they are filled and stacked. A picture-in-picture window is not a grid
  /// cell and is added on top of these by [cellRects].
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
    oneOverThree => const [
      Rect.fromLTRB(0, 0, 1, 2 / 3),
      Rect.fromLTRB(0, 2 / 3, 1 / 3, 1),
      Rect.fromLTRB(1 / 3, 2 / 3, 2 / 3, 1),
      Rect.fromLTRB(2 / 3, 2 / 3, 1, 1),
    ],
    pictureInPictureTopLeft ||
    pictureInPictureTopRight ||
    pictureInPictureBottomLeft ||
    pictureInPictureBottomRight => const [Rect.fromLTRB(0, 0, 1, 1)],
  };

  /// Where each cell sits in a frame of [aspectRatio] (width / height), as
  /// fractions of the frame's width and height.
  ///
  /// [gap] is the space between two cells and between a cell and the frame's
  /// edge, as a fraction of the frame's shorter side, so it is equally thick
  /// horizontally and vertically whatever shape the frame is.
  ///
  /// The picture-in-picture window keeps the frame's own shape: it is a
  /// smaller copy of the frame rather than a cell of the grid, and has no
  /// gap to share with the clip under it — its margin to the edges grows with
  /// [gap] instead.
  List<Rect> cellRects({required double aspectRatio, required double gap}) {
    final frame = Size(aspectRatio, 1);
    final spacing =
        gap.clamp(0.0, SplitScreenLayoutGeometry.maxGap) * frame.shortestSide;

    final corner = _pictureInPictureCorner;
    final cells = [
      for (final unit in _unitCells) _inset(unit, frame, spacing),
      if (corner != null) _pictureInPictureWindow(frame, spacing, corner),
    ];
    return [
      for (final cell in cells)
        Rect.fromLTRB(
          cell.left / frame.width,
          cell.top / frame.height,
          cell.right / frame.width,
          cell.bottom / frame.height,
        ),
    ];
  }

  /// [unit] scaled into [frame] and pulled in by [spacing] on the frame's
  /// edges and half of it on edges it shares with another cell, so two
  /// neighbours end up [spacing] apart.
  static Rect _inset(Rect unit, Size frame, double spacing) {
    double edge(double fraction) =>
        fraction <= 0 || fraction >= 1 ? spacing : spacing / 2;
    return Rect.fromLTRB(
      unit.left * frame.width + edge(unit.left),
      unit.top * frame.height + edge(unit.top),
      unit.right * frame.width - edge(unit.right),
      unit.bottom * frame.height - edge(unit.bottom),
    );
  }

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

/// Sizes the split-screen geometry is built from.
abstract final class SplitScreenLayoutGeometry {
  /// The largest gap the slider offers, as a fraction of the frame's shorter
  /// side. Wider than this and the cells start to read as thumbnails on a
  /// coloured card rather than a split screen.
  static const double maxGap = 0.08;

  /// Width of the picture-in-picture window as a fraction of the frame's.
  static const double pictureInPictureWidth = 0.38;

  /// Distance of the picture-in-picture window from the frame's edges with no
  /// gap, as a fraction of the frame's shorter side.
  static const double pictureInPictureMargin = 0.04;

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
