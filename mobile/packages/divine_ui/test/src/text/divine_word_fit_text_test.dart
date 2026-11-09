import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// The test font draws every glyph one em wide, so at a 10px font size a word
// is ten pixels per character.
const _fontSize = 10.0;

void main() {
  group(DivineWordFitText, () {
    Widget buildSubject(
      String text, {
      required double width,
      double scale = 1,
    }) {
      return MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: DivineWordFitText(
                text,
                style: const TextStyle(fontSize: _fontSize),
              ),
            ),
          ),
        ),
      );
    }

    double renderedFontSize(WidgetTester tester) =>
        tester.widget<Text>(find.byType(Text)).textScaler!.scale(_fontSize);

    /// Number of lines [word] is drawn across.
    int linesOf(WidgetTester tester, String text, String word) {
      final paragraph = tester.renderObject<RenderParagraph>(
        find.byType(RichText),
      );
      final start = text.indexOf(word);
      final boxes = paragraph.getBoxesForSelection(
        TextSelection(baseOffset: start, extentOffset: start + word.length),
      );
      return boxes.map((box) => box.top).toSet().length;
    }

    testWidgets('follows the system text size while every word fits', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject('aa bbb', width: 400, scale: 2));

      expect(renderedFontSize(tester), equals(20));
    });

    testWidgets('stops growing once the widest word fills the line', (
      tester,
    ) async {
      // "abcdefghij" is 100px at the normal size, so it fills the 200px
      // line (plus the pixel of slack) at twice that, short of the 3x asked.
      await tester.pumpWidget(
        buildSubject('tiny abcdefghij', width: 201, scale: 3),
      );

      expect(renderedFontSize(tester), equals(20));
      expect(linesOf(tester, 'tiny abcdefghij', 'abcdefghij'), equals(1));
    });

    testWidgets('keeps the normal size when a word is too wide even there', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject('abcdefghij', width: 50, scale: 2));

      expect(renderedFontSize(tester), equals(_fontSize));
    });

    testWidgets('keeps punctuation with the word it touches', (tester) async {
      // A line cannot break before the "!", so the unit is nine characters
      // wide, not eight. Measuring the letters alone would allow 2.25x, at
      // which the nine no longer fit and the word is split.
      await tester.pumpWidget(buildSubject('abcdefgh!', width: 181, scale: 3));

      expect(renderedFontSize(tester), equals(20));
      expect(linesOf(tester, 'abcdefgh!', 'abcdefgh!'), equals(1));
    });

    testWidgets('lets a line break after a hyphen', (tester) async {
      // "abcde-" and "fghij" each fit the line at the 3x asked. Taking the
      // whole compound as one word would hold it at 1.8x.
      await tester.pumpWidget(
        buildSubject('abcde-fghij', width: 201, scale: 3),
      );

      expect(renderedFontSize(tester), equals(30));
      expect(linesOf(tester, 'abcde-fghij', 'abcde-'), equals(1));
      expect(linesOf(tester, 'abcde-fghij', 'fghij'), equals(1));
    });

    testWidgets('finds the words in text written without spaces', (
      tester,
    ) async {
      // Japanese has no spaces between words but breaks lines between them.
      // Its longest word here, "アクセス", fits at the 3x asked; counting the
      // whole 16-character sentence as one word would hold it at 1.25x.
      const text = 'カメラとマイクへのアクセスを許可';
      await tester.pumpWidget(buildSubject(text, width: 201, scale: 3));

      expect(renderedFontSize(tester), equals(30));
    });
  });
}
