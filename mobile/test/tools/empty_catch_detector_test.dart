// ABOUTME: Tests for the AST detector and ratchet behind the empty-catch guard.
// ABOUTME: Pins multiline detection, documented no-ops, and numeric ceilings.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports, scripts are outside lib/ and not importable through package:openvine.
import '../../scripts/lib/empty_catch_detector.dart';

void main() {
  group('findEmptyCatchesInSource', () {
    List<EmptyCatchSite> scan(String source) =>
        findEmptyCatchesInSource(source, path: 'lib/subject.dart');

    test('counts every empty CatchClause form independent of wrapping', () {
      final sites = scan('''
void run() {
  try {} catch (e) {}
  try {} catch (e, stackTrace) {
  }
  try {} on FormatException catch (e) {}
  try {} on FormatException {}
  try {
    work();
  } on LongExceptionName catch (
    error,
    stackTrace,
  ) {
  }
}
''');

      expect(sites, hasLength(5));
      expect(sites.map((site) => site.line), [2, 3, 5, 6, 9]);
    });

    test('does not count line or block-comment-only bodies', () {
      final sites = scan('''
void run() {
  try {} catch (_) {
    // Best-effort cleanup.
  }
  try {} catch (_) { /* Best-effort cleanup. */ }
  try {} catch (_) {

    /* Best-effort cleanup. */

  }
}
''');

      expect(sites, isEmpty);
    });

    test('does not count a comment that touches a brace', () {
      final sites = scan('''
void run() {
  try {} catch (_) {/* documented */}
  try {} catch (_) {// documented
  }
}
''');

      expect(sites, isEmpty);
    });

    test(
      'counts an empty body even when the clause has an outside comment',
      () {
        final sites = scan('''
void run() {
  try {} catch (_) /* not a body explanation */ {}
}
''');

        expect(sites, hasLength(1));
      },
    );

    test('does not count a body containing a statement', () {
      expect(scan('void run() { try {} catch (_) { recover(); } }'), isEmpty);
    });

    test('ignores catch-like text in comments and strings', () {
      final sites = scan('''
// try {} catch (e) {}
const example = 'try {} catch (e) {}';
void run() {}
''');

      expect(sites, isEmpty);
    });

    test('provides stable detail data', () {
      final sites = scan('''
void run() {
  try {} on FormatException catch (error) {}
}
''');

      expect(sites.single.line, 2);
      expect(sites.single.snippet, 'on FormatException catch (error) {}');
    });
  });

  group('shouldScanEmptyCatchFile', () {
    test('includes app and package production libraries', () {
      expect(shouldScanEmptyCatchFile('lib/services/example.dart'), isTrue);
      expect(
        shouldScanEmptyCatchFile('packages/example/lib/src/example.dart'),
        isTrue,
      );
    });

    test('excludes tests, package tools, and generated files', () {
      expect(
        shouldScanEmptyCatchFile('packages/example/test/example_test.dart'),
        isFalse,
      );
      expect(
        shouldScanEmptyCatchFile('packages/example/tool/generate.dart'),
        isFalse,
      );
      expect(shouldScanEmptyCatchFile('lib/example.g.dart'), isFalse);
      expect(
        shouldScanEmptyCatchFile('lib/l10n/generated/messages.dart'),
        isFalse,
      );
    });
  });

  group('empty-catch ceiling ratchet', () {
    late Directory tmp;
    late String scriptPath;
    late String baselinePath;

    ProcessResult run({bool update = false}) => Process.runSync(
      'bash',
      [scriptPath],
      environment: {
        'EMPTY_CATCH_SCAN_DIRS': '${tmp.path}/lib ${tmp.path}/packages',
        'EMPTY_CATCH_PATH_PREFIX': tmp.path,
        'EMPTY_CATCH_BASELINE_FILE': baselinePath,
        // HEAD always resolves, and the absent repo path makes
        // numeric_ratchet.sh take the first-introduction path.
        'EMPTY_CATCH_BASELINE_BASE_REF': 'HEAD',
        'EMPTY_CATCH_BASELINE_REPO_PATH':
            'mobile/scripts/baseline/empty-catch-test-no-base-baseline.txt',
        if (update) 'UPDATE_BASELINE': '1',
      },
    );

    void write(String relativePath, String body) {
      final file = File('${tmp.path}/$relativePath');
      file.parent.createSync(recursive: true);
      file.writeAsStringSync('void run() { try {} $body }');
    }

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('empty_catch_ratchet_test');
      Directory('${tmp.path}/lib').createSync(recursive: true);
      Directory('${tmp.path}/packages/example/lib').createSync(recursive: true);
      scriptPath = File('scripts/check_empty_catch_ceiling.sh').absolute.path;
      baselinePath = '${tmp.path}/baseline.txt';
      File(baselinePath).writeAsStringSync('# zero baseline\n');
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    test('passes with a zero baseline and documented catches', () {
      write('lib/a.dart', 'catch (_) { /* expected */ }');
      expect(run().exitCode, 0);
    });

    test('fails for a new single-line empty catch', () {
      write('lib/a.dart', 'catch (_) {}');
      final result = run();
      expect(result.exitCode, isNot(0));
      expect(result.stdout, contains('lib/a.dart\t1'));
    });

    test('fails for a new multiline package empty catch', () {
      write('packages/example/lib/a.dart', 'catch (_) {\n}');
      final result = run();
      expect(result.exitCode, isNot(0));
      expect(result.stdout, contains('packages/example/lib/a.dart\t1'));
    });

    test('UPDATE_BASELINE records per-file counts', () {
      write('lib/a.dart', 'catch (_) {} try {} catch (_) {}');
      final result = run(update: true);
      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(File(baselinePath).readAsStringSync(), contains('lib/a.dart\t2'));
    });
  });
}
