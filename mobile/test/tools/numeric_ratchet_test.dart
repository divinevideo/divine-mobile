// ABOUTME: Tests for the shared numeric per-key ceiling engine (scripts/lib/numeric_ratchet.sh)
// ABOUTME: Drives the lib via a probe script against temp fixtures: pass/growth/new/stale/decrease

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Exercises `scripts/lib/numeric_ratchet.sh` in isolation through a tiny probe
/// script whose `emit_current` reads a fixture file. Pins the engine contract
/// shared by the service-sentinel and ARB-{error} ceilings (epic #4336).
void main() {
  group('numeric_ratchet engine', () {
    late Directory tmp;
    late String libPath;
    late File current;
    late File baseline;
    late File probe;

    void writeCurrent(String body) => current.writeAsStringSync(body);

    void commitBaseBaseline(String body) {
      File(
        '${tmp.path}/mobile/scripts/baseline/__probe_nonexistent__.txt',
      ).writeAsStringSync(body);
      for (final args in [
        ['add', '.'],
        ['commit', '-m', 'update base baseline'],
      ]) {
        final result = Process.runSync('git', ['-C', tmp.path, ...args]);
        expect(result.exitCode, 0, reason: result.stderr.toString());
      }
    }

    ProcessResult run({
      bool update = false,
      bool requireBaselineUpdateOnDecrease = false,
      bool allowRenameClaims = true,
      String baseRef = 'HEAD',
    }) {
      return Process.runSync(
        'bash',
        [probe.path],
        environment: {
          'PROBE_MOBILE': '${tmp.path}/m',
          'PROBE_BASELINE': baseline.path,
          'PROBE_CURRENT': current.path,
          'PROBE_LIB': libPath,
          'PROBE_BASE_REF': baseRef,
          'PROBE_BASELINE_REPO_PATH':
              'mobile/scripts/baseline/__probe_nonexistent__.txt',
          if (allowRenameClaims) 'PROBE_ALLOW_RENAME_CLAIMS': '1',
          if (requireBaselineUpdateOnDecrease)
            'PROBE_REQUIRE_BASELINE_UPDATE_ON_DECREASE': '1',
          if (update) 'UPDATE_BASELINE': '1',
        },
      );
    }

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('numeric_ratchet_test');
      Directory('${tmp.path}/m').createSync(recursive: true);
      Directory(
        '${tmp.path}/mobile/scripts/baseline',
      ).createSync(recursive: true);
      File(
        '${tmp.path}/mobile/scripts/baseline/__probe_nonexistent__.txt',
      ).writeAsStringSync('# probe baseline\na\t5\nb\t3\n');
      File('${tmp.path}/a').writeAsStringSync('same\n');
      for (final args in [
        ['init'],
        ['config', 'user.email', 'test@example.invalid'],
        ['config', 'user.name', 'Ratchet Test'],
        ['add', '.'],
        ['commit', '-m', 'base'],
      ]) {
        final result = Process.runSync('git', ['-C', tmp.path, ...args]);
        expect(result.exitCode, 0, reason: result.stderr.toString());
      }
      libPath = File('scripts/lib/numeric_ratchet.sh').absolute.path;
      current = File('${tmp.path}/current.txt');
      baseline = File('${tmp.path}/baseline.txt');
      probe = File('${tmp.path}/probe.sh');
      probe.writeAsStringSync(r'''
#!/usr/bin/env bash
set -euo pipefail
MOBILE_DIR="$PROBE_MOBILE"
RATCHET_LABEL="probe"
BASELINE_FILE="$PROBE_BASELINE"
BASELINE_REPO_PATH="${PROBE_BASELINE_REPO_PATH:-mobile/scripts/baseline/__probe_nonexistent__.txt}"
BASE_REF="${PROBE_BASE_REF:-origin/main}"
ALLOW_NO_BASE=1
ALLOW_NO_BASE_VAR="PROBE_ALLOW_NO_BASE"
ALLOW_RENAME_CLAIMS="${PROBE_ALLOW_RENAME_CLAIMS:-0}"
REQUIRE_BASELINE_UPDATE_ON_DECREASE="${PROBE_REQUIRE_BASELINE_UPDATE_ON_DECREASE:-0}"
NEW_HINT="new-hint"
STALE_HINT="stale-hint"
FOOTER="footer"
emit_current() { cat "$PROBE_CURRENT"; }
print_baseline_header() { echo "# probe baseline"; }
rename_key_to_repo_path() { printf '%s\n' "$1"; }
source "$PROBE_LIB"
run_numeric_ratchet
''');
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    test('UPDATE_BASELINE freezes the current key/count set', () {
      writeCurrent('a\t5\nb\t3\n');
      final res = run(update: true);
      expect(res.exitCode, 0, reason: res.stderr.toString());
      final entries = baseline
          .readAsLinesSync()
          .where((l) => l.isNotEmpty && !l.startsWith('#'))
          .toList();
      expect(entries, hasLength(2));
    });

    test('passes when counts are unchanged', () {
      writeCurrent('a\t5\nb\t3\n');
      run(update: true);
      final res = run();
      expect(res.exitCode, 0, reason: res.stdout.toString());
      expect(res.stdout, contains('OK [probe]'));
    });

    test('fails when a key count grows', () {
      writeCurrent('a\t5\nb\t3\n');
      run(update: true);
      writeCurrent('a\t6\nb\t3\n');
      final res = run();
      expect(res.exitCode, 1);
      expect(res.stdout, contains('GREW'));
    });

    test('fails when a new key appears', () {
      writeCurrent('a\t5\nb\t3\n');
      run(update: true);
      writeCurrent('a\t5\nb\t3\nc\t1\n');
      final res = run();
      expect(res.exitCode, 1);
      expect(res.stdout, contains('NEW key'));
    });

    test('fails (stale) when a baselined key disappears', () {
      writeCurrent('a\t5\nb\t3\n');
      run(update: true);
      writeCurrent('a\t5\n');
      final res = run();
      expect(res.exitCode, 1);
      expect(res.stdout, contains('no longer emitted'));
    });

    test('passes when a count decreases (low friction)', () {
      writeCurrent('a\t5\nb\t3\n');
      run(update: true);
      writeCurrent('a\t4\nb\t3\n');
      final res = run();
      expect(res.exitCode, 0, reason: res.stdout.toString());
      expect(res.stdout, contains('OK [probe]'));
    });

    test('can require a baseline update when a count decreases', () {
      writeCurrent('a\t5\n');
      run(update: true);
      writeCurrent('a\t4\n');

      final res = run(requireBaselineUpdateOnDecrease: true);

      expect(res.exitCode, 1);
      expect(res.stdout, contains('DECREASED'));
      expect(res.stdout, contains('a\t5 -> 4'));
    });

    group('renamed-from provenance', () {
      void moveTrackedKey(String oldKey, String newKey) {
        File('${tmp.path}/$oldKey').renameSync('${tmp.path}/$newKey');
        final intentToAdd = Process.runSync('git', [
          '-C',
          tmp.path,
          'add',
          '-N',
          newKey,
        ]);
        expect(intentToAdd.exitCode, 0, reason: intentToAdd.stderr.toString());
      }

      test('rejects rename claims unless the guard opts in', () {
        baseline.writeAsStringSync(
          '# probe baseline\nb\t3\nc\t4 # renamed-from: a\n',
        );
        writeCurrent('b\t3\nc\t4\n');

        final res = run(allowRenameClaims: false);

        expect(res.exitCode, 1);
        expect(res.stdout, contains('does not allow renamed-from annotations'));
        expect(res.stdout, contains('+added'));
      });

      test('allows a pending rename that preserves the old ceiling', () {
        moveTrackedKey('a', 'c');
        baseline.writeAsStringSync(
          '# probe baseline\nb\t3\nc\t4 # renamed-from: a\n',
        );
        writeCurrent('b\t3\nc\t4\n');

        final res = run();

        expect(res.exitCode, 0, reason: res.stdout.toString());
      });

      test('rejects a quota transfer that is not a Git rename', () {
        baseline.writeAsStringSync(
          '# probe baseline\nb\t3\nc\t4 # renamed-from: a\n',
        );
        writeCurrent('b\t3\nc\t4\n');

        final res = run();

        expect(res.exitCode, 1);
        expect(res.stdout, contains('is not a Git rename'));
        expect(res.stdout, contains('+added'));
      });

      test('rejects a renamed key above the old ceiling', () {
        moveTrackedKey('a', 'c');
        baseline.writeAsStringSync(
          '# probe baseline\nb\t3\nc\t6 # renamed-from: a\n',
        );
        writeCurrent('b\t3\nc\t6\n');

        final res = run();

        expect(res.exitCode, 1);
        expect(res.stdout, contains('exceeds old ceiling'));
      });

      test('rejects a non-numeric count on an annotated row', () {
        moveTrackedKey('a', 'c');
        // The feature asks humans to hand-edit this row, so a stray character
        // in the count column is the expected typo. Bash arithmetic on a
        // non-numeric operand makes `[[ -gt ]]` return 2, not 1, which `if`
        // reads as false — before this guard the script printed OK and exited
        // 0 with a 9999-count key holding a ceiling of 5.
        baseline.writeAsStringSync(
          '# probe baseline\nb\t3\nc\t9999, # renamed-from: a\n',
        );
        writeCurrent('b\t3\nc\t9999\n');

        final res = run();

        expect(res.exitCode, 1, reason: res.stdout.toString());
        expect(res.stdout, contains('non-numeric ceiling'));
      });

      test('reports a rename annotation written without the hash', () {
        // Dropping the '#' leaves a bare word in the count column. Under
        // `set -u` that used to abort the script mid-run: empty stdout, no
        // FAIL banner, no footer, and the temp claim file left behind. It is
        // not a claim at all now, so the row is reported as what it is — an
        // unapproved baseline addition.
        baseline.writeAsStringSync(
          '# probe baseline\nb\t3\nc\t4 renamed-from: a\n',
        );
        writeCurrent('b\t3\nc\t4\n');

        final res = run();

        expect(res.exitCode, 1);
        expect(res.stdout, contains('FAIL [probe]'));
        expect(res.stdout, contains('+added'));
        expect(res.stdout, contains('footer'));
      });

      test('does not parse a reason that merely mentions the phrase', () {
        // "# recover: ..." is the documented shape for a skip-ceiling reason,
        // and #4836 reasons are prose. Matching the phrase anywhere on the row
        // turned one into a claim against a key nobody renamed.
        baseline.writeAsStringSync(
          '# probe baseline\n'
          'a\t5\n'
          'b\t3\n'
          'c\t4 # recover: renamed-from: the legacy harness\n',
        );
        writeCurrent('a\t5\nb\t3\nc\t4\n');

        final res = run();

        expect(res.exitCode, 1);
        expect(res.stdout, contains('+added'));
        expect(res.stdout, isNot(contains('renamed-from old key')));
      });

      test('keeps an annotation written without a space before the hash', () {
        // Both readers accept "4# renamed-from: a"; the baseline writer
        // required whitespace, so regeneration silently dropped the claim and
        // the next run failed with a bare "+added" nothing in the diff explains.
        baseline.writeAsStringSync(
          '# probe baseline\nb\t3\nc\t4# renamed-from: a\n',
        );
        writeCurrent('b\t3\nc\t4\n');

        run(update: true);

        expect(baseline.readAsStringSync(), contains('renamed-from: a'));
      });

      test('rejects a claim whose old key is absent from the base', () {
        baseline.writeAsStringSync(
          '# probe baseline\na\t5\nc\t3 # renamed-from: missing\n',
        );
        writeCurrent('a\t5\nc\t3\n');

        final res = run();

        expect(res.exitCode, 1);
        expect(res.stdout, contains('old key is not in HEAD'));
      });

      test('rejects a claim while the old key remains', () {
        baseline.writeAsStringSync(
          '# probe baseline\na\t5\nb\t3\nc\t4 # renamed-from: a\n',
        );
        writeCurrent('a\t5\nb\t3\nc\t4\n');

        final res = run();

        expect(res.exitCode, 1);
        expect(res.stdout, contains('old key remains'));
        expect(res.stdout, contains('old key is still emitted'));
      });

      test('does not invent a ceiling failure for an absent old key', () {
        // `-z "$old_count"` was folded into the ceiling condition, so a claim
        // naming a key that is not on the base ref produced a second,
        // factually wrong line about a ceiling that never existed.
        baseline.writeAsStringSync(
          '# probe baseline\na\t5\nc\t4 # renamed-from: ghost\n',
        );
        writeCurrent('a\t5\nc\t4\n');

        final res = run();

        expect(res.exitCode, 1);
        expect(res.stdout, contains('old key is not in HEAD'));
        expect(res.stdout, isNot(contains('exceeds old ceiling')));
        expect(res.stdout, isNot(contains('non-numeric ceiling')));
      });

      test('still names the unapproved row when a claim fails', () {
        // The `added` subtraction ran even for a claim that just failed
        // validation, so the operator was told the annotation was wrong and
        // never told which baseline row was unapproved.
        baseline.writeAsStringSync(
          '# probe baseline\na\t5\nb\t3\nc\t4 # renamed-from: a\n',
        );
        writeCurrent('a\t5\nb\t3\nc\t4\n');

        final res = run();

        expect(res.exitCode, 1);
        expect(res.stdout, contains('old key remains'));
        expect(res.stdout, contains('+added'));
      });

      test('rejects a second un-annotated row for the renamed key', () {
        // The ceiling lookup reads the first row for the key; the `added`
        // subtraction removed every row with it. One annotation therefore
        // carried a duplicate, un-annotated row past the report.
        baseline.writeAsStringSync(
          '# probe baseline\nb\t3\nc\t9\nc\t4 # renamed-from: a\n',
        );
        writeCurrent('b\t3\nc\t4\n');

        final res = run();

        expect(res.exitCode, 1, reason: res.stdout.toString());
        expect(res.stdout, contains('appears more than once'));
      });

      test('rejects duplicate claims for a new or old key', () {
        baseline.writeAsStringSync(
          '# probe baseline\n'
          'a\t5\n'
          'b\t3\n'
          'c\t4 # renamed-from: a\n'
          'c\t4 # renamed-from: b\n',
        );
        writeCurrent('a\t5\nb\t3\nc\t4\n');

        final duplicateNew = run();

        expect(duplicateNew.exitCode, 1);
        expect(
          duplicateNew.stdout,
          contains('duplicate rename claim for new key c'),
        );

        baseline.writeAsStringSync(
          '# probe baseline\n'
          'b\t3\n'
          'c\t4 # renamed-from: a\n'
          'd\t2 # renamed-from: a\n',
        );
        writeCurrent('b\t3\nc\t4\nd\t2\n');
        final duplicateOld = run();

        expect(duplicateOld.exitCode, 1);
        expect(
          duplicateOld.stdout,
          contains('old key a is claimed more than once'),
        );
      });

      test('rejects an empty renamed-from key', () {
        baseline.writeAsStringSync(
          '# probe baseline\na\t5\nb\t3\nc\t2 # renamed-from:\n',
        );
        writeCurrent('a\t5\nb\t3\nc\t2\n');

        final res = run();

        expect(res.exitCode, 1);
        expect(res.stdout, contains('malformed renamed-from annotation'));
      });

      test('ignores a settled claim when the old key comes back', () {
        // Base and branch are identical here: the rename landed long ago and a
        // later key reused the old name. Nothing grew, so nothing may fail.
        const settled =
            '# probe baseline\na\t5\nb\t3\nc\t4 # renamed-from: a\n';
        commitBaseBaseline(settled);
        baseline.writeAsStringSync(settled);
        writeCurrent('a\t5\nb\t3\nc\t4\n');

        final res = run();

        expect(res.exitCode, 0, reason: res.stdout.toString());
      });

      test("lets a later rename reuse a settled claim's old key", () {
        // The rename landed long ago and the annotation was kept (AGENTS.md
        // says it may be removed, not must). A settled claim grants nothing,
        // but it was still counted by the duplicate checks, so it reserved the
        // old key forever and failed the next legitimate rename onto it.
        commitBaseBaseline(
          '# probe baseline\na\t5\nb\t3\nc\t4 # renamed-from: a\n',
        );
        moveTrackedKey('a', 'd');
        baseline.writeAsStringSync(
          '# probe baseline\n'
          'b\t3\n'
          'c\t4 # renamed-from: a\n'
          'd\t5 # renamed-from: a\n',
        );
        writeCurrent('b\t3\nc\t4\nd\t5\n');

        final res = run();

        expect(res.exitCode, 0, reason: res.stdout.toString());
        expect(res.stdout, isNot(contains('claimed more than once')));
      });

      test('validates annotation syntax without a base ref', () {
        // The whole claim block sat inside the base-available arm, so a
        // malformed annotation was accepted silently on bootstrap and under
        // the documented local opt-out -- the runs where one gets planted.
        baseline.writeAsStringSync(
          '# probe baseline\na\t5\nb\t3\nc\t2 # renamed-from:\n',
        );
        writeCurrent('a\t5\nb\t3\nc\t2\n');

        final res = run(baseRef: 'no-such-ref-for-the-probe');

        expect(res.exitCode, 1, reason: res.stdout.toString());
        expect(res.stdout, contains('malformed renamed-from annotation'));
        expect(res.stdout, contains('local opt-out'));
      });

      test('names an honoured claim in the output', () {
        // A run that exercised the bypass must not be byte-identical to one
        // that did not: review is the only enforcement this mechanism has.
        moveTrackedKey('a', 'c');
        baseline.writeAsStringSync(
          '# probe baseline\nb\t3\nc\t4 # renamed-from: a\n',
        );
        writeCurrent('b\t3\nc\t4\n');

        final res = run();

        expect(res.exitCode, 0, reason: res.stdout.toString());
        expect(res.stdout, contains('honoured rename claim c <- a'));
      });

      test('ignores a comment line that documents the annotation', () {
        // print_baseline_header output is part of the file the claim scan
        // reads, so a header explaining the annotation must not parse as one.
        baseline.writeAsStringSync(
          '# probe baseline\n'
          '# A row may carry "# renamed-from: <old-key>" provenance.\n'
          'a\t5\n'
          'b\t3\n',
        );
        writeCurrent('a\t5\nb\t3\n');

        final res = run();

        expect(res.exitCode, 0, reason: res.stdout.toString());
      });

      test(
        'accepts preserved provenance after the rename reaches the base',
        () {
          const renamed = '# probe baseline\nb\t3\nc\t4 # renamed-from: a\n';
          commitBaseBaseline(renamed);
          baseline.writeAsStringSync(renamed);
          writeCurrent('b\t3\nc\t4\n');

          final res = run();

          expect(res.exitCode, 0, reason: res.stdout.toString());
        },
      );
    });

    group('trailing "# reason" comments', () {
      test('survive UPDATE_BASELINE, matched by key not by count', () {
        writeCurrent('a\t5\nb\t3\n');
        run(update: true);
        baseline.writeAsStringSync(
          '# probe baseline\na\t5 # rewrite: shell setup is stale (#4836)\nb\t3\n',
        );

        // `a` drops to 4: the count moves, the explanation must not.
        writeCurrent('a\t4\nb\t3\n');
        final res = run(update: true);

        expect(res.exitCode, 0, reason: res.stderr.toString());
        final lines = baseline
            .readAsLinesSync()
            .where((line) => !line.startsWith('#'))
            .toList();
        expect(lines, ['a\t4 # rewrite: shell setup is stale (#4836)', 'b\t3']);
      });

      test('are ignored by every comparison', () {
        writeCurrent('a\t5\n');
        run(update: true);
        baseline.writeAsStringSync('# probe baseline\na\t5 # some reason\n');

        final res = run();

        expect(res.exitCode, 0, reason: res.stdout.toString());
        expect(res.stdout, contains('OK [probe]'));
      });

      test('are dropped for a key that stops being emitted', () {
        writeCurrent('a\t5\nb\t3\n');
        run(update: true);
        baseline.writeAsStringSync(
          '# probe baseline\na\t5 # keep me\nb\t3 # drop me\n',
        );

        writeCurrent('a\t5\n');
        final res = run(update: true);

        expect(res.exitCode, 0, reason: res.stderr.toString());
        final lines = baseline
            .readAsLinesSync()
            .where((line) => !line.startsWith('#'))
            .toList();
        expect(lines, ['a\t5 # keep me']);
      });

      test(
        'an EMPTY offender set writes a zero-entry baseline, not an error',
        () {
          // A frozen-at-zero guard regenerates from nothing as its NORMAL state.
          // `grep -v` matches no lines and exits 1, so under `set -o pipefail`
          // plus `set -e` the write aborts unless it is guarded. Losing that
          // guard made every check_*_ceiling.sh exit 1 on a clean fixture.
          writeCurrent('');

          final res = run(update: true);

          expect(res.exitCode, 0, reason: res.stderr.toString());
          expect(res.stdout, contains('wrote 0 baseline entries'));
          expect(
            baseline.readAsLinesSync().where(
              (line) => line.isNotEmpty && !line.startsWith('#'),
            ),
            isEmpty,
          );
        },
      );

      test('a reason-free baseline regenerates byte-identically', () {
        writeCurrent('a\t5\nb\t3\n');
        run(update: true);
        final before = baseline.readAsStringSync();
        expect(before, contains('a\t5'));
        expect(before, contains('b\t3'));

        final res = run(update: true);

        expect(res.exitCode, 0, reason: res.stderr.toString());
        expect(baseline.readAsStringSync(), before);
      });
    });
  });
}
