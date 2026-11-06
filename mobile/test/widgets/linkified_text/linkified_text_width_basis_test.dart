// ABOUTME: Tests LinkifiedText's textWidthBasis on both of its render paths,
// ABOUTME: plain text and text with links, so wrapped text can hug its width.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/linkified_text/linkified_text_widgets.dart';

const _maxWidth = 300.0;

void main() {
  group('LinkifiedText textWidthBasis', () {
    Future<double> pumpWidth(
      WidgetTester tester,
      String text, {
      TextWidthBasis? textWidthBasis,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _maxWidth),
                  child: LinkifiedText(
                    text: text,
                    textWidthBasis: textWidthBasis,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      return tester.getSize(find.byType(LinkifiedText)).width;
    }

    // Two words that each fill most of a line, so the text wraps after the
    // first and its longest line ends well short of the maximum width.
    final wrapsShort = '${'w' * 14} ${'w' * 14}';

    for (final (path, text) in [
      ('plain text', wrapsShort),
      ('text with a link', '#$wrapsShort'),
    ]) {
      group(path, () {
        testWidgets('fills the width by default', (tester) async {
          expect(await pumpWidth(tester, text), _maxWidth);
        });

        testWidgets('hugs its longest line with longestLine', (tester) async {
          expect(
            await pumpWidth(
              tester,
              text,
              textWidthBasis: TextWidthBasis.longestLine,
            ),
            lessThan(_maxWidth * 0.9),
          );
        });
      });
    }
  });
}
