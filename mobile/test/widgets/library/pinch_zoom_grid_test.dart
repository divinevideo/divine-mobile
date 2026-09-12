// ABOUTME: Tests for PinchZoomGrid - pinch-to-zoom column stepping
// ABOUTME: Verifies column reporting, clamping, and the residual scale settle

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/widgets/library/pinch_zoom_grid.dart';

/// Surface the grid under test sits on.
const _background = Color(0xFF101010);

/// Opacity the layer holding [layer] is drawn at.
double opacityOf(WidgetTester tester, Finder layer) => tester
    .widget<Opacity>(
      find.ancestor(of: layer, matching: find.byType(Opacity)).first,
    )
    .opacity;

void main() {
  group(PinchZoomGrid, () {
    late List<int> reported;
    late int renderedColumns;

    setUp(() {
      reported = <int>[];
      renderedColumns = 3;
    });

    Widget buildWidget({int columnCount = 3}) {
      return MaterialApp(
        home: Scaffold(
          body: PinchZoomGrid(
            columnCount: columnCount,
            minColumnCount: 2,
            maxColumnCount: 5,
            onColumnCountChanged: reported.add,
            backgroundColor: _background,
            builder: (context, columns, controller) {
              renderedColumns = columns;
              return GridView.count(
                controller: controller,
                crossAxisCount: columns,
                children: [
                  for (var i = 0; i < 60; i++)
                    ColoredBox(color: Colors.grey, child: Text('$i')),
                ],
              );
            },
          ),
        ),
      );
    }

    /// Pinches around the centre of the grid, from fingers [from] logical
    /// pixels apart to [to] apart. Spreading (to > from) zooms in.
    Future<void> pinch(
      WidgetTester tester, {
      required double from,
      required double to,
    }) async {
      final centre = tester.getCenter(find.byType(PinchZoomGrid));
      final first = await tester.startGesture(centre - Offset(from, 0));
      final second = await tester.startGesture(centre + Offset(from, 0));
      await tester.pump();
      await first.moveTo(centre - Offset(to, 0));
      await second.moveTo(centre + Offset(to, 0));
      await tester.pump();
      await first.up();
      await second.up();
      await tester.pumpAndSettle();
    }

    testWidgets('reports fewer columns when the fingers spread apart', (
      tester,
    ) async {
      await tester.pumpWidget(buildWidget());

      // 80 -> 120 is a 1.5x zoom: 3 columns / 1.5 = 2.
      await pinch(tester, from: 80, to: 120);

      expect(reported, equals([2]));
      expect(renderedColumns, equals(2));
    });

    testWidgets('reports more columns when the fingers pinch together', (
      tester,
    ) async {
      await tester.pumpWidget(buildWidget());

      // 80 -> 60 is a 0.75x zoom: 3 columns / 0.75 = 4.
      await pinch(tester, from: 80, to: 60);

      expect(reported, equals([4]));
      expect(renderedColumns, equals(4));
    });

    testWidgets('clamps to maxColumnCount', (tester) async {
      await tester.pumpWidget(buildWidget());

      // 3 / 0.25 = 12 columns, far past the maximum of 5.
      await pinch(tester, from: 160, to: 40);

      expect(reported, equals([5]));
      expect(renderedColumns, equals(5));
    });

    testWidgets('reports nothing when the pinch stays inside one step', (
      tester,
    ) async {
      await tester.pumpWidget(buildWidget());

      // 3 / 0.875 = 3.4 columns, which still rounds to the current 3.
      await pinch(tester, from: 160, to: 140);

      expect(reported, isEmpty);
      expect(renderedColumns, equals(3));
    });

    testWidgets('scales the grid mid-pinch and settles back to unscaled', (
      tester,
    ) async {
      await tester.pumpWidget(buildWidget());

      final centre = tester.getCenter(find.byType(PinchZoomGrid));
      final first = await tester.startGesture(centre - const Offset(80, 0));
      final second = await tester.startGesture(centre + const Offset(80, 0));
      await tester.pump();
      await first.moveTo(centre - const Offset(120, 0));
      await second.moveTo(centre + const Offset(120, 0));
      await tester.pump();
      // The step is applied at the end of the frame, once the outgoing
      // layout has been captured for the crossfade.
      await tester.pump();

      final tile = find
          .descendant(
            of: find.byType(GridView),
            matching: find.byType(ColoredBox),
          )
          .first;

      // The grid already lays out 2 columns, but the tile on screen is still
      // the in-between size the fingers are at, larger than a third of the
      // viewport and smaller than half of it.
      expect(renderedColumns, equals(2));
      expect(tester.getRect(tile).width, greaterThan(800 / 3));
      expect(tester.getRect(tile).width, lessThan(400));

      await first.up();
      await second.up();
      await tester.pumpAndSettle();

      // Settled onto the whole step: 800 / 2.
      expect(tester.getRect(tile).width, closeTo(400, 0.5));
      expect(reported, equals([2]));
    });

    testWidgets('crossfades the two layouts by how far the pinch got', (
      tester,
    ) async {
      await tester.pumpWidget(buildWidget());

      final frozenLayout = find.descendant(
        of: find.byType(PinchZoomGrid),
        matching: find.byType(RawImage),
      );
      final tile = find
          .descendant(
            of: find.byType(GridView),
            matching: find.byType(ColoredBox),
          )
          .first;
      expect(frozenLayout, findsNothing);

      final centre = tester.getCenter(find.byType(PinchZoomGrid));
      final first = await tester.startGesture(centre - const Offset(160, 0));
      final second = await tester.startGesture(centre + const Offset(160, 0));
      await tester.pump();
      // Just past the point where the pinch is recognised, which is where the
      // outgoing layout gets frozen — one frame later.
      await first.moveTo(centre - const Offset(172, 0));
      await second.moveTo(centre + const Offset(172, 0));
      await tester.pump();
      await tester.pump();
      expect(frozenLayout, findsOneWidget);

      // Part of the way towards 2 columns, but not far enough to commit.
      await first.moveTo(centre - const Offset(176, 0));
      await second.moveTo(centre + const Offset(176, 0));
      await tester.pump();

      expect(renderedColumns, equals(2));

      // The tile on screen says where between the two steps the pinch is, and
      // the fade has to move with it — that is what makes it follow the
      // fingers rather than a timer.
      final columnsOnScreen = 800 / tester.getRect(tile).width;
      expect(columnsOnScreen, greaterThan(2));
      expect(columnsOnScreen, lessThan(3));
      final partWay = opacityOf(tester, find.byType(GridView));
      expect(partWay, greaterThan(0));
      expect(partWay, lessThan(1));

      // Carry on a little and it has to have moved on with the pinch.
      await first.moveTo(centre - const Offset(184, 0));
      await second.moveTo(centre + const Offset(184, 0));
      await tester.pump();

      expect(800 / tester.getRect(tile).width, lessThan(columnsOnScreen));
      expect(opacityOf(tester, find.byType(GridView)), greaterThan(partWay));

      // Zooming in blows the outgoing 3-column layout up past the viewport,
      // pushing its third column over the right edge. It is the only layer
      // covering everything, so it stays solid and underneath — the incoming
      // one reaches neither the right edge nor the bottom row yet, and fading
      // the covering layer instead would leave those areas empty.
      expect(tester.getRect(frozenLayout).width, greaterThan(800));
      expect(tester.getRect(frozenLayout).height, greaterThan(600));
      expect(opacityOf(tester, frozenLayout), equals(1));
      expect(
        tester
            .widget<Stack>(
              find
                  .descendant(
                    of: find.byType(PinchZoomGrid),
                    matching: find.byType(Stack),
                  )
                  .first,
            )
            .children
            .first
            .key,
        equals(const ValueKey('frozen')),
      );

      await first.up();
      await second.up();
      await tester.pumpAndSettle();

      // Stopping short falls back to the step it started on, and once settled
      // there is nothing left to fade.
      expect(frozenLayout, findsNothing);
      expect(renderedColumns, equals(3));
      expect(tester.getRect(tile).width, closeTo(800 / 3, 0.5));
      expect(reported, isEmpty);
    });

    testWidgets('shrinks the outgoing layout so the next column can slide in', (
      tester,
    ) async {
      await tester.pumpWidget(buildWidget());

      final frozenLayout = find.descendant(
        of: find.byType(PinchZoomGrid),
        matching: find.byType(RawImage),
      );

      final centre = tester.getCenter(find.byType(PinchZoomGrid));
      final first = await tester.startGesture(centre - const Offset(160, 0));
      final second = await tester.startGesture(centre + const Offset(160, 0));
      await tester.pump();
      await first.moveTo(centre - const Offset(148, 0));
      await second.moveTo(centre + const Offset(148, 0));
      await tester.pump();
      await tester.pump();

      // 0.857x: 3 / 0.857 = 3.5 columns, half way from 3 to 4.
      await first.moveTo(centre - const Offset(137, 0));
      await second.moveTo(centre + const Offset(137, 0));
      await tester.pump();

      // Pinching closed shrinks the outgoing 3-column layout away from the
      // right edge, and the incoming 4-column layout still reaches past it —
      // its fourth column slides in as the pinch finishes. The roles are
      // mirrored from zooming in: here the incoming layout is the one covering
      // everything, so it is the solid one and the outgoing layout fades.
      expect(renderedColumns, equals(4));
      expect(tester.getRect(frozenLayout).width, lessThan(800));
      expect(tester.getRect(find.byType(GridView)).width, greaterThan(800));
      expect(opacityOf(tester, find.byType(GridView)), equals(1));
      expect(opacityOf(tester, frozenLayout), lessThan(1));
    });

    // Removing a layout that is still faintly on screen reads as a blink,
    // which is what the eye catches at the end of a slow pinch: by then the
    // settle has decelerated to almost nothing, so the last few percent
    // leaving in one frame is the only movement left.
    testWidgets('has the outgoing layout gone before it drops it', (
      tester,
    ) async {
      await tester.pumpWidget(buildWidget());

      final frozenLayout = find.descendant(
        of: find.byType(PinchZoomGrid),
        matching: find.byType(RawImage),
      );
      final tile = find
          .descendant(
            of: find.byType(GridView),
            matching: find.byType(ColoredBox),
          )
          .first;

      final centre = tester.getCenter(find.byType(PinchZoomGrid));
      final first = await tester.startGesture(centre - const Offset(300, 0));
      final second = await tester.startGesture(centre + const Offset(300, 0));
      await tester.pump();
      await first.moveTo(centre - const Offset(280, 0));
      await second.moveTo(centre + const Offset(280, 0));
      await tester.pump();
      await tester.pump();

      // Almost all the way from 3 columns to 4, but not there yet.
      await first.moveTo(centre - const Offset(200, 0));
      await second.moveTo(centre + const Offset(200, 0));
      await tester.pump();

      final columnsOnScreen = 800 / tester.getRect(tile).width;
      expect(columnsOnScreen, greaterThan(3.85));
      expect(columnsOnScreen, lessThan(4));

      expect(
        frozenLayout,
        findsOneWidget,
        reason: 'the outgoing layout is still on screen',
      );
      expect(opacityOf(tester, frozenLayout), isZero);
    });

    // A grid is transparent between its tiles. Without a backing of their own,
    // the layout behind stays fully visible through those gaps however far the
    // fade has come — a tenth of the screen still showing the old clips, which
    // then vanish in one frame when the layer is dropped.
    testWidgets('backs each layout so neither shows through the other', (
      tester,
    ) async {
      await tester.pumpWidget(buildWidget());

      expect(
        find.descendant(
          of: find.byType(PinchZoomGrid),
          matching: find.byWidgetPredicate(
            (widget) => widget is ColoredBox && widget.color == _background,
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('settles even if the last finger drifts before lifting', (
      tester,
    ) async {
      await tester.pumpWidget(buildWidget());

      final tile = find
          .descendant(
            of: find.byType(GridView),
            matching: find.byType(ColoredBox),
          )
          .first;

      final centre = tester.getCenter(find.byType(PinchZoomGrid));
      final first = await tester.startGesture(centre - const Offset(80, 0));
      final second = await tester.startGesture(centre + const Offset(80, 0));
      await tester.pump();
      await first.moveTo(centre - const Offset(120, 0));
      await second.moveTo(centre + const Offset(120, 0));
      await tester.pump();

      // Fingers rarely leave together: one lifts, the other slides a little
      // before following.
      await first.up();
      await tester.pump(const Duration(milliseconds: 40));
      await second.moveBy(const Offset(0, 8));
      await tester.pump();
      await second.up();
      await tester.pumpAndSettle();

      // That drift must not leave the grid stranded between two steps.
      expect(renderedColumns, equals(2));
      expect(tester.getRect(tile).width, closeTo(400, 0.5));
      expect(reported, equals([2]));
    });

    testWidgets('ignores a rebuild that repeats the count it reported', (
      tester,
    ) async {
      await tester.pumpWidget(buildWidget());

      final tile = find
          .descendant(
            of: find.byType(GridView),
            matching: find.byType(ColoredBox),
          )
          .first;

      await pinch(tester, from: 80, to: 120);
      expect(reported, equals([2]));

      // The owner persists before it emits, so the next rebuild can still
      // carry the count from before the pinch.
      await tester.pumpWidget(buildWidget());
      await tester.pump();

      expect(renderedColumns, equals(2));
      expect(tester.getRect(tile).width, closeTo(400, 0.5));

      // Once it catches up, nothing moves either.
      await tester.pumpWidget(buildWidget(columnCount: 2));
      await tester.pump();

      expect(renderedColumns, equals(2));
      expect(tester.getRect(tile).width, closeTo(400, 0.5));
    });

    testWidgets('reports a second pinch made before the owner caught up', (
      tester,
    ) async {
      await tester.pumpWidget(buildWidget());

      // Both pinches land inside one owner round trip: it persists before it
      // emits, so the rebuild in between still carries the pre-pinch count.
      await pinch(tester, from: 80, to: 120);
      await pinch(tester, from: 120, to: 80);

      // Deciding against the count last sent rather than the one the owner is
      // still showing is what keeps the second pinch from reading as a no-op.
      // Without it the owner is never told, and persists a step the user has
      // already left.
      expect(reported, equals([2, 3]));
      expect(renderedColumns, equals(3));
    });

    testWidgets('follows a column count changed from outside', (tester) async {
      await tester.pumpWidget(buildWidget());

      await tester.pumpWidget(buildWidget(columnCount: 5));
      await tester.pump();

      expect(renderedColumns, equals(5));
      expect(
        tester
            .getRect(
              find
                  .descendant(
                    of: find.byType(GridView),
                    matching: find.byType(ColoredBox),
                  )
                  .first,
            )
            .width,
        closeTo(160, 0.5),
      );
    });

    testWidgets('announces the pinch so ancestors can stop dragging', (
      tester,
    ) async {
      final announced = <bool>[];
      await tester.pumpWidget(
        NotificationListener<PinchZoomNotification>(
          onNotification: (notification) {
            announced.add(notification.active);
            return false;
          },
          child: buildWidget(),
        ),
      );

      final centre = tester.getCenter(find.byType(PinchZoomGrid));
      final first = await tester.startGesture(centre - const Offset(80, 0));
      expect(announced, isEmpty, reason: 'one finger is not a pinch');

      final second = await tester.startGesture(centre + const Offset(80, 0));
      await tester.pump();
      expect(announced, equals([true]));

      await first.up();
      await second.up();
      await tester.pumpAndSettle();

      expect(announced, equals([true, false]));
    });

    testWidgets('holds the scroll position when the fingers land', (
      tester,
    ) async {
      await tester.pumpWidget(buildWidget());
      await tester.drag(find.byType(Scrollable), const Offset(0, -300));
      await tester.pumpAndSettle();

      double offset() => tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position
          .pixels;
      final scrolled = offset();
      expect(scrolled, greaterThan(0));

      final centre = tester.getCenter(find.byType(PinchZoomGrid));
      final first = await tester.startGesture(centre - const Offset(80, 0));
      final second = await tester.startGesture(centre + const Offset(80, 0));
      await tester.pump();

      // Locking the grid for the pinch must not disturb where it sits.
      expect(offset(), equals(scrolled));

      await first.up();
      await second.up();
      await tester.pumpAndSettle();

      expect(offset(), equals(scrolled));
    });

    testWidgets('scrolls to the clips that were on screen before the pinch', (
      tester,
    ) async {
      await tester.pumpWidget(buildWidget());
      await tester.drag(find.byType(Scrollable), const Offset(0, -300));
      await tester.pumpAndSettle();

      final scrolled = tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position
          .pixels;

      await pinch(tester, from: 80, to: 120);

      // Two columns instead of three make every row half again as tall and
      // half again as long to get through, so the offset that shows the same
      // clip grows with the square of the ratio.
      expect(reported, equals([2]));
      expect(
        tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
        closeTo(scrolled * 1.5 * 1.5, 1),
      );
    });

    testWidgets('keeps the grid scrollable when only one finger is down', (
      tester,
    ) async {
      await tester.pumpWidget(buildWidget());

      final scrollable = find.byType(Scrollable);
      expect(tester.state<ScrollableState>(scrollable).position.pixels, isZero);

      await tester.drag(scrollable, const Offset(0, -200));
      await tester.pumpAndSettle();

      expect(
        tester.state<ScrollableState>(scrollable).position.pixels,
        greaterThan(0),
      );
      expect(reported, isEmpty);
    });
  });
}
