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

    File serviceFile(String name) => File('${tmp.path}/lib/services/$name');

    void writeLines(String name, int n) {
      serviceFile(
        name,
      ).writeAsStringSync('${List.filled(n, '// line').join('\n')}\n');
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
          'SERVICE_GOD_FILE_SCAN_DIR': '${tmp.path}/lib/services',
          'SERVICE_GOD_FILE_PATH_PREFIX': tmp.path,
          'SERVICE_GOD_FILE_BASELINE_FILE': baselinePath,
          'SERVICE_GOD_FILE_THRESHOLD': '5',
          'SERVICE_GOD_FILE_BASELINE_BASE_REF': baseRef,
          'SERVICE_GOD_FILE_CEILING_ALLOW_NO_BASE': allowNoBase ? '1' : '0',
          'SERVICE_GOD_FILE_BASELINE_REPO_PATH': ?baseRepoPath,
          if (update) 'UPDATE_BASELINE': '1',
        },
      );
    }

    List<String> baselineRows() => File(baselinePath)
        .readAsLinesSync()
        .where((l) => l.isNotEmpty && !l.startsWith('#'))
        .toList();

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('service_god_file_test');
      Directory('${tmp.path}/lib/services').createSync(recursive: true);
      scriptPath = File(
        'scripts/check_service_god_file_ceiling.sh',
      ).absolute.path;
      baselinePath = '${tmp.path}/baseline.txt';
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
      expect(res.stdout, contains('Lock the win by regenerating the baseline'));
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

      final baseline = File(baselinePath);
      baseline.writeAsStringSync(
        baseline.readAsStringSync().replaceFirst(
          'lib/services/large_service.dart\t6',
          'lib/services/auth_service.dart\t9999',
        ),
      );

      final res = run(
        allowNoBase: false,
        baseRef: 'HEAD',
        baseRepoPath:
            'mobile/test/tools/fixtures/service_god_file_base_sizes.txt',
      );
      expect(res.exitCode, 1);
      expect(res.stdout, contains('ADDED a key or RAISED a ceiling'));
      expect(res.stdout, contains('^raised lib/services/auth_service.dart'));
    });
  });
}
