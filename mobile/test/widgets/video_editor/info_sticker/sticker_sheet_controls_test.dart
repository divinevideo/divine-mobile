// ABOUTME: Tests the controls the sticker sheets share: the button keeps its
// ABOUTME: label whole on one line while the keyboard is up.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/info_sticker/sticker_sheet_controls.dart';

import '../../../helpers/text_lines.dart';

void main() {
  group(StickerSheetButton, () {
    group('renders', () {
      testWidgets('a long label whole on one line while the keyboard is up', (
        tester,
      ) async {
        // An iPhone SE at the largest iOS text size, typing in German.
        tester.view.physicalSize = const Size(375, 667);
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = const FakeViewPadding(bottom: 260);
        tester.platformDispatcher.textScaleFactorTestValue = 3.12;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final label = lookupAppLocalizations(
          const Locale('de'),
        ).videoEditorInfoStickerAdd;
        await tester.pumpWidget(
          MaterialApp(
            theme: VineTheme.theme,
            locale: const Locale('de'),
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            // A sheet sees the keyboard's inset, which a resizing Scaffold
            // would take from its body.
            home: Scaffold(
              resizeToAvoidBottomInset: false,
              body: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: StickerSheetButton(label: label, onPressed: () {}),
                ),
              ),
            ),
          ),
        );

        final text = find.text(label);
        expect(
          tester.renderObject<RenderParagraph>(text).didExceedMaxLines,
          isFalse,
        );
        expect(lineCountOf(tester, text), equals(1));
      });
    });
  });
}
