// ABOUTME: Widget tests for the row of list header buttons above the grid
// ABOUTME: Covers equal widths, a lone full-width button, an empty row and
// ABOUTME: the readable width the row stops at on large screens

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/widgets/list_action_buttons.dart';

import '../helpers/large_screen_layout.dart';
import '../helpers/test_provider_overrides.dart';

Future<void> _pump(WidgetTester tester, List<Widget> buttons) =>
    tester.pumpWidget(
      testMaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: ListActionButtons(buttons: buttons),
            ),
          ),
        ),
      ),
    );

void main() {
  group(ListActionButtons, () {
    group('renders', () {
      testWidgets('two buttons sharing the width equally', (tester) async {
        await _pump(tester, const [
          SizedBox(key: Key('a'), height: 48),
          SizedBox(key: Key('b'), height: 48),
        ]);

        final a = tester.getRect(find.byKey(const Key('a')));
        final b = tester.getRect(find.byKey(const Key('b')));
        expect(a.width, (300 - kListActionButtonsSpacing) / 2);
        expect(b.width, a.width);
        expect(b.left - a.right, kListActionButtonsSpacing);
      });

      testWidgets('a lone button across the whole row', (tester) async {
        await _pump(tester, const [SizedBox(key: Key('a'), height: 48)]);

        expect(tester.getSize(find.byKey(const Key('a'))).width, 300);
      });

      testWidgets('nothing when there are no buttons', (tester) async {
        await _pump(tester, const []);

        expect(find.byType(Row), findsNothing);
        expect(
          tester.getSize(find.byType(ListActionButtons)),
          const Size(300, 0),
        );
      });
    });

    group('on a wide window', () {
      /// Two buttons in a header as wide as a 1024 pt window.
      Future<(Rect, Rect)> pumpWide(
        WidgetTester tester, {
        required bool largeScreenLayout,
      }) async {
        setTestWindowSize(tester, 1024);
        await tester.pumpWidget(
          largeScreenLayoutApp(
            enabled: largeScreenLayout,
            home: const Scaffold(
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListActionButtons(
                    buttons: [
                      SizedBox(key: Key('a'), height: 48),
                      SizedBox(key: Key('b'), height: 48),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
        return (
          tester.getRect(find.byKey(const Key('a'))),
          tester.getRect(find.byKey(const Key('b'))),
        );
      }

      testWidgets('stops at the readable width with the large-screen layouts', (
        tester,
      ) async {
        final (a, b) = await pumpWide(tester, largeScreenLayout: true);

        expect(a.left, 0);
        expect(b.right, kListActionButtonsMaxWidth);
        expect(
          a.width,
          (kListActionButtonsMaxWidth - kListActionButtonsSpacing) / 2,
        );
      });

      testWidgets('spans the window with the flag off', (tester) async {
        final (a, b) = await pumpWide(tester, largeScreenLayout: false);

        expect(a.left, 0);
        expect(b.right, 1024);
      });
    });
  });
}
