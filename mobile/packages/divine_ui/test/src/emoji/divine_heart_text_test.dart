import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(home: Scaffold(body: child)),
  );

  group(DivineHeartText, () {
    testWidgets('renders text with no green heart as plain text', (
      tester,
    ) async {
      await pump(tester, const DivineHeartText('hello'));

      expect(find.text('hello'), findsOneWidget);
      expect(find.byType(DivineIcon), findsNothing);
    });

    testWidgets('paints a green heart in the brand green', (tester) async {
      await pump(tester, const DivineHeartText('hi $divineGreenHeart'));

      final icon = tester.widget<DivineIcon>(find.byType(DivineIcon));
      expect(icon.color, VineTheme.vineGreen);
    });

    testWidgets('sizes the heart from the inherited default style', (
      tester,
    ) async {
      await pump(
        tester,
        const DefaultTextStyle(
          style: TextStyle(fontSize: 30),
          child: DivineHeartText(divineGreenHeart),
        ),
      );

      final icon = tester.widget<DivineIcon>(find.byType(DivineIcon));
      expect(icon.size, 30 * kDivineHeartFontScale);
    });

    testWidgets('lets an explicit style win over the inherited one', (
      tester,
    ) async {
      await pump(
        tester,
        const DefaultTextStyle(
          style: TextStyle(fontSize: 30),
          child: DivineHeartText(
            divineGreenHeart,
            style: TextStyle(fontSize: 10),
          ),
        ),
      );

      final icon = tester.widget<DivineIcon>(find.byType(DivineIcon));
      expect(icon.size, 10 * kDivineHeartFontScale);
    });

    testWidgets('exposes the caller style on the Text, like Text does', (
      tester,
    ) async {
      const style = TextStyle(fontWeight: FontWeight.w600);
      await pump(tester, const DivineHeartText('hello', style: style));

      expect(tester.widget<Text>(find.byType(Text)).style, style);
    });

    testWidgets('forwards maxLines, overflow and textAlign', (tester) async {
      await pump(
        tester,
        const DivineHeartText(
          'a long line that wraps',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      );

      final rich = tester.widget<Text>(find.byType(Text));
      expect(rich.maxLines, 2);
      expect(rich.overflow, TextOverflow.ellipsis);
      expect(rich.textAlign, TextAlign.center);
    });
  });
}
