// ABOUTME: Tests for the service god-file ceiling ratchet (#4338)
// ABOUTME: Verifies pass, growth/new/stale-fail, shrink-pass, and anti-bypass

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Drives `scripts/check_service_god_file_ceiling.sh` against an isolated temp
/// tree so the service-layer god-file line ceiling is verified without touching
/// the real baseline.
void main() {
  group('service_god_file_ceiling ratchet', () {
    late Directory tmp;
    late String scriptPath;
    late String baselinePath;

    File serviceFile(String name) =>
        File('${tmp.path}/mobile/lib/services/$name');

    void writeLines(String name, int n) {
      serviceFile(
        name,
      ).writeAsStringSync('${List.filled(n, '// line').join('\n')}\n');
    }

    void writeDistinctLines(String name, int n, {String prefix = 'kept'}) {
      serviceFile(name).writeAsStringSync(
        '${List.generate(n, (index) => '// $prefix line $index').join('\n')}\n',
      );
    }

    void git(List<String> args) {
      final result = Process.runSync('git', ['-C', tmp.path, ...args]);
      expect(result.exitCode, 0, reason: result.stderr.toString());
    }

    void commit(String message) {
      git(['add', '.']);
      git(['commit', '-m', message]);
    }

    ProcessResult run({
      bool update = false,
      bool allowNoBase = true,
      String baseRef = 'refs/heads/service-god-file-test-no-base-ref',
      String? baseRepoPath,
    }) {
      return Process.runSync(
        'bash',
        [scriptPath],
        environment: {
          'SERVICE_GOD_FILE_SCAN_DIR': '${tmp.path}/mobile/lib/services',
          'SERVICE_GOD_FILE_PATH_PREFIX': '${tmp.path}/mobile',
          'SERVICE_GOD_FILE_BASELINE_FILE': baselinePath,
          'SERVICE_GOD_FILE_THRESHOLD': '5',
          'SERVICE_GOD_FILE_BASELINE_BASE_REF': baseRef,
          'SERVICE_GOD_FILE_CEILING_ALLOW_NO_BASE': allowNoBase ? '1' : '0',
          'SERVICE_GOD_FILE_BASELINE_REPO_PATH': ?baseRepoPath,
          if (update) 'UPDATE_BASELINE': '1',
        },
      );
    }

    List<String> baselineRows() =>
        File(baselinePath)
            .readAsLinesSync()
            .where((l) => l.isNotEmpty && !l.startsWith('#'))
            .toList();

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('service_god_file_test');
      Directory('${tmp.path}/mobile/lib/services').createSync(recursive: true);
      Directory('${tmp.path}/mobile/scripts/lib').createSync(recursive: true);
      Directory(
        '${tmp.path}/mobile/scripts/baseline',
      ).createSync(recursive: true);
      File('scripts/check_service_god_file_ceiling.sh').copySync(
        '${tmp.path}/mobile/scripts/check_service_god_file_ceiling.sh',
      );
      File(
        'scripts/lib/numeric_ratchet.sh',
      ).copySync('${tmp.path}/mobile/scripts/lib/numeric_ratchet.sh');
      scriptPath =
          '${tmp.path}/mobile/scripts/check_service_god_file_ceiling.sh';
      baselinePath = '${tmp.path}/mobile/scripts/baseline/test.txt';
      git(['init']);
      git(['config', 'user.email', 'test@example.invalid']);
      git(['config', 'user.name', 'Ratchet Test']);
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    test('UPDATE_BASELINE freezes only oversized service files', () {
      writeLines('large_service.dart', 6);
      writeLines('small_service.dart', 5);

      final res = run(update: true);
      expect(res.exitCode, 0, reason: res.stderr.toString());

      expect(baselineRows(), hasLength(1));
      expect(baselineRows().single, 'lib/services/large_service.dart\t6');
    });

    test('passes when nothing changed', () {
      writeLines('large_service.dart', 6);
      run(update: true);

      final res = run();
      expect(res.exitCode, 0, reason: res.stdout.toString());
      expect(res.stdout, contains('OK [service_god_file_ceiling]'));
    });

    test('fails when a baselined service file grows past its ceiling', () {
      writeLines('large_service.dart', 6);
      run(update: true);

      writeLines('large_service.dart', 7);
      final res = run();
      expect(res.exitCode, 1);
      expect(res.stdout, contains('GREW past the frozen ceiling'));
    });

    test('fails when a new service file crosses the threshold', () {
      writeLines('large_service.dart', 6);
      run(update: true);

      writeLines('new_large_service.dart', 6);
      final res = run();
      expect(res.exitCode, 1);
      expect(res.stdout, contains('NEW key'));
    });

    test('fails stale when a baselined service drops below the threshold', () {
      writeLines('large_service.dart', 6);
      run(update: true);

      writeLines('large_service.dart', 5);
      final res = run();
      expect(res.exitCode, 1);
      expect(res.stdout, contains('no longer emitted'));
      expect(res.stdout, contains('removed, renamed, or dropped below'));
      expect(res.stdout, contains('UPDATE_BASELINE=1 bash'));
      expect(res.stdout, contains('check_service_god_file_ceiling.sh'));
    });

    test('passes when a service shrinks but remains oversized', () {
      writeLines('large_service.dart', 8);
      run(update: true);

      writeLines('large_service.dart', 6);
      final res = run();
      expect(res.exitCode, 0, reason: res.stdout.toString());
      expect(res.stdout, contains('OK [service_god_file_ceiling]'));
    });

    test('fails when the branch baseline raises a ceiling vs base ref', () {
      writeLines('large_service.dart', 6);
      run(update: true);
      commit('base');
      git(['branch', 'base']);

      final baseline = File(baselinePath);
      baseline.writeAsStringSync(
        baseline.readAsStringSync().replaceFirst(
          'lib/services/large_service.dart\t6',
          'lib/services/large_service.dart\t7',
        ),
      );
      writeLines('large_service.dart', 7);

      final res = run(
        allowNoBase: false,
        baseRef: 'base',
        baseRepoPath: 'mobile/scripts/baseline/test.txt',
      );
      expect(res.exitCode, 1);
      expect(res.stdout, contains('ADDED a key or RAISED a ceiling'));
      expect(res.stdout, contains('^raised lib/services/large_service.dart'));
    });

    group('guard-owned rename policy', () {
      void seedRenameBase({int lines = 20}) {
        writeDistinctLines('old_service.dart', lines);
        run(update: true);
        commit('base');
        git(['branch', 'base']);
      }

      void commitRename({int keptLines = 6}) {
        serviceFile(
          'old_service.dart',
        ).renameSync(serviceFile('new_service.dart').path);
        writeDistinctLines('new_service.dart', keptLines);
        File(baselinePath).writeAsStringSync(
          '# Frozen baseline\n'
          'lib/services/new_service.dart\t$keptLines '
          '# renamed-from: lib/services/old_service.dart\n',
        );
        commit('rename');
      }

      ProcessResult runAgainstBase() => run(
        allowNoBase: false,
        baseRef: 'base',
        baseRepoPath: 'mobile/scripts/baseline/test.txt',
      );

      test('accepts a verified move with a substantial extraction', () {
        seedRenameBase();
        commitRename();

        final res = runAgainstBase();

        expect(res.exitCode, 0, reason: '${res.stdout}\n${res.stderr}');
        expect(res.stderr, contains('honoured rename claim'));
      });

      test('rejects an unrelated file claiming retired quota', () {
        seedRenameBase();
        serviceFile('old_service.dart').deleteSync();
        writeDistinctLines('new_service.dart', 6, prefix: 'unrelated');
        File(baselinePath).writeAsStringSync(
          '# Frozen baseline\n'
          'lib/services/new_service.dart\t6 '
          '# renamed-from: lib/services/old_service.dart\n',
        );
        commit('replace');

        final res = runAgainstBase();

        expect(res.exitCode, 1);
        expect(res.stdout, contains('is not a Git rename'));
      });

      test('rejects ceiling headroom above the current extracted size', () {
        seedRenameBase();
        commitRename();
        File(baselinePath).writeAsStringSync(
          '# Frozen baseline\n'
          'lib/services/new_service.dart\t20 '
          '# renamed-from: lib/services/old_service.dart\n',
        );

        final res = runAgainstBase();

        expect(res.exitCode, 1);
        expect(res.stdout, contains('must equal its current count'));
      });

      test('rejects zero-padded ceilings and multiple claim clauses', () {
        seedRenameBase();
        commitRename();
        File(baselinePath).writeAsStringSync(
          '# Frozen baseline\n'
          'lib/services/new_service.dart\t06 '
          '# renamed-from: lib/services/old_service.dart '
          '# renamed-from: lib/services/other.dart\n',
        );

        final res = runAgainstBase();

        expect(res.exitCode, 1);
        expect(res.stdout, contains('malformed renamed-from annotation'));
      });

      test('rejects semicolon claims', () {
        seedRenameBase();
        commitRename();
        File(baselinePath).writeAsStringSync(
          '# Frozen baseline\n'
          'lib/services/new_service.dart\t6 '
          '; renamed-from: lib/services/old_service.dart\n',
        );

        final res = runAgainstBase();

        expect(res.exitCode, 1);
        expect(res.stdout, contains('malformed renamed-from annotation'));
      });

      test(
        'rejects malformed claims even when the base ref is unavailable',
        () {
          writeLines('new_service.dart', 6);
          File(baselinePath).writeAsStringSync(
            '# Frozen baseline\n'
            'lib/services/new_service.dart\t06 '
            '# renamed-from: lib/services/old_service.dart\n',
          );

          final res = run();

          expect(res.exitCode, 1);
          expect(res.stdout, contains('malformed renamed-from annotation'));
        },
      );

      test('ignores a settled annotation that grants no growth', () {
        seedRenameBase();
        commitRename();
        git(['branch', '-f', 'base', 'HEAD']);

        final res = runAgainstBase();

        expect(res.exitCode, 0, reason: '${res.stdout}\n${res.stderr}');
        expect(res.stderr, isNot(contains('honoured rename claim')));
      });

      test('rejects rename chains with an explicit diagnostic', () {
        writeDistinctLines('old_service.dart', 10);
        writeDistinctLines('existing_service.dart', 6, prefix: 'existing');
        run(update: true);
        commit('base');
        git(['branch', 'base']);
        File(baselinePath).writeAsStringSync(
          '# Frozen baseline\n'
          'lib/services/existing_service.dart\t7 '
          '# renamed-from: lib/services/old_service.dart\n',
        );
        serviceFile('old_service.dart').deleteSync();
        writeDistinctLines('existing_service.dart', 7, prefix: 'existing');

        final res = runAgainstBase();

        expect(res.exitCode, 1);
        expect(
          res.stdout,
          contains('rename chains and swaps are not supported'),
        );
      });
    });
  });
}
