// ABOUTME: Tests the parallel guard driver behind Mobile CI's Guards job.
// ABOUTME: Pins replay order, failure reporting, gating, and manifest coverage.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Drives `scripts/ci/run_guards.sh` against throwaway manifests.
///
/// The driver replaces ~60 sequential workflow steps, so the properties a
/// reader of the Guards job log relied on are pinned here: every guard's
/// output appears, in manifest order, a failure is a `::error` annotation
/// naming the guard, and a guard the manifest gates or marks advisory is
/// treated exactly as its old step's `if:` and warning wrapper did.
void main() {
  group('run_guards.sh', () {
    late Directory sandbox;
    late String driverPath;

    setUp(() {
      sandbox = Directory.systemTemp.createTempSync('run_guards_');
      driverPath = File(
        p.join(Directory.current.path, 'scripts', 'ci', 'run_guards.sh'),
      ).absolute.path;
    });

    tearDown(() {
      sandbox.deleteSync(recursive: true);
    });

    String writeManifest(String contents) {
      final file = File(p.join(sandbox.path, 'guards.tsv'))
        ..writeAsStringSync(contents);
      return file.path;
    }

    ProcessResult runDriver(
      List<String> args, {
      bool onActions = true,
    }) {
      return Process.runSync(
        'bash',
        [driverPath, ...args],
        environment: {
          'GITHUB_ACTIONS': onActions ? 'true' : 'false',
          'GUARDS_JOBS': '3',
        },
      );
    }

    group('replay', () {
      test('prints every guard in manifest order, not completion order', () {
        final manifest = writeManifest(
          'slow\t-\tsleep 1; echo slow-output\n'
          'fast\t-\techo fast-output\n'
          '# a comment between entries\n'
          '\n'
          'last\t-\techo last-output\n',
        );

        final result = runDriver(['--manifest', manifest]);

        expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
        final stdout = result.stdout as String;
        final slow = stdout.indexOf('::group::✅ slow');
        final fast = stdout.indexOf('::group::✅ fast');
        final last = stdout.indexOf('::group::✅ last');
        expect(slow, greaterThanOrEqualTo(0));
        expect(fast, greaterThan(slow));
        expect(last, greaterThan(fast));
        expect(stdout, contains('slow-output'));
        expect(stdout, contains('fast-output'));
        expect(stdout, contains('last-output'));
        expect(stdout, contains('Guards: 3 passed, 0 failed, 0 skipped'));
      });

      test('uses plain headers outside GitHub Actions', () {
        final manifest = writeManifest('only\t-\techo hi\n');

        final result = runDriver(['--manifest', manifest], onActions: false);

        expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
        expect(result.stdout, contains('=== ✅ only ('));
        expect(result.stdout, isNot(contains('::group::')));
      });
    });

    group('failures', () {
      test('a failing guard fails the run and is annotated by name', () {
        final manifest = writeManifest(
          'good\t-\techo fine\n'
          'bad guard\t-\techo diagnostic-line; exit 3\n'
          'also good\t-\techo fine-too\n',
        );

        final result = runDriver(['--manifest', manifest]);

        expect(result.exitCode, 1, reason: '${result.stdout}${result.stderr}');
        final stdout = result.stdout as String;
        expect(stdout, contains('::group::✅ good'));
        expect(stdout, contains('::group::❌ bad guard ('));
        expect(stdout, contains('exit 3)'));
        expect(stdout, contains('diagnostic-line'));
        expect(
          stdout,
          contains('::error title=bad guard::Guard failed (exit 3)'),
        );
        expect(stdout, contains('::group::✅ also good'));
        expect(stdout, contains('Guards: 2 passed, 1 failed, 0 skipped'));
        expect(stdout, contains('  - bad guard'));
      });

      test('a failing guard does not stop the others from running', () {
        final manifest = writeManifest(
          'first\t-\texit 1\n'
          'second\t-\techo second-ran\n'
          'third\t-\techo third-ran\n',
        );

        final result = runDriver(['--manifest', manifest, '--jobs', '1']);

        expect(result.exitCode, 1);
        expect(result.stdout, contains('second-ran'));
        expect(result.stdout, contains('third-ran'));
      });
    });

    group('flags', () {
      test(
        'native guards are skipped with --native false and run with true',
        () {
          final manifest = writeManifest(
            'plain\t-\techo plain-ran\n'
            'native only\tnative\techo native-ran\n',
          );

          final skipped = runDriver([
            '--manifest',
            manifest,
            '--native',
            'false',
          ]);
          expect(
            skipped.exitCode,
            0,
            reason: '${skipped.stdout}${skipped.stderr}',
          );
          expect(skipped.stdout, contains('plain-ran'));
          expect(skipped.stdout, isNot(contains('native-ran')));
          expect(skipped.stdout, contains('⏭️  native only — skipped'));
          expect(
            skipped.stdout,
            contains('Guards: 1 passed, 0 failed, 1 skipped'),
          );

          final ran = runDriver(['--manifest', manifest, '--native', 'true']);
          expect(ran.exitCode, 0, reason: '${ran.stdout}${ran.stderr}');
          expect(ran.stdout, contains('native-ran'));
          expect(ran.stdout, contains('Guards: 2 passed, 0 failed, 0 skipped'));
        },
      );

      test('an advisory guard never fails the run', () {
        final manifest = writeManifest(
          'size report\tadvisory\techo "WARN [file_size_ceiling]: foo.dart grew"; exit 0\n'
          'crashy advisory\tadvisory\techo boom; exit 7\n',
        );

        final result = runDriver(['--manifest', manifest]);

        expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
        final stdout = result.stdout as String;
        expect(stdout, contains('::group::🟡 size report ('));
        expect(
          stdout,
          contains(
            '::warning title=size report (advisory)::WARN [file_size_ceiling]: foo.dart grew',
          ),
        );
        expect(
          stdout,
          contains('::warning title=crashy advisory (advisory)::Exited 7.'),
        );
        expect(stdout, isNot(contains('::error')));
        expect(stdout, contains('Guards: 2 passed, 0 failed, 0 skipped'));
      });

      test('--list prints each guard with its run/skip decision', () {
        final manifest = writeManifest(
          'plain\t-\techo a\n'
          'gated\tnative\techo b\n',
        );

        final result = runDriver([
          '--manifest',
          manifest,
          '--native',
          'false',
          '--list',
        ]);

        expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
        expect(
          result.stdout,
          equals('run\tplain\t-\techo a\nskip\tgated\tnative\techo b\n'),
        );
      });
    });

    group('manifest validation', () {
      test('a malformed line is rejected with its line number', () {
        final manifest = writeManifest(
          'fine\t-\techo ok\n'
          'missing command\t-\n',
        );

        final result = runDriver(['--manifest', manifest]);

        expect(result.exitCode, 2);
        expect(
          result.stderr,
          contains(':2: expected <name>TAB<flags>TAB<command>'),
        );
      });

      test('an unknown flag is rejected', () {
        final manifest = writeManifest('weird\tsometimes\techo ok\n');

        final result = runDriver(['--manifest', manifest]);

        expect(result.exitCode, 2);
        expect(result.stderr, contains(":1: unknown flag 'sometimes'"));
      });

      test('a missing manifest is rejected', () {
        final result = runDriver([
          '--manifest',
          p.join(sandbox.path, 'nope.tsv'),
        ]);

        expect(result.exitCode, 2);
        expect(result.stderr, contains('Guard manifest not found'));
      });
    });

    group('committed manifest', () {
      final manifestFile = File(p.join('scripts', 'ci', 'guards.tsv'));

      List<String> manifestCommands() => manifestFile
          .readAsLinesSync()
          .where((line) => line.isNotEmpty && !line.startsWith('#'))
          .map((line) => line.split('\t').last)
          .toList();

      test('parses and lists every entry as runnable', () {
        final result = runDriver(['--manifest', manifestFile.path, '--list']);

        expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
        final rows = (result.stdout as String).trim().split('\n');
        expect(rows, hasLength(manifestCommands().length));
        expect(rows.every((row) => row.startsWith('run\t')), isTrue);
      });

      test('names every scripts/check_*.sh, or the test names where it runs', () {
        // A check script that is in neither list runs nowhere. Add a new guard
        // to the manifest; add it here only when it is wired into a different
        // job or workflow, and say which.
        const runsElsewhere = <String, String>{
          'check_async_safety_ceiling.sh': 'its own Async Safety job: rewrites analysis_options.yaml in place',
          'check_codemagic_groups.sh': 'Codemagic Variable Groups job',
          'check_store_url_identifiers.sh': 'CI Configuration Tests job',
          'check_web_bundle_file_size.sh': 'Web Bundle Size job',
          'check_apple_required_reason_catalogue.sh':
              'Apple Required-Reason Catalogue Probe workflow',
          'check_coordinator_route_serving.sh':
              'Coordinator Route Probe workflow and codemagic.yaml',
          'check_ios_analytics_product.sh': 'codemagic.yaml',
          'check_ios_extension_signing_contract.sh': 'codemagic.yaml',
          'check_signing_endpoint.sh': 'codemagic.yaml',
          'check_supporters_config.sh':
              'codemagic.yaml, and check_codemagic_groups.sh calls it',
          'check_todos.sh': 'not wired anywhere; predates the manifest',
        };

        final checkScripts = Directory('scripts')
            .listSync()
            .whereType<File>()
            .map((f) => p.basename(f.path))
            .where((n) => n.startsWith('check_') && n.endsWith('.sh'))
            .toSet();
        expect(checkScripts, isNotEmpty);

        final manifested = manifestCommands()
            .map((c) => RegExp(r'check_[a-z0-9_]+\.sh').firstMatch(c)?.group(0))
            .whereType<String>()
            .toSet();

        final unaccounted = checkScripts
            .difference(manifested)
            .difference(runsElsewhere.keys.toSet());
        expect(
          unaccounted,
          isEmpty,
          reason: 'add each to scripts/ci/guards.tsv or to runsElsewhere',
        );

        final stale = runsElsewhere.keys.toSet().difference(checkScripts);
        expect(stale, isEmpty, reason: 'runsElsewhere names a deleted script');

        final doubleListed = manifested.intersection(
          runsElsewhere.keys.toSet(),
        );
        expect(
          doubleListed,
          isEmpty,
          reason: 'listed both in the manifest and here',
        );
      });
    });
  });
}
