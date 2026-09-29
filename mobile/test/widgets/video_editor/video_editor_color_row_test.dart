// ABOUTME: Tests for VideoEditorColorRow: the picker tile and palette, the
// ABOUTME: edge-to-edge scroll with its inset, and what taps report.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/video_editor_color_row.dart';

void main() {
  group(VideoEditorColorRow, () {
    late List<Color> picked;
    late int customTaps;

    setUp(() {
      picked = [];
      customTaps = 0;
    });

    Future<void> pumpRow(
      WidgetTester tester, {
      required Color selected,
      double width = 800,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          theme: VineTheme.theme,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: VideoEditorColorRow(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  selected: selected,
                  onSelected: picked.add,
                  onCustom: () => customTaps++,
                ),
              ),
            ),
          ),
        ),
      );
    }

    Finder tile(Color color) => find.byWidgetPredicate(
      (widget) =>
          widget is VideoEditorColorTile &&
          !widget.isCustom &&
          widget.color == color,
    );

    final customTile = find.byWidgetPredicate(
      (widget) => widget is VideoEditorColorTile && widget.isCustom,
    );

    group('renders', () {
      testWidgets('the picker tile, then every palette color', (tester) async {
        await pumpRow(tester, selected: VideoEditorConstants.colors.first);

        expect(customTile, findsOneWidget);
        for (final color in VideoEditorConstants.colors) {
          expect(tile(color), findsOneWidget, reason: '$color');
        }
        expect(
          tester.getTopLeft(customTile).dx,
          lessThan(tester.getTopLeft(tile(VideoEditorConstants.colors[0])).dx),
        );
      });

      testWidgets('the selected palette color as selected', (tester) async {
        final color = VideoEditorConstants.colors[3];
        await pumpRow(tester, selected: color);

        expect(tester.widget<VideoEditorColorTile>(tile(color)).selected, true);
        expect(
          tester.widget<VideoEditorColorTile>(customTile).selected,
          isFalse,
        );
      });

      testWidgets('a color off the palette on the picker tile', (
        tester,
      ) async {
        const custom = Color(0xFF123456);
        await pumpRow(tester, selected: custom);

        final picker = tester.widget<VideoEditorColorTile>(customTile);
        expect(picker.selected, isTrue);
        expect(picker.color, custom);
      });

      testWidgets('the picker tile without the picked color', (tester) async {
        // Painting the picked color behind the brush would hide the brush on
        // a color close to it.
        const custom = Color(0xFF27C58B);
        await pumpRow(tester, selected: custom);

        final painted = find.descendant(
          of: customTile,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Container &&
                widget.decoration is BoxDecoration &&
                (widget.decoration! as BoxDecoration).color == custom,
          ),
        );
        expect(painted, findsNothing);
        expect(
          find.descendant(of: customTile, matching: find.byType(DivineIcon)),
          findsOneWidget,
        );
      });

      testWidgets('the first tile inset by the padding while the row spans '
          'the full width', (tester) async {
        await pumpRow(tester, selected: VideoEditorConstants.colors.first);

        expect(tester.getTopLeft(find.byType(ListView)).dx, 0);
        expect(tester.getTopLeft(customTile).dx, 16);
      });
    });

    group('interactions', () {
      testWidgets('tapping a palette tile reports its color', (tester) async {
        await pumpRow(tester, selected: VideoEditorConstants.colors.first);

        await tester.tap(tile(VideoEditorConstants.colors[2]));

        expect(picked, [VideoEditorConstants.colors[2]]);
      });

      testWidgets('tapping the picker tile asks for a custom color', (
        tester,
      ) async {
        await pumpRow(tester, selected: VideoEditorConstants.colors.first);

        await tester.tap(customTile);

        expect(customTaps, 1);
        expect(picked, isEmpty);
      });

      testWidgets('scrolls to the last palette color in a narrow row', (
        tester,
      ) async {
        final last = VideoEditorConstants.colors.last;
        await pumpRow(
          tester,
          selected: VideoEditorConstants.colors.first,
          width: 240,
        );

        await tester.dragUntilVisible(
          tile(last),
          find.byType(ListView),
          const Offset(-100, 0),
        );
        await tester.tap(tile(last));

        expect(picked, [last]);
      });
    });
  });
}
