// ABOUTME: Masonry sliver shared by the profile video tabs,
// ABOUTME: mixing vertical 2:3 and square 1:1 tiles like the Explore feeds.

import 'package:flutter/widgets.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:models/models.dart' show VideoEvent;
import 'package:openvine/ui/adaptive_grid.dart';
import 'package:openvine/ui/adaptive_layout.dart';

/// Shape of a vertical profile tile.
const double profileVerticalTileAspectRatio = 2 / 3;

/// Shape of a square profile tile, also used for landscape videos.
const double profileSquareTileAspectRatio = 1;

/// Below this width/height ratio a video counts as vertical. Matches the
/// threshold the Explore tiles (`VideoThumbnailWidget`) use to pick cover over
/// contain.
const double _verticalRatioThreshold = 0.9;

/// Tile shape for a video with `WIDTHxHEIGHT` [dimensions].
///
/// Vertical videos get a 2:3 tile; square and landscape videos get a square
/// one. Without usable dimensions the tile falls back to [fallback].
double profileTileAspectRatio(
  String? dimensions, {
  double fallback = profileVerticalTileAspectRatio,
}) {
  final parts = dimensions?.toLowerCase().split('x');
  if (parts == null || parts.length != 2) return fallback;
  final width = int.tryParse(parts[0].trim());
  final height = int.tryParse(parts[1].trim());
  if (width == null || height == null || width <= 0 || height <= 0) {
    return fallback;
  }
  return profileTileAspectRatioForRatio(width / height);
}

/// Tile shape for a video whose frames are [ratio] wide per unit of height.
///
/// Vertical videos get a 2:3 tile; square and landscape videos get a square
/// one. A missing, non-finite or non-positive ratio falls back to [fallback].
double profileTileAspectRatioForRatio(
  double? ratio, {
  double fallback = profileVerticalTileAspectRatio,
}) {
  if (ratio == null || !ratio.isFinite || ratio <= 0) return fallback;
  return ratio < _verticalRatioThreshold
      ? profileVerticalTileAspectRatio
      : profileSquareTileAspectRatio;
}

/// Tile shape for [video]. Original Vines without dimensions are square,
/// since every Vine was; anything else without them is vertical.
double profileTileAspectRatioForVideo(VideoEvent video) =>
    profileTileAspectRatio(
      video.dimensions,
      fallback: video.isOriginalVine
          ? profileSquareTileAspectRatio
          : profileVerticalTileAspectRatio,
    );

/// Masonry grid for the profile tabs: three columns on a phone, more on wide
/// windows with the large-screen layouts.
///
/// Each tile is sized by [aspectRatioOf] and placed in the shortest column,
/// so vertical and square tiles interlock the way the Explore feeds do.
class ProfileMasonryGrid extends StatelessWidget {
  const ProfileMasonryGrid({
    required this.childCount,
    required this.aspectRatioOf,
    required this.itemBuilder,
    super.key,
  });

  /// Number of tiles.
  final int childCount;

  /// Width/height ratio of the tile at an index.
  final double Function(int index) aspectRatioOf;

  /// Builds the tile at an index; it fills the cell [aspectRatioOf] sizes.
  final IndexedWidgetBuilder itemBuilder;

  /// Columns on a phone, matching the square grid this replaced. With the
  /// large-screen layouts on, wider windows get more (see
  /// [AdaptiveLayout.gridColumns]).
  static const int crossAxisCount = 3;

  /// Gap between tiles on both axes.
  static const double spacing = 4;

  /// The column count of a grid [width] wide in a window of [layout].
  static int columnsFor(AdaptiveLayout layout, double width) =>
      layout.gridColumns(compact: crossAxisCount, width: width);

  @override
  Widget build(BuildContext context) {
    return SliverMasonryGrid(
      // Counted from the grid's own width, which leaves out a status bar
      // column.
      gridDelegate: AdaptiveMasonryColumns(
        layout: context.adaptiveLayout,
        compactColumns: crossAxisCount,
      ),
      mainAxisSpacing: spacing,
      crossAxisSpacing: spacing,
      delegate: SliverChildBuilderDelegate(
        (context, index) => AspectRatio(
          aspectRatio: aspectRatioOf(index),
          child: itemBuilder(context, index),
        ),
        childCount: childCount,
      ),
    );
  }
}
