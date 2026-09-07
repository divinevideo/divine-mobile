// ABOUTME: Runs check_process_global_mutations.sh --selftest under the Tests job.
// ABOUTME: The guard's fixture cases are otherwise never executed by automation.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The guard ships 27 fixture cases behind `--selftest`, and until this test
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

    setUpAll(() {
      final scriptPath = File(
        'scripts/check_process_global_mutations.sh',
      ).absolute;
      expect(
        scriptPath.existsSync(),
        isTrue,
        reason: 'guard script must exist at ${scriptPath.path}',
      );
      result = Process.runSync('bash', [scriptPath.path, '--selftest']);
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
      expect(passingCases, greaterThanOrEqualTo(27));
    });
  });
}
