// ABOUTME: Tests for Future.delayed detection tool
// ABOUTME: Verifies ability to find and report Future.delayed usage across codebase

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FutureDelayedDetector', () {
    setUp(() {
      // Ensure test directory exists
      final testDir = Directory('test/temp');
      if (!testDir.existsSync()) {
        testDir.createSync(recursive: true);
      }
    });

    test('tool exists and can be executed', () {
      final toolFile = File('tools/detect_future_delayed.dart');
      expect(
        toolFile.existsSync(),
        isTrue,
        reason: 'detect_future_delayed.dart tool should exist',
      );
    });

    test('detects simple Future.delayed usage', () {
      // Create a test file with Future.delayed
      final testDir = Directory('test/temp');
      if (!testDir.existsSync()) {
        testDir.createSync(recursive: true);
      }

      final testFile = File('test/temp/test_future_delayed.dart');
      testFile.writeAsStringSync('''
import 'dart:async';

class TestClass {
  void badMethod() async {
    await Future.delayed(Duration(seconds: 2));
    Log.info('Done');
  }
}
''');

      // Run the detection tool
      final result = Process.runSync('dart', [
        'run',
        'tools/detect_future_delayed.dart',
        'test/temp',
      ], workingDirectory: Directory.current.path);

      expect(
        result.exitCode,
        equals(1),
        reason: 'Should exit with code 1 when Future.delayed is found',
      );
      expect(
        result.stdout.toString(),
        contains('test_future_delayed.dart'),
        reason: 'Should report the file containing Future.delayed',
      );
      expect(
        result.stdout.toString(),
        contains('Line 5'),
        reason: 'Should report the line number',
      );
      expect(
        result.stdout.toString(),
        contains('await Future.delayed'),
        reason: 'Should show the problematic code',
      );

      // Cleanup
      testFile.deleteSync();
    });

    test('detects Future.delayed with const Duration', () {
      final testFile = File('test/temp/test_const_duration.dart');
      testFile.writeAsStringSync('''
import 'dart:async';

void delayedOperation() {
  Future.delayed(const Duration(milliseconds: 500), () {
    Log.info('Delayed action');
  });
}
''');

      final result = Process.runSync('dart', [
        'run',
        'tools/detect_future_delayed.dart',
        'test/temp',
      ], workingDirectory: Directory.current.path);

      expect(result.exitCode, equals(1));
      expect(result.stdout.toString(), contains('test_const_duration.dart'));
      expect(result.stdout.toString(), contains('Line 4'));

      testFile.deleteSync();
    });

    test('detects Future.delayed in expression', () {
      final testFile = File('test/temp/test_expression.dart');
      testFile.writeAsStringSync('''
import 'dart:async';

Future<void> waitAndReturn() =>
    Future.delayed(Duration(seconds: 1)).then((_) => Log.info('Done'));
''');

      final result = Process.runSync('dart', [
        'run',
        'tools/detect_future_delayed.dart',
        'test/temp',
      ], workingDirectory: Directory.current.path);

      expect(result.exitCode, equals(1));
      expect(result.stdout.toString(), contains('test_expression.dart'));
      expect(result.stdout.toString(), contains('Line 4'));

      testFile.deleteSync();
    });

    test('counts total Future.delayed occurrences', () {
      // Create multiple test files
      File('test/temp/file1.dart').writeAsStringSync('''
import 'dart:async';
void test1() async {
  await Future.delayed(Duration(seconds: 1));
  await Future.delayed(Duration(seconds: 2));
}
''');

      File('test/temp/file2.dart').writeAsStringSync('''
import 'dart:async';
void test2() => Future.delayed(Duration(milliseconds: 100));
''');

      final result = Process.runSync('dart', [
        'run',
        'tools/detect_future_delayed.dart',
        'test/temp',
      ], workingDirectory: Directory.current.path);

      expect(
        result.stdout.toString(),
        contains('Total Future.delayed occurrences: 3'),
        reason: 'Should count total occurrences',
      );
      expect(
        result.stdout.toString(),
        contains('Files affected: 2'),
        reason: 'Should count affected files',
      );

      // Cleanup
      File('test/temp/file1.dart').deleteSync();
      File('test/temp/file2.dart').deleteSync();
    });

    test('suggests AsyncUtils replacements', () {
      final testFile = File('test/temp/test_suggestions.dart');
      testFile.writeAsStringSync('''
import 'dart:async';

// Polling pattern
void pollCondition() async {
  while (!someCondition) {
    await Future.delayed(Duration(milliseconds: 100));
  }
}

// Simple delay
void simpleDelay() async {
  await Future.delayed(Duration(seconds: 2));
  doSomething();
}

// Retry pattern
Future<T> retryOperation<T>(Future<T> Function() operation) async {
  for (int i = 0; i < 3; i++) {
    try {
      return await operation();
    } catch (e) {
      if (i < 2) {
        await Future.delayed(Duration(seconds: 1));
      } else {
        rethrow;
      }
    }
  }
  throw Exception('Should not reach here');
}
''');

      final result = Process.runSync('dart', [
        'run',
        'tools/detect_future_delayed.dart',
        '--suggest',
        'test/temp',
      ], workingDirectory: Directory.current.path);

      expect(
        result.stdout.toString(),
        contains('AsyncUtils.waitForCondition'),
        reason: 'Should suggest waitForCondition for polling',
      );
      expect(
        result.stdout.toString(),
        contains('AsyncUtils.retry'),
        reason: 'Should suggest retry for retry patterns',
      );
      expect(
        result.stdout.toString(),
        contains('Timer or platform callbacks'),
        reason: 'Should suggest alternatives for simple delays',
      );

      testFile.deleteSync();
    });

    test('can output results in JSON format', () {
      final testFile = File('test/temp/test_json.dart');
      testFile.writeAsStringSync('''
import 'dart:async';
void test() => Future.delayed(Duration(seconds: 1));
''');

      final result = Process.runSync('dart', [
        'run',
        'tools/detect_future_delayed.dart',
        '--format=json',
        'test/temp',
      ], workingDirectory: Directory.current.path);

      expect(
        result.stdout.toString(),
        contains('"file":'),
        reason: 'JSON output should contain file field',
      );
      expect(
        result.stdout.toString(),
        contains('"line":'),
        reason: 'JSON output should contain line field',
      );
      expect(
        result.stdout.toString(),
        contains('"code":'),
        reason: 'JSON output should contain code field',
      );
      expect(
        result.stdout.toString(),
        contains('"suggestion":'),
        reason: 'JSON output should contain suggestion field',
      );

      testFile.deleteSync();
    });

    test('excludes test files by default', () {
      final testFile = File('test/temp/some_test.dart');
      testFile.writeAsStringSync('''
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses Future.delayed', () async {
    await Future.delayed(Duration(seconds: 1));
    expect(true, isTrue);
  });
}
''');

      final result = Process.runSync('dart', [
        'run',
        'tools/detect_future_delayed.dart',
        'test/temp',
      ], workingDirectory: Directory.current.path);

      expect(
        result.exitCode,
        equals(0),
        reason: 'Should exit with 0 when only test files have Future.delayed',
      );
      expect(
        result.stdout.toString(),
        contains('No Future.delayed found in source files'),
        reason: 'Should report no occurrences in source files',
      );

      testFile.deleteSync();
    });

    test('can include test files with flag', () {
      final testFile = File('test/temp/some_test.dart');
      testFile.writeAsStringSync('''
import 'dart:async';
void main() {
  test('test', () => Future.delayed(Duration(seconds: 1)));
}
''');

      final result = Process.runSync('dart', [
        'run',
        'tools/detect_future_delayed.dart',
        '--include-tests',
        'test/temp',
      ], workingDirectory: Directory.current.path);

      expect(
        result.exitCode,
        equals(1),
        reason: 'Should find Future.delayed when including tests',
      );
      expect(
        result.stdout.toString(),
        contains('some_test.dart'),
        reason: 'Should report test files when included',
      );

      testFile.deleteSync();
    });

    test('provides fix option to replace with AsyncUtils', () {
      final testFile = File('test/temp/test_fix.dart');
      testFile.writeAsStringSync('''
import 'dart:async';

void waitForInit() async {
  // Wait for initialization
  await Future.delayed(Duration(milliseconds: 500));
  startApp();
}
''');

      // Run with --fix option
      final result = Process.runSync('dart', [
        'run',
        'tools/detect_future_delayed.dart',
        '--fix',
        'test/temp',
      ], workingDirectory: Directory.current.path);

      expect(result.exitCode, equals(0), reason: 'Should succeed when fixing');
      expect(
        result.stdout.toString(),
        contains('Fixed 1 occurrence'),
        reason: 'Should report fixes made',
      );

      // Verify the file was updated
      final fixedContent = testFile.readAsStringSync();
      expect(
        fixedContent,
        contains("import 'dart:async'"),
        reason: 'Should have async import for Timer',
      );
      expect(
        fixedContent.contains('Future.delayed'),
        isFalse,
        reason: 'Should remove Future.delayed',
      );
      expect(
        fixedContent,
        contains('Timer('),
        reason: 'Should replace with Timer for simple delays',
      );

      testFile.deleteSync();
    });

    tearDown(() {
      // Clean up test directory
      final testDir = Directory('test/temp');
      if (testDir.existsSync()) {
        testDir.deleteSync(recursive: true);
      }
    });
  });
}
