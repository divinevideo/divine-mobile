// ABOUTME: Widget tests for DisplayNameField in the profile-setup form.
// ABOUTME: Covers label rendering, card shape, and controller binding.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/profile_setup/widgets/display_name_field.dart';
import 'package:openvine/screens/profile_setup/widgets/profile_setup_rows.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group(DisplayNameField, () {
    late TextEditingController controller;
    late FocusNode focusNode;

    setUp(() {
      controller = TextEditingController();
      focusNode = FocusNode();
    });

    tearDown(() {
      controller.dispose();
      focusNode.dispose();
    });

    Future<void> pump(WidgetTester tester) {
      return tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: Scaffold(
            body: DisplayNameField(
              controller: controller,
              focusNode: focusNode,
            ),
          ),
        ),
      );
    }

    testWidgets('renders the localized label and nothing under it', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text(l10n.profileSetupDisplayNameLabel), findsOneWidget);
    });

    testWidgets('typing updates the bound controller', (tester) async {
      await pump(tester);

      await tester.enterText(find.byType(TextField), 'Alice');

      expect(controller.text, 'Alice');
    });

    testWidgets('takes focus from the node the parent owns', (tester) async {
      await pump(tester);

      focusNode.requestFocus();
      await tester.pump();

      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode,
        focusNode,
      );
      expect(focusNode.hasFocus, isTrue);
    });

    testWidgets('the keyboard next key moves focus to the following field', (
      tester,
    ) async {
      final nextField = FocusNode();
      addTearDown(nextField.dispose);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: Scaffold(
            body: Column(
              children: [
                DisplayNameField(controller: controller, focusNode: focusNode),
                TextField(focusNode: nextField),
                // Stands in for the NIP-05 select card: focusable, but with no
                // keyboard of its own. Landing here is the bug this pins.
                InkWell(onTap: () {}, child: const Text('select')),
              ],
            ),
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();

      expect(nextField.hasFocus, isTrue);
    });

    testWidgets('sits on the rounder profile card surface', (tester) async {
      await pump(tester);

      final field = tester.widget<DivineTextField>(
        find.byType(DivineTextField),
      );
      expect(field.filled, isTrue);
      expect(field.fillBorderRadius, profileFormCardRadius);
    });
  });
}
