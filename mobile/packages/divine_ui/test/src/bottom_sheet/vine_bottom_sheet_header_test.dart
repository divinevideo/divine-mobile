// ABOUTME: Tests for VineBottomSheetHeader and VineBottomSheetBadge
// ABOUTME: Verifies header rendering and structure

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const _longTitle = 'A comment title long enough to need wrapping';

/// The header's private layout render object, reached by name because the
/// widget that configures it is private to the library.
RenderBox _headerRow(WidgetTester tester) =>
    tester.allRenderObjects.firstWhere(
          (object) => object.runtimeType.toString() == '_RenderHeaderRow',
        )
        as RenderBox;

/// Pumps [header] at a fixed width so layout maths in the tests are exact.
Future<void> _pumpHeader(
  WidgetTester tester,
  VineBottomSheetHeader header, {
  double width = 400,
  TextDirection textDirection = TextDirection.ltr,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: textDirection,
        child: Scaffold(
          body: Center(
            child: SizedBox(width: width, child: header),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('VineBottomSheetHeader', () {
    testWidgets('renders title', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VineBottomSheetHeader(title: Text('Test Title')),
          ),
        ),
      );

      expect(find.text('Test Title'), findsOneWidget);
    });

    testWidgets('renders with trailing widget', (tester) async {
      const trailingWidget = Icon(Icons.settings, key: Key('trailing'));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VineBottomSheetHeader(
              title: Text('Test Title'),
              trailing: trailingWidget,
            ),
          ),
        ),
      );

      expect(find.text('Test Title'), findsOneWidget);
      expect(find.byKey(const Key('trailing')), findsOneWidget);
    });

    testWidgets('uses default padding when none is provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VineBottomSheetHeader(title: Text('Test Title')),
          ),
        ),
      );

      final padding = tester.widget<Padding>(
        find
            .descendant(
              of: find.byType(VineBottomSheetHeader),
              matching: find.byType(Padding),
            )
            .first,
      );

      expect(
        padding.padding,
        const EdgeInsetsDirectional.only(start: 16, end: 16, top: 8),
      );
    });

    testWidgets('applies custom padding when provided', (tester) async {
      const customPadding = EdgeInsetsDirectional.only(
        start: 12,
        end: 12,
        top: 4,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VineBottomSheetHeader(
              title: Text('Test Title'),
              padding: customPadding,
            ),
          ),
        ),
      );

      final padding = tester.widget<Padding>(
        find
            .descendant(
              of: find.byType(VineBottomSheetHeader),
              matching: find.byType(Padding),
            )
            .first,
      );

      expect(padding.padding, customPadding);
    });

    testWidgets('renders with leading widget', (tester) async {
      const leadingWidget = Icon(Icons.close, key: Key('leading'));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VineBottomSheetHeader(
              title: Text('Test Title'),
              leading: leadingWidget,
            ),
          ),
        ),
      );

      expect(find.text('Test Title'), findsOneWidget);
      expect(find.byKey(const Key('leading')), findsOneWidget);
    });

    group('title centering', () {
      testWidgets('centers the title when only a leading action is given', (
        tester,
      ) async {
        await _pumpHeader(
          tester,
          VineBottomSheetHeader(
            title: const Text('Test Title'),
            leadingAction: DivineIconButton(
              key: const Key('leading_action'),
              icon: DivineIconName.x,
              onPressed: () {},
            ),
          ),
        );

        expect(find.byKey(const Key('leading_action')), findsOneWidget);
        expect(
          tester.getCenter(find.text('Test Title')).dx,
          moreOrLessEquals(
            tester.getCenter(find.byType(VineBottomSheetHeader)).dx,
          ),
        );
      });

      testWidgets('centers the title when only a trailing widget is given', (
        tester,
      ) async {
        await _pumpHeader(
          tester,
          const VineBottomSheetHeader(
            title: Text('Test Title'),
            trailing: SizedBox(width: 120, height: 40, child: Text('Newest')),
          ),
        );

        expect(
          tester.getCenter(find.text('Test Title')).dx,
          moreOrLessEquals(
            tester.getCenter(find.byType(VineBottomSheetHeader)).dx,
          ),
        );
      });

      testWidgets('keeps the title centered as the trailing width changes', (
        tester,
      ) async {
        Future<(double title, double header)> pumpTrailingWidth(
          double width,
        ) async {
          await _pumpHeader(
            tester,
            VineBottomSheetHeader(
              title: const Text('Test Title'),
              trailing: SizedBox(width: width, height: 40),
            ),
          );
          return (
            tester.getCenter(find.text('Test Title')).dx,
            tester.getCenter(find.byType(VineBottomSheetHeader)).dx,
          );
        }

        final (narrow, narrowHeader) = await pumpTrailingWidth(60);
        final (wide, wideHeader) = await pumpTrailingWidth(160);

        expect(narrow, moreOrLessEquals(wide));
        // Not just stable across widths — centered at each of them.
        expect(narrow, moreOrLessEquals(narrowHeader));
        expect(wide, moreOrLessEquals(wideHeader));
      });

      testWidgets('centers the title when the two slots differ in width', (
        tester,
      ) async {
        await _pumpHeader(
          tester,
          const VineBottomSheetHeader(
            title: Text('Test Title'),
            leading: SizedBox(width: 48, height: 48),
            trailing: SizedBox(width: 52, height: 52),
          ),
        );

        expect(
          tester.getCenter(find.text('Test Title')).dx,
          moreOrLessEquals(
            tester.getCenter(find.byType(VineBottomSheetHeader)).dx,
          ),
        );
      });

      testWidgets('keeps the slots at the edges', (tester) async {
        await _pumpHeader(
          tester,
          const VineBottomSheetHeader(
            title: Text('Test Title'),
            leading: SizedBox(width: 48, height: 48, key: Key('leading')),
            trailing: SizedBox(width: 120, height: 48, key: Key('trailing')),
          ),
        );

        final row = tester.getRect(find.byType(VineBottomSheetHeader));

        // 16px of header padding on each side.
        expect(
          tester.getTopLeft(find.byKey(const Key('leading'))).dx,
          moreOrLessEquals(row.left + 16),
        );
        expect(
          tester.getTopRight(find.byKey(const Key('trailing'))).dx,
          moreOrLessEquals(row.right - 16),
        );
      });

      testWidgets('mirrors the slot sides in RTL and still centers', (
        tester,
      ) async {
        const header = VineBottomSheetHeader(
          title: Text('Test Title'),
          leading: SizedBox(width: 48, height: 48, key: Key('leading')),
          trailing: SizedBox(width: 120, height: 48, key: Key('trailing')),
        );

        await _pumpHeader(tester, header);
        // Flip direction on the mounted element so the render object is
        // updated in place rather than rebuilt from scratch.
        await _pumpHeader(tester, header, textDirection: TextDirection.rtl);

        final row = tester.getRect(find.byType(VineBottomSheetHeader));

        expect(
          tester.getTopRight(find.byKey(const Key('leading'))).dx,
          moreOrLessEquals(row.right - 16),
        );
        expect(
          tester.getTopLeft(find.byKey(const Key('trailing'))).dx,
          moreOrLessEquals(row.left + 16),
        );
        expect(
          tester.getCenter(find.text('Test Title')).dx,
          moreOrLessEquals(
            tester.getCenter(find.byType(VineBottomSheetHeader)).dx,
          ),
        );
      });

      testWidgets('caps the title instead of overflowing on a wide slot', (
        tester,
      ) async {
        // A text-driven slot at an accessibility text scale. Reserving this
        // width opposite the slot to center the title used to overflow the
        // row; capping the title cannot.
        await _pumpHeader(
          tester,
          const VineBottomSheetHeader(
            title: Text(_longTitle),
            trailing: SizedBox(width: 100, height: 40),
          ),
          width: 360,
        );

        expect(tester.takeException(), isNull);
        expect(
          tester.getCenter(find.text(_longTitle)).dx,
          moreOrLessEquals(
            tester.getCenter(find.byType(VineBottomSheetHeader)).dx,
          ),
        );
        expect(
          tester.getRect(find.text(_longTitle)).right,
          lessThanOrEqualTo(
            tester.getRect(find.byType(VineBottomSheetHeader)).right,
          ),
        );
      });

      testWidgets('falls back to the space between the slots when centering '
          'leaves no room', (tester) async {
        // Both sides would have to keep 190px clear on a 328px row.
        await _pumpHeader(
          tester,
          const VineBottomSheetHeader(
            title: Text('Comments'),
            trailing: SizedBox(width: 178, height: 40, key: Key('trailing')),
          ),
          width: 360,
        );

        expect(tester.takeException(), isNull);

        final title = tester.getRect(find.text('Comments'));
        final row = tester.getRect(find.byType(VineBottomSheetHeader));

        // Starts at the leading edge and stops before the trailing slot.
        expect(title.left, moreOrLessEquals(row.left + 16));
        expect(
          title.right,
          lessThanOrEqualTo(
            tester.getTopLeft(find.byKey(const Key('trailing'))).dx,
          ),
        );
      });

      testWidgets('falls back to the other side in RTL', (tester) async {
        await _pumpHeader(
          tester,
          const VineBottomSheetHeader(
            title: Text('Comments'),
            leading: SizedBox(width: 178, height: 40, key: Key('leading')),
          ),
          width: 360,
          textDirection: TextDirection.rtl,
        );

        expect(tester.takeException(), isNull);

        final title = tester.getRect(find.text('Comments'));

        // The leading slot sits on the right in RTL, so the title hugs it
        // from the left, keeping the 12px gap.
        expect(
          tester.getTopLeft(find.byKey(const Key('leading'))).dx - title.right,
          moreOrLessEquals(12),
        );
        expect(
          title.left,
          greaterThanOrEqualTo(
            tester.getRect(find.byType(VineBottomSheetHeader)).left + 16,
          ),
        );
      });
    });

    group('slot behaviour', () {
      testWidgets('routes taps to the slot, not to the empty side', (
        tester,
      ) async {
        var trailingTaps = 0;

        await _pumpHeader(
          tester,
          VineBottomSheetHeader(
            title: const Text('Test Title'),
            trailing: GestureDetector(
              key: const Key('trailing'),
              behavior: HitTestBehavior.opaque,
              onTap: () => trailingTaps++,
              child: const SizedBox(width: 120, height: 40),
            ),
          ),
        );

        final row = tester.getRect(find.byType(VineBottomSheetHeader));
        final trailing = tester.getRect(find.byKey(const Key('trailing')));

        // The empty leading side is inert — nothing is laid out there.
        await tester.tapAt(Offset(row.left + 20, trailing.center.dy));
        expect(trailingTaps, isZero);

        await tester.tap(find.byKey(const Key('trailing')));
        expect(trailingTaps, equals(1));
      });

      testWidgets('announces the slot to screen readers exactly once', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();

        await _pumpHeader(
          tester,
          VineBottomSheetHeader(
            title: const Text('Test Title'),
            trailing: Semantics(
              key: const Key('trailing'),
              button: true,
              label: 'Sort comments',
              child: const SizedBox(width: 120, height: 40),
            ),
          ),
        );

        expect(find.byKey(const Key('trailing')), findsOneWidget);
        expect(find.bySemanticsLabel('Sort comments'), findsOneWidget);

        semantics.dispose();
      });

      testWidgets('keeps the slots at the edges without a title', (
        tester,
      ) async {
        await _pumpHeader(
          tester,
          const VineBottomSheetHeader(
            leading: SizedBox(width: 48, height: 48, key: Key('leading')),
            trailing: SizedBox(width: 120, height: 48, key: Key('trailing')),
          ),
        );

        final row = tester.getRect(find.byType(VineBottomSheetHeader));

        expect(
          tester.getTopLeft(find.byKey(const Key('leading'))).dx,
          moreOrLessEquals(row.left + 16),
        );
        expect(
          tester.getTopRight(find.byKey(const Key('trailing'))).dx,
          moreOrLessEquals(row.right - 16),
        );
      });
    });

    group('layout protocol', () {
      testWidgets('reports intrinsics for both slots and the title', (
        tester,
      ) async {
        await _pumpHeader(
          tester,
          const VineBottomSheetHeader(
            showDragHandle: false,
            showDivider: false,
            // Wrapped: the header reads a title that *is* a SizedBox as
            // "no title".
            title: ColoredBox(
              color: Color(0xFF000000),
              child: SizedBox(width: 80, height: 20),
            ),
            leading: SizedBox(width: 48, height: 48),
            trailing: SizedBox(width: 100, height: 40),
          ),
        );

        final row = _headerRow(tester);

        // Both sides keep the wider slot (100) plus the 12px gap clear, and
        // the title asks for its own 80px on top of that.
        expect(
          row.getMinIntrinsicWidth(double.infinity),
          moreOrLessEquals(304),
        );
        expect(
          row.getMaxIntrinsicWidth(double.infinity),
          moreOrLessEquals(304),
        );
        // The tallest child wins.
        expect(row.getMinIntrinsicHeight(400), moreOrLessEquals(48));
        expect(row.getMaxIntrinsicHeight(400), moreOrLessEquals(48));
        // Unbounded width falls back to the intrinsic width.
        expect(
          row.getMaxIntrinsicHeight(double.infinity),
          moreOrLessEquals(48),
        );
      });

      testWidgets('dry layout matches the laid out size', (tester) async {
        await _pumpHeader(
          tester,
          const VineBottomSheetHeader(
            showDragHandle: false,
            showDivider: false,
            title: Text('Test Title'),
            trailing: SizedBox(width: 100, height: 60),
          ),
        );

        final row = _headerRow(tester);

        expect(
          row.getDryLayout(BoxConstraints(maxWidth: row.size.width)),
          equals(row.size),
        );
        // The tallest child sets the height.
        expect(row.size.height, moreOrLessEquals(60));
      });

      testWidgets('sizes to its content when the width is unbounded', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: UnconstrainedBox(
                  child: VineBottomSheetHeader(
                    showDragHandle: false,
                    showDivider: false,
                    title: Text('Hi'),
                    trailing: SizedBox(width: 100, height: 40),
                  ),
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        final row = _headerRow(tester);
        final title = tester.getRect(find.text('Hi'));

        // Title width plus the 112px both sides keep clear.
        expect(row.size.width, moreOrLessEquals(title.width + 224));
        expect(
          tester.getCenter(find.text('Hi')).dx,
          moreOrLessEquals(
            tester.getCenter(find.byType(VineBottomSheetHeader)).dx,
          ),
        );
      });
    });
  });
}
