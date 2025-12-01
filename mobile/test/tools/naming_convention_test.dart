// ABOUTME: TDD test for enforcing consistent file and class naming conventions
// ABOUTME: Validates removal of temporal suffixes and proper naming patterns

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  group('Naming Convention Tests', () {
    test('should not have temporal suffixes in file names', () {
      final libDir = Directory('lib');
      final dartFiles = _findDartFiles(libDir);

      final temporalSuffixes = ['_v2', '_new', '_improved', '_old', '_temp'];
      final violatingFiles = <String>[];

      for (final file in dartFiles) {
        final fileName = path.basename(file.path);
        for (final suffix in temporalSuffixes) {
          if (fileName.contains(suffix)) {
            violatingFiles.add(file.path);
            break;
          }
        }
      }

      expect(
        violatingFiles,
        isEmpty,
        reason:
            'Files with temporal suffixes found: ${violatingFiles.join(', ')}\n'
            'These should be renamed to use evergreen naming conventions.',
      );
    });

    test(
      'should follow feature_component_type.dart naming pattern for screens',
      () {
        final screensDir = Directory('lib/screens');
        if (!screensDir.existsSync()) return;

        final screenFiles = _findDartFiles(screensDir);
        final invalidNames = <String>[];

        for (final file in screenFiles) {
          final fileName = path.basenameWithoutExtension(file.path);

          // Should end with _screen
          if (!fileName.endsWith('_screen')) {
            invalidNames.add('${file.path} (should end with _screen)');
          }

          // Should use lowercase_with_underscores
          if (fileName.contains(RegExp('[A-Z]'))) {
            invalidNames.add(
              '${file.path} (should use lowercase_with_underscores)',
            );
          }
        }

        expect(
          invalidNames,
          isEmpty,
          reason:
              'Screen files with invalid naming found: ${invalidNames.join(', ')}',
        );
      },
    );

    test('should follow PascalCase for class names matching file names', () {
      final libDir = Directory('lib');
      final dartFiles = _findDartFiles(libDir);
      final violations = <String>[];

      for (final file in dartFiles) {
        final content = file.readAsStringSync();
        final fileName = path.basenameWithoutExtension(file.path);

        // Convert snake_case to PascalCase for expected class name
        final expectedClassName = _snakeToPascalCase(fileName);

        // Look for class definitions
        final classPattern = RegExp(r'class\s+(\w+)');
        final matches = classPattern.allMatches(content);

        var hasMatchingClass = false;
        for (final match in matches) {
          final className = match.group(1)!;
          if (className == expectedClassName) {
            hasMatchingClass = true;
            break;
          }
        }

        // Only check files that define classes
        if (matches.isNotEmpty && !hasMatchingClass) {
          violations.add(
            '${file.path}: Expected class name $expectedClassName',
          );
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Class names not matching file names: ${violations.join(', ')}',
      );
    });
  });
}

List<File> _findDartFiles(Directory dir) {
  final files = <File>[];
  if (!dir.existsSync()) return files;

  for (final entity in dir.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      files.add(entity);
    }
  }
  return files;
}

String _snakeToPascalCase(String snakeCase) => snakeCase
    .split('_')
    .map(
      (word) => word.isNotEmpty
          ? word[0].toUpperCase() + word.substring(1).toLowerCase()
          : '',
    )
    .join('');
