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
      e2eDirectory = Directory(p.join(sandbox.path, 'integration_test', 'e2e'))
        ..createSync(recursive: true);
      manifest = File(p.join(sandbox.path, 'exclusions.txt'));
      baseManifest = File(p.join(sandbox.path, 'base-exclusions.txt'));

      _writeSuite(e2eDirectory, 'focused_test.dart');
      _writeSuite(e2eDirectory, 'app_test.dart');
      _writeSuite(e2eDirectory, 'excluded_test.dart');
      _writeWorkflow(
        workflow,
        focused: const ['focused_test.dart'],
        app: const ['app_test.dart'],
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

    test('rejects an unaccounted suite in a nested directory', () {
      final nestedDirectory = Directory(p.join(e2eDirectory.path, 'dm'))
        ..createSync();
      _writeSuite(nestedDirectory, 'nested_test.dart');

      final result = runGuard();

      expect(result.exitCode, 1);
      expect(result.stdout, contains('missing from the workflow'));
      expect(result.stdout, contains('dm/nested_test.dart'));
    });

    test('rejects a suite included more than once', () {
      _writeWorkflow(
        workflow,
        focused: const ['focused_test.dart', 'focused_test.dart'],
        app: const ['app_test.dart'],
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
      _writeWorkflow(
        workflow,
        focused: const ['focused_test.dart', 'excluded_test.dart'],
        app: const ['app_test.dart'],
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
      _writeWorkflow(
        workflow,
        focused: const ['focused_test.dart', 'excluded_test.dart'],
        app: const ['app_test.dart'],
      );
      manifest.writeAsStringSync('# No exclusions remain.\n');

      final result = runGuard();

      expect(result.exitCode, 0, reason: result.stderr.toString());
    });

    test('does not count a commented-out suite as included', () {
      _writeSuite(e2eDirectory, 'commented_test.dart');
      workflow.writeAsStringSync(
        '# SERVICE_SUITE_LIST_START\n'
        'focused_suites=(\n'
        '  integration_test/e2e/focused_test.dart\n'
        '  # FLAKY: integration_test/e2e/commented_test.dart\n'
        ')\n'
        'app_suites=(\n'
        '  integration_test/e2e/app_test.dart\n'
        ')\n'
        '# SERVICE_SUITE_LIST_END\n',
      );

      final result = runGuard();

      expect(result.exitCode, 1);
      expect(result.stdout, contains('missing from the workflow'));
      expect(result.stdout, contains('commented_test.dart'));
    });

    test('rejects suite paths outside the declared arrays', () {
      workflow.writeAsStringSync(
        '# SERVICE_SUITE_LIST_START\n'
        'focused_suites=(\n'
        '  integration_test/e2e/focused_test.dart\n'
        ')\n'
        'integration_test/e2e/app_test.dart\n'
        '# SERVICE_SUITE_LIST_END\n',
      );

      final result = runGuard();

      expect(result.exitCode, 1);
      expect(result.stderr, contains('Unexpected line'));
    });
  });

  group('check_service_suite_coverage.sh base-ref handling', () {
    late Directory repo;
    late Directory e2eDirectory;
    late File workflow;
    late File manifest;
    late String scriptPath;
    late String defaultPath;

    ProcessResult git(List<String> arguments) =>
        Process.runSync('git', arguments, workingDirectory: repo.path);

    void commitBase() {
      expect(git(['add', '-A']).exitCode, 0);
      final result = git([
        '-c',
        'user.name=Service Suite Test',
        '-c',
        'user.email=service-suite-test@example.invalid',
        'commit',
        '-q',
        '-m',
        'base',
      ]);
      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(git(['branch', '-f', 'base', 'HEAD']).exitCode, 0);
    }

    ProcessResult runGuard({
      String baseRef = 'base',
      bool allowNoBase = false,
      bool makeBaseBlobUnreadable = false,
    }) => Process.runSync(
      'bash',
      [scriptPath],
      environment: {
        ...Platform.environment,
        'PATH': makeBaseBlobUnreadable
            ? '${p.join(repo.path, 'fake-bin')}:$defaultPath'
            : defaultPath,
        'SERVICE_SUITE_WORKFLOW_FILE': workflow.path,
        'SERVICE_SUITE_E2E_DIR': e2eDirectory.path,
        'SERVICE_SUITE_PATH_ROOT': p.join(repo.path, 'mobile'),
        'SERVICE_SUITE_MANIFEST_FILE': manifest.path,
        'SERVICE_SUITE_BASE_REF': baseRef,
        if (allowNoBase) 'SERVICE_SUITE_ALLOW_NO_BASE': '1',
      },
    );

    setUp(() {
      repo = Directory.systemTemp.createTempSync('service_suite_base_ref_');
      expect(git(['init', '-q']).exitCode, 0);
      defaultPath = Platform.environment['PATH']!;
      final scripts = Directory(p.join(repo.path, 'mobile', 'scripts'))
        ..createSync(recursive: true);
      final sourceScript = File(
        p.join(
          Directory.current.path,
          'scripts',
          'check_service_suite_coverage.sh',
        ),
      );
      final copiedScript = File(
        p.join(scripts.path, sourceScript.uri.pathSegments.last),
      )..writeAsBytesSync(sourceScript.readAsBytesSync());
      scriptPath = copiedScript.path;
      workflow = File(p.join(repo.path, 'workflow.yaml'));
      e2eDirectory = Directory(
        p.join(repo.path, 'mobile', 'integration_test', 'e2e'),
      )..createSync(recursive: true);
      manifest = File(p.join(e2eDirectory.path, 'moved_exclusions.txt'));
      _writeSuite(e2eDirectory, 'focused_test.dart');
      _writeSuite(e2eDirectory, 'app_test.dart');
      _writeWorkflow(
        workflow,
        focused: const ['focused_test.dart'],
        app: const ['app_test.dart'],
      );
      _writeManifest(manifest, const {});
    });

    tearDown(() {
      if (repo.existsSync()) repo.deleteSync(recursive: true);
    });

    test('derives the base manifest path when the manifest moves', () {
      _writeSuite(e2eDirectory, 'excluded_test.dart');
      _writeManifest(manifest, const {});
      commitBase();
      _writeManifest(manifest, const {'excluded_test.dart': 'new debt'});

      final result = runGuard();

      expect(result.exitCode, 1);
      expect(result.stdout, contains('exclusion debt grew'));
      expect(result.stdout, contains('excluded_test.dart'));
    });

    test('fails closed when the base ref cannot be resolved', () {
      final result = runGuard(baseRef: 'missing-base');

      expect(result.exitCode, 1);
      expect(result.stdout, contains('cannot resolve base ref missing-base'));
      expect(result.stdout, contains('failing closed'));
    });

    test('fails closed when the base manifest blob cannot be read', () {
      commitBase();
      final realGit = Process.runSync('which', [
        'git',
      ]).stdout.toString().trim();
      final fakeGit = File(p.join(repo.path, 'fake-bin', 'git'))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(
          '#!/usr/bin/env bash\n'
          'if [[ "\$*" == *" show "* ]]; then exit 1; fi\n'
          'exec "$realGit" "\$@"\n',
        );
      expect(Process.runSync('chmod', ['+x', fakeGit.path]).exitCode, 0);

      final result = runGuard(makeBaseBlobUnreadable: true);

      expect(result.exitCode, 1);
      expect(result.stdout, contains('not be read'));
      expect(result.stdout, contains('failing closed'));
    });

    test('allows an explicit local opt-out when the base is unavailable', () {
      final result = runGuard(baseRef: 'missing-base', allowNoBase: true);

      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(result.stdout, contains('local opt-out'));
      expect(result.stdout, contains('no-growth comparison skipped'));
      expect(result.stdout, isNot(contains('exclusion debt did not grow')));
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

void _writeWorkflow(
  File file, {
  required List<String> focused,
  required List<String> app,
}) {
  file.writeAsStringSync(
    '# SERVICE_SUITE_LIST_START\n'
    'focused_suites=(\n'
    '${focused.map((name) => '  integration_test/e2e/$name').join('\n')}\n'
    ')\n'
    'app_suites=(\n'
    '${app.map((name) => '  integration_test/e2e/$name').join('\n')}\n'
    ')\n'
    '# SERVICE_SUITE_LIST_END\n',
  );
}
