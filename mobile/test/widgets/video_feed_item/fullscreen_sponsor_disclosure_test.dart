// ABOUTME: Widget tests for the fullscreen sponsorship disclosure.
// ABOUTME: Guards contrast, semantics, and large-text wrapping over video.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_feed_item/fullscreen_sponsor_disclosure.dart';

import '../../helpers/test_provider_overrides.dart';

void main() {
  group(FullscreenSponsorDisclosure, () {
    Widget buildSubject({double textScale = 1, Locale? locale}) {
      return testMaterialApp(
        locale: locale,
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: const Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 180,
                child: FullscreenSponsorDisclosure(
                  sponsorName: 'Acme Bikes',
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('maintains normal-text contrast over a bright frame', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());

      final decoration =
          tester
                  .widget<DecoratedBox>(
                    find.descendant(
                      of: find.byType(FullscreenSponsorDisclosure),
                      matching: find.byType(DecoratedBox),
                    ),
                  )
                  .decoration
              as BoxDecoration;
      final background = Color.alphaBlend(
        decoration.color!,
        VineTheme.whiteText,
      );
      final contrast = _contrastRatio(VineTheme.whiteText, background);

      expect(contrast, greaterThanOrEqualTo(4.5));
    });

    testWidgets('wraps the complete label at large text sizes', (tester) async {
      await tester.pumpWidget(buildSubject(textScale: 3));

      final text = tester.widget<Text>(
        find.descendant(
          of: find.byType(FullscreenSponsorDisclosure),
          matching: find.byType(Text),
        ),
      );
      final disclosureRect = tester.getRect(
        find.byType(FullscreenSponsorDisclosure),
      );

      expect(text.maxLines, isNull);
      expect(text.overflow, isNull);
      expect(disclosureRect.height, greaterThan(54));
      expect(tester.takeException(), isNull);
    });

    testWidgets('announces the complete localized disclosure', (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(buildSubject());
        final expected = lookupAppLocalizations(
          const Locale('en'),
        ).exploreFeaturedSponsoredBy('Acme Bikes');

        expect(find.bySemanticsLabel(expected), findsOneWidget);
      } finally {
        semanticsHandle.dispose();
      }
    });

    for (final language in ['es', 'ar', 'ko', 'te']) {
      testWidgets('$language disclosure stays complete at large text sizes', (
        tester,
      ) async {
        final locale = Locale(language);
        final l10n = lookupAppLocalizations(locale);
        final expected = l10n.exploreFeaturedSponsoredBy('Acme Bikes');
        final english = lookupAppLocalizations(
          const Locale('en'),
        ).exploreFeaturedSponsoredBy('Acme Bikes');
        final handle = tester.ensureSemantics();
        try {
          await tester.pumpWidget(buildSubject(locale: locale, textScale: 3));

          expect(expected, isNot(english));
          expect(find.text(expected), findsOneWidget);
          expect(find.text(english), findsNothing);
          expect(find.bySemanticsLabel(expected), findsOneWidget);
          final text = tester.widget<Text>(find.text(expected));
          expect(text.maxLines, isNull);
          expect(text.overflow, isNull);
          expect(
            Directionality.of(tester.element(find.text(expected))),
            language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
          );
          expect(tester.takeException(), isNull);
        } finally {
          handle.dispose();
        }
      });
    }
  });
}

double _contrastRatio(Color foreground, Color background) {
  final lighter = foreground.computeLuminance();
  final darker = background.computeLuminance();
  return (lighter + 0.05) / (darker + 0.05);
}
