// ABOUTME: Tests for the hand-written route ceiling ratchet (#3572).
// ABOUTME: Pins what counts as a hand-written route and the shrink-only contract.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Drives `scripts/check_hand_written_route_ceiling.sh` against an isolated
/// temp tree, so the detector and the ratchet contract are pinned without
/// touching the real baseline.
void main() {
  group('hand_written_route_ceiling ratchet', () {
    late Directory tmp;
    late String baselinePath;

    File libFile(String name) => File('${tmp.path}/lib/$name');

    ProcessResult run({bool update = false}) => Process.runSync(
      'bash',
      [File('scripts/check_hand_written_route_ceiling.sh').absolute.path],
      environment: {
        'HAND_WRITTEN_ROUTE_SCAN_DIR': '${tmp.path}/lib',
        'HAND_WRITTEN_ROUTE_PATH_PREFIX': tmp.path,
        'HAND_WRITTEN_ROUTE_BASELINE_FILE': baselinePath,
        'HAND_WRITTEN_ROUTE_BASELINE_REPO_PATH': 'does/not/exist/baseline.txt',
        'HAND_WRITTEN_ROUTE_BASELINE_BASE_REF': 'HEAD',
        if (update) 'UPDATE_BASELINE': '1',
      },
    );

    List<String> baselineRows() =>
        File(baselinePath)
            .readAsLinesSync()
            .where((l) => l.isNotEmpty && !l.startsWith('#'))
            .toList();

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('hand_written_route_test');
      Directory('${tmp.path}/lib').createSync(recursive: true);
      baselinePath = '${tmp.path}/baseline.txt';
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    test('counts every hand-written route construction, subclasses too', () {
      libFile('routes.dart').writeAsStringSync('''
final a = GoRoute(path: '/a', builder: build);
final b = ShellRoute(builder: shell, routes: []);
final c = StatefulShellRoute(builder: shell, branches: []);
final d = StatefulShellRoute.indexedStack(builder: shell, branches: []);
final e = FadeGoRoute(path: '/e', builder: build);
''');

      final res = run(update: true);
      expect(res.exitCode, 0, reason: res.stderr.toString());
      expect(baselineRows(), equals(['lib/routes.dart\t5']));
    });

    test('does not count typed routes, type references or prose', () {
      libFile('typed.dart').writeAsStringSync(r'''
@TypedGoRoute<HomeRouteData>(path: '/', routes: [
  TypedGoRoute<ChildRouteData>(path: 'child'),
])
@TypedShellRoute<FrameRouteData>(routes: [])
final r = GoRouteData.$route(path: '/', factory: f);
final List<GoRoute> routes = [];
final isGoRoute = route is GoRoute;
// a GoRoute( in a comment
/* ShellRoute( in a block comment */
final m = 'GoRoute( in a log line';
''');

      final res = run(update: true);
      expect(res.exitCode, 0, reason: res.stderr.toString());
      expect(baselineRows(), isEmpty);
    });

    test('does not count generated files', () {
      libFile(
        'routes.g.dart',
      ).writeAsStringSync("final a = GoRoute(path: '/a', builder: build);\n");

      final res = run(update: true);
      expect(res.exitCode, 0, reason: res.stderr.toString());
      expect(baselineRows(), isEmpty);
    });

    test('fails when a baselined file adds a hand-written route', () {
      libFile('routes.dart')
          .writeAsStringSync("final a = GoRoute(path: '/a');\n");
      expect(run(update: true).exitCode, 0);

      libFile('routes.dart').writeAsStringSync(
        "final a = GoRoute(path: '/a');\nfinal b = GoRoute(path: '/b');\n",
      );

      final res = run();
      expect(res.exitCode, 1);
      expect(res.stdout, contains('GREW past the frozen ceiling'));
      expect(res.stdout, contains('@TypedGoRoute'));
    });

    test('fails when a new file adds a hand-written route', () {
      libFile('routes.dart')
          .writeAsStringSync("final a = GoRoute(path: '/a');\n");
      expect(run(update: true).exitCode, 0);

      libFile('more_routes.dart').writeAsStringSync(
        "final b = GoRoute(path: '/b');\n",
      );

      final res = run();
      expect(res.exitCode, 1);
      expect(res.stdout, contains('NEW key(s) not in the baseline'));
      expect(res.stdout, contains('lib/more_routes.dart'));
    });

    test('a migrated route fails until the lower ceiling is committed', () {
      libFile('routes.dart').writeAsStringSync(
        "final a = GoRoute(path: '/a');\nfinal b = GoRoute(path: '/b');\n",
      );
      expect(run(update: true).exitCode, 0);

      libFile('routes.dart')
          .writeAsStringSync("final a = GoRoute(path: '/a');\n");

      final res = run();
      expect(res.exitCode, 1);
      expect(res.stdout, contains('DECREASED below the frozen ceiling'));
      expect(res.stdout, contains('2 -> 1'));

      expect(run(update: true).exitCode, 0);
      expect(baselineRows(), equals(['lib/routes.dart\t1']));
      expect(run().exitCode, 0);
    });
  });
}
