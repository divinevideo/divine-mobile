import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/linkified_text/linkified_text_widgets.dart';

void main() {
  group('Inline link appearance', () {
    for (final (name, theme, colors) in [
      ('dark', VineTheme.theme, VineTheme.darkColors),
      ('light', VineTheme.lightTheme, VineTheme.lightColors),
    ]) {
      for (final selectable in [false, true]) {
        testWidgets(
          '$name ${selectable ? 'selectable' : 'plain'} links have a non-color cue',
          (tester) async {
            const content = 'Read #topic at https://example.com';
            await tester.pumpWidget(
              MaterialApp(
                theme: theme,
                localizationsDelegates: appLocalizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: selectable
                      ? const SelectableLinkifiedText(text: content)
                      : const LinkifiedText(text: content),
                ),
              ),
            );

            final root = selectable
                ? tester
                      .widget<SelectableText>(find.byType(SelectableText))
                      .textSpan!
                : tester.widget<Text>(find.byType(Text)).textSpan! as TextSpan;
            final spans = root.children!.cast<TextSpan>();
            final links = spans.where((span) => span.recognizer != null);
            expect(links, hasLength(2));
            for (final link in links) {
              expect(link.style?.color, colors.link);
              expect(link.style?.decoration, TextDecoration.underline);
              expect(link.style?.decorationColor, colors.link);
            }
            for (final span in spans.where((span) => span.recognizer == null)) {
              expect(span.style?.decoration, isNot(TextDecoration.underline));
            }
          },
        );

        testWidgets(
          '$name ${selectable ? 'selectable' : 'plain'} preserves explicit media styles',
          (tester) async {
            const mediaStyle = TextStyle(color: VineTheme.whiteText);
            const content = 'Read #topic';
            await tester.pumpWidget(
              MaterialApp(
                theme: theme,
                localizationsDelegates: appLocalizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: selectable
                      ? const SelectableLinkifiedText(
                          text: content,
                          linkStyle: mediaStyle,
                        )
                      : const LinkifiedText(
                          text: content,
                          linkStyle: mediaStyle,
                        ),
                ),
              ),
            );

            final root = selectable
                ? tester
                      .widget<SelectableText>(find.byType(SelectableText))
                      .textSpan!
                : tester.widget<Text>(find.byType(Text)).textSpan! as TextSpan;
            final link = root.children!.cast<TextSpan>().singleWhere(
              (span) => span.recognizer != null,
            );
            expect(link.style, mediaStyle);
          },
        );
      }
    }
  });
}
