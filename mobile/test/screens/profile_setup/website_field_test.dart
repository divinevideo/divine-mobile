// ABOUTME: Widget tests for WebsiteField in the profile-setup form.
// ABOUTME: Covers label rendering and controller binding.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/profile_setup/widgets/website_field.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group(WebsiteField, () {
    late TextEditingController controller;

    setUp(() => controller = TextEditingController());
    tearDown(() => controller.dispose());

    Future<void> pump(WidgetTester tester) {
      return tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: Scaffold(body: WebsiteField(controller: controller)),
        ),
      );
    }

    testWidgets('renders the localized label', (tester) async {
      await pump(tester);

      expect(find.text(l10n.profileSetupWebsiteLabel), findsOneWidget);
    });

    testWidgets('typing updates the bound controller', (tester) async {
      await pump(tester);

      await tester.enterText(find.byType(TextField), 'https://divine.video');

      expect(controller.text, 'https://divine.video');
    });

    testWidgets('opens a URL keyboard', (tester) async {
      await pump(tester);

      expect(
        tester.widget<TextField>(find.byType(TextField)).keyboardType,
        TextInputType.url,
      );
    });

    testWidgets('does not autocorrect a typed web address', (tester) async {
      await pump(tester);

      expect(
        tester.widget<TextField>(find.byType(TextField)).autocorrect,
        isFalse,
      );
    });
  });
}
