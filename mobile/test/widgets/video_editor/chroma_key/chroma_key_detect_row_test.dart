// ABOUTME: Pins how Auto-detect and the green/blue presets reflow, so no
// ABOUTME: language or text size on a small phone overflows or cuts a label.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/chroma_key/chroma_key_detect_row.dart';

void main() {
  group(ChromaKeyDetectRow, () {
    /// The panel's side gutter, so the row is as wide as it is on a phone.
    const gutter = 16.0;

    /// The iOS text scale at its largest accessibility size.
    const largestIosScale = 3.12;

    Future<void> pump(
      WidgetTester tester, {
      required Locale locale,
      double screenWidth = 375,
      double textScale = 1,
      TextDirection? textDirection,
      VoidCallback? onDetect,
      VoidCallback? onGreenPreset,
      VoidCallback? onBluePreset,
    }) async {
      tester.view.physicalSize = Size(screenWidth * 3, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Widget row = ChromaKeyDetectRow(
        isDetecting: false,
        onDetect: onDetect ?? () {},
        onGreenPreset: onGreenPreset ?? () {},
        onBluePreset: onBluePreset ?? () {},
      );
      if (textDirection != null) {
        row = Directionality(textDirection: textDirection, child: row);
      }

      await tester.pumpWidget(
        MaterialApp(
          theme: VineTheme.theme,
          locale: locale,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.all(gutter),
                child: row,
              ),
            ),
          ),
        ),
      );
    }

    /// The three buttons' rectangles: Auto-detect, Green, Blue.
    List<Rect> buttonRects(WidgetTester tester, Locale locale) {
      final l10n = lookupAppLocalizations(locale);
      return [
        for (final label in [
          l10n.videoEditorChromaKeyAutoDetect,
          l10n.videoEditorChromaKeyPresetGreen,
          l10n.videoEditorChromaKeyPresetBlue,
        ])
          tester.getRect(
            find.ancestor(
              of: find.text(label),
              matching: find.byType(DivineButton),
            ),
          ),
      ];
    }

    group('renders', () {
      testWidgets('keeps all three on one row when they fit', (tester) async {
        const en = Locale('en');
        await pump(tester, locale: en);

        final [autoDetect, green, blue] = buttonRects(tester, en);
        expect(green.top, equals(autoDetect.top));
        expect(blue.top, equals(autoDetect.top));
        expect(autoDetect.right, lessThan(green.left));
        expect(green.right, lessThan(blue.left));
        // Auto-detect stretches over what the presets leave, as the plain
        // Row it replaces did, so the default English look is unchanged.
        expect(autoDetect.left, equals(gutter));
        expect(blue.right, equals(375 - gutter));
      });

      testWidgets(
        'gives Auto-detect a row of its own when the three do not fit',
        (tester) async {
          // "Wykryj automatycznie" was cut to "Wykr…" at the normal text size
          // on a 375pt phone when all three shared one row (#10796).
          const pl = Locale('pl');
          await pump(tester, locale: pl);

          final [autoDetect, green, blue] = buttonRects(tester, pl);
          expect(autoDetect.width, equals(375 - gutter * 2));
          expect(green.top, greaterThan(autoDetect.bottom));
          expect(blue.top, equals(green.top));
          expect(green.width, equals(blue.width));
          expect(green.left, equals(gutter));
          expect(blue.right, equals(375 - gutter));
        },
      );

      testWidgets(
        'gives every button a row when the presets cannot share one',
        (tester) async {
          // English overflowed by 14px here as a single row.
          const en = Locale('en');
          await pump(tester, locale: en, textScale: largestIosScale);

          final [autoDetect, green, blue] = buttonRects(tester, en);
          expect(green.top, greaterThan(autoDetect.bottom));
          expect(blue.top, greaterThan(green.bottom));
          for (final rect in [autoDetect, green, blue]) {
            expect(rect.width, equals(375 - gutter * 2));
          }
        },
      );

      testWidgets('mirrors both layouts right to left', (tester) async {
        const en = Locale('en');
        await pump(tester, locale: en, textDirection: TextDirection.rtl);

        var [autoDetect, green, blue] = buttonRects(tester, en);
        expect(autoDetect.right, equals(375 - gutter));
        expect(green.right, lessThan(autoDetect.left));
        expect(blue.right, lessThan(green.left));

        await pump(
          tester,
          locale: en,
          screenWidth: 360,
          textDirection: TextDirection.rtl,
        );

        [autoDetect, green, blue] = buttonRects(tester, en);
        expect(green.top, greaterThan(autoDetect.bottom));
        expect(green.right, equals(360 - gutter));
        expect(blue.left, equals(gutter));
      });

      for (final locale in AppLocalizations.supportedLocales) {
        testWidgets(
          'neither overflows nor cuts a label in ${locale.toLanguageTag()}',
          (tester) async {
            final l10n = lookupAppLocalizations(locale);
            // 360dp is the narrowest Android phone the app supports and 375pt
            // the iPhone SE; 3.12 is the largest iOS accessibility size.
            for (final screenWidth in [360.0, 375.0]) {
              for (final textScale in [1.0, 1.2, 1.4, 2.0, largestIosScale]) {
                await pump(
                  tester,
                  locale: locale,
                  screenWidth: screenWidth,
                  textScale: textScale,
                );
                final at = '$screenWidth wide at ${textScale}x';
                expect(tester.takeException(), isNull, reason: at);

                for (final label in [
                  l10n.videoEditorChromaKeyAutoDetect,
                  l10n.videoEditorChromaKeyPresetGreen,
                  l10n.videoEditorChromaKeyPresetBlue,
                ]) {
                  final paragraph = tester.renderObject<RenderParagraph>(
                    find.text(label),
                  );
                  expect(
                    paragraph.didExceedMaxLines,
                    isFalse,
                    reason: '"$label" was cut short $at',
                  );
                  // The widest unbreakable run of the label: wider than the
                  // line, and the line breaker split a word to fit it.
                  expect(
                    paragraph.getMinIntrinsicWidth(double.infinity),
                    lessThanOrEqualTo(paragraph.size.width),
                    reason: '"$label" broke inside a word $at',
                  );
                }
              }
            }
          },
        );
      }
    });

    group('interactions', () {
      testWidgets('reaches every button once the row reflows', (tester) async {
        var detected = 0;
        var green = 0;
        var blue = 0;
        const en = Locale('en');
        await pump(
          tester,
          locale: en,
          textScale: largestIosScale,
          onDetect: () => detected++,
          onGreenPreset: () => green++,
          onBluePreset: () => blue++,
        );

        final l10n = lookupAppLocalizations(en);
        await tester.tap(find.text(l10n.videoEditorChromaKeyAutoDetect));
        await tester.tap(find.text(l10n.videoEditorChromaKeyPresetGreen));
        await tester.tap(find.text(l10n.videoEditorChromaKeyPresetBlue));

        expect((detected, green, blue), equals((1, 1, 1)));
      });
    });
  });
}
