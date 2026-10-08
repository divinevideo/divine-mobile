import 'dart:ui';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/media_chrome_backdrop.dart';

void main() {
  group(MediaChromeBackdrop, () {
    Widget buildSubject({
      required ThemeData theme,
      Color? color,
      BoxBorder? border,
      List<BoxShadow>? boxShadow,
    }) {
      return MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: theme,
        home: Center(
          child: MediaChromeBackdrop(
            borderRadius: BorderRadius.circular(12),
            color: color,
            border: border,
            boxShadow: boxShadow,
            child: const SizedBox.square(dimension: 40),
          ),
        ),
      );
    }

    BoxDecoration tintOf(WidgetTester tester) {
      final box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(MediaChromeBackdrop),
          matching: find.byType(DecoratedBox),
        ),
      );
      return box.decoration as BoxDecoration;
    }

    group('renders', () {
      testWidgets('blurs what is behind it with a sigma of 4', (tester) async {
        await tester.pumpWidget(buildSubject(theme: VineTheme.theme));

        final backdrop = tester.widget<BackdropFilter>(
          find.byType(BackdropFilter),
        );
        expect(backdrop.filter, equals(ImageFilter.blur(sigmaX: 4, sigmaY: 4)));
      });

      testWidgets('tints with scrim-30 under the dark theme', (tester) async {
        await tester.pumpWidget(buildSubject(theme: VineTheme.theme));

        expect(tintOf(tester).color, equals(VineTheme.scrim30));
      });

      testWidgets('tints with light media chrome under the light theme', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject(theme: VineTheme.lightTheme));

        expect(
          tintOf(tester).color,
          equals(VineTheme.lightColors.mediaChrome),
        );
      });

      testWidgets('tints with the color it is given instead of the theme', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(theme: VineTheme.lightTheme, color: VineTheme.scrim65),
        );

        expect(tintOf(tester).color, equals(VineTheme.scrim65));
      });

      testWidgets('paints the border and shadow it is given', (tester) async {
        final border = Border.all(color: VineTheme.scrim15);
        const shadows = [BoxShadow(color: VineTheme.shadow25, blurRadius: 4)];

        await tester.pumpWidget(
          buildSubject(
            theme: VineTheme.theme,
            border: border,
            boxShadow: shadows,
          ),
        );

        final tint = tintOf(tester);
        expect(tint.border, equals(border));
        expect(tint.boxShadow, equals(shadows));
      });
    });
  });
}
