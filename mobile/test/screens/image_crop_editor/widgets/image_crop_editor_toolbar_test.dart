// ABOUTME: Widget tests for the image crop editor's top toolbar chrome.
// ABOUTME: Covers close/done buttons, callbacks, and the disabled-done state.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/image_crop_editor/widgets/image_crop_editor_toolbar.dart';

void main() {
  group(ImageCropEditorToolbar, () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    Finder buttonWithIcon(DivineIconName icon) => find.byWidgetPredicate(
      (widget) => widget is DivineIconButton && widget.icon == icon,
    );

    Future<void> pump(
      WidgetTester tester, {
      required VoidCallback onClose,
      VoidCallback? onDone,
      ThemeData? theme,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: theme ?? VineTheme.theme,
          home: Scaffold(
            appBar: ImageCropEditorToolbar(onClose: onClose, onDone: onDone),
          ),
        ),
      );
    }

    Color? glyphColor(WidgetTester tester, DivineIconName icon) => tester
        .widget<DivineIcon>(
          find.descendant(
            of: buttonWithIcon(icon),
            matching: find.byType(DivineIcon),
          ),
        )
        .color;

    testWidgets('renders close and done buttons', (tester) async {
      await pump(tester, onClose: () {}, onDone: () {});

      expect(buttonWithIcon(DivineIconName.x), findsOneWidget);
      expect(buttonWithIcon(DivineIconName.check), findsOneWidget);
    });

    testWidgets('invokes onClose when the close button is tapped', (
      tester,
    ) async {
      var closed = false;
      await pump(tester, onClose: () => closed = true, onDone: () {});

      await tester.tap(buttonWithIcon(DivineIconName.x));
      await tester.pump();

      expect(closed, isTrue);
    });

    testWidgets('invokes onDone when the done button is tapped', (
      tester,
    ) async {
      var done = false;
      await pump(tester, onClose: () {}, onDone: () => done = true);

      await tester.tap(buttonWithIcon(DivineIconName.check));
      await tester.pump();

      expect(done, isTrue);
    });

    testWidgets('disables the done button when onDone is null', (tester) async {
      await pump(tester, onClose: () {});

      final doneButton = tester.widget<DivineIconButton>(
        buttonWithIcon(DivineIconName.check),
      );
      expect(doneButton.onPressed, isNull);
    });

    testWidgets('close glyph follows the palette on light', (tester) async {
      await pump(tester, onClose: () {}, theme: VineTheme.lightTheme);

      // `CropRotateEditor` puts this bar in a plain `Scaffold.appBar` over
      // `CropRotateEditorStyle.background`, which the screen sets to
      // `colors.surface` — #FFFFFF on light. A fixed light glyph on the 15%
      // scrim over that is 1.39:1; the palette token is 9.07:1.
      expect(
        glyphColor(tester, DivineIconName.x),
        VineTheme.lightColors.onSurface,
      );
      expect(glyphColor(tester, DivineIconName.x), isNot(VineTheme.onSurface));
    });

    testWidgets('close glyph stays light on dark', (tester) async {
      await pump(tester, onClose: () {}, theme: VineTheme.theme);

      expect(glyphColor(tester, DivineIconName.x), VineTheme.onSurface);
    });

    testWidgets('labels the buttons for screen readers', (tester) async {
      await pump(tester, onClose: () {}, onDone: () {});

      expect(
        find.bySemanticsLabel(l10n.imageCropEditorCloseSemanticLabel),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(l10n.imageCropEditorDoneSemanticLabel),
        findsOneWidget,
      );
    });
  });
}
