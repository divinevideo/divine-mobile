// ABOUTME: Tests changed-path classification for service integration suites.
// ABOUTME: Pins focused/app scopes and every pull-request API fall-open guard.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('detect_service_suite_scope.sh', () {
    late Directory sandbox;
    late String scriptPath;
    late String outputPath;

    setUp(() {
      sandbox = Directory.systemTemp.createTempSync('service_suite_scope_');
      scriptPath = File(
        p.join(
          Directory.current.path,
          'scripts',
          'ci',
          'detect_service_suite_scope.sh',
        ),
      ).absolute.path;
      outputPath = p.join(sandbox.path, 'github-output');

      final fakeGh = File(p.join(sandbox.path, 'bin', 'gh'))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(
          '#!/usr/bin/env bash\n'
          r'''
set -euo pipefail

if [[ "$*" == *"/files"* ]]; then
  if [ -n "${FAKE_CHANGED_FILES:-}" ]; then
    printf '%s\n' "$FAKE_CHANGED_FILES"
  fi
elif [[ "$*" == *".changed_files"* ]]; then
  printf '%s\n' "${FAKE_CHANGED_TOTAL:-0}"
else
  echo "Unexpected gh invocation: $*" >&2
  exit 2
fi
''',
        );
      Process.runSync('chmod', ['+x', fakeGh.path]);
    });

    tearDown(() {
      if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
    });

    ({ProcessResult result, Map<String, String> outputs}) runDetector({
      String event = 'pull_request',
      List<String> changedFiles = const [],
      int? changedTotal,
    }) {
      final result = Process.runSync(
        'bash',
        [scriptPath],
        environment: {
          'PATH':
              '${p.join(sandbox.path, 'bin')}:${Platform.environment['PATH']}',
          'GITHUB_EVENT_NAME': event,
          'GITHUB_REPOSITORY': 'divinevideo/divine-mobile',
          'GITHUB_OUTPUT': outputPath,
          'PR_NUMBER': '8756',
          'FAKE_CHANGED_FILES': changedFiles.join('\n'),
          'FAKE_CHANGED_TOTAL': '${changedTotal ?? changedFiles.length}',
        },
      );

      final outputs = <String, String>{};
      final outputFile = File(outputPath);
      if (outputFile.existsSync()) {
        for (final line in outputFile.readAsLinesSync()) {
          final separator = line.indexOf('=');
          if (separator > 0) {
            outputs[line.substring(0, separator)] = line.substring(
              separator + 1,
            );
          }
        }
      }
      return (result: result, outputs: outputs);
    }

    void expectScope(
      ({ProcessResult result, Map<String, String> outputs}) run, {
      required bool focused,
      required bool app,
    }) {
      expect(run.result.exitCode, 0, reason: run.result.stderr.toString());
      expect(run.outputs, {'focused': '$focused', 'app': '$app'});
    }

    test('runs both groups for every focused package dependency', () {
      const packages = [
        'cache_sync',
        'db_client',
        'dm_repository',
        'follow_repository',
        'funnelcake_api_client',
        'models',
        'nostr_client',
        'nostr_sdk',
        'text_sanitizer',
        'unified_logger',
      ];

      for (final package in packages) {
        expectScope(
          runDetector(
            changedFiles: ['mobile/packages/$package/lib/change.dart'],
          ),
          focused: true,
          app: true,
        );
      }
    });

    test('runs both groups for every focused app dependency', () {
      const paths = [
        'mobile/lib/observability/crash_reporter.dart',
        'mobile/lib/services/outgoing_dm_retry_service.dart',
        'mobile/lib/services/outgoing_dm_retry_service_reportable_sites.dart',
        'mobile/lib/services/relay_discovery_service.dart',
        'mobile/lib/utils/relay_url_utils.dart',
      ];

      for (final path in paths) {
        expectScope(
          runDetector(changedFiles: [path]),
          focused: true,
          app: true,
        );
      }
    });

    test('runs only app-connected suites for other app and package code', () {
      for (final path in [
        'mobile/lib/widgets/video_grid.dart',
        'mobile/packages/feed_repository/lib/src/feed_repository.dart',
      ]) {
        expectScope(
          runDetector(changedFiles: [path]),
          focused: false,
          app: true,
        );
      }
    });

    test('runs both groups for shared test and runner inputs', () {
      for (final path in [
        'mobile/integration_test/e2e/new_test.dart',
        'mobile/integration_test/helpers/fake_relay.dart',
        'mobile/integration_test/e2e/service_suite_exclusions.txt',
        'mobile/pubspec.yaml',
        'mobile/pubspec.lock',
        'mobile/dart_test.yaml',
        'mobile/linux/CMakeLists.txt',
        '.github/workflows/mobile_service_integration_tests.yaml',
        'mobile/scripts/ci/detect_service_suite_scope.sh',
        'mobile/scripts/check_service_suite_coverage.sh',
      ]) {
        expectScope(
          runDetector(changedFiles: [path]),
          focused: true,
          app: true,
        );
      }
    });

    test('skips both groups for docs-only changes', () {
      expectScope(
        runDetector(changedFiles: ['docs/testing.md']),
        focused: false,
        app: false,
      );
    });

    test('falls open above the pull-request file cap', () {
      final run = runDetector(
        changedFiles: ['docs/only.md'],
        changedTotal: 3001,
      );

      expectScope(run, focused: true, app: true);
      expect(run.result.stdout, contains('touches 3001 files'));
    });

    test('falls open when the file response is empty', () {
      final run = runDetector(changedTotal: 1);

      expectScope(run, focused: true, app: true);
      expect(run.result.stdout, contains('returned 0 files but reported 1'));
    });

    test('falls open when the file response is truncated', () {
      final run = runDetector(changedFiles: ['docs/only.md'], changedTotal: 2);

      expectScope(run, focused: true, app: true);
      expect(run.result.stdout, contains('returned 1 files but reported 2'));
    });

    test('workflow dispatch falls open without calling the API', () {
      expectScope(
        runDetector(event: 'workflow_dispatch'),
        focused: true,
        app: true,
      );
    });
  });
}
