// ABOUTME: Tests for the line-break helpers used by large-text widget tests.
// ABOUTME: Pins that a split word is reported and a missing label is not clean.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'text_lines.dart';

/// Ahem draws every glyph as a square of the font size, so widths are exact.
const _style = TextStyle(fontFamily: 'Ahem', fontSize: 10);

Widget _textInBox(String text, {required double width}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: width,
      child: Text(text, style: _style),
    ),
  ),
);

void main() {
  group('text_lines', () {
    group('wordsSplitAcrossLines', () {
      testWidgets('reports a word wider than the box it is laid out in', (
        tester,
      ) async {
        await tester.pumpWidget(
          _textInBox('Supercalifragilistic', width: 40),
        );

        expect(
          wordsSplitAcrossLines(tester, find.byType(Text)),
          equals(['Supercalifragilistic']),
        );
      });

      testWidgets('does not report words that only wrap between each other', (
        tester,
      ) async {
        await tester.pumpWidget(_textInBox('aa bb cc dd', width: 45));

        expect(lineCountOf(tester, find.byType(Text)), greaterThan(1));
        expect(wordsSplitAcrossLines(tester, find.byType(Text)), isEmpty);
      });

      testWidgets('fails when the finder matches no text', (tester) async {
        await tester.pumpWidget(_textInBox('aa bb', width: 45));

        expect(
          () => wordsSplitAcrossLines(tester, find.text('not on screen')),
          throwsA(isA<TestFailure>()),
        );
      });
    });

    group('lineCountOf', () {
      testWidgets('counts one line for text that fits its box', (
        tester,
      ) async {
        await tester.pumpWidget(_textInBox('aa bb', width: 100));

        expect(lineCountOf(tester, find.byType(Text)), equals(1));
      });
    });
  });
}
