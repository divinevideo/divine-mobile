import 'package:flutter/foundation.dart';
// ABOUTME: Tool to check that Dart functions don't exceed maximum line count
// ABOUTME: Enforces 30 line limit per function for better maintainability

import 'dart:io';

const int maxFunctionLines = 30;
const List<String> excludePatterns = [
  '.g.dart',
  '.freezed.dart',
  '.mocks.dart',
  'generated/',
];

void main(List<String> args) {
  debugPrint('Checking function lengths (max $maxFunctionLines lines)...\n');

  final libDir = Directory('lib');
  if (!libDir.existsSync()) {
    debugPrint('Error: lib directory not found');
    exit(1);
  }

  final violations = <String, List<FunctionViolation>>{};

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
        final fileViolations = checkFile(entity);
        if (fileViolations.isNotEmpty) {
          violations[entity.path] = fileViolations;
        }
      }
    }
  });

  if (violations.isEmpty) {
    debugPrint('✅ All functions are within the $maxFunctionLines line limit!');
    exit(0);
  } else {
    debugPrint('❌ Found functions exceeding $maxFunctionLines lines:\n');

    violations.forEach((path, fileViolations) {
      final relativePath = path.replaceFirst('${Directory.current.path}/', '');
      debugPrint('  $relativePath:');
      for (final violation in fileViolations) {
        debugPrint(
          '    - ${violation.functionName} at line ${violation.startLine}: '
          '${violation.lineCount} lines (${violation.lineCount - maxFunctionLines} over limit)',
        );
      }
    });

    debugPrint(
      '\nPlease refactor these functions to be under $maxFunctionLines lines.',
    );
    exit(1);
  }
}

List<FunctionViolation> checkFile(File file) {
  final violations = <FunctionViolation>[];
  final lines = file.readAsLinesSync();

  // Simple function detection - looks for common patterns
  // This is a basic implementation that may need refinement
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trim();

    // Check for function/method declarations
    if (_isFunctionDeclaration(line)) {
      final functionName = _extractFunctionName(line);
      final endLine = _findFunctionEnd(lines, i);

      if (endLine != -1) {
        final lineCount = endLine - i + 1;
        if (lineCount > maxFunctionLines) {
          violations.add(
            FunctionViolation(
              functionName: functionName,
              startLine: i + 1,
              lineCount: lineCount,
            ),
          );
        }
      }
    }
  }

  return violations;
}

bool _isFunctionDeclaration(String line) {
  // Skip comments
  if (line.startsWith('//') || line.startsWith('/*')) {
    return false;
  }

  // Common function patterns
  final patterns = [
    RegExp(r'^\s*(static\s+)?(\w+\s+)+\w+\s*\('), // Regular methods
    RegExp(r'^\s*get\s+\w+\s*(=>|\{)'), // Getters
    RegExp(r'^\s*set\s+\w+\s*\('), // Setters
    RegExp(r'^\s*\w+\s*\(.*\)\s*(async\s*)?(=>|\{)'), // Short functions
  ];

  return patterns.any((pattern) => pattern.hasMatch(line));
}

String _extractFunctionName(String line) {
  // Try to extract function name from the line
  final patterns = [
    RegExp(r'(\w+)\s*\('), // Method name before parenthesis
    RegExp(r'get\s+(\w+)'), // Getter name
    RegExp(r'set\s+(\w+)'), // Setter name
  ];

  for (final pattern in patterns) {
    final match = pattern.firstMatch(line);
    if (match != null && match.groupCount > 0) {
      return match.group(1)!;
    }
  }

  return 'unknown';
}

int _findFunctionEnd(List<String> lines, int startIndex) {
  var braceCount = 0;
  var inFunction = false;

  for (var i = startIndex; i < lines.length; i++) {
    final line = lines[i];

    // Handle single-line arrow functions
    if (i == startIndex && line.contains('=>') && line.contains(';')) {
      return i;
    }

    for (final char in line.split('')) {
      if (char == '{') {
        braceCount++;
        inFunction = true;
      } else if (char == '}') {
        braceCount--;
        if (inFunction && braceCount == 0) {
          return i;
        }
      }
    }
  }

  return -1;
}

class FunctionViolation {
  FunctionViolation({
    required this.functionName,
    required this.startLine,
    required this.lineCount,
  });
  final String functionName;
  final int startLine;
  final int lineCount;
}
