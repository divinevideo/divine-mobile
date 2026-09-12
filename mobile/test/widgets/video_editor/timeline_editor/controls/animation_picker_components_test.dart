// ABOUTME: Tests that the shared animation-picker chip marks its selected
// ABOUTME: state visibly in both appearance modes.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/animation_picker_components.dart';

void main() {
  group(AnimationPickerChip, () {
    Future<void> pumpChip(
      WidgetTester tester, {
      required bool selected,
      ThemeData? theme,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AnimationPickerChip(
              selected: selected,
              onTap: () {},
              semanticLabel: 'Curve 1',
              child: const SizedBox(width: 28, height: 18),
            ),
          ),
        ),
      );
    }

    // Scoped to the chip rather than `find.byType(DecoratedBox).first`, which
    // asserts on a tree shape this test does not control: anything the ambient
    // route wraps around the app — a Cupertino page transition's
    // `_CupertinoEdgeShadowDecoration`, for one — sorts ahead of the chip and
    // fails the cast. The chip owns exactly one DecoratedBox, so name it.
    BoxDecoration decorationOf(WidgetTester tester) =>
        tester
                .widget<DecoratedBox>(
                  find.descendant(
                    of: find.byType(AnimationPickerChip),
                    matching: find.byType(DecoratedBox),
                  ),
                )
                .decoration
            as BoxDecoration;

    testWidgets('marks the selected chip with a readable border in light '
        'mode', (tester) async {
      await pumpChip(tester, selected: true, theme: VineTheme.lightTheme);

      final decoration = decorationOf(tester);
      expect(decoration.color, VineTheme.lightColors.controlSelectedFill);
      expect(
        (decoration.border! as Border).top.color,
        VineTheme.lightColors.accentBrand,
      );
    });

    testWidgets(
      'leaves the unselected chip on the muted border in light mode',
      (tester) async {
        await pumpChip(tester, selected: false, theme: VineTheme.lightTheme);

        final decoration = decorationOf(tester);
        expect(decoration.color, VineTheme.lightColors.controlFill);
        expect(
          (decoration.border! as Border).top.color,
          VineTheme.lightColors.controlOutline,
        );
      },
    );

    testWidgets('keeps the accent border in dark mode', (tester) async {
      await pumpChip(tester, selected: true, theme: VineTheme.theme);

      expect(
        (decorationOf(tester).border! as Border).top.color,
        VineTheme.darkColors.accentBrand,
      );
    });
  });
}
