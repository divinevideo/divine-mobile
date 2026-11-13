// ABOUTME: Tests the Edit Profile row that opens the external NIP-05 flow.
// ABOUTME: Pins that a tap pushes NIP-05 settings over the profile form.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/profile_setup/widgets/nip05_row.dart';
import 'package:openvine/screens/settings/nip05_settings_screen.dart';
import 'package:openvine/screens/settings/nostr_settings_screen.dart';

void main() {
  group(Nip05Row, () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    testWidgets('a tap pushes NIP-05 settings over the profile form', (
      tester,
    ) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Nip05Row()),
          ),
          GoRoute(
            path: NostrSettingsScreen.path,
            builder: (_, _) => const Text('nostr-settings'),
            routes: [
              GoRoute(
                path: Nip05SettingsScreen.subpath,
                name: Nip05SettingsScreen.routeName,
                builder: (_, _) => const Text('nip05-settings'),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          routerConfig: router,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.profileSetupUseOwnNip05));
      await tester.pumpAndSettle();

      expect(find.text('nip05-settings'), findsOneWidget);
      // Pushed, not gone to: the form is still underneath, offstage.
      expect(find.byType(Nip05Row, skipOffstage: false), findsOneWidget);
    });
  });
}
