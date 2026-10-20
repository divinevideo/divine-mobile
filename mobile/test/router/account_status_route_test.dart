// ABOUTME: Tests that the account status route parses as its own route and
// ABOUTME: round-trips through parseMatchedRoute/buildRoute (s-t-s#200).

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/router/providers/page_context_provider.dart';
import 'package:openvine/router/route_paths.dart';

void main() {
  group('account status route', () {
    test('parses to the account status context', () {
      final context = parseMatchedRoute(
        RoutePaths.accountStatus,
        matchedTemplate: RoutePaths.accountStatus,
      );

      expect(context, isNotNull);
      expect(context!.type, RouteType.accountStatus);
    });

    test('builds back to its path', () {
      expect(
        buildRoute(const RouteContext(type: RouteType.accountStatus)),
        RoutePaths.accountStatus,
      );
    });

    test('does not shadow the settings root', () {
      final context = parseMatchedRoute(
        RoutePaths.settings,
        matchedTemplate: RoutePaths.settings,
      );

      expect(context, isNotNull);
      expect(context!.type, isNot(RouteType.accountStatus));
    });
  });
}
