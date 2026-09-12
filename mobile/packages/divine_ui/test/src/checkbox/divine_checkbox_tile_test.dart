import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/accessibility_guidelines.dart';

void main() {
  group(DivineCheckboxTile, () {
    Widget buildSubject({
      required bool value,
      ValueChanged<bool>? onChanged,
      String? subtitle,
    }) {
      return MaterialApp(
        theme: VineTheme.theme,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: DivineCheckboxTile(
                title: 'I am 18 or older',
                subtitle: subtitle,
                value: value,
                onChanged: onChanged,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('renders the title', (tester) async {
      await tester.pumpWidget(buildSubject(value: false, onChanged: (_) {}));

      expect(find.text('I am 18 or older'), findsOneWidget);
    });

    testWidgets('renders the subtitle when given one', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          value: false,
          onChanged: (_) {},
          subtitle: 'Required to see adult content',
        ),
      );

      expect(find.text('Required to see adult content'), findsOneWidget);
    });

    testWidgets('omits the subtitle when absent', (tester) async {
      await tester.pumpWidget(buildSubject(value: false, onChanged: (_) {}));

      expect(tester.widget<ListTile>(find.byType(ListTile)).subtitle, isNull);
    });

    testWidgets('shows the checkbox ticked when on', (tester) async {
      await tester.pumpWidget(buildSubject(value: true, onChanged: (_) {}));

      final box = tester.widget<DivineSpriteCheckbox>(
        find.byType(DivineSpriteCheckbox),
      );
      expect(box.state, DivineCheckboxState.selected);
    });

    testWidgets('shows the checkbox empty when off', (tester) async {
      await tester.pumpWidget(buildSubject(value: false, onChanged: (_) {}));

      final box = tester.widget<DivineSpriteCheckbox>(
        find.byType(DivineSpriteCheckbox),
      );
      expect(box.state, DivineCheckboxState.unselected);
    });

    testWidgets('ticks on tap', (tester) async {
      bool? received;
      await tester.pumpWidget(
        buildSubject(value: false, onChanged: (v) => received = v),
      );

      await tester.tap(find.text('I am 18 or older'));
      await tester.pumpAndSettle();

      expect(received, isTrue);
    });

    testWidgets('unticks on tap when already on', (tester) async {
      bool? received;
      await tester.pumpWidget(
        buildSubject(value: true, onChanged: (v) => received = v),
      );

      await tester.tap(find.text('I am 18 or older'));
      await tester.pumpAndSettle();

      expect(received, isFalse);
    });

    testWidgets('is non-interactive and dimmed when disabled', (tester) async {
      await tester.pumpWidget(buildSubject(value: false, subtitle: 'Locked'));

      final tile = tester.widget<ListTile>(find.byType(ListTile));
      expect(tile.enabled, isFalse);
      expect(tile.onTap, isNull);
      expect(
        tester.widget<Opacity>(find.byType(Opacity).first).opacity,
        DivineCheckboxTile.disabledOpacity,
      );
    });

    testWidgets('keeps full opacity when enabled', (tester) async {
      await tester.pumpWidget(buildSubject(value: false, onChanged: (_) {}));

      expect(tester.widget<Opacity>(find.byType(Opacity).first).opacity, 1.0);
    });

    testWidgets('announces its checked state', (tester) async {
      await tester.pumpWidget(buildSubject(value: true, onChanged: (_) {}));

      expect(
        tester.getSemantics(find.byType(ListTile)),
        isSemantics(
          hasCheckedState: true,
          isChecked: true,
          hasEnabledState: true,
          isEnabled: true,
        ),
      );
    });

    // Same trap as DivineSwitchTile: a row gated on an async value is built
    // disabled first and flips once it resolves. Assert the styles rather
    // than the absence of an exception — the layout assertion needs a
    // paragraph that remeasures, which the deterministic test font never
    // produces.
    testWidgets('keeps its text styles across a disabled → enabled flip', (
      tester,
    ) async {
      const longSubtitle =
          'You must confirm you are over 18 before adult content can be '
          'shown in your feed on this device.';

      TextStyle styleOf(String data) =>
          tester.widget<Text>(find.text(data)).style!;

      await tester.pumpWidget(
        buildSubject(value: false, subtitle: longSubtitle),
      );
      await tester.pump();
      final disabledTitle = styleOf('I am 18 or older');
      final disabledSubtitle = styleOf(longSubtitle);

      await tester.pumpWidget(
        buildSubject(value: false, subtitle: longSubtitle, onChanged: (_) {}),
      );
      await tester.pumpAndSettle();

      expect(styleOf('I am 18 or older'), equals(disabledTitle));
      expect(styleOf(longSubtitle), equals(disabledSubtitle));
      expect(tester.takeException(), isNull);
    });

    group('accessibility', () {
      testWidgets('meets the accessibility guidelines', (tester) async {
        await tester.pumpWidget(buildSubject(value: true, onChanged: (_) {}));

        await expectMeetsAccessibilityGuidelines(tester);
      });
    });
  });
}
