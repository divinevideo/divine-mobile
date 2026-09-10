// ABOUTME: Widget tests for DivineSelectableRow — the single-select row
// ABOUTME: shared by the language, audio-input and video-shape pickers.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/accessibility_guidelines.dart';

void main() {
  group(DivineSelectableRow, () {
    Widget buildSubject({
      required bool isSelected,
      String? subtitle,
      DivineIconName? leadingIcon,
      VoidCallback? onTap,
      ThemeData? theme,
    }) {
      return MaterialApp(
        theme: theme ?? VineTheme.theme,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: DivineSelectableRow(
                title: 'Deutsch',
                subtitle: subtitle,
                leadingIcon: leadingIcon,
                isSelected: isSelected,
                onTap: onTap ?? () {},
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('renders the title', (tester) async {
      await tester.pumpWidget(buildSubject(isSelected: false));

      expect(find.text('Deutsch'), findsOneWidget);
    });

    testWidgets('renders the subtitle when given one', (tester) async {
      await tester.pumpWidget(buildSubject(isSelected: false, subtitle: 'DE'));

      expect(find.text('DE'), findsOneWidget);
    });

    testWidgets('omits the subtitle when absent', (tester) async {
      await tester.pumpWidget(buildSubject(isSelected: false));

      expect(tester.widget<ListTile>(find.byType(ListTile)).subtitle, isNull);
    });

    testWidgets('marks the active row with a check', (tester) async {
      await tester.pumpWidget(buildSubject(isSelected: true));

      final tile = tester.widget<ListTile>(find.byType(ListTile));
      expect(tile.selected, isTrue);
      expect((tile.trailing! as DivineIcon).icon, DivineIconName.check);
    });

    testWidgets('leaves an inactive row unmarked', (tester) async {
      await tester.pumpWidget(buildSubject(isSelected: false));

      final tile = tester.widget<ListTile>(find.byType(ListTile));
      expect(tile.selected, isFalse);
      expect(tile.trailing, isNull);
    });

    testWidgets('renders the leading icon when given one', (tester) async {
      await tester.pumpWidget(
        buildSubject(isSelected: false, leadingIcon: DivineIconName.globe),
      );

      final leading =
          tester.widget<ListTile>(find.byType(ListTile)).leading! as DivineIcon;
      expect(leading.icon, DivineIconName.globe);
    });

    testWidgets('omits the leading icon when absent', (tester) async {
      await tester.pumpWidget(buildSubject(isSelected: false));

      expect(tester.widget<ListTile>(find.byType(ListTile)).leading, isNull);
    });

    testWidgets('reports taps', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        buildSubject(isSelected: false, onTap: () => tapped = true),
      );

      await tester.tap(find.byType(DivineSelectableRow));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('the selection tick clears contrast in both appearances', (
      tester,
    ) async {
      // The tick is the row's only selected-state cue, so it has to stay
      // readable on the selected fill. The raw brand green is 1.92:1 on the
      // light `surfaceContainer`; the token keeps dark unchanged and swaps to
      // the darkened green in light.
      await tester.pumpWidget(buildSubject(isSelected: true));
      await tester.pumpAndSettle();
      expect(
        (tester.widget<ListTile>(find.byType(ListTile)).trailing! as DivineIcon)
            .color,
        VineTheme.darkColors.accentPositive,
      );

      await tester.pumpWidget(
        buildSubject(isSelected: true, theme: VineTheme.lightTheme),
      );
      // MaterialApp lerps between themes, so a single pump samples the
      // transition rather than the destination palette.
      await tester.pumpAndSettle();
      final lightTick =
          tester.widget<ListTile>(find.byType(ListTile)).trailing!
              as DivineIcon;
      expect(lightTick.color, VineTheme.lightColors.accentPositive);
      expect(
        lightTick.color,
        isNot(VineTheme.vineGreen),
        reason: 'light mode must not fall back to the dark-only brand green',
      );
    });

    group('accessibility', () {
      testWidgets('meets the accessibility guidelines when selected', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject(isSelected: true, subtitle: 'DE'));

        await expectMeetsAccessibilityGuidelines(tester);
      });
    });
  });
}
