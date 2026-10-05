import 'dart:ui';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/caption_pill.dart';

void main() {
  group(CaptionPill, () {
    const cueText = 'Hello there';

    Widget buildSubject({required ThemeData theme}) {
      return MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: theme,
        home: const Center(child: CaptionPill(text: cueText)),
      );
    }

    Color? tintBehindCue(WidgetTester tester) {
      final box = tester.widget<DecoratedBox>(
        find.ancestor(
          of: find.text(cueText),
          matching: find.byType(DecoratedBox),
        ),
      );
      return (box.decoration as BoxDecoration).color;
    }

    TextStyle styleOf(WidgetTester tester) =>
        tester.widget<Text>(find.text(cueText)).style!;

    group('renders', () {
      testWidgets('blurs the video behind the cue like the playback pill', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject(theme: VineTheme.theme));

        final backdrop = tester.widget<BackdropFilter>(
          find.ancestor(
            of: find.text(cueText),
            matching: find.byType(BackdropFilter),
          ),
        );
        expect(backdrop.filter, equals(ImageFilter.blur(sigmaX: 4, sigmaY: 4)));
      });

      testWidgets('white shadowed text on scrim-65 under the dark theme', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject(theme: VineTheme.theme));

        expect(tintBehindCue(tester), equals(VineTheme.scrim65));
        expect(styleOf(tester).color, equals(VineTheme.whiteText));
        expect(styleOf(tester).shadows, isNotEmpty);
      });

      testWidgets(
        'keeps white text on scrim-65 under the light theme instead of the '
        'light media chrome',
        (tester) async {
          await tester.pumpWidget(buildSubject(theme: VineTheme.lightTheme));

          expect(tintBehindCue(tester), equals(VineTheme.scrim65));
          expect(styleOf(tester).color, equals(VineTheme.whiteText));
        },
      );
    });
  });
}
