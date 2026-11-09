// ABOUTME: Reads how a widget test's text was broken into lines, to catch
// ABOUTME: labels that wrap or split a word at large text sizes.

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// The number of lines the text found by [finder] is laid out on.
int lineCountOf(WidgetTester tester, Finder finder) {
  final paragraph = tester.renderObject<RenderParagraph>(finder);
  return _lineTops(paragraph, 0, paragraph.text.toPlainText().length).length;
}

/// The words of the texts found by [finder] that their layout breaks across
/// two or more lines, which happens when a word is wider than its text.
List<String> wordsSplitAcrossLines(WidgetTester tester, Finder finder) => [
  for (final paragraph in tester.renderObjectList<RenderParagraph>(finder))
    for (final word in RegExp(r'\S+').allMatches(paragraph.text.toPlainText()))
      if (_lineTops(paragraph, word.start, word.end).length > 1) word[0]!,
];

Set<int> _lineTops(RenderParagraph paragraph, int start, int end) => {
  for (final box in paragraph.getBoxesForSelection(
    TextSelection(baseOffset: start, extentOffset: end),
  ))
    box.top.round(),
};
