// ABOUTME: Guards the campaign following route against /following/:pubkey.
// ABOUTME: The literal route must stay in the earlier shell route module.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('campaign following route order', () {
    test('literal route is registered before the pubkey route module', () {
      final appRouter = File('lib/router/app_router.dart').readAsStringSync();
      final shellOffset = appRouter.indexOf('...shellRoutes()');
      final profileOffset = appRouter.indexOf('...profileRoutes()');
      final shell = File('lib/router/routes/shell.dart').readAsStringSync();

      expect(shell.indexOf('RoutePaths.followingNew'), isNonNegative);
      expect(shellOffset, isNonNegative);
      expect(profileOffset, greaterThan(shellOffset));
    });
  });
}
