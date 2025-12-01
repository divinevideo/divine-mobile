import 'package:flutter/foundation.dart';
// ABOUTME: Tool to check that Dart files don't exceed maximum line count
// ABOUTME: Enforces 200 line limit per file for better maintainability

import 'dart:io';

const int maxLines = 200;
const List<String> excludePatterns = [
  '.g.dart',
  '.freezed.dart',
  '.mocks.dart',
  'generated/',
];

void main(List<String> args) {
  debugPrint('Checking file lengths (max $maxLines lines)...\n');

  final libDir = Directory('lib');
  if (!libDir.existsSync()) {
    debugPrint('Error: lib directory not found');
    exit(1);
  }

  final violations = <String, int>{};

  // Recursively check all Dart files
  libDir.listSync(recursive: true).forEach((entity) {
    if (entity is File && entity.path.endsWith('.dart')) {
      // Skip excluded patterns
      var shouldSkip = false;
      for (final pattern in excludePatterns) {
        if (entity.path.contains(pattern)) {
          shouldSkip = true;
          break;
        }
      }

      if (!shouldSkip) {
        final lines = entity.readAsLinesSync();
        if (lines.length > maxLines) {
          violations[entity.path] = lines.length;
        }
      }
    }
  });

  if (violations.isEmpty) {
    debugPrint('✅ All files are within the $maxLines line limit!');
    exit(0);
  } else {
    debugPrint(
      '❌ Found ${violations.length} files exceeding $maxLines lines:\n',
    );

    violations.forEach((path, lineCount) {
      final relativePath = path.replaceFirst('${Directory.current.path}/', '');
      debugPrint(
        '  $relativePath: $lineCount lines (${lineCount - maxLines} over limit)',
      );
    });

    debugPrint('\nPlease refactor these files to be under $maxLines lines.');
    exit(1);
  }
}
