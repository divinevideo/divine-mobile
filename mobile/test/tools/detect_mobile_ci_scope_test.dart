// ABOUTME: Tests Mobile CI scope detection across PR and merge-queue events.
// ABOUTME: Pins app/native classification and every fall-open API boundary.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('detect_mobile_ci_scope.sh', () {
    late Directory sandbox;
    late String scriptPath;
    late String outputPath;

    setUp(() {
      sandbox = Directory.systemTemp.createTempSync('mobile_ci_scope_');
      scriptPath = File(
        p.join(
          Directory.current.path,
          'scripts',
          'ci',
          'detect_mobile_ci_scope.sh',
        ),
      ).absolute.path;
      outputPath = p.join(sandbox.path, 'github-output');

      final fakeGh = File(p.join(sandbox.path, 'bin', 'gh'))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(
          '#!/usr/bin/env bash\n'
          r'''
set -euo pipefail

emit_files() {
  if [ -n "${FAKE_CHANGED_FILES:-}" ]; then
    printf '%s\n' "$FAKE_CHANGED_FILES"
  fi
}

case "$*" in
  *"/files"*) emit_files ;;
  *".changed_files"*) printf '%s\n' "${FAKE_CHANGED_TOTAL:-0}" ;;
  *"/compare/"*) emit_files ;;
  *) echo "Unexpected gh invocation: $*" >&2; exit 2 ;;
esac
''',
        );
      Process.runSync('chmod', ['+x', fakeGh.path]);
    });

    tearDown(() {
      if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
    });

    ({ProcessResult result, Map<String, String> outputs}) runDetector({
      required String event,
      List<String> changedFiles = const [],
      int changedTotal = 0,
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
          'PR_NUMBER': '7058',
          'QUEUE_BASE_SHA': 'base-sha',
          'QUEUE_HEAD_SHA': 'head-sha',
          'FAKE_CHANGED_FILES': changedFiles.join('\n'),
          'FAKE_CHANGED_TOTAL': '$changedTotal',
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
      required bool app,
      required bool native,
    }) {
      expect(run.result.exitCode, 0, reason: run.result.stderr.toString());
      expect(run.outputs, {'app': '$app', 'native': '$native'});
    }

    for (final event in ['pull_request', 'merge_group']) {
      group(event, () {
        test('runs app CI for app code', () {
          expectScope(
            runDetector(
              event: event,
              changedFiles: ['mobile/lib/main.dart'],
              changedTotal: 1,
            ),
            app: true,
            native: false,
          );
        });

        test('runs app CI for an analytics contract lock-only change', () {
          expectScope(
            runDetector(
              event: event,
              changedFiles: ['analytics-contract.lock'],
              changedTotal: 1,
            ),
            app: true,
            native: false,
          );
        });

        test('runs app CI for an analytics contract manifest-only change', () {
          expectScope(
            runDetector(
              event: event,
              changedFiles: ['analytics-contract.manifest.json'],
              changedTotal: 1,
            ),
            app: true,
            native: false,
          );
        });

        test('skips app CI for a codemagic.yaml-only change', () {
          // Intentionally out of app-scope so a config-only edit does not
          // drag the full matrix. The Codemagic group guard must therefore
          // be required through the Mobile CI aggregator, not this detector.
          expectScope(
            runDetector(
              event: event,
              changedFiles: ['codemagic.yaml'],
              changedTotal: 1,
            ),
            app: false,
            native: false,
          );
        });

        test('skips app CI for docs-only changes', () {
          expectScope(
            runDetector(
              event: event,
              changedFiles: ['docs/merge-queue.md'],
              changedTotal: 1,
            ),
            app: false,
            native: false,
          );
        });

        test('runs app and native checks for native configuration', () {
          expectScope(
            runDetector(
              event: event,
              changedFiles: ['mobile/ios/Runner/Info.plist'],
              changedTotal: 1,
            ),
            app: true,
            native: true,
          );
        });
      });
    }

    test('merge group falls open when compare output is empty', () {
      final run = runDetector(event: 'merge_group');

      expectScope(run, app: true, native: true);
      expect(run.result.stdout, contains('returned 0 files'));
    });

    test('merge group falls open at the 300-file compare cap', () {
      final run = runDetector(
        event: 'merge_group',
        changedFiles: [for (var i = 0; i < 300; i++) 'docs/file_$i.md'],
      );

      expectScope(run, app: true, native: true);
      expect(run.result.stdout, contains('returned 300 files'));
    });

    test('pull request falls open above the 3000-file API cap', () {
      final run = runDetector(
        event: 'pull_request',
        changedFiles: ['docs/only.md'],
        changedTotal: 3001,
      );

      expectScope(run, app: true, native: true);
      expect(run.result.stdout, contains('touches 3001 files'));
    });

    test('pull request falls open when files output is empty', () {
      final run = runDetector(event: 'pull_request', changedTotal: 1);

      expectScope(run, app: true, native: true);
      expect(
        run.result.stdout,
        contains('returned 0 files but reported 1 changed files'),
      );
    });

    test('pull request falls open when files output is truncated', () {
      final run = runDetector(
        event: 'pull_request',
        changedFiles: ['docs/only.md'],
        changedTotal: 2,
      );

      expectScope(run, app: true, native: true);
      expect(
        run.result.stdout,
        contains('returned 1 files but reported 2 changed files'),
      );
    });

    test('detector changes run native checks', () {
      expectScope(
        runDetector(
          event: 'pull_request',
          changedFiles: ['mobile/scripts/ci/detect_mobile_ci_scope.sh'],
          changedTotal: 1,
        ),
        app: true,
        native: true,
      );
    });

    test('gradle wrapper guard changes run native checks', () {
      // The guard reads mobile/android/** and its own script, so a change to
      // the script alone must still schedule the native-gated step that runs
      // it (#7201) -- otherwise editing the guard could not re-verify it.
      expectScope(
        runDetector(
          event: 'pull_request',
          changedFiles: ['mobile/scripts/check_gradle_wrapper_checksum.sh'],
          changedTotal: 1,
        ),
        app: true,
        native: true,
      );
    });

    test('gitattributes changes run wrapper checks', () {
      // The tracked wrapper launchers depend on their root-level line-ending
      // attributes, so changing that file must run the app and native gates.
      expectScope(
        runDetector(
          event: 'pull_request',
          changedFiles: ['.gitattributes'],
          changedTotal: 1,
        ),
        app: true,
        native: true,
      );
    });

    test('push falls open to preserve the full main-branch matrix', () {
      expectScope(runDetector(event: 'push'), app: true, native: true);
    });
  });
}
