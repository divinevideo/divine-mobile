// ABOUTME: Tests Mobile CI and QA scope detection across GitHub event types.
// ABOUTME: Pins focused classifications and every fail-open API boundary.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// One detector invocation: its process result, the parsed $GITHUB_OUTPUT,
/// and the argument line of every `gh` call it made.
typedef DetectorRun = ({
  ProcessResult result,
  Map<String, String> outputs,
  List<String> ghCalls,
});

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

if [ -n "${FAKE_GH_LOG:-}" ]; then
  printf '%s\n' "$*" >> "$FAKE_GH_LOG"
fi

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

    DetectorRun runDetector({
      required String event,
      List<String> changedFiles = const [],
      int changedTotal = 0,
      String pushBeforeSha = 'push-before',
      String pushAfterSha = 'push-after',
    }) {
      final ghLogPath = p.join(sandbox.path, 'gh-calls');
      final result = Process.runSync(
        'bash',
        [scriptPath],
        environment: {
          'FAKE_GH_LOG': ghLogPath,
          'PATH':
              '${p.join(sandbox.path, 'bin')}:${Platform.environment['PATH']}',
          'GITHUB_EVENT_NAME': event,
          'GITHUB_REPOSITORY': 'divinevideo/divine-mobile',
          'GITHUB_OUTPUT': outputPath,
          'PR_NUMBER': '7058',
          'QUEUE_BASE_SHA': 'base-sha',
          'QUEUE_HEAD_SHA': 'head-sha',
          'PUSH_BEFORE_SHA': pushBeforeSha,
          'PUSH_AFTER_SHA': pushAfterSha,
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
      final ghLog = File(ghLogPath);
      return (
        result: result,
        outputs: outputs,
        ghCalls: ghLog.existsSync()
            ? ghLog.readAsLinesSync()
            : const <String>[],
      );
    }

    void expectScope(
      DetectorRun run, {
      required bool app,
      required bool native,
      Map<String, bool> also = const {},
    }) {
      expect(run.result.exitCode, 0, reason: run.result.stderr.toString());
      expect(run.outputs['app'], '$app');
      expect(run.outputs['native'], '$native');
      expect(
        run.outputs.keys,
        containsAll(<String>{
          'docs_only',
          'app',
          'native',
          'android',
          'ios',
          'service',
          'goldens',
          'maestro_static',
          'smoke',
          'performance',
          'ci_config',
        }),
      );
      for (final entry in also.entries) {
        expect(run.outputs[entry.key], '${entry.value}', reason: entry.key);
      }
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
            also: const {
              'docs_only': false,
              'android': true,
              'ios': true,
              'smoke': true,
            },
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
            also: const {
              'docs_only': false,
              'maestro_static': true,
              'ci_config': true,
            },
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
            also: const {'docs_only': true},
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
            also: const {'android': false, 'ios': true, 'smoke': true},
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

    test('repo-root script changes run app CI', () {
      // mobile/test/tools/ only runs in the app matrix, so a scripts/-only PR
      // must not skip the one job that tests it (#8761).
      expectScope(
        runDetector(
          event: 'pull_request',
          changedFiles: ['scripts/prune-merged-branches.sh'],
          changedTotal: 1,
        ),
        app: true,
        native: false,
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
        also: const {
          'android': true,
          'ios': true,
          'service': true,
          'goldens': true,
          'maestro_static': true,
          'smoke': true,
          'performance': true,
          'ci_config': true,
        },
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

    test('push compares github.event.before against github.sha', () {
      // The compared range is the whole point of the push path, and nothing
      // else observes it: the fake gh answers any /compare/ URL, so swapping
      // the two SHAs, or passing the merge-group pair instead, produces an
      // identical $GITHUB_OUTPUT. In production a reversed range three-dot
      // resolves to before-vs-before, returns 0 files, and falls open to
      // every scope on every merge to main — green, and silently the
      // opposite of what this PR is for.
      final run = runDetector(
        event: 'push',
        changedFiles: ['mobile/lib/main.dart'],
      );

      expect(
        run.ghCalls.singleWhere((call) => call.contains('/compare/')),
        contains('/compare/push-before...push-after'),
      );
      expectScope(
        run,
        app: true,
        native: false,
        also: const {
          'docs_only': false,
          'android': true,
          'ios': true,
          'service': true,
          'smoke': true,
        },
      );
    });

    test('push classifies a docs-only merge as docs-only', () {
      expectScope(
        runDetector(event: 'push', changedFiles: ['docs/release-notes.md']),
        app: false,
        native: false,
        also: const {'docs_only': true, 'smoke': false},
      );
    });

    test('push falls open when the before SHA is all zeroes', () {
      // A docs-only file, so the zero-file fall-open cannot fire and stand in
      // for the zeroes guard: without it this test passed unchanged when the
      // guard was deleted, because the default empty file list falls open on
      // its own. The stdout reason is what distinguishes the two.
      final run = runDetector(
        event: 'push',
        changedFiles: ['docs/release-notes.md'],
        pushBeforeSha: '0000000000000000000000000000000000000000',
      );

      expect(run.result.stdout, contains('no comparable before SHA'));
      expectScope(
        run,
        app: true,
        native: true,
        also: const {
          'docs_only': false,
          'android': true,
          'ios': true,
          'service': true,
          'goldens': true,
          'maestro_static': true,
          'smoke': true,
          'performance': true,
          'ci_config': true,
        },
      );
    });

    for (final path in [
      'mobile/lib/notifications/widgets/actor_notification_row.dart',
      'mobile/lib/l10n/app_en.arb',
      'mobile/pubspec.yaml',
      'mobile/pubspec.lock',
    ]) {
      test('$path runs the golden suite', () {
        expectScope(
          runDetector(
            event: 'pull_request',
            changedFiles: [path],
            changedTotal: 1,
          ),
          app: true,
          native: false,
          also: const {'goldens': true},
        );
      });
    }

    test('classifies focused QA scopes independently', () {
      final run = runDetector(
        event: 'pull_request',
        changedFiles: [
          'mobile/lib/screens/feed/video_feed_page.dart',
          'mobile/e2e/maestro/flows/feed.yaml',
          '.github/workflows/mobile_ci.yaml',
        ],
        changedTotal: 3,
      );

      expectScope(
        run,
        app: true,
        native: true,
        also: const {
          'docs_only': false,
          'android': true,
          'ios': true,
          'goldens': true,
          'maestro_static': true,
          'smoke': true,
          'performance': true,
          'ci_config': true,
        },
      );
    });
  });
}
