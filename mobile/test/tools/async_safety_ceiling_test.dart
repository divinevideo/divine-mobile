// ABOUTME: Tests parsing and ratcheting analyzer async-safety diagnostics.
// ABOUTME: Pins per-rule, per-file counts used by check_async_safety_ceiling.sh.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('async safety ceiling', () {
    late Directory tmp;
    late File diagnostics;
    late File baseline;

    ProcessResult run({
      bool update = false,
      String? baseRef,
    }) => Process.runSync(
      'bash',
      ['scripts/check_async_safety_ceiling.sh'],
      environment: {
        'ASYNC_SAFETY_DIAGNOSTICS_FILE': diagnostics.path,
        'ASYNC_SAFETY_BASELINE_FILE': baseline.path,
        'ASYNC_SAFETY_CEILING_ALLOW_NO_BASE': '1',
        'ASYNC_SAFETY_BASELINE_BASE_REF': ?baseRef,
        // A repo-relative path no ref carries, so the engine takes its
        // "no baseline on the base ref" branch deterministically instead of
        // comparing the three-key fixture against the real one.
        'ASYNC_SAFETY_BASELINE_REPO_PATH':
            'mobile/scripts/baseline/__async_safety_fixture_absent.txt',
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

    test('reports growth alone when the base ref carries a baseline', () {
      // The growth test above passes today only because origin/main has no
      // async-safety baseline yet, so the engine skips its bypass check. Once
      // this merges it will have one, and without the repo-path seam the
      // three-key fixture would be compared against the real 488-key baseline:
      // the run would still exit 1 and still say GREW, so both existing
      // assertions would hold while a second, unasked failure did the work --
      // and a regression in the growth check alone could no longer turn the
      // suite red. Pointing the base ref at a commit that does carry a
      // baseline is what makes that reachable here rather than after merge.
      expect(run(update: true, baseRef: 'HEAD').exitCode, 0);
      diagnostics.writeAsStringSync('''
INFO|LINT|DISCARDED_FUTURES|${Directory.current.path}/lib/a.dart|1|1|1|message
INFO|LINT|DISCARDED_FUTURES|${Directory.current.path}/lib/a.dart|2|1|1|message
INFO|LINT|DISCARDED_FUTURES|${Directory.current.path}/lib/a.dart|3|1|1|message
INFO|LINT|UNAWAITED_FUTURES|${Directory.current.path}/lib/a.dart|4|1|1|message
INFO|LINT|UNAWAITED_FUTURES|${Directory.current.path}/test/b_test.dart|5|1|1|message
''');

      final result = run(baseRef: 'HEAD');

      expect(result.exitCode, 1, reason: '${result.stdout}${result.stderr}');
      expect(result.stdout, contains('GREW'));
      expect(result.stdout, isNot(contains('may only shrink')));
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

    test('operational guidance points to the active paydown tracker', () {
      for (final path in [
        'scripts/check_async_safety_ceiling.sh',
        'scripts/baseline/async_safety_counts.txt',
        '../.github/workflows/mobile_ci.yaml',
      ]) {
        final contents = File(path).readAsStringSync();
        expect(contents, contains('#9118'), reason: path);
        expect(contents, isNot(contains('#3342')), reason: path);
      }
    });
  });

  // Everything above drives the guard through ASYNC_SAFETY_DIAGNOSTICS_FILE,
  // which short-circuits the whole config-rewrite block. These run the real
  // path in a sandbox instead: the guard temporarily deletes the two `ignore`
  // lines from a tracked file, and losing that file is the worst thing it can
  // do to a checkout. Each case bails out before `dart analyze`, so they stay
  // fast.
  group('analysis_options rewrite and restore', () {
    late Directory sandbox;
    late File options;

    const suppressions = '''
analyzer:
  errors:
    discarded_futures: ignore
    unawaited_futures: ignore
''';

    ProcessResult runGuard() => Process.runSync(
      'bash',
      ['scripts/check_async_safety_ceiling.sh'],
      workingDirectory: sandbox.path,
      environment: {
        'ASYNC_SAFETY_BASELINE_FILE':
            '${sandbox.path}/scripts/baseline/async_safety_counts.txt',
        'ASYNC_SAFETY_CEILING_ALLOW_NO_BASE': '1',
        'UPDATE_BASELINE': '',
      },
    );

    List<File> backups() => sandbox
        .listSync()
        .whereType<File>()
        .where((f) => f.path.contains('.analysis_options.yaml.ratchet-backup.'))
        .toList();

    setUp(() {
      final repoRoot = Directory.current.path;
      sandbox = Directory.systemTemp.createTempSync('async_safety_restore_');
      Directory('${sandbox.path}/scripts/lib').createSync(recursive: true);
      Directory('${sandbox.path}/scripts/baseline').createSync(recursive: true);
      File(
        '$repoRoot/scripts/check_async_safety_ceiling.sh',
      ).copySync('${sandbox.path}/scripts/check_async_safety_ceiling.sh');
      File(
        '$repoRoot/scripts/lib/numeric_ratchet.sh',
      ).copySync('${sandbox.path}/scripts/lib/numeric_ratchet.sh');
      File(
        '${sandbox.path}/scripts/baseline/async_safety_counts.txt',
      ).writeAsStringSync('# frozen baseline\n');
      options = File('${sandbox.path}/analysis_options.yaml');
    });

    tearDown(() => sandbox.deleteSync(recursive: true));

    test('restores the config when the suppression assertion fails', () {
      // One line reformatted, one not: the awk strips the plain one and the
      // assertion then fires on the survivor. That is the path that used to
      // leave the tracked file permanently missing a suppression.
      const body = '''
analyzer:
  errors:
    discarded_futures: ignore  # intentionally reformatted for this fixture
    unawaited_futures: ignore
''';
      options.writeAsStringSync(body);

      final result = runGuard();

      // The restore is asserted first: it is the behaviour that matters, so a
      // regression should fail here rather than on the message wording.
      expect(options.readAsStringSync(), body);
      expect(backups(), isEmpty);
      expect(result.exitCode, 1, reason: '${result.stdout}${result.stderr}');
      expect('${result.stderr}', contains('still suppresses'));
    });

    test('rejects a tracked rule suppressed in a nested analyzer config', () {
      options.writeAsStringSync(suppressions);
      Directory('${sandbox.path}/test').createSync();
      File('${sandbox.path}/test/analysis_options.yaml').writeAsStringSync('''
include: ../analysis_options.yaml

analyzer:
  errors:
    unawaited_futures: ignore
''');

      final result = runGuard();

      expect(result.exitCode, 1, reason: '${result.stdout}${result.stderr}');
      expect('${result.stderr}', contains('test/analysis_options.yaml'));
      expect(options.readAsStringSync(), suppressions);
    });

    test('refuses to run while another run holds a backup', () {
      options.writeAsStringSync(suppressions);
      final foreign = File(
        '${sandbox.path}/.analysis_options.yaml.ratchet-backup.999999',
      )..writeAsStringSync('other run owns this\n');

      final result = runGuard();

      expect(result.exitCode, 1, reason: '${result.stdout}${result.stderr}');
      expect('${result.stderr}', contains('already'));
      // The other run's backup and the config are both left alone; consuming
      // either is how two concurrent runs delete both suppressions.
      expect(foreign.readAsStringSync(), 'other run owns this\n');
      expect(options.readAsStringSync(), suppressions);
    });
  });
}
