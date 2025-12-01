import 'package:flutter/foundation.dart';
// ABOUTME: Script to check for Future.delayed usage in the codebase
// ABOUTME: Run this as part of CI/CD to enforce no Future.delayed pattern

import 'dart:io';

void main(List<String> args) async {
  final libDir = Directory('lib');
  final testDir = Directory('test');

  var violationCount = 0;
  final violations = <String>[];

  debugPrint('Checking for Future.delayed usage...\n');

  // Check lib directory
  if (libDir.existsSync()) {
    await _checkDirectory(libDir, violations);
  }

  // Check test directory (some test patterns might be acceptable)
  if (testDir.existsSync()) {
    await _checkDirectory(testDir, violations, isTest: true);
  }

  violationCount = violations.length;

  if (violationCount > 0) {
    debugPrint('❌ Found $violationCount Future.delayed violations:\n');

    for (final violation in violations) {
      debugPrint(violation);
    }

    debugPrint('\n📖 See docs/FUTURE_DELAYED_MIGRATION.md for migration guide');
    exit(1);
  } else {
    debugPrint('✅ No Future.delayed usage found!');
    exit(0);
  }
}

Future<void> _checkDirectory(
  Directory dir,
  List<String> violations, {
  bool isTest = false,
}) async {
  await for (final entity in dir.list(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      // Skip generated files
      if (entity.path.contains('.g.dart') ||
          entity.path.contains('.freezed.dart') ||
          entity.path.contains('.mocks.dart')) {
        continue;
      }

      // Skip AsyncUtils itself
      if (entity.path.endsWith('async_utils.dart')) {
        continue;
      }

      await _checkFile(entity, violations, isTest: isTest);
    }
  }
}

Future<void> _checkFile(
  File file,
  List<String> violations, {
  bool isTest = false,
}) async {
  final lines = await file.readAsLines();

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final lineNumber = i + 1;

    // Check for Future.delayed pattern
    if (line.contains('Future.delayed') && !line.trim().startsWith('//')) {
      // In tests, allow if it's in a comment explaining old pattern
      if (isTest && _isExampleCode(lines, i)) {
        continue;
      }

      final context = _getContext(lines, i);
      violations.add(
        '${file.path}:$lineNumber - ${line.trim()}\n'
        '  Context:\n$context\n',
      );
    }
  }
}

bool _isExampleCode(List<String> lines, int index) {
  // Check if this is in a comment block showing old patterns
  for (var i = index - 5; i <= index && i >= 0; i++) {
    if (lines[i].contains('OLD PATTERN') ||
        lines[i].contains("what we're replacing") ||
        lines[i].contains('WRONG') ||
        lines[i].contains("DON'T DO THIS")) {
      return true;
    }
  }
  return false;
}

String _getContext(List<String> lines, int index) {
  final buffer = StringBuffer();
  final start = (index - 2).clamp(0, lines.length - 1);
  final end = (index + 2).clamp(0, lines.length - 1);

  for (var i = start; i <= end; i++) {
    final prefix = i == index ? '>>> ' : '    ';
    buffer.writeln('$prefix${lines[i]}');
  }

  return buffer.toString();
}
