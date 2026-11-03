// ABOUTME: Pins that the DM inbox prototype route exists only in debug
// ABOUTME: builds, so a typed URL cannot reach it in a release build.

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

    test('registers nothing when disabled, as in a release build', () {
      expect(dmInboxPrototypeRoutes(enabled: false), isEmpty);
    });
  });
}
