// ABOUTME: Test enforcing consistent file naming conventions across lib/
// ABOUTME: Validates that no source file name carries a temporal suffix

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
