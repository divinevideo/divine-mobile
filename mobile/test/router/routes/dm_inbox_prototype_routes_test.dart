// ABOUTME: Pins that the DM inbox prototype route registers only when
// ABOUTME: enabled, which defaults to debug builds.

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/prototypes/dm_inbox_tabs/dm_inbox_tabs_prototype_screen.dart';
import 'package:openvine/router/routes/dm_inbox_prototype_routes.dart';

void main() {
  group('dmInboxPrototypeRoutes', () {
    test('registers the prototype route in a debug build', () {
      // Tests run in debug mode, so the default is the debug-build value.
      final routes = dmInboxPrototypeRoutes();

      expect(routes, hasLength(1));
      expect(
        (routes.single as GoRoute).path,
        equals(DmInboxTabsPrototypeScreen.path),
      );
    });

    test('registers nothing when disabled', () {
      // The release-build gate itself is the const `kDebugMode` at the call
      // site in settings_routes.dart, which a debug-mode test cannot reach.
      expect(dmInboxPrototypeRoutes(enabled: false), isEmpty);
    });
  });
}
