// ABOUTME: Widget tests for the colour swatch shared by every colour picker.
// ABOUTME: Covers what the swatch announces and that it can be activated.

import 'dart:ui' show Tristate;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/widgets/color_swatch_button.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: VineTheme.theme,
        home: Scaffold(
          body: Center(
            child: SizedBox.square(
              dimension: 48,
              child: ColorSwatchButton(
                color: const Color(0xFF33CCBF),
                isSelected: isSelected,
                onTap: onTap,
                semanticLabel: 'Lime',
              ),
            ),
          ),
        ),
      ),
    );
  }

  group(ColorSwatchButton, () {
    testWidgets('taps call back', (tester) async {
      var taps = 0;
      await pump(tester, onTap: () => taps++);

      await tester.tap(find.byType(ColorSwatchButton));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('announces its label and selection', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, onTap: () {}, isSelected: true);

      final node = tester.getSemantics(find.byType(ColorSwatchButton));
      expect(node.label, 'Lime');
      expect(
        node.getSemanticsData().flagsCollection.isSelected,
        Tristate.isTrue,
      );

      handle.dispose();
    });

    testWidgets('a screen reader can activate the swatch', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await pump(tester, onTap: () => taps++);

      // The swatch excludes its own subtree so the fill, ring and badge stay
      // silent — which also drops the gesture detector's tap action, so the
      // announcing node has to carry one itself.
      final node = tester.getSemantics(find.byType(ColorSwatchButton));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

      tester.semantics.tap(find.semantics.byLabel('Lime'));
      await tester.pump();

      expect(taps, 1);
      handle.dispose();
    });
  });
}
