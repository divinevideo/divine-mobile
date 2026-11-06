// ABOUTME: Pins shared go_router page-name fallback behavior.
// ABOUTME: Covers shell states whose name and path are null in production.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/router/go_router_page_name.dart';

class _FakeGoRouterState extends Fake implements GoRouterState {
  _FakeGoRouterState({
    this.name,
    this.path,
    this.topRoute,
    this.fullPath,
    Uri? uri,
  }) : uri = uri ?? Uri(path: '/');

  @override
  final String? name;

  @override
  final String? path;

  @override
  final GoRoute? topRoute;

  @override
  final String? fullPath;

  @override
  final Uri uri;
}

GoRoute _goRoute({required String path, required String name}) {
  return GoRoute(
    path: path,
    name: name,
    builder: (_, _) => const SizedBox.shrink(),
  );
}

void main() {
  group(goRouterPageName, () {
    test('prefers the explicit route name', () {
      expect(
        goRouterPageName(
          _FakeGoRouterState(
            name: 'video-recorder',
            path: '/video-recorder',
            topRoute: _goRoute(path: '/home', name: 'home'),
            fullPath: '/home',
          ),
        ),
        'video-recorder',
      );
    });

    test('falls back to route path when a route has no name', () {
      expect(goRouterPageName(_FakeGoRouterState(path: '/drafts')), '/drafts');
    });

    test('uses topRoute name for shell states', () {
      expect(
        goRouterPageName(
          _FakeGoRouterState(
            topRoute: _goRoute(path: '/home', name: 'home'),
            fullPath: '/home',
          ),
        ),
        'home',
      );
    });

    test('falls back to fullPath when no stable name is available', () {
      expect(
        goRouterPageName(_FakeGoRouterState(fullPath: '/search/:query')),
        '/search/:query',
      );
    });

    test('normalizes unnamed shell tab path templates to screen names', () {
      expect(
        goRouterPageName(_FakeGoRouterState(path: '/notifications/:index')),
        'notifications',
      );
      expect(
        goRouterPageName(_FakeGoRouterState(path: '/explore/tab/:name')),
        'explore',
      );
      expect(
        goRouterPageName(_FakeGoRouterState(path: '/profile/:npub/:index')),
        'profile',
      );
    });

    test(
      'uses concrete shell URI path when go_router leaves name and path null',
      () {
        expect(
          goRouterPageName(_FakeGoRouterState(uri: Uri(path: '/inbox'))),
          'inbox',
        );
      },
    );
  });
}
