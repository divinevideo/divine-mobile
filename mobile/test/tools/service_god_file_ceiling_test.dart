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
      expect(
        res.stdout,
        contains('UPDATE_BASELINE alone cannot approve'),
      );
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

      test(
        'allows a settled annotation when the base ref is unavailable',
        () {
          writeLines('new_service.dart', 6);
          File(baselinePath).writeAsStringSync(
            '# Frozen baseline\n'
            'lib/services/new_service.dart\t6 '
            '# renamed-from: lib/services/old_service.dart\n',
          );

          final res = run();

          expect(res.exitCode, 0, reason: '${res.stdout}\n${res.stderr}');
          expect(res.stdout, contains('unavailable; skipping'));
          expect(res.stdout, isNot(contains('renamed-from old key is not')));
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

      /// Commits a base whose baseline already carries a settled annotation,
      /// the state every rename reaches once it merges. `UPDATE_BASELINE`
      /// carries the annotation forward by key, so the row outlives the move.
      void seedLandedAnnotation({int lines = 8}) {
        writeDistinctLines('new_service.dart', lines);
        File(baselinePath).writeAsStringSync(
          '# Frozen baseline\n'
          'lib/services/new_service.dart\t$lines '
          '# renamed-from: lib/services/old_service.dart\n',
        );
        commit('landed');
        git(['branch', 'base']);
      }

      test('a landed annotation does not block a later shrink', () {
        seedLandedAnnotation();
        writeDistinctLines('new_service.dart', 6);
        commit('shrink');

        final res = runAgainstBase();

        expect(res.exitCode, 0, reason: '${res.stdout}\n${res.stderr}');
        expect(res.stdout, isNot(contains('rename chains')));
      });

      test('a landed annotation survives regenerating after a shrink', () {
        seedLandedAnnotation();
        writeDistinctLines('new_service.dart', 6);
        run(update: true);
        commit('shrink');

        expect(
          baselineRows().single,
          'lib/services/new_service.dart\t6 '
          '# renamed-from: lib/services/old_service.dart',
        );
        final res = runAgainstBase();

        expect(res.exitCode, 0, reason: '${res.stdout}\n${res.stderr}');
      });

      test('a landed annotation still reports growth, and only growth', () {
        seedLandedAnnotation();
        writeDistinctLines('new_service.dart', 12);
        commit('grow');

        final res = runAgainstBase();

        expect(res.exitCode, 1);
        expect(res.stdout, contains('GREW past the frozen ceiling'));
        expect(res.stdout, isNot(contains('rename chains')));
      });

      test(
        'a settled claim does not reserve its old key for a later move',
        () {
          writeDistinctLines('c_service.dart', 6, prefix: 'c');
          writeDistinctLines('a_service.dart', 10, prefix: 'a');
          File(baselinePath).writeAsStringSync(
            '# Frozen baseline\n'
            'lib/services/a_service.dart\t10\n'
            'lib/services/c_service.dart\t6 '
            '# renamed-from: lib/services/a_service.dart\n',
          );
          commit('base');
          git(['branch', 'base']);
          serviceFile(
            'a_service.dart',
          ).renameSync(serviceFile('e_service.dart').path);
          File(baselinePath).writeAsStringSync(
            '# Frozen baseline\n'
            'lib/services/c_service.dart\t6 '
            '# renamed-from: lib/services/a_service.dart\n'
            'lib/services/e_service.dart\t10 '
            '# renamed-from: lib/services/a_service.dart\n',
          );
          commit('move');

          final res = runAgainstBase();

          expect(res.exitCode, 0, reason: '${res.stdout}\n${res.stderr}');
          expect(res.stdout, isNot(contains('claimed more than once')));
        },
      );

      test('verifies a rename claim in a shallow CI checkout', () {
        // Mobile CI checks out at actions/checkout's default fetch-depth of 1
        // and fetches the base ref with --depth=1, so the two grafts share no
        // ancestor. Every other test here runs against full local history,
        // where the probe cannot fail this way.
        writeDistinctLines('old_service.dart', 20);
        File(baselinePath).writeAsStringSync(
          '# Frozen baseline\nlib/services/old_service.dart\t20\n',
        );
        commit('base');
        // The harness inits without -b, so the first branch is named by the
        // runner's init.defaultBranch: main here, master on a stock CI image.
        // This test names the base branch three times, so pin it.
        git(['branch', '-M', 'main']);
        git(['checkout', '-b', 'pr']);
        serviceFile(
          'old_service.dart',
        ).renameSync(serviceFile('new_service.dart').path);
        writeDistinctLines('new_service.dart', 8);
        File(baselinePath).writeAsStringSync(
          '# Frozen baseline\n'
          'lib/services/new_service.dart\t8 '
          '# renamed-from: lib/services/old_service.dart\n',
        );
        commit('rename');
        // The ref GitHub builds for a pull request: the branch merged into the
        // base tip. main itself stays where it was.
        git(['checkout', '-b', 'pr-merge', 'main']);
        git(['merge', '--no-ff', '-m', 'merge', 'pr']);
        git(['checkout', 'main']);

        final ws = Directory.systemTemp.createTempSync('service_god_file_ws');
        addTearDown(() {
          if (ws.existsSync()) ws.deleteSync(recursive: true);
        });
        void wsGit(List<String> args) {
          final result = Process.runSync('git', ['-C', ws.path, ...args]);
          expect(result.exitCode, 0, reason: result.stderr.toString());
        }

        wsGit(['init']);
        wsGit(['config', 'user.email', 'test@example.invalid']);
        wsGit(['config', 'user.name', 'Ratchet Test']);
        wsGit(['remote', 'add', 'origin', tmp.path]);
        wsGit(['fetch', '--no-tags', '--depth=1', 'origin', 'pr-merge']);
        wsGit(['checkout', '--detach', 'FETCH_HEAD']);
        wsGit(['fetch', '--depth=1', 'origin', 'main']);
        expect(
          Process.runSync('git', [
            '-C',
            ws.path,
            'merge-base',
            'origin/main',
            'HEAD',
          ]).exitCode,
          isNot(0),
          reason: 'the checkout under test must start without a merge base',
        );

        final res = Process.runSync(
          'bash',
          ['${ws.path}/mobile/scripts/check_service_god_file_ceiling.sh'],
          environment: {
            'SERVICE_GOD_FILE_SCAN_DIR': '${ws.path}/mobile/lib/services',
            'SERVICE_GOD_FILE_PATH_PREFIX': '${ws.path}/mobile',
            'SERVICE_GOD_FILE_BASELINE_FILE':
                '${ws.path}/mobile/scripts/baseline/test.txt',
            'SERVICE_GOD_FILE_BASELINE_REPO_PATH':
                'mobile/scripts/baseline/test.txt',
            'SERVICE_GOD_FILE_THRESHOLD': '5',
            'SERVICE_GOD_FILE_BASELINE_BASE_REF': 'origin/main',
            'SERVICE_GOD_FILE_CEILING_ALLOW_NO_BASE': '0',
          },
        );

        expect(res.exitCode, 0, reason: '${res.stdout}\n${res.stderr}');
        expect(res.stderr, contains('honoured rename claim'));
      });
    });
  });
}
