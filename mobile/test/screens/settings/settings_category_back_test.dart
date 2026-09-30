// ABOUTME: New Settings destinations can return to Settings from cold deep links.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/screens/settings/settings_categories_screen.dart';

void main() {
  testWidgets('Help & About returns to Settings on cold entry', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: HelpAboutSettingsScreen.path,
      routes: [
        GoRoute(
          path: RoutePaths.settings,
          builder: (_, _) => const Scaffold(body: Text('Settings fallback')),
        ),
        GoRoute(
          path: HelpAboutSettingsScreen.path,
          builder: (_, _) => const HelpAboutSettingsScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();
    expect(router.canPop(), isFalse);

    tester.widget<DiVineAppBar>(find.byType(DiVineAppBar)).onBackPressed!();
    await tester.pumpAndSettle();
    expect(find.text('Settings fallback'), findsOneWidget);
  });
}
