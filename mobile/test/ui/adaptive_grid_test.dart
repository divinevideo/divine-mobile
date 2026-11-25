// ABOUTME: Tests the grid delegates that count columns from the grid's own
// ABOUTME: width with the large-screen layouts, and keep the old rule without

import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/ui/adaptive_grid.dart';
import 'package:openvine/ui/adaptive_layout.dart';

import '../helpers/large_screen_layout.dart';

const _gap = 4.0;

/// Width of the first cell of a grid laid out by [sliver], [gridWidth] wide
/// in a [windowWidth] wide window.
Future<double> _firstCellWidth(
  WidgetTester tester, {
  required double windowWidth,
  required double gridWidth,
  required bool largeScreenLayout,
  required Widget Function(AdaptiveLayout layout, IndexedWidgetBuilder cell)
  sliver,
}) async {
  setTestWindowSize(tester, windowWidth);
  await tester.pumpWidget(
    largeScreenLayoutApp(
      enabled: largeScreenLayout,
      home: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: gridWidth,
          child: Builder(
            builder: (context) => CustomScrollView(
              slivers: [
                sliver(
                  context.adaptiveLayout,
                  (context, index) =>
                      ColoredBox(key: ValueKey(index), color: Colors.black),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  return tester.getSize(find.byKey(const ValueKey(0))).width;
}

Widget _grid(
  AdaptiveLayout layout,
  IndexedWidgetBuilder cell, {
  required int compactColumns,
  int? largeColumnsWithoutFlag,
}) => SliverGrid.builder(
  gridDelegate: AdaptiveGridDelegate(
    layout: layout,
    compactColumns: compactColumns,
    largeColumnsWithoutFlag: largeColumnsWithoutFlag,
    crossAxisSpacing: _gap,
    mainAxisSpacing: _gap,
  ),
  itemCount: 12,
  itemBuilder: cell,
);

void main() {
  group(AdaptiveGridDelegate, () {
    testWidgets("counts columns from the grid's own width with the flag on", (
      tester,
    ) async {
      // A 700 pt grid in a 1300 pt window crosses one breakpoint, not three.
      final width = await _firstCellWidth(
        tester,
        windowWidth: 1300,
        gridWidth: 700,
        largeScreenLayout: true,
        sliver: (layout, cell) => _grid(layout, cell, compactColumns: 3),
      );

      expect(width, moreOrLessEquals((700 - 3 * _gap) / 4));
    });

    testWidgets('keeps the phone count on a wide window with the flag off', (
      tester,
    ) async {
      final width = await _firstCellWidth(
        tester,
        windowWidth: 1300,
        gridWidth: 1300,
        largeScreenLayout: false,
        sliver: (layout, cell) => _grid(layout, cell, compactColumns: 3),
      );

      expect(width, moreOrLessEquals((1300 - 2 * _gap) / 3));
    });

    testWidgets('keeps the large-window count of the window with the flag '
        'off', (tester) async {
      // Before the flag, the window decided: a grid narrower than 600 in a
      // tablet window still got its tablet count.
      final width = await _firstCellWidth(
        tester,
        windowWidth: 700,
        gridWidth: 500,
        largeScreenLayout: false,
        sliver: (layout, cell) => _grid(
          layout,
          cell,
          compactColumns: 2,
          largeColumnsWithoutFlag: 3,
        ),
      );

      expect(width, moreOrLessEquals((500 - 2 * _gap) / 3));
    });
  });

  group(AdaptiveMasonryColumns, () {
    testWidgets("counts columns from the grid's own width with the flag on", (
      tester,
    ) async {
      final width = await _firstCellWidth(
        tester,
        windowWidth: 1300,
        gridWidth: 700,
        largeScreenLayout: true,
        sliver: (layout, cell) => SliverMasonryGrid(
          gridDelegate: AdaptiveMasonryColumns(
            layout: layout,
            compactColumns: 2,
          ),
          crossAxisSpacing: _gap,
          mainAxisSpacing: _gap,
          delegate: SliverChildBuilderDelegate(
            (context, index) =>
                AspectRatio(aspectRatio: 1, child: cell(context, index)),
            childCount: 12,
          ),
        ),
      );

      expect(width, moreOrLessEquals((700 - 2 * _gap) / 3));
    });
  });
}
