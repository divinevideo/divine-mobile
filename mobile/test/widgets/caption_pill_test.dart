import 'dart:ui';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/caption_pill.dart';

void main() {
  group(CaptionPill, () {
    const cueText = 'Hello there';

    Widget buildSubject({required ThemeData theme, Widget? beneath}) {
      return MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: theme,
        home: Stack(
          children: [
            if (beneath != null) Positioned.fill(child: beneath),
            const Center(child: CaptionPill(text: cueText)),
          ],
        ),
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

      testWidgets('white shadowed text on scrim-56 under the dark theme', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject(theme: VineTheme.theme));

        expect(tintBehindCue(tester), equals(VineTheme.scrim56));
        expect(styleOf(tester).color, equals(VineTheme.whiteText));
        expect(styleOf(tester).shadows, isNotEmpty);
      });

      testWidgets(
        'keeps white text on scrim-56 under the light theme instead of the '
        'light media chrome',
        (tester) async {
          await tester.pumpWidget(buildSubject(theme: VineTheme.lightTheme));

          expect(tintBehindCue(tester), equals(VineTheme.scrim56));
          expect(styleOf(tester).color, equals(VineTheme.whiteText));
        },
      );

      testWidgets('keeps the cue at 5:1 contrast over a pure-white frame', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject(theme: VineTheme.theme));

        // alphaBlend mixes in encoded sRGB, as the engine does: on the iOS
        // simulator this tint over pure white renders as #6F6F6F, the exact
        // value alphaBlend predicts. The glyph shadow does not count.
        final textLuminance = styleOf(tester).color!.computeLuminance();
        final groundLuminance = Color.alphaBlend(
          tintBehindCue(tester)!,
          VineTheme.whiteText,
        ).computeLuminance();
        final contrast = (textLuminance + 0.05) / (groundLuminance + 0.05);

        // At least 5:1, and no darker than the next alpha step requires.
        expect(contrast, inInclusiveRange(5.0, 5.05));
      });
    });

    group('interactions', () {
      testWidgets('lets taps and holds through to the video beneath it', (
        tester,
      ) async {
        var taps = 0;
        var holds = 0;
        await tester.pumpWidget(
          buildSubject(
            theme: VineTheme.theme,
            beneath: GestureDetector(
              onTap: () => taps++,
              onLongPress: () => holds++,
            ),
          ),
        );

        // Positive control: the video surface takes a tap beside the cue.
        await tester.tapAt(const Offset(4, 4));
        expect(taps, equals(1));

        final cueCenter = tester.getCenter(find.text(cueText));
        await tester.tapAt(cueCenter);
        await tester.longPressAt(cueCenter);

        expect(taps, equals(2));
        expect(holds, equals(1));
      });
    });
  });
}
