// ABOUTME: Tests for the raw-Icons ceiling ratchet (scripts/check_raw_icons_ceiling.sh)
// ABOUTME: Verifies bootstrap, comment-exclusion, pass, growth/new/stale-fail, shrink-pass, anti-bypass

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Drives `scripts/check_raw_icons_ceiling.sh` against an isolated temp tree so
/// the per-file raw-`Icons.*` ceiling logic (#4803, epic #4339) is verified
/// without touching the real baseline. The bash script is the source of truth;
/// this test pins its exit-code contract.
void main() {
  // Failure wording below comes from the shared engine in
  // scripts/lib/numeric_ratchet.sh, which this guard sources (#8323). It is
  // key-oriented ("NEW key(s)", "no longer emitted") rather than the
  // file-oriented phrasing the pre-port inline copy used.
  group('raw_icons_ceiling ratchet', () {
    late Directory tmp;
    late String scriptPath;
    late String baselinePath;

    File libFile(String name) => File('${tmp.path}/lib/$name');

    // Writes [n] code lines, each containing exactly one raw `Icons.*` match.
    void writeIcons(String name, int n) {
      final body = List.filled(
        n,
        'final w = const Icon(Icons.add);',
      ).join('\n');
      libFile(name).writeAsStringSync('$body\n');
    }

    void writeRaw(String name, String contents) {
      libFile(name).writeAsStringSync(contents);
    }

    ProcessResult run({
      bool update = false,
      bool allowNoBase = true,
      String baseRef = 'refs/heads/raw-icons-ceiling-test-no-base-ref',
      String? baseRepoPath,
    }) {
      return Process.runSync(
        'bash',
        [scriptPath],
        environment: {
          'RAW_ICONS_SCAN_DIR': '${tmp.path}/lib',
          'RAW_ICONS_PATH_PREFIX': tmp.path,
          'RAW_ICONS_BASELINE_FILE': baselinePath,
          'RAW_ICONS_BASELINE_BASE_REF': baseRef,
          'RAW_ICONS_CEILING_ALLOW_NO_BASE': allowNoBase ? '1' : '0',
          'RAW_ICONS_BASELINE_REPO_PATH': ?baseRepoPath,
          if (update) 'UPDATE_BASELINE': '1',
        },
      );
    }

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('raw_icons_ceiling_test');
      Directory('${tmp.path}/lib').createSync(recursive: true);
      scriptPath = File('scripts/check_raw_icons_ceiling.sh').absolute.path;
      baselinePath = '${tmp.path}/baseline.txt';
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    test('script exists', () {
      expect(File(scriptPath).existsSync(), isTrue);
    });

    test('UPDATE_BASELINE freezes only files using raw Icons.*', () {
      writeIcons('uses.dart', 3);
      writeIcons('clean.dart', 0); // 0 icons -> empty file, excluded

      final res = run(update: true);
      expect(res.exitCode, 0, reason: res.stderr.toString());

      final baseline = File(baselinePath)
          .readAsLinesSync()
          .where((l) => l.isNotEmpty && !l.startsWith('#'))
          .toList();
      expect(baseline, hasLength(1));
      expect(baseline.single, contains('lib/uses.dart'));
      expect(baseline.single, contains('3'));
    });

    test('does not count raw Icons.* inside full-line doc comments', () {
      writeRaw('doc.dart', '/// Example: const Icon(Icons.favorite)\n');

      final res = run(update: true);
      expect(res.exitCode, 0, reason: res.stderr.toString());

      final baseline = File(baselinePath)
          .readAsLinesSync()
          .where((l) => l.isNotEmpty && !l.startsWith('#'))
          .toList();
      expect(baseline, isEmpty);
    });

    test('passes when nothing changed', () {
      writeIcons('uses.dart', 3);
      run(update: true);

      final res = run();
      expect(res.exitCode, 0, reason: res.stdout.toString());
      expect(res.stdout, contains('OK [raw_icons_ceiling]'));
    });

    test('fails when a baselined file gains icons past its ceiling', () {
      writeIcons('uses.dart', 3);
      run(update: true);

      writeIcons('uses.dart', 5);
      final res = run();
      expect(res.exitCode, 1);
      expect(res.stdout, contains('GREW past the frozen ceiling'));
    });

    test('fails when a new file introduces raw Icons.*', () {
      writeIcons('uses.dart', 3);
      run(update: true);

      writeIcons('newbie.dart', 1);
      final res = run();
      expect(res.exitCode, 1);
      expect(res.stdout, contains('NEW key(s)'));
    });

    test('fails (stale) when a baselined file drops all raw Icons.*', () {
      writeIcons('uses.dart', 3);
      run(update: true);

      writeIcons('uses.dart', 0);
      final res = run();
      expect(res.exitCode, 1);
      expect(res.stdout, contains('no longer emitted'));
    });

    // Before #8323 this shape PASSED: a drop that stayed above zero was slack
    // the guard tolerated, so a migration's win was left unlocked and the file
    // could silently regrow to its stale ceiling. The guard now requires the
    // lower ceiling to be committed in the same change.
    test(
      'fails when a file drops some icons without relocking the ceiling',
      () {
        writeIcons('uses.dart', 5);
        run(update: true);

        writeIcons('uses.dart', 2);
        final res = run();
        expect(res.exitCode, 1);
        expect(res.stdout, contains('DECREASED below the frozen ceiling'));
        expect(res.stdout, contains('lib/uses.dart\t5 -> 2'));
        expect(res.stdout, contains('UPDATE_BASELINE=1'));
      },
    );

    test('passes once the lower ceiling is committed', () {
      writeIcons('uses.dart', 5);
      run(update: true);

      writeIcons('uses.dart', 2);
      run(update: true);
      final res = run();
      expect(res.exitCode, 0, reason: res.stdout.toString());
      expect(res.stdout, contains('OK [raw_icons_ceiling]'));
    });

    test('fails when the branch baseline adds a file vs base ref', () {
      writeIcons('uses.dart', 3);
      run(update: true);

      // Diff the temp baseline against a committed fixture baseline to exercise
      // the anti-bypass ADDED path. 'lib/uses.dart' is absent from that base,
      // so it must be flagged as added.
      final res = run(
        allowNoBase: false,
        baseRef: 'HEAD',
        baseRepoPath: 'mobile/test/tools/fixtures/raw_icons_base_sizes.txt',
      );
      expect(res.exitCode, 1);
      expect(res.stdout, contains('ADDED a key or RAISED a ceiling'));
      expect(res.stdout, contains('+added lib/uses.dart'));
    });
  });
}
