// ABOUTME: Tests accessibility semantics for the custom caption-style sheet.
// ABOUTME: Verifies color swatches expose their precise RGB values and action.

import 'dart:ui' show SemanticsAction, Tristate;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/video_editor/caption_style.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_caption_custom_style_sheet.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show LayerBackgroundMode;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  const customColor = Color.fromARGB(255, 100, 20, 20);

  Future<void> pumpSheet(
    WidgetTester tester, {
    Locale? locale,
    bool disableAnimations = false,
  }) async {
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final initial = CaptionCustomStyle.initial().copyWith(
      color: customColor,
      colorMode: LayerBackgroundMode.onlyColor,
    );

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: disableAnimations),
          child: child!,
        ),
        locale: locale,
        theme: VineTheme.theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () =>
                  showCaptionCustomStyleSheet(context, initial: initial),
              child: const Text('Open style sheet'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open style sheet'));
    await tester.pump(const Duration(milliseconds: 300));
  }

  String expectedLabel(AppLocalizations l10n) =>
      l10n.videoEditorColorPickerSwatchSemanticLabel(
        l10n.videoEditorColorPickerSemanticLabel,
        l10n.rgbColorSemanticLabel(100, 20, 20),
      );

  group('custom color swatch semantics', () {
    testWidgets('stops preview loops when animations are disabled', (
      tester,
    ) async {
      await pumpSheet(tester, disableAnimations: true);

      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('custom color swatch exposes RGB semantics', (tester) async {
      await pumpSheet(tester);

      final l10n = lookupAppLocalizations(const Locale('en'));
      final semantics = tester.getSemantics(
        find.bySemanticsLabel(expectedLabel(l10n)),
      );
      final data = semantics.getSemanticsData();

      expect(data.flagsCollection.isButton, isTrue);
      expect(data.flagsCollection.isSelected, Tristate.isTrue);
      expect(data.hasAction(SemanticsAction.tap), isTrue);
    });

    testWidgets('custom color swatch joins its label the way the locale lists', (
      tester,
    ) async {
      // Japanese lists with '、', so a swatch label rebuilt by hand with a Latin
      // ', ' would still read correctly in English and wrong here. Pinning ja is
      // what stops the join from drifting back into Dart.
      await pumpSheet(tester, locale: const Locale('ja'));

      final ja = lookupAppLocalizations(const Locale('ja'));
      expect(expectedLabel(ja), contains('、'));
      expect(find.bySemanticsLabel(expectedLabel(ja)), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          expectedLabel(lookupAppLocalizations(const Locale('en'))),
        ),
        findsNothing,
      );
    });
  });
}
