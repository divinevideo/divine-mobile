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
        if (update) 'UPDATE_BASELINE': '1',
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
}
