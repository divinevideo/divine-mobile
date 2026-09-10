// ABOUTME: Divine paints U+1F49A in its own brand green, so the green heart
// ABOUTME: must survive LinkifiedText's plain-text fast path as a widget span.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/linkified_text/linkified_text_widgets.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );

  group('LinkifiedText green heart', () {
    testWidgets('paints a green heart in text carrying no other token', (
      tester,
    ) async {
      // The plain-text fast path returns a bare Text and drops the spans,
      // so a heart with no neighbouring link/mention/hashtag is the case
      // most likely to regress.
      await pump(
        tester,
        const LinkifiedText(text: 'so good $divineGreenHeart'),
      );

      expect(find.byType(DivineIcon), findsOneWidget);
      final icon = tester.widget<DivineIcon>(find.byType(DivineIcon));
      expect(icon.color, VineTheme.vineGreen);
    });

    testWidgets('paints a green heart alongside a hashtag', (tester) async {
      await pump(tester, const LinkifiedText(text: '#vine $divineGreenHeart'));

      expect(find.byType(DivineIcon), findsOneWidget);
    });

    testWidgets('bounds painted hearts across runs split by tokens', (
      tester,
    ) async {
      // The builder runs the splitter once per plain run between tokens, so
      // a per-run cap would reset on every hashtag and an interleaved note
      // (one heart per tag) would still build one SVG widget per heart.
      // The budget is shared across the whole build instead.
      await pump(
        tester,
        LinkifiedText(
          text: '#tag $divineGreenHeart ' * (kDivineHeartMaxPainted + 2),
        ),
      );

      expect(find.byType(DivineIcon), findsNWidgets(kDivineHeartMaxPainted));
    });

    testWidgets('leaves text without a green heart on the plain path', (
      tester,
    ) async {
      await pump(tester, const LinkifiedText(text: 'nothing to see'));

      expect(find.byType(DivineIcon), findsNothing);
      expect(find.text('nothing to see'), findsOneWidget);
    });

    testWidgets('leaves a red heart to the platform emoji font', (
      tester,
    ) async {
      await pump(tester, const LinkifiedText(text: 'love ❤️'));

      expect(find.byType(DivineIcon), findsNothing);
    });

    testWidgets('keeps the platform glyph in selectable text so copy keeps '
        'the character', (tester) async {
      // SelectableText seeds its editing controller from the span plain
      // text, where a WidgetSpan heart contributes U+FFFC — a copied bio
      // would silently lose the character. That copy fidelity is why the
      // PR leaves selectable surfaces on the platform emoji font.
      await pump(
        tester,
        const SelectableLinkifiedText(text: 'bio $divineGreenHeart'),
      );

      expect(find.byType(DivineIcon), findsNothing);
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.controller.text, contains(divineGreenHeart));
      expect(editable.controller.text.contains('\u{FFFC}'), isFalse);
    });

    testWidgets('keeps copy intact on the selectable rich path too', (
      tester,
    ) async {
      await pump(
        tester,
        const SelectableLinkifiedText(text: 'bio $divineGreenHeart #vine'),
      );

      expect(find.byType(DivineIcon), findsNothing);
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.controller.text, contains(divineGreenHeart));
      expect(editable.controller.text.contains('\u{FFFC}'), isFalse);
    });
  });
}
