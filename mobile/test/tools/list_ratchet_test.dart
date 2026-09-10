// ABOUTME: Tests for the shared shrink-only list engine (scripts/lib/list_ratchet.sh)
// ABOUTME: Pins the optional filter_baseline_growth hook contract for all consumers

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Exercises `scripts/lib/list_ratchet.sh` in isolation through a probe script
/// whose `emit_current` reads a fixture file.
///
/// Ten `check_*.sh` guards source this engine. Only one of them defines the
/// optional `filter_baseline_growth` hook, so the path that matters most to
/// the other nine is the one where the hook is *absent* and growth must still
/// fail. That path has no coverage through any concrete consumer, which is
/// what these tests pin.
void main() {
  group('list_ratchet engine', () {
    late Directory tmp;
    late String libPath;
    late File current;
    late File baseline;
    late File probe;

    void writeCurrent(List<String> items) =>
        current.writeAsStringSync('${items.join('\n')}\n');

    void writeBaseline(List<String> items) =>
        baseline.writeAsStringSync('# probe baseline\n${items.join('\n')}\n');

    ProcessResult run({
      String? filterBody,
      String baseRef = 'basemain',
      bool allowNoBase = false,
      bool update = false,
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
          'PROBE_ALLOW_NO_BASE': allowNoBase ? '1' : '0',
          'PROBE_FILTER': ?filterBody,
          if (update) 'UPDATE_BASELINE': '1',
        },
      );
    }

    /// Commits [items] as the baseline on branch `basemain`, then leaves the
    /// working tree free for the test to diverge from it.
    void seedBaseRef(List<String> items) {
      String git(List<String> args) => Process.runSync('git', [
        '-C',
        tmp.path,
        '-c',
        'user.email=probe@example.com',
        '-c',
        'user.name=probe',
        ...args,
      ]).stdout.toString();

      git(['init', '--initial-branch=basemain']);
      writeBaseline(items);
      git(['add', '-A']);
      git(['commit', '-m', 'seed']);
    }

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('list_ratchet_test');
      Directory('${tmp.path}/m/scripts/baseline').createSync(recursive: true);
      libPath = File('scripts/lib/list_ratchet.sh').absolute.path;
      current = File('${tmp.path}/current.txt');
      baseline = File('${tmp.path}/m/scripts/baseline/probe.txt');
      probe = File('${tmp.path}/probe.sh');
      probe.writeAsStringSync(r'''
#!/usr/bin/env bash
set -euo pipefail
MOBILE_DIR="$PROBE_MOBILE"
RATCHET_LABEL="probe"
BASELINE_FILE="$PROBE_BASELINE"
BASELINE_REPO_PATH="m/scripts/baseline/probe.txt"
BASE_REF="$PROBE_BASE_REF"
ALLOW_NO_BASE="$PROBE_ALLOW_NO_BASE"
ALLOW_NO_BASE_VAR="PROBE_ALLOW_NO_BASE"
NEW_HINT="new-hint"
STALE_HINT="stale-hint"
FOOTER="footer"
emit_current() { cat "$PROBE_CURRENT"; }
print_baseline_header() { echo "# probe baseline"; }
if [[ -n "${PROBE_FILTER:-}" ]]; then
  eval "filter_baseline_growth() { $PROBE_FILTER; }"
fi
source "$PROBE_LIB"
run_list_ratchet
''');
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    group('filter_baseline_growth hook', () {
      test('growth fails when no hook is declared', () {
        seedBaseRef(['a']);
        writeBaseline(['a', 'b']);
        writeCurrent(['a', 'b']);

        final res = run();

        expect(res.exitCode, 1, reason: res.stdout.toString());
        expect(res.stdout, contains('baseline GREW'));
        expect(res.stdout, contains('b'));
      });

      test('growth still fails when the hook passes entries through', () {
        seedBaseRef(['a']);
        writeBaseline(['a', 'b']);
        writeCurrent(['a', 'b']);

        final res = run(filterBody: 'cat');

        expect(res.exitCode, 1, reason: res.stdout.toString());
        expect(res.stdout, contains('baseline GREW'));
      });

      test('growth passes when the hook exempts every entry', () {
        seedBaseRef(['a']);
        writeBaseline(['a', 'b']);
        writeCurrent(['a', 'b']);

        final res = run(filterBody: 'grep -v . || true');

        expect(res.exitCode, 0, reason: res.stdout.toString());
        expect(res.stdout, contains('OK [probe]'));
        expect(res.stdout, isNot(contains('baseline GREW')));
      });

      test('only the entries the hook keeps are reported', () {
        seedBaseRef(['a']);
        writeBaseline(['a', 'b', 'c']);
        writeCurrent(['a', 'b', 'c']);

        // Exempt 'b', keep 'c' as a failure.
        final res = run(filterBody: r"grep -v '^b$' || true");

        expect(res.exitCode, 1, reason: res.stdout.toString());
        expect(res.stdout, contains('baseline GREW'));

        // The engine indents each reported entry by two spaces. Match those
        // lines exactly: a bare substring search for 'b' also hits 'basemain'.
        final reported = res.stdout
            .toString()
            .split('\n')
            .where((l) => l.startsWith('  ') && !l.startsWith('  ->'))
            .map((l) => l.trim())
            .toList();
        expect(reported, contains('c'));
        expect(reported, isNot(contains('b')));
      });

      test('the hook cannot suppress a NEW entry', () {
        seedBaseRef(['a']);
        writeBaseline(['a']);
        // 'z' is a current offender that the baseline never declared.
        writeCurrent(['a', 'z']);

        final res = run(filterBody: 'grep -v . || true');

        expect(res.exitCode, 1, reason: res.stdout.toString());
        expect(res.stdout, contains('NEW entr'));
        expect(res.stdout, contains('z'));
      });

      test('the hook cannot suppress a STALE entry', () {
        seedBaseRef(['a', 'gone']);
        writeBaseline(['a', 'gone']);
        // 'gone' is baselined but no longer an offender.
        writeCurrent(['a']);

        final res = run(filterBody: 'grep -v . || true');

        expect(res.exitCode, 1, reason: res.stdout.toString());
        expect(res.stdout, contains('no longer offending'));
        expect(res.stdout, contains('gone'));
      });
    });

    group('base-ref handling', () {
      test('skips the growth check when the base ref has no baseline yet', () {
        seedBaseRef(['a']);
        // Point at a ref that exists but carries no baseline file.
        Process.runSync('git', [
          '-C',
          tmp.path,
          '-c',
          'user.email=probe@example.com',
          '-c',
          'user.name=probe',
          'rm',
          '-q',
          '--cached',
          'm/scripts/baseline/probe.txt',
        ]);
        Process.runSync('git', [
          '-C',
          tmp.path,
          '-c',
          'user.email=probe@example.com',
          '-c',
          'user.name=probe',
          'commit',
          '-m',
          'drop baseline',
        ]);
        writeBaseline(['a', 'b']);
        writeCurrent(['a', 'b']);

        final res = run();

        expect(res.exitCode, 0, reason: res.stdout.toString());
        expect(res.stdout, contains('no baseline on'));
      });

      test('fails closed when the base ref cannot be loaded', () {
        seedBaseRef(['a']);
        writeBaseline(['a']);
        writeCurrent(['a']);

        final res = run(baseRef: 'no/such/ref');

        expect(res.exitCode, 1, reason: res.stdout.toString());
        expect(res.stdout, contains('failing closed'));
      });

      test('soft-skips an unloadable base ref under the opt-out', () {
        seedBaseRef(['a']);
        writeBaseline(['a']);
        writeCurrent(['a']);

        final res = run(baseRef: 'no/such/ref', allowNoBase: true);

        expect(res.exitCode, 0, reason: res.stdout.toString());
        expect(res.stdout, contains('skipping growth check'));
      });
    });
  });
}
