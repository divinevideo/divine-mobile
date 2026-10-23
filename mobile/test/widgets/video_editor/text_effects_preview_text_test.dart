// ABOUTME: Tests for TextEffectsPreviewText: only the fill takes the
// ABOUTME: highlight color or the gradient; outline and shadow keep theirs.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/text_effects.dart';
import 'package:openvine/widgets/video_editor/text_effects_preview_text.dart';
import 'package:pro_image_editor/pro_image_editor.dart' show TextGradient;

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

    group('gradient', () {
      const gradient = TextGradient(
        colors: [Color(0xFF34BBF1), Color(0xFF8568FF)],
      );

      Future<void> pumpGradient(
        WidgetTester tester, {
        required TextEffects effects,
      }) {
        return tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Center(
              child: TextEffectsPreviewText(
                'Do It For',
                style: style,
                effects: effects,
                gradient: gradient,
              ),
            ),
          ),
        );
      }

      /// The shadows of the passes drawn through the gradient, and of the
      /// passes drawn outside it.
      ({List<Shadow> filled, List<Shadow> outside}) shadowsByPass(
        WidgetTester tester,
      ) {
        final filled = find.descendant(
          of: find.byType(ShaderMask),
          matching: find.byType(Text),
        );
        final outside = find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              !filled.evaluate().any((element) => element.widget == widget),
        );
        List<Shadow> shadows(Finder finder) => [
          for (final text in tester.widgetList<Text>(finder))
            ...?text.style?.shadows,
        ];
        return (filled: shadows(filled), outside: shadows(outside));
      }

      testWidgets('leaves the shadow out of the gradient', (tester) async {
        await pumpGradient(
          tester,
          effects: const TextEffects(shadowStrength: 0.5),
        );

        final shadows = shadowsByPass(tester);
        expect(find.byType(ShaderMask), findsOneWidget);
        expect(shadows.filled, isEmpty);
        expect(shadows.outside, isNotEmpty);
      });

      testWidgets('leaves the outline out of the gradient', (tester) async {
        await pumpGradient(
          tester,
          effects: const TextEffects(outlineThickness: 0.5),
        );

        final masked = tester.widget<Text>(
          find.descendant(
            of: find.byType(ShaderMask),
            matching: find.byType(Text),
          ),
        );
        expect(masked.style?.foreground, isNull);
        expect(find.byType(Text), findsNWidgets(2));
      });
    });
  });
}
