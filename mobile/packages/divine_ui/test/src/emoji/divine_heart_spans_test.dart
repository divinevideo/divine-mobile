import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  const style = TextStyle(fontSize: 16);

  group('divineGreenHeart', () {
    test('is U+1F49A', () {
      expect(divineGreenHeart, '\u{1F49A}');
      expect(divineGreenHeart.runes.single, 0x1F49A);
    });
  });

  group('divineHeartSpans', () {
    test('returns a single text span when the text has no green heart', () {
      final spans = divineHeartSpans('plain text', style: style);

      expect(spans, hasLength(1));
      expect(spans.single, isA<TextSpan>());
      expect((spans.single as TextSpan).text, 'plain text');
      expect((spans.single as TextSpan).style, style);
    });

    test('returns a single text span for empty text', () {
      final spans = divineHeartSpans('', style: style);

      expect(spans, hasLength(1));
      expect((spans.single as TextSpan).text, '');
    });

    test('replaces a lone green heart with a widget span', () {
      final spans = divineHeartSpans(divineGreenHeart, style: style);

      expect(spans, hasLength(1));
      expect(spans.single, isA<WidgetSpan>());
    });

    test('keeps the surrounding text around a green heart', () {
      final spans = divineHeartSpans(
        'love $divineGreenHeart you',
        style: style,
      );

      expect(spans, hasLength(3));
      expect((spans[0] as TextSpan).text, 'love ');
      expect(spans[1], isA<WidgetSpan>());
      expect((spans[2] as TextSpan).text, ' you');
    });

    test('replaces every occurrence', () {
      final spans = divineHeartSpans(
        '$divineGreenHeart$divineGreenHeart',
        style: style,
      );

      expect(spans, hasLength(2));
      expect(spans.every((s) => s is WidgetSpan), isTrue);
    });

    test('leaves other heart emoji untouched', () {
      final spans = divineHeartSpans('❤️ and \u{1F499}', style: style);

      expect(spans, hasLength(1));
      expect(spans.single, isA<TextSpan>());
    });

    test('does not emit empty text spans at the edges', () {
      final spans = divineHeartSpans('$divineGreenHeart!', style: style);

      expect(spans, hasLength(2));
      expect(spans[0], isA<WidgetSpan>());
      expect((spans[1] as TextSpan).text, '!');
    });

    test('consumes an orphaned VS16 after a painted heart', () {
      // U+1F49A U+FE0F is the explicit emoji presentation sequence. Once the
      // heart is a widget the VS16 has no base character; leaving it would
      // apply it to whatever follows.
      final spans = divineHeartSpans(
        'a$divineGreenHeart\u{FE0F}b',
        style: style,
      );

      expect(spans, hasLength(3));
      expect((spans[0] as TextSpan).text, 'a');
      expect(spans[1], isA<WidgetSpan>());
      expect((spans[2] as TextSpan).text, 'b');
    });

    test('caps the painted hearts and leaves the rest to the platform', () {
      // Each painted heart is a real SVG widget on arbitrary remote text, so
      // the count must stay bounded no matter what a note contains.
      final spans = divineHeartSpans(
        divineGreenHeart * (kDivineHeartMaxPainted + 2),
        style: style,
      );

      expect(spans.whereType<WidgetSpan>(), hasLength(kDivineHeartMaxPainted));
      expect(spans.last, isA<TextSpan>());
      expect(
        (spans.last as TextSpan).text,
        divineGreenHeart * 2,
      );
    });

    test('keeps the VS16 on hearts left to the platform font', () {
      final spans = divineHeartSpans(
        '${divineGreenHeart * kDivineHeartMaxPainted}$divineGreenHeart\u{FE0F}',
        style: style,
      );

      expect(spans.last, isA<TextSpan>());
      expect((spans.last as TextSpan).text, '$divineGreenHeart\u{FE0F}');
    });

    testWidgets('paints the heart in the Divine brand green', (tester) async {
      final spans = divineHeartSpans(divineGreenHeart, style: style);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Text.rich(TextSpan(children: spans))),
        ),
      );

      final icon = tester.widget<DivineIcon>(find.byType(DivineIcon));
      expect(icon.icon, DivineIconName.heartFill);
      expect(icon.color, VineTheme.vineGreen);
    });

    testWidgets('sizes the heart from the run font size', (tester) async {
      final spans = divineHeartSpans(
        divineGreenHeart,
        style: const TextStyle(fontSize: 20),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Text.rich(TextSpan(children: spans))),
        ),
      );

      final icon = tester.widget<DivineIcon>(find.byType(DivineIcon));
      expect(icon.size, 20 * kDivineHeartFontScale);
    });

    testWidgets('falls back to a default size when the style has none', (
      tester,
    ) async {
      final spans = divineHeartSpans(
        divineGreenHeart,
        style: const TextStyle(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Text.rich(TextSpan(children: spans))),
        ),
      );

      final icon = tester.widget<DivineIcon>(find.byType(DivineIcon));
      expect(icon.size, kDivineHeartFallbackFontSize * kDivineHeartFontScale);
    });

    testWidgets('grows the heart with the text scaler', (tester) async {
      // A WidgetSpan child is laid out at its intrinsic size, so the scaler
      // that doubles the surrounding run does not reach the glyph on its own.
      // Without scaling here the heart shrinks to a dot beside large text.
      final spans = divineHeartSpans(
        divineGreenHeart,
        style: const TextStyle(fontSize: 16),
      );

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: MaterialApp(
            home: Scaffold(body: Text.rich(TextSpan(children: spans))),
          ),
        ),
      );

      // Measured, not read off the constructor. DivineIcon scales `size` by
      // the ambient scaler again, so asserting `icon.size` stays green even
      // when the glyph paints 1.3x larger than it was asked for.
      expect(
        tester.getSize(find.byType(DivineIcon)).width,
        16 * 2 * kDivineHeartFontScale,
      );
    });

    testWidgets('pins the heart under MediaQuery.withNoTextScaling', (
      tester,
    ) async {
      final spans = divineHeartSpans(
        divineGreenHeart,
        style: const TextStyle(fontSize: 16),
      );

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: MaterialApp(
            home: Scaffold(
              body: MediaQuery.withNoTextScaling(
                child: Text.rich(TextSpan(children: spans)),
              ),
            ),
          ),
        ),
      );

      expect(
        tester.getSize(find.byType(DivineIcon)).width,
        16 * kDivineHeartFontScale,
      );
    });

    testWidgets('keeps the heart readable to screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      final spans = divineHeartSpans(divineGreenHeart, style: style);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Text.rich(TextSpan(children: spans))),
        ),
      );

      expect(
        find.bySemanticsLabel(divineGreenHeart),
        findsOneWidget,
        reason: 'the swapped glyph must still announce as a green heart',
      );
      handle.dispose();
    });
  });
}
