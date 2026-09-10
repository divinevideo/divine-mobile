// ABOUTME: Widget tests for the image crop editor's bottom action bar.
// ABOUTME: Covers the rotate/flip/reset actions, labels, and callbacks.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/image_crop_editor/widgets/image_crop_editor_bottom_bar.dart';

void main() {
  group(ImageCropEditorBottomBar, () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    Future<void> pump(
      WidgetTester tester, {
      VoidCallback? onRotate,
      VoidCallback? onFlip,
      VoidCallback? onReset,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: Scaffold(
            body: ImageCropEditorBottomBar(
              onRotate: onRotate ?? () {},
              onFlip: onFlip ?? () {},
              onReset: onReset ?? () {},
            ),
          ),
        ),
      );
    }

    testWidgets('renders the rotate, flip and reset actions', (tester) async {
      await pump(tester);

      expect(find.text(l10n.imageCropEditorRotateLabel), findsOneWidget);
      expect(find.text(l10n.imageCropEditorFlipLabel), findsOneWidget);
      expect(find.text(l10n.imageCropEditorResetLabel), findsOneWidget);
      expect(find.byType(DivineIcon), findsNWidgets(3));
    });

    testWidgets('invokes onRotate when the rotate action is tapped', (
      tester,
    ) async {
      var rotated = false;
      await pump(tester, onRotate: () => rotated = true);

      await tester.tap(find.text(l10n.imageCropEditorRotateLabel));
      await tester.pump();

      expect(rotated, isTrue);
    });

    testWidgets('invokes onFlip when the flip action is tapped', (
      tester,
    ) async {
      var flipped = false;
      await pump(tester, onFlip: () => flipped = true);

      await tester.tap(find.text(l10n.imageCropEditorFlipLabel));
      await tester.pump();

      expect(flipped, isTrue);
    });

    testWidgets('invokes onReset when the reset action is tapped', (
      tester,
    ) async {
      var reset = false;
      await pump(tester, onReset: () => reset = true);

      await tester.tap(find.text(l10n.imageCropEditorResetLabel));
      await tester.pump();

      expect(reset, isTrue);
    });
  });
}
