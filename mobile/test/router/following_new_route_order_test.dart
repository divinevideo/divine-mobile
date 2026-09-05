// ABOUTME: Proves the campaign route beats /following/:pubkey in real routes.
// ABOUTME: This guards cross-module route ordering without app initialization.

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/router/routes/profile_routes.dart';
import 'package:openvine/router/routes/shell.dart';

void main() {
  group('campaign following route order', () {
    test('literal matches the shell route instead of the pubkey route', () {
      final router = GoRouter(
        initialLocation: RoutePaths.followingNew,
        routes: [...shellRoutes(), ...profileRoutes()],
      );
      addTearDown(router.dispose);

      final matches = router.configuration.findMatch(
        Uri.parse(RoutePaths.followingNew),
      );

      expect(matches.isError, isFalse);
      expect(matches.fullPath, RoutePaths.followingNew);
    });
  });
}
