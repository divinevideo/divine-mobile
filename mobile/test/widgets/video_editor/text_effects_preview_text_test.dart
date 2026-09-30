// ABOUTME: Tests for TextEffectsPreviewText's highlighted range: only the fill
// ABOUTME: is recolored, so the outline pass keeps its stroke.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/text_effects.dart';
import 'package:openvine/widgets/video_editor/text_effects_preview_text.dart';

void main() {
  group(TextEffectsPreviewText, () {
    const highlightColor = Color(0xFF27C58B);
    const style = TextStyle(fontSize: 20, color: Color(0xFFFFFFFF));

    Future<void> pump(WidgetTester tester, {required TextEffects effects}) {
      return tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Center(
            child: TextEffectsPreviewText(
              'Do It For',
              style: style,
              effects: effects,
              highlightRange: const TextRange(start: 3, end: 5),
              highlightColor: highlightColor,
            ),
          ),
        ),
      );
    }

    /// The part of [text] drawn in [highlightColor], or `null` for none.
    String? litText(Text text) {
      String? lit;
      text.textSpan?.visitChildren((span) {
        if (span is TextSpan && span.style?.color == highlightColor) {
          lit = span.text;
          return false;
        }
        return true;
      });
      return lit;
    }

    /// [litText] of every rendered pass, bottom first.
    List<String?> litPerPass(WidgetTester tester) =>
        tester.widgetList<Text>(find.byType(Text)).map(litText).toList();

    testWidgets('fills the highlighted range in the highlight color', (
      tester,
    ) async {
      await pump(tester, effects: TextEffects.none);

      expect(litPerPass(tester), ['It']);
    });

    testWidgets('leaves the outline pass unlit', (tester) async {
      await pump(tester, effects: const TextEffects(outlineThickness: 0.5));

      // The stroke pass first, then the fill pass on top.
      expect(litPerPass(tester), [null, 'It']);
    });
  });
}
