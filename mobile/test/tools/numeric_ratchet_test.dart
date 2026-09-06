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

    ProcessResult run({
      bool update = false,
      bool requireBaselineUpdateOnDecrease = false,
    }) {
      return Process.runSync(
        'bash',
        [probe.path],
        environment: {
          'PROBE_MOBILE': '${tmp.path}/m',
          'PROBE_BASELINE': baseline.path,
          'PROBE_CURRENT': current.path,
          'PROBE_LIB': libPath,
          'PROBE_BASE_REF': 'HEAD',
          'PROBE_BASELINE_REPO_PATH':
              'mobile/scripts/baseline/__probe_nonexistent__.txt',
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
REQUIRE_BASELINE_UPDATE_ON_DECREASE="${PROBE_REQUIRE_BASELINE_UPDATE_ON_DECREASE:-0}"
NEW_HINT="new-hint"
STALE_HINT="stale-hint"
FOOTER="footer"
emit_current() { cat "$PROBE_CURRENT"; }
print_baseline_header() { echo "# probe baseline"; }
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
