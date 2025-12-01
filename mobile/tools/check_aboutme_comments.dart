import 'package:flutter/foundation.dart';
// ABOUTME: Tool to check that all Dart files have proper ABOUTME comments
// ABOUTME: Enforces documentation standards for better code understanding

import 'dart:io';

void main(List<String> args) {
  debugPrint('Checking ABOUTME comments...\n');

  final libDir = Directory('lib');
  if (!libDir.existsSync()) {
    debugPrint('Error: lib directory not found');
    exit(1);
  }

  final violations = <String>[];

  // Recursively check all Dart files
  libDir.listSync(recursive: true).forEach((entity) {
    if (entity is File && entity.path.endsWith('.dart')) {
      // Skip generated files
      if (entity.path.contains('.g.dart') ||
          entity.path.contains('.freezed.dart') ||
          entity.path.contains('.mocks.dart') ||
          entity.path.contains('/generated/')) {
        return;
      }

      if (!hasValidAboutMeComment(entity)) {
        violations.add(entity.path);
      }
    }
  });

  if (violations.isEmpty) {
    debugPrint('✅ All files have proper ABOUTME comments!');
    exit(0);
  } else {
    debugPrint(
      '❌ Found ${violations.length} files without proper ABOUTME comments:\n',
    );

    for (final path in violations) {
      final relativePath = path.replaceFirst('${Directory.current.path}/', '');
      debugPrint('  $relativePath');
    }

    debugPrint('\nEach file must start with two ABOUTME comment lines:');
    debugPrint('// ABOUTME: Brief description of what this file does');
    debugPrint('// ABOUTME: Second line with key responsibility');
    exit(1);
  }
}

bool hasValidAboutMeComment(File file) {
  final lines = file.readAsLinesSync();

  if (lines.length < 2) {
    return false;
  }

  // Check first two non-empty lines for ABOUTME comments
  var foundCount = 0;
  for (var i = 0; i < lines.length && foundCount < 2; i++) {
    final line = lines[i].trim();

    // Skip empty lines and other comments
    if (line.isEmpty) continue;
    if (line.startsWith('//') && !line.startsWith('// ABOUTME:')) continue;

    // Check for ABOUTME comment
    if (line.startsWith('// ABOUTME:')) {
      foundCount++;
    } else {
      // If we hit non-comment, non-empty line before finding 2 ABOUTME comments
      break;
    }
  }

  return foundCount >= 2;
}
