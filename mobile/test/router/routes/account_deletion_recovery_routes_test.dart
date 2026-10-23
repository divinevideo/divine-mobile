// ABOUTME: Tests the typed account-deletion recovery route.
// ABOUTME: Pins that navigation lands where the deletion gate redirects.

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/router/routes/account_deletion_recovery_routes.dart';
import 'package:openvine/screens/account_deletion_recovery_screen.dart';

void main() {
  group(AccountDeletionRecoveryRouteData, () {
    // The deletion gate in app_router_redirect.dart redirects to the raw path,
    // so a typed route registered anywhere else would leave the gate pointing
    // at no route, and the user on the unknown-path error screen.
    test('navigates to the path the deletion gate redirects to', () {
      expect(
        const AccountDeletionRecoveryRouteData().location,
        equals(AccountDeletionRecoveryScreen.path),
      );
    });

    test('resolves its location to the named recovery route', () {
      final router = GoRouter(routes: accountDeletionRecoveryRoutes());
      addTearDown(router.dispose);

      final match = router.configuration.findMatch(
        Uri.parse(RoutePaths.accountDeletionRecovery),
      );

      expect(match.isError, isFalse);
      expect(
        match.last.route,
        isA<GoRoute>().having(
          (route) => route.name,
          'name',
          AccountDeletionRecoveryScreen.routeName,
        ),
      );
    });
  });
}
