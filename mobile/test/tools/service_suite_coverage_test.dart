// ABOUTME: Tests complete accounting of headless service integration suites.
// ABOUTME: Pins duplicate, stale, reason, and exclusion-debt failure modes.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('check_service_suite_coverage.sh', () {
    late Directory sandbox;
    late String scriptPath;
    late File workflow;
    late Directory e2eDirectory;
    late File manifest;
    late File baseManifest;

    setUp(() {
      sandbox = Directory.systemTemp.createTempSync('service_suite_coverage_');
      scriptPath = File(
        p.join(
          Directory.current.path,
          'scripts',
          'check_service_suite_coverage.sh',
        ),
      ).absolute.path;
      workflow = File(p.join(sandbox.path, 'workflow.yaml'));
      e2eDirectory = Directory(
        p.join(sandbox.path, 'integration_test', 'e2e'),
      )..createSync(recursive: true);
      manifest = File(p.join(sandbox.path, 'exclusions.txt'));
      baseManifest = File(p.join(sandbox.path, 'base-exclusions.txt'));

      _writeSuite(e2eDirectory, 'focused_test.dart');
      _writeSuite(e2eDirectory, 'app_test.dart');
      _writeSuite(e2eDirectory, 'excluded_test.dart');
      workflow.writeAsStringSync(
        '# SERVICE_SUITE_LIST_START\n'
        'integration_test/e2e/focused_test.dart\n'
        'integration_test/e2e/app_test.dart\n'
        '# SERVICE_SUITE_LIST_END\n',
      );
      _writeManifest(manifest, const {
        'excluded_test.dart': 'requires unavailable service',
      });
      _writeManifest(baseManifest, const {
        'excluded_test.dart': 'requires unavailable service',
      });
    });

    tearDown(() {
      if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
    });

    ProcessResult runGuard() => Process.runSync(
      'bash',
      [scriptPath],
      environment: {
        ...Platform.environment,
        'SERVICE_SUITE_WORKFLOW_FILE': workflow.path,
        'SERVICE_SUITE_E2E_DIR': e2eDirectory.path,
        'SERVICE_SUITE_PATH_ROOT': sandbox.path,
        'SERVICE_SUITE_MANIFEST_FILE': manifest.path,
        'SERVICE_SUITE_BASE_MANIFEST': baseManifest.path,
        'SERVICE_SUITE_BASE_REF': 'test-base',
      },
    );

    test('accepts suites accounted for exactly once', () {
      final result = runGuard();

      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(result.stdout, contains('2 included, 1 excluded'));
    });

    test('rejects an unaccounted suite', () {
      _writeSuite(e2eDirectory, 'new_test.dart');

      final result = runGuard();

      expect(result.exitCode, 1);
      expect(result.stdout, contains('missing from the workflow'));
      expect(result.stdout, contains('new_test.dart'));
    });

    test('rejects a suite included more than once', () {
      workflow.writeAsStringSync(
        '# SERVICE_SUITE_LIST_START\n'
        'integration_test/e2e/focused_test.dart\n'
        'integration_test/e2e/app_test.dart\n'
        'integration_test/e2e/focused_test.dart\n'
        '# SERVICE_SUITE_LIST_END\n',
      );

      final result = runGuard();

      expect(result.exitCode, 1);
      expect(result.stdout, contains('duplicate included suites'));
    });

    test('rejects a workflow without the suite-list markers', () {
      workflow.writeAsStringSync(
        'integration_test/e2e/focused_test.dart\n'
        'integration_test/e2e/app_test.dart\n',
      );

      final result = runGuard();

      expect(result.exitCode, 1);
      expect(result.stdout, contains('exactly one service-suite list marker'));
    });

    test('rejects an exclusion without a reason', () {
      manifest.writeAsStringSync(
        'integration_test/e2e/excluded_test.dart |   \n',
      );

      final result = runGuard();

      expect(result.exitCode, 1);
      expect(result.stderr, contains('suite path and reason are required'));
    });

    test('rejects a suite that is both included and excluded', () {
      workflow.writeAsStringSync(
        '# SERVICE_SUITE_LIST_START\n'
        'integration_test/e2e/focused_test.dart\n'
        'integration_test/e2e/app_test.dart\n'
        'integration_test/e2e/excluded_test.dart\n'
        '# SERVICE_SUITE_LIST_END\n',
      );

      final result = runGuard();

      expect(result.exitCode, 1);
      expect(result.stdout, contains('both included and excluded'));
    });

    test('rejects an exclusion for a suite that does not exist', () {
      _writeManifest(manifest, const {
        'excluded_test.dart': 'requires unavailable service',
        'missing_test.dart': 'not actually present',
      });
      _writeManifest(baseManifest, const {
        'excluded_test.dart': 'requires unavailable service',
        'missing_test.dart': 'not actually present',
      });

      final result = runGuard();

      expect(result.exitCode, 1);
      expect(result.stdout, contains('accounted suites that do not exist'));
    });

    test('rejects growth in exclusion debt', () {
      _writeSuite(e2eDirectory, 'new_excluded_test.dart');
      _writeManifest(manifest, const {
        'excluded_test.dart': 'requires unavailable service',
        'new_excluded_test.dart': 'new debt',
      });

      final result = runGuard();

      expect(result.exitCode, 1);
      expect(result.stdout, contains('exclusion debt grew'));
      expect(result.stdout, contains('new_excluded_test.dart'));
    });

    test('allows exclusion debt to shrink', () {
      workflow.writeAsStringSync(
        '# SERVICE_SUITE_LIST_START\n'
        'integration_test/e2e/focused_test.dart\n'
        'integration_test/e2e/app_test.dart\n'
        'integration_test/e2e/excluded_test.dart\n'
        '# SERVICE_SUITE_LIST_END\n',
      );
      manifest.writeAsStringSync('# No exclusions remain.\n');

      final result = runGuard();

      expect(result.exitCode, 0, reason: result.stderr.toString());
    });
  });
}

void _writeSuite(Directory directory, String name) {
  File(p.join(directory.path, name)).writeAsStringSync('// test fixture\n');
}

void _writeManifest(File file, Map<String, String> entries) {
  file.writeAsStringSync(
    entries.entries
        .map((entry) => 'integration_test/e2e/${entry.key} | ${entry.value}\n')
        .join(),
  );
}
