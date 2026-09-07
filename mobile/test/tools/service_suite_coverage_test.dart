// ABOUTME: Tests the service E2E suite coverage ratchet (#8755).
// ABOUTME: Verifies workflow parsing, manifest invariants, and shrink-only behavior.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('service suite coverage guard', () {
    late Directory temporaryDirectory;
    late String mobileDirectory;
    late String workflowPath;
    late String baselinePath;
    late String scriptPath;

    void writeSuite(String name) {
      File('$mobileDirectory/integration_test/e2e/${name}_test.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync('// fixture\n');
    }

    void writeWorkflow({
      List<String> suites = const ['included'],
      bool includeAnchor = true,
      String afterLoop = '',
    }) {
      final suiteLines = suites
          .map(
            (suite) => '          integration_test/e2e/${suite}_test.dart \\\n',
          )
          .join();
      File(workflowPath)
        ..createSync(recursive: true)
        ..writeAsStringSync('''
jobs:
  service-tests:
    steps:
      ${includeAnchor ? '- name: 🚀 Run service integration tests' : '- name: Different step'}
        run: |
          for suite in \\
$suiteLines          ; do
            flutter test "\$suite"
          done
$afterLoop
''');
    }

    void writeBaseline(List<String> entries) {
      File(baselinePath)
        ..createSync(recursive: true)
        ..writeAsStringSync('${entries.join('\n')}\n');
    }

    ProcessResult run({
      bool update = false,
      String baseRef = 'refs/heads/service-suite-test-no-base',
      bool allowNoBase = true,
    }) => Process.runSync(
      'bash',
      [scriptPath],
      environment: {
        'SERVICE_SUITE_MOBILE_DIR': mobileDirectory,
        'SERVICE_SUITE_WORKFLOW': workflowPath,
        'SERVICE_SUITE_E2E_DIR': '$mobileDirectory/integration_test/e2e',
        'SERVICE_SUITE_BASELINE_FILE': baselinePath,
        'SERVICE_SUITE_BASE_REF': baseRef,
        'SERVICE_SUITE_ALLOW_NO_BASE': allowNoBase ? '1' : '0',
        if (update) 'UPDATE_BASELINE': '1',
      },
    );

    setUp(() {
      temporaryDirectory = Directory.systemTemp.createTempSync(
        'service_suite_coverage_test',
      );
      mobileDirectory = '${temporaryDirectory.path}/mobile';
      workflowPath = '${temporaryDirectory.path}/service_workflow.yaml';
      baselinePath =
          '$mobileDirectory/scripts/baseline/service_suite_exclusions.txt';
      scriptPath =
          '${Directory.current.path}/scripts/check_service_suite_coverage.sh';
      writeSuite('included');
      writeSuite('excluded');
      writeWorkflow();
      writeBaseline([
        'integration_test/e2e/excluded_test.dart # requires full stack',
      ]);
    });

    tearDown(() => temporaryDirectory.deleteSync(recursive: true));

    test('passes when every suite is run or excluded with a reason', () {
      final result = run();

      expect(result.exitCode, equals(0), reason: result.stdout.toString());
      expect(result.stdout, contains('no new entries'));
    });

    test('fails when a suite is unaccounted for', () {
      writeSuite('unaccounted');

      final result = run();

      expect(result.exitCode, equals(1));
      expect(result.stdout, contains('NEW entr(y/ies)'));
      expect(result.stdout, contains('unaccounted_test.dart'));
    });

    test('fails when an exclusion becomes stale', () {
      File(
        '$mobileDirectory/integration_test/e2e/excluded_test.dart',
      ).deleteSync();

      final result = run();

      expect(result.exitCode, equals(1));
      expect(result.stdout, contains('no longer offending'));
    });

    test('fails when an exclusion has no reason', () {
      writeBaseline(['integration_test/e2e/excluded_test.dart']);

      final result = run();

      expect(result.exitCode, equals(1));
      expect(result.stderr, contains("nonempty '# reason'"));
    });

    test('fails when the workflow runs a suite twice', () {
      writeWorkflow(suites: ['included', 'included']);

      final result = run();

      expect(result.exitCode, equals(1));
      expect(result.stderr, contains('duplicate suite path'));
    });

    test('fails when the exclusion manifest repeats a suite', () {
      writeBaseline([
        'integration_test/e2e/excluded_test.dart # first reason',
        'integration_test/e2e/excluded_test.dart # second reason',
      ]);

      final result = run();

      expect(result.exitCode, equals(1));
      expect(result.stderr, contains('duplicate path'));
    });

    test('fails when a workflow suite does not exist', () {
      writeWorkflow(suites: ['missing']);

      final result = run();

      expect(result.exitCode, equals(1));
      expect(result.stderr, contains('workflow suite does not exist'));
    });

    test('fails when a suite appears in both accounting lists', () {
      writeBaseline([
        'integration_test/e2e/included_test.dart # contradictory exclusion',
        'integration_test/e2e/excluded_test.dart # requires full stack',
      ]);

      final result = run();

      expect(result.exitCode, equals(1));
      expect(result.stderr, contains('both the workflow and exclusion'));
    });

    test('fails when the workflow anchor is missing', () {
      writeWorkflow(includeAnchor: false);

      final result = run();

      expect(result.exitCode, equals(1));
      expect(result.stderr, contains('expected exactly one'));
    });

    test('does not count a suite path mentioned after the executable loop', () {
      writeSuite('mentioned_only');
      writeWorkflow(
        afterLoop:
            '          # integration_test/e2e/mentioned_only_test.dart\n',
      );

      final result = run();

      expect(result.exitCode, equals(1));
      expect(result.stdout, contains('mentioned_only_test.dart'));
    });

    test('UPDATE_BASELINE preserves reasons for remaining exclusions', () {
      final result = run(update: true);

      expect(result.exitCode, equals(0), reason: result.stderr.toString());
      expect(
        File(baselinePath).readAsStringSync(),
        contains('# requires full stack'),
      );
    });

    test('fails closed when the base baseline cannot be loaded', () {
      final result = run(allowNoBase: false);

      expect(result.exitCode, equals(1));
      expect(result.stdout, contains('failing closed'));
    });

    test('regenerating cannot hide growth versus the base baseline', () {
      final gitInit = Process.runSync('git', [
        'init',
      ], workingDirectory: temporaryDirectory.path);
      expect(gitInit.exitCode, equals(0), reason: gitInit.stderr.toString());
      final gitAdd = Process.runSync('git', [
        'add',
        '.',
      ], workingDirectory: temporaryDirectory.path);
      expect(gitAdd.exitCode, equals(0), reason: gitAdd.stderr.toString());
      final gitCommit = Process.runSync('git', [
        '-c',
        'user.name=Service Suite Test',
        '-c',
        'user.email=service-suite-test@example.com',
        'commit',
        '-m',
        'baseline',
      ], workingDirectory: temporaryDirectory.path);
      expect(
        gitCommit.exitCode,
        equals(0),
        reason: gitCommit.stderr.toString(),
      );

      writeSuite('new_exclusion');
      expect(run(update: true, baseRef: 'HEAD').exitCode, equals(0));
      final regenerated = File(baselinePath).readAsStringSync();
      File(baselinePath).writeAsStringSync(
        regenerated.replaceFirst(
          'integration_test/e2e/new_exclusion_test.dart\n',
          'integration_test/e2e/new_exclusion_test.dart # attempted growth\n',
        ),
      );

      final result = run(baseRef: 'HEAD', allowNoBase: false);

      expect(result.exitCode, equals(1));
      expect(result.stdout, contains('baseline GREW'));
      expect(result.stdout, contains('new_exclusion_test.dart'));
    });
  });
}
