// ABOUTME: Tests the literal navigation path AST guard.
// ABOUTME: Pins which call shapes count as a literal location and which do not.

import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports, scripts live outside lib/.
import '../../scripts/lib/literal_navigation_path_detector.dart';

void main() {
  group('literal navigation path detector', () {
    test('finds a literal path on one line', () {
      final sites = findLiteralNavigationPathsInSource(
        "void a(BuildContext context) => context.go('/home/0');",
      );

      expect(sites, hasLength(1));
      expect(sites.single.method, 'go');
      expect(sites.single.location, "'/home/0'");
      expect(sites.single.line, 1);
    });

    test('finds a path that dart format wrapped onto the next line', () {
      final sites = findLiteralNavigationPathsInSource('''
void a(BuildContext context) {
  context.push(
    '/content-filters',
  );
}
''');

      expect(sites.map((site) => site.line), [2]);
    });

    test('finds interpolated, adjacent and concatenated paths', () {
      final sites = findLiteralNavigationPathsInSource(r'''
void a(BuildContext context, String npub, String id) {
  context.go('/profile/$npub');
  context.push('/people-lists/' '$id');
  context.push('/video/' + id);
  context.go(('/home/0'));
}
''');

      expect(sites.map((site) => site.line), [2, 3, 4, 5]);
    });

    test('finds typed pushes and calls on any router target', () {
      final sites = findLiteralNavigationPathsInSource('''
void a(BuildContext context, GoRouter router) {
  context.push<void>('/settings');
  GoRouter.of(context).go('/home/0');
  router.push('/inbox');
  router..go('/explore');
}
''');

      expect(sites.map((site) => site.method), ['push', 'go', 'push', 'go']);
    });

    test('finds every method that takes a location first', () {
      final sites = findLiteralNavigationPathsInSource('''
void a(BuildContext context) {
  context.pushReplacement('/a');
  context.replace('/b');
  context.pushWithVideoPause('/c');
  pushDetached('/d', 'open d');
  _push('/e');
}
''');

      expect(sites.map((site) => site.method), [
        'pushReplacement',
        'replace',
        'pushWithVideoPause',
        'pushDetached',
        '_push',
      ]);
    });

    test('ignores comments and dartdoc', () {
      final sites = findLiteralNavigationPathsInSource('''
/// context.pushWithVideoPause('/profile/npub1...');
void a(BuildContext context) {
  // context.go('/home/0');
  context.go(RoutePaths.root);
}
''');

      expect(sites, isEmpty);
    });

    test('ignores a literal that is not the first positional argument', () {
      final sites = findLiteralNavigationPathsInSource('''
void a(BuildContext context) {
  context.push(RoutePaths.contentFilters, extra: '/not-a-location');
  pushDetached(RoutePaths.accountStatus, '/a description');
  context.go(extra: '/named-first', RoutePaths.root);
}
''');

      expect(sites, isEmpty);
    });

    test('ignores RoutePaths and screen path builders', () {
      final sites = findLiteralNavigationPathsInSource('''
void a(BuildContext context, String npub) {
  context.go(RoutePaths.videoFeedForIndex(0));
  context.push(OtherProfileScreen.pathForNpub(npub));
  context.go(WelcomeScreen.createAccountPath);
}
''');

      expect(sites, isEmpty);
    });

    test('ignores strings that do not start with a slash', () {
      final sites = findLiteralNavigationPathsInSource(r'''
void a(BuildContext context, String npub) {
  context.go('home');
  context.go('${RoutePaths.profile}/$npub');
  context.push('' '/later');
}
''');

      expect(sites, isEmpty);
    });

    test('ignores other calls that take a path', () {
      final sites = findLiteralNavigationPathsInSource('''
void a(Uri base) {
  base.resolve('/relative');
  print('/home/0');
  Navigator.of(context).pushNamed('/legacy');
}
''');

      expect(sites, isEmpty);
    });

    test('scan filter includes app libraries only', () {
      expect(shouldScanNavigationFile('lib/a.dart'), isTrue);
      expect(shouldScanNavigationFile('lib/router/a.dart'), isTrue);
      expect(shouldScanNavigationFile('test/a_test.dart'), isFalse);
      expect(shouldScanNavigationFile('integration_test/a.dart'), isFalse);
      expect(shouldScanNavigationFile('lib/a.g.dart'), isFalse);
      expect(shouldScanNavigationFile('lib/a.freezed.dart'), isFalse);
      expect(shouldScanNavigationFile('lib/a.txt'), isFalse);
    });
  });
}
