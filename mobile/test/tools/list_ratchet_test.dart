// ABOUTME: Tests for the shared shrink-only list ratchet engine.
// ABOUTME: Verifies rename provenance while preserving the no-growth guard.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('list_ratchet engine renamed-from provenance', () {
    late Directory tmp;
    late String libPath;
    late File current;
    late File baseline;
    late File probe;
    late File baseBaseline;

    void writeCurrent(String body) => current.writeAsStringSync(body);

    void commitBaseBaseline(String body) {
      baseBaseline.writeAsStringSync(body);
      for (final args in [
        ['add', '.'],
        ['commit', '-m', 'update base baseline'],
      ]) {
        final result = Process.runSync('git', ['-C', tmp.path, ...args]);
        expect(result.exitCode, 0, reason: result.stderr.toString());
      }
    }

    ProcessResult run() => Process.runSync(
      'bash',
      [probe.path],
      environment: {
        'PROBE_MOBILE': '${tmp.path}/m',
        'PROBE_BASELINE': baseline.path,
        'PROBE_CURRENT': current.path,
        'PROBE_LIB': libPath,
      },
    );

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('list_ratchet_test');
      Directory('${tmp.path}/m').createSync(recursive: true);
      baseBaseline = File(
        '${tmp.path}/mobile/scripts/baseline/__list_probe__.txt',
      )..createSync(recursive: true);
      baseBaseline.writeAsStringSync('# probe baseline\na\nb\n');
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
      libPath = File('scripts/lib/list_ratchet.sh').absolute.path;
      current = File('${tmp.path}/current.txt');
      baseline = File('${tmp.path}/baseline.txt');
      probe = File('${tmp.path}/probe.sh')
        ..writeAsStringSync(r'''
#!/usr/bin/env bash
set -euo pipefail
MOBILE_DIR="$PROBE_MOBILE"
RATCHET_LABEL="probe"
BASELINE_FILE="$PROBE_BASELINE"
BASELINE_REPO_PATH="mobile/scripts/baseline/__list_probe__.txt"
BASE_REF="HEAD"
ALLOW_NO_BASE=0
ALLOW_NO_BASE_VAR="PROBE_ALLOW_NO_BASE"
NEW_HINT="new-hint"
STALE_HINT="stale-hint"
FOOTER="footer"
emit_current() { sort -u "$PROBE_CURRENT"; }
print_baseline_header() { echo "# probe baseline"; }
source "$PROBE_LIB"
run_list_ratchet
''');
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    test('allows a pending rename', () {
      baseline.writeAsStringSync('# probe baseline\nb\nc # renamed-from: a\n');
      writeCurrent('b\nc\n');

      final res = run();

      expect(res.exitCode, 0, reason: res.stdout.toString());
    });

    test('rejects a missing or retained old key', () {
      baseline.writeAsStringSync(
        '# probe baseline\na\nb\nc # renamed-from: missing\n',
      );
      writeCurrent('a\nb\nc\n');

      final missing = run();
      expect(missing.exitCode, 1);
      expect(missing.stdout, contains('old key is not in HEAD'));

      baseline.writeAsStringSync(
        '# probe baseline\na\nb\nc # renamed-from: a\n',
      );
      final retained = run();
      expect(retained.exitCode, 1);
      expect(retained.stdout, contains('old key remains'));
      expect(retained.stdout, contains('old key is still emitted'));
    });

    test('rejects duplicate new and old claims', () {
      baseline.writeAsStringSync(
        '# probe baseline\n'
        'a\n'
        'b\n'
        'c # renamed-from: a\n'
        'c # renamed-from: b\n',
      );
      writeCurrent('a\nb\nc\n');

      final duplicateNew = run();

      expect(duplicateNew.exitCode, 1);
      expect(
        duplicateNew.stdout,
        contains('duplicate rename claim for new key c'),
      );

      baseline.writeAsStringSync(
        '# probe baseline\n'
        'b\n'
        'c # renamed-from: a\n'
        'd # renamed-from: a\n',
      );
      writeCurrent('b\nc\nd\n');
      final duplicateOld = run();

      expect(duplicateOld.exitCode, 1);
      expect(
        duplicateOld.stdout,
        contains('old key a is claimed more than once'),
      );
    });

    test('rejects an empty renamed-from key', () {
      baseline.writeAsStringSync('# probe baseline\na\nb\nc # renamed-from:\n');
      writeCurrent('a\nb\nc\n');

      final res = run();

      expect(res.exitCode, 1);
      expect(res.stdout, contains('malformed renamed-from annotation'));
    });

    test('accepts preserved provenance after the rename reaches the base', () {
      const renamed = '# probe baseline\nb\nc # renamed-from: a\n';
      commitBaseBaseline(renamed);
      baseline.writeAsStringSync(renamed);
      writeCurrent('b\nc\n');

      final res = run();

      expect(res.exitCode, 0, reason: res.stdout.toString());
    });
  });
}
