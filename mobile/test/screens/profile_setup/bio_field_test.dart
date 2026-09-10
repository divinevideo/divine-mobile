// ABOUTME: Widget tests for BioField in the profile-setup form.
// ABOUTME: Covers the character counter for user input and programmatic load.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/profile_setup/widgets/bio_field.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group(BioField, () {
    late TextEditingController controller;

    setUp(() => controller = TextEditingController());
    tearDown(() => controller.dispose());

    Future<void> pump(WidgetTester tester) {
      return tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: Scaffold(body: BioField(controller: controller)),
        ),
      );
    }

    testWidgets('renders the localized label and empty counter', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text(l10n.profileSetupBioLabel), findsOneWidget);
      expect(find.text('0/1000'), findsOneWidget);
    });

    testWidgets('counter tracks user input', (tester) async {
      await pump(tester);
      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();
      expect(find.text('5/1000'), findsOneWidget);
    });

    testWidgets('counter tracks programmatic controller changes (load)', (
      tester,
    ) async {
      await pump(tester);
      controller.text = 'loaded bio';
      await tester.pump();
      expect(find.text('${'loaded bio'.length}/1000'), findsOneWidget);
    });

    testWidgets('counter follows a swapped controller', (
      tester,
    ) async {
      await pump(tester);

      final swapped = TextEditingController(text: 'abc');
      addTearDown(swapped.dispose);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: Scaffold(body: BioField(controller: swapped)),
        ),
      );
      await tester.pump();
      expect(find.text('3/1000'), findsOneWidget);

      // Mutating the new controller drives the counter only if the field
      // listens to the instance it was last handed.
      swapped.text = 'abcdef';
      await tester.pump();
      expect(find.text('6/1000'), findsOneWidget);
    });

    testWidgets('tapping the counter still focuses the field', (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: Scaffold(
            body: BioField(controller: controller, focusNode: focusNode),
          ),
        ),
      );

      // The counter is painted over the field's top-right corner. Left
      // hit-testable it wins that rectangle, and the tap escapes to the
      // screen's dismiss-the-keyboard gesture instead of reaching the input.
      // Missing the counter is the point — it sits behind an IgnorePointer,
      // so the tap is meant to fall through to the field underneath.
      await tester.tap(find.text('0/1000'), warnIfMissed: false);
      await tester.pump();

      expect(focusNode.hasFocus, isTrue);
    });
  });
}
