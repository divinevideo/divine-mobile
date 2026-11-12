// ABOUTME: Widget tests for the row of list header buttons above the grid
// ABOUTME: Covers equal widths, a lone full-width button and an empty row

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/widgets/list_action_buttons.dart';

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
  });
}
