// ABOUTME: Grid delegates whose column count follows the large-screen layout
// ABOUTME: rules for the grid's own width, counted during layout

import 'package:flutter/rendering.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:openvine/ui/adaptive_layout.dart';

/// A grid of equal cells with [AdaptiveLayout.gridColumns] columns.
///
/// The count is worked out during layout from the grid's own width, which
/// leaves out the side navigation, a comments panel and the grid's padding,
/// rather than read in a builder: a sliver builder runs again on every scroll
/// frame and would rebuild every cell with it.
class AdaptiveGridDelegate extends SliverGridDelegate {
  const AdaptiveGridDelegate({
    required this.layout,
    required this.compactColumns,
    this.largeColumnsWithoutFlag,
    this.mainAxisSpacing = 0,
    this.crossAxisSpacing = 0,
    this.childAspectRatio = 1,
    this.mainAxisExtent,
  });

  /// The layout class of the window the grid is drawn in.
  final AdaptiveLayout layout;

  /// Columns on a phone (see [AdaptiveLayout.gridColumns]).
  final int compactColumns;

  /// Columns a large window had before the large-screen layouts (see
  /// [AdaptiveLayout.gridColumns]).
  final int? largeColumnsWithoutFlag;

  /// Gap between rows.
  final double mainAxisSpacing;

  /// Gap between columns.
  final double crossAxisSpacing;

  /// Width/height ratio of a cell, unless [mainAxisExtent] fixes its height.
  final double childAspectRatio;

  /// Height of a cell, overriding [childAspectRatio].
  final double? mainAxisExtent;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) =>
      SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: layout.gridColumns(
          compact: compactColumns,
          width: constraints.crossAxisExtent,
          largeColumnsWithoutFlag: largeColumnsWithoutFlag,
        ),
        mainAxisSpacing: mainAxisSpacing,
        crossAxisSpacing: crossAxisSpacing,
        childAspectRatio: childAspectRatio,
        mainAxisExtent: mainAxisExtent,
      ).getLayout(constraints);

  @override
  bool shouldRelayout(AdaptiveGridDelegate oldDelegate) =>
      oldDelegate.layout != layout ||
      oldDelegate.compactColumns != compactColumns ||
      oldDelegate.largeColumnsWithoutFlag != largeColumnsWithoutFlag ||
      oldDelegate.mainAxisSpacing != mainAxisSpacing ||
      oldDelegate.crossAxisSpacing != crossAxisSpacing ||
      oldDelegate.childAspectRatio != childAspectRatio ||
      oldDelegate.mainAxisExtent != mainAxisExtent;
}

/// Masonry columns that follow [AdaptiveLayout.gridColumns], counted during
/// layout from the grid's own width for the same reason as
/// [AdaptiveGridDelegate].
class AdaptiveMasonryColumns extends SliverSimpleGridDelegate {
  const AdaptiveMasonryColumns({
    required this.layout,
    required this.compactColumns,
    this.largeColumnsWithoutFlag,
  });

  /// The layout class of the window the grid is drawn in.
  final AdaptiveLayout layout;

  /// Columns on a phone (see [AdaptiveLayout.gridColumns]).
  final int compactColumns;

  /// Columns a large window had before the large-screen layouts (see
  /// [AdaptiveLayout.gridColumns]).
  final int? largeColumnsWithoutFlag;

  @override
  int getCrossAxisCount(
    SliverConstraints constraints,
    double crossAxisSpacing,
  ) => layout.gridColumns(
    compact: compactColumns,
    width: constraints.crossAxisExtent,
    largeColumnsWithoutFlag: largeColumnsWithoutFlag,
  );

  @override
  bool shouldRelayout(AdaptiveMasonryColumns oldDelegate) =>
      oldDelegate.layout != layout ||
      oldDelegate.compactColumns != compactColumns ||
      oldDelegate.largeColumnsWithoutFlag != largeColumnsWithoutFlag;
}
