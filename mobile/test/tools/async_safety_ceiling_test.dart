// ABOUTME: Tests parsing and ratcheting analyzer async-safety diagnostics.
// ABOUTME: Pins per-rule, per-file counts used by check_async_safety_ceiling.sh.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('async safety ceiling', () {
    late Directory tmp;
    late File diagnostics;
    late File baseline;

    ProcessResult run({bool update = false}) => Process.runSync(
      'bash',
      ['scripts/check_async_safety_ceiling.sh'],
      environment: {
        'ASYNC_SAFETY_DIAGNOSTICS_FILE': diagnostics.path,
        'ASYNC_SAFETY_BASELINE_FILE': baseline.path,
        'ASYNC_SAFETY_CEILING_ALLOW_NO_BASE': '1',
        // Explicitly cleared, not merely omitted: Process.runSync merges the
        // parent environment, and `UPDATE_BASELINE=1 bash scripts/check_*.sh`
        // is the documented relock idiom, so exporting it for a relock session
        // would otherwise send the growth test down the regeneration path and
        // fail it with exit 0 for a reason unrelated to the change under test.
        'UPDATE_BASELINE': update ? '1' : '',
      },
    );

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('async_safety_ceiling_test');
      diagnostics = File('${tmp.path}/diagnostics.txt');
      baseline = File('${tmp.path}/baseline.txt');
      diagnostics.writeAsStringSync('''
INFO|LINT|DISCARDED_FUTURES|${Directory.current.path}/lib/a.dart|1|1|1|message
INFO|LINT|DISCARDED_FUTURES|${Directory.current.path}/lib/a.dart|2|1|1|message
INFO|LINT|UNAWAITED_FUTURES|${Directory.current.path}/lib/a.dart|3|1|1|message
INFO|LINT|UNAWAITED_FUTURES|${Directory.current.path}/test/b_test.dart|4|1|1|message
''');
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    test('stores separate per-rule, per-file counts', () {
      final result = run(update: true);

      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(
        baseline.readAsLinesSync().where((line) => !line.startsWith('#')),
        containsAll(<String>[
          'discarded_futures|lib/a.dart\t2',
          'unawaited_futures|lib/a.dart\t1',
          'unawaited_futures|test/b_test.dart\t1',
        ]),
      );
    });

    test('rejects growth in one diagnostic without conflating rules', () {
      expect(run(update: true).exitCode, 0);
      diagnostics.writeAsStringSync('''
INFO|LINT|DISCARDED_FUTURES|${Directory.current.path}/lib/a.dart|1|1|1|message
INFO|LINT|DISCARDED_FUTURES|${Directory.current.path}/lib/a.dart|2|1|1|message
INFO|LINT|DISCARDED_FUTURES|${Directory.current.path}/lib/a.dart|3|1|1|message
INFO|LINT|UNAWAITED_FUTURES|${Directory.current.path}/lib/a.dart|4|1|1|message
INFO|LINT|UNAWAITED_FUTURES|${Directory.current.path}/test/b_test.dart|5|1|1|message
''');

      final result = run();

      expect(result.exitCode, 1);
      expect(result.stdout, contains('GREW'));
      expect(result.stdout, contains('discarded_futures|lib/a.dart'));
    });
  });

  group('analyzer configuration coupling', () {
    // The guard re-enables the two rules by deleting one exact line shape from
    // analysis_options.yaml. Reformatting either line leaves the suppression
    // in place, which reads as 491 STALE keys whose printed remedy erases the
    // baseline. Removing the lines outright is the endgame and stays legal.
    test('every suppression of a tracked rule matches the stripped shape', () {
      const rules = ['discarded_futures', 'unawaited_futures'];
      final suppresses = RegExp(
        '^\\s*-?\\s*["\']?(${rules.join('|')})["\']?\\s*:'
        '\\s*["\']?(ignore|false)["\']?\\s*(#.*)?\$',
      );
      // `\\s+`, not a literal space: the awk this mirrors matches
      // `:[[:space:]]+ignore`, so a two-space reformat that the guard strips
      // correctly would otherwise be reported here as an offender.
      final stripped = RegExp('^\\s+(${rules.join('|')}):\\s+ignore\\s*\$');

      final offenders = File('analysis_options.yaml')
          .readAsLinesSync()
          .where(suppresses.hasMatch)
          .where((line) => !stripped.hasMatch(line))
          .toList();

      expect(offenders, isEmpty);
    });
  });
}
