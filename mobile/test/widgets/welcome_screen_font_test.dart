// ABOUTME: Widget test for AuthHeroSection text rendering
// ABOUTME: Verifies that the hero tagline text renders correctly

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/auth/auth_hero_section.dart';

void main() {
  group('AuthHeroSection', () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    testWidgets('renders hero tagline text correctly', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: AuthHeroSection()),
        ),
      );

      // Verify hero tagline text
      expect(find.text(l10n.authHeroTaglineAuthentic), findsOneWidget);
      expect(find.text(l10n.authHeroTaglineHuman), findsOneWidget);
    });

    testWidgets('uses BricolageGrotesque font family', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: AuthHeroSection()),
        ),
      );

      final greenText = tester.widget<Text>(
        find.text(l10n.authHeroTaglineAuthentic),
      );
      expect(
        greenText.style?.fontFamily,
        equals(VineTheme.fontFamilyBricolage),
      );
      expect(greenText.style?.fontWeight, equals(FontWeight.w800));

      final whiteText = tester.widget<Text>(
        find.text(l10n.authHeroTaglineHuman),
      );
      expect(
        whiteText.style?.fontFamily,
        equals(VineTheme.fontFamilyBricolage),
      );
      expect(whiteText.style?.fontWeight, equals(FontWeight.w800));
    });
  });
}
