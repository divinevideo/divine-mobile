// ABOUTME: Tests the generator that bundles service suites into one entrypoint.
// ABOUTME: Pins the tag, the per-suite groups, and the path guards.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('write_service_suite_bundle.sh', () {
    late Directory sandbox;
    late String scriptPath;

    setUp(() {
      sandbox = Directory.systemTemp.createTempSync('service_suite_bundle_');
      scriptPath = File(
        p.join(
          Directory.current.path,
          'scripts',
          'ci',
          'write_service_suite_bundle.sh',
        ),
      ).absolute.path;
      for (final name in ['alpha_test.dart', 'beta_test.dart']) {
        File(p.join(sandbox.path, 'integration_test', 'e2e', name))
          ..parent.createSync(recursive: true)
          ..writeAsStringSync('void main() {}\n');
      }
    });

    tearDown(() {
      if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
    });

    ProcessResult runScript(List<String> arguments) => Process.runSync(
      'bash',
      [scriptPath, ...arguments],
      workingDirectory: sandbox.path,
    );

    File bundleFile() =>
        File(p.join(sandbox.path, 'integration_test', 'bundle_test.dart'));

    test('runs every suite under a group named after its file', () {
      final result = runScript([
        'integration_test/bundle_test.dart',
        'integration_test/e2e/alpha_test.dart',
        'integration_test/e2e/beta_test.dart',
      ]);

      expect(result.exitCode, 0, reason: result.stderr.toString());
      final source = bundleFile().readAsStringSync();
      expect(
        source,
        contains("import 'e2e/alpha_test.dart' as suite_0;\n"),
      );
      expect(source, contains("import 'e2e/beta_test.dart' as suite_1;\n"));
      expect(
        source,
        contains(
          "  group('integration_test/e2e/alpha_test.dart', suite_0.main);\n"
          "  group('integration_test/e2e/beta_test.dart', suite_1.main);\n",
        ),
      );
    });

    // The workflow runs the bundle with `--tags service`, and package:test
    // reads suite tags from the entrypoint only, never from an imported
    // library. Without this line the filter would select no test at all.
    test('tags the bundle itself as a service suite', () {
      final result = runScript([
        'integration_test/bundle_test.dart',
        'integration_test/e2e/alpha_test.dart',
      ]);

      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(
        bundleFile().readAsStringSync(),
        contains("@Tags(['service'])\nlibrary;\n"),
      );
    });

    test('refuses a bundle below integration_test/', () {
      final result = runScript([
        'integration_test/e2e/bundle_test.dart',
        'integration_test/e2e/alpha_test.dart',
      ]);

      expect(result.exitCode, 64);
      expect(
        File(
          p.join(sandbox.path, 'integration_test', 'e2e', 'bundle_test.dart'),
        ).existsSync(),
        isFalse,
      );
    });

    test('writes nothing when a suite is missing', () {
      final result = runScript([
        'integration_test/bundle_test.dart',
        'integration_test/e2e/alpha_test.dart',
        'integration_test/e2e/missing_test.dart',
      ]);

      expect(result.exitCode, 1);
      expect(result.stderr.toString(), contains('missing_test.dart'));
      expect(bundleFile().existsSync(), isFalse);
    });
  });
}
