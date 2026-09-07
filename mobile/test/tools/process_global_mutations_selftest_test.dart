// ABOUTME: Runs check_process_global_mutations.sh --selftest under the Tests job.
// ABOUTME: The guard's fixture cases are otherwise never executed by automation.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The guard ships 40 fixture cases behind `--selftest`, and until this test
/// existed nothing in the repository ran them: the flag appears in no workflow,
/// no mise task, no git hook, and no Codex config, so CI invoked the scanner
/// bare. A later edit to GLOBALS, to the snapshot/restore regexes, or to the
/// transitive `orig_ids` copy loop could break a whole detection class while
/// `run_scan` still exited 0 on a compliant tree, and the first symptom would
/// be an undetected singleton leak surfacing as an order-dependent flake.
///
/// Every sibling detector in this family is pinned by a
/// `mobile/test/tools/*_detector_test.dart`; this one had a self-test with no
/// runner.
void main() {
  group('check_process_global_mutations --selftest', () {
    late ProcessResult result;
    late String sourceScriptPath;
    late String sourceFilterPath;

    ({Directory root, String scriptPath}) copyGuard({
      bool includeFilter = true,
    }) {
      final root = Directory.systemTemp.createTempSync(
        'process_global_mutations_test',
      );
      final scriptsDirectory = Directory('${root.path}/mobile/scripts')
        ..createSync(recursive: true);
      final scriptPath =
          '${scriptsDirectory.path}/check_process_global_mutations.sh';
      File(sourceScriptPath).copySync(scriptPath);
      if (includeFilter) {
        final filterDirectory = Directory('${scriptsDirectory.path}/lib')
          ..createSync(recursive: true);
        File(
          sourceFilterPath,
        ).copySync('${filterDirectory.path}/dart_code_only.awk');
      }
      return (root: root, scriptPath: scriptPath);
    }

    setUpAll(() {
      sourceScriptPath = File(
        'scripts/check_process_global_mutations.sh',
      ).absolute.path;
      sourceFilterPath = File('scripts/lib/dart_code_only.awk').absolute.path;
      expect(
        File(sourceScriptPath).existsSync(),
        isTrue,
        reason: 'guard script must exist at $sourceScriptPath',
      );
      expect(
        File(sourceFilterPath).existsSync(),
        isTrue,
        reason: 'code-only filter must exist at $sourceFilterPath',
      );
      result = Process.runSync('bash', [sourceScriptPath, '--selftest']);
    });

    test('every fixture case still produces its expected exit code', () {
      final stdout = result.stdout.toString();
      expect(
        result.exitCode,
        0,
        reason: 'self-test reported a broken detection class:\n$stdout',
      );
      expect(stdout, isNot(contains('FAIL (')));
    });

    test('the case list has not been silently emptied', () {
      final stdout = result.stdout.toString();
      final passingCases = RegExp(
        r'^  ok   \(\d\) ',
        multiLine: true,
      ).allMatches(stdout).length;

      // Shrink guard: deleting cases would make the assertion above pass
      // vacuously. Raise this number when cases are added; lower it only
      // deliberately, in the same change that removes one.
      expect(passingCases, greaterThanOrEqualTo(40));
    });

    test('removing a detection class turns the self-test red', () {
      final sandbox = copyGuard();
      addTearDown(() => sandbox.root.deleteSync(recursive: true));
      final script = File(sandbox.scriptPath);
      final original = script.readAsStringSync();
      final mutated = original.replaceFirst("  'Bloc\\.observer'\n", '');
      expect(mutated, isNot(equals(original)));
      script.writeAsStringSync(mutated);

      final mutationResult = Process.runSync('bash', [
        sandbox.scriptPath,
        '--selftest',
      ]);

      expect(mutationResult.exitCode, equals(1));
      expect(
        mutationResult.stdout,
        contains('capture-restore leaker (Bloc.observer install, no restore)'),
      );
      expect(mutationResult.stdout, contains('FAIL (got 0, want 1)'));
    });

    test('fails closed when the code-only filter is missing', () {
      final sandbox = copyGuard(includeFilter: false);
      addTearDown(() => sandbox.root.deleteSync(recursive: true));
      Directory('${sandbox.root.path}/mobile/test').createSync(recursive: true);

      final missingFilterResult = Process.runSync('bash', [sandbox.scriptPath]);

      expect(missingFilterResult.exitCode, equals(1));
      expect(
        missingFilterResult.stderr,
        contains('Dart code-only filter is unavailable'),
      );
    });

    test('production scan includes package test trees', () {
      final sandbox = copyGuard();
      addTearDown(() => sandbox.root.deleteSync(recursive: true));
      Directory('${sandbox.root.path}/mobile/test').createSync(recursive: true);
      final packageTest = File(
        '${sandbox.root.path}/mobile/packages/example/test/leak_test.dart',
      )..createSync(recursive: true);
      packageTest.writeAsStringSync('''
void main() {
  Bloc.observer = MyObserver();
}
''');

      final packageResult = Process.runSync('bash', [sandbox.scriptPath]);

      expect(packageResult.exitCode, equals(1));
      expect(
        packageResult.stdout,
        contains('packages/example/test/leak_test.dart'),
      );
      expect(
        packageResult.stdout,
        contains('(Bloc.observer) [capture-restore]'),
      );
    });
  });
}
