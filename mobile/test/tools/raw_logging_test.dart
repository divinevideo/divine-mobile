// ABOUTME: Regression tests for the raw-logging guard and package import ratchet.
// ABOUTME: Covers import forms, list-ratchet semantics, and code-only call detection.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('raw logging guard', () {
    late Directory temporaryDirectory;
    late String mobileDirectory;
    late String baselinePath;
    late String scriptPath;

    void writeMobileFile(String path, String contents) {
      File('$mobileDirectory/$path')
        ..createSync(recursive: true)
        ..writeAsStringSync(contents);
    }

    void writeBaseline(String contents) {
      File(baselinePath)
        ..createSync(recursive: true)
        ..writeAsStringSync(contents);
    }

    ProcessResult runGuard({
      bool update = false,
      String baseRef = 'refs/heads/raw-logging-test-missing',
      bool allowNoBase = true,
    }) {
      return Process.runSync(
        'bash',
        [scriptPath],
        environment: {
          'RAW_LOGGING_MOBILE_DIR': mobileDirectory,
          'RAW_LOGGING_LIB_DIR': '$mobileDirectory/lib',
          'RAW_LOGGING_PACKAGES_DIR': '$mobileDirectory/packages',
          'RAW_LOGGING_PATH_PREFIX': mobileDirectory,
          'RAW_LOGGING_BASELINE_FILE': baselinePath,
          'RAW_LOGGING_BASELINE_REPO_PATH':
              'mobile/scripts/baseline/developer_log_imports.txt',
          'RAW_LOGGING_BASELINE_BASE_REF': baseRef,
          'RAW_LOGGING_ALLOW_NO_BASE': allowNoBase ? '1' : '0',
          if (update) 'UPDATE_BASELINE': '1',
        },
      );
    }

    setUp(() {
      temporaryDirectory = Directory.systemTemp.createTempSync(
        'raw_logging_test',
      );
      mobileDirectory = '${temporaryDirectory.path}/mobile';
      baselinePath =
          '$mobileDirectory/scripts/baseline/developer_log_imports.txt';
      scriptPath = '${Directory.current.path}/scripts/check_raw_logging.sh';
      Directory('$mobileDirectory/lib').createSync(recursive: true);
      Directory('$mobileDirectory/packages').createSync(recursive: true);
      writeBaseline('');
    });

    tearDown(() => temporaryDirectory.deleteSync(recursive: true));

    test('passes with no raw logging', () {
      writeMobileFile('lib/clean.dart', "import 'dart:async';\n");

      final result = runGuard();

      expect(result.exitCode, 0, reason: result.stdout.toString());
      expect(result.stdout, contains('No raw logging violations'));
    });

    for (final importLine in [
      "import 'dart:developer';",
      "import 'dart:developer' as developer;",
      'import "dart:developer" as developer;',
      "import 'stub.dart' if (dart.library.io) 'dart:developer';",
    ]) {
      test('fails NEW for package import: $importLine', () {
        writeMobileFile('packages/example/lib/logging.dart', '$importLine\n');

        final result = runGuard();

        expect(result.exitCode, 1);
        expect(result.stdout, contains('NEW entr(y/ies)'));
        expect(result.stdout, contains('packages/example/lib/logging.dart'));
      });
    }

    test('fails NEW for a formatted multiline conditional import', () {
      writeMobileFile(
        'packages/example/lib/logging.dart',
        "import 'package:example/very_long_developer_logging_stub.dart'\n"
            "    if (dart.library.io) 'dart:developer'\n"
            '    as developer;\n',
      );

      final result = runGuard();

      expect(result.exitCode, 1);
      expect(result.stdout, contains('NEW entr(y/ies)'));
      expect(result.stdout, contains('packages/example/lib/logging.dart'));
    });

    test('comments cannot invent a multiline conditional import', () {
      writeMobileFile(
        'packages/example/lib/logging.dart',
        "/* import 'package:example/logging_stub.dart'\n"
            "    if (dart.library.io) 'dart:developer'; */\n"
            'void log() {}\n',
      );

      expect(runGuard().exitCode, 0);
    });

    test('a baselined package import passes', () {
      writeMobileFile(
        'packages/example/lib/logging.dart',
        "import 'dart:developer';\n",
      );
      writeBaseline(
        'packages/example/lib/logging.dart # legacy dependency boundary\n',
      );

      expect(runGuard().exitCode, 0);
    });

    test('fails STALE after a baselined import is removed', () {
      writeMobileFile('packages/example/lib/logging.dart', 'void log() {}\n');
      writeBaseline('packages/example/lib/logging.dart # legacy\n');

      final result = runGuard();

      expect(result.exitCode, 1);
      expect(result.stdout, contains('baseline entr(y/ies) no longer'));
      expect(
        result.stdout,
        contains('UPDATE_BASELINE=1 bash mobile/scripts/check_raw_logging.sh'),
      );
    });

    test('fails GROWTH against a resolvable base baseline', () {
      writeMobileFile(
        'packages/example/lib/legacy.dart',
        "import 'dart:developer';\n",
      );
      writeBaseline('packages/example/lib/legacy.dart # legacy\n');
      expect(
        Process.runSync('git', [
          'init',
          '-q',
        ], workingDirectory: temporaryDirectory.path).exitCode,
        0,
      );
      expect(
        Process.runSync('git', [
          'add',
          '.',
        ], workingDirectory: temporaryDirectory.path).exitCode,
        0,
      );
      expect(
        Process.runSync('git', [
          '-c',
          'user.name=Raw Logging Test',
          '-c',
          'user.email=raw-logging-test@example.invalid',
          'commit',
          '-qm',
          'fixture baseline',
        ], workingDirectory: temporaryDirectory.path).exitCode,
        0,
      );
      final baseRef = Process.runSync('git', [
        'rev-parse',
        'HEAD',
      ], workingDirectory: temporaryDirectory.path).stdout.toString().trim();

      writeMobileFile(
        'packages/example/lib/new.dart',
        "import 'dart:developer';\n",
      );
      writeBaseline(
        'packages/example/lib/legacy.dart # legacy\n'
        'packages/example/lib/new.dart # attempted growth\n',
      );

      final result = runGuard(baseRef: baseRef, allowNoBase: false);

      expect(result.exitCode, 1);
      expect(result.stdout, contains('baseline GREW'));
      expect(result.stdout, contains('packages/example/lib/new.dart'));
    });

    test('fails closed when the base ref cannot be loaded', () {
      final result = runGuard(allowNoBase: false);

      expect(result.exitCode, 1);
      expect(result.stdout, contains('could not load the baseline'));
    });

    test('UPDATE_BASELINE preserves reason text', () {
      writeMobileFile(
        'packages/example/lib/logging.dart',
        "import 'dart:developer';\n",
      );
      writeBaseline(
        'packages/example/lib/logging.dart # preserve this reason\n',
      );

      final result = runGuard(update: true);

      expect(result.exitCode, 0, reason: result.stdout.toString());
      expect(
        File(baselinePath).readAsStringSync(),
        contains('# preserve this reason'),
      );
    });

    test('app imports are hard failures and cannot be baselined', () {
      writeMobileFile('lib/bad.dart', "import 'dart:developer';\n");

      final result = runGuard(update: true);

      expect(result.exitCode, 1);
      expect(result.stdout, contains('dart:developer import found in app'));
      expect(File(baselinePath).readAsStringSync(), isNot(contains('lib/bad')));
    });

    test('unified_logger is the structural import exemption', () {
      writeMobileFile(
        'packages/unified_logger/lib/unified_logger.dart',
        "import 'dart:developer';\n",
      );

      expect(runGuard().exitCode, 0);
    });

    test('raw print in nostr_sdk is rejected', () {
      writeMobileFile(
        'packages/nostr_sdk/lib/logging.dart',
        "void log() { print('bypass'); }\n",
      );

      final result = runGuard();

      expect(result.exitCode, 1);
      expect(result.stdout, contains('FAIL [avoid_print]'));
      expect(result.stdout, contains('packages/nostr_sdk/lib/logging.dart'));
    });

    test('package test imports are outside the library ratchet', () {
      writeMobileFile(
        'packages/example/test/logging_test.dart',
        "import 'dart:developer';\n",
      );

      expect(runGuard().exitCode, 0);
    });

    test('comments and string bodies do not trigger call checks', () {
      writeMobileFile(
        'lib/commented.dart',
        "// print('comment');\n"
            "/* debugPrint('comment'); */\n"
            "const printText = 'print(value)';\n"
            "const debugText = 'debugPrint(value)';\n",
      );

      expect(runGuard().exitCode, 0);
    });

    test('live inline print and debugPrint calls fail', () {
      writeMobileFile(
        'lib/live_calls.dart',
        "void logBoth() { print('x'); debugPrint('y'); }\n",
      );

      final result = runGuard();

      expect(result.exitCode, 1);
      expect(result.stdout, contains('FAIL [avoid_print]'));
      expect(result.stdout, contains('FAIL [avoid_debugPrint]'));
    });
  });
}
