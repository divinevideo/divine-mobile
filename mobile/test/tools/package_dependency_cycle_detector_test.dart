// ABOUTME: Tests the workspace package dependency-cycle detector.
// ABOUTME: Covers path, shorthand, and version-constrained workspace edges.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Scripts live outside lib/ and cannot be imported through package:openvine.
// ignore: avoid_relative_lib_imports
import '../../scripts/lib/package_dependency_cycle_detector.dart';

void main() {
  group('findPackageDependencyCycle', () {
    late Directory temporaryDirectory;
    late Directory packagesDirectory;

    void writePackage(
      String name, [
      Map<String, String?> dependencies = const {},
    ]) {
      final dependencyBlock = dependencies.isEmpty
          ? ''
          : '''
dependencies:
${dependencies.entries.map((entry) => entry.value == null ? '  ${entry.key}:' : '  ${entry.key}: ${entry.value}').join('\n')}
''';
      File('${packagesDirectory.path}/$name/pubspec.yaml')
        ..createSync(recursive: true)
        ..writeAsStringSync('name: $name\n$dependencyBlock');
    }

    setUp(() {
      temporaryDirectory = Directory.systemTemp.createTempSync(
        'package_dependency_cycle_test_',
      );
      packagesDirectory = Directory('${temporaryDirectory.path}/packages')
        ..createSync();
    });

    tearDown(() {
      temporaryDirectory.deleteSync(recursive: true);
    });

    test('accepts an acyclic dependency graph', () {
      writePackage('logging_types');
      writePackage('models', {'logging_types': null});
      writePackage('unified_logger', {'logging_types': '^1.0.0'});

      expect(findPackageDependencyCycle(packagesDirectory), isNull);
    });

    test('finds a cycle through shorthand declarations', () {
      writePackage('models', {'unified_logger': null});
      writePackage('unified_logger', {'models': null});

      expect(findPackageDependencyCycle(packagesDirectory), [
        'models',
        'unified_logger',
        'models',
      ]);
    });

    test('finds a cycle through version-constrained declarations', () {
      writePackage('alpha', {'beta': '^1.0.0'});
      writePackage('beta', {'gamma': '^1.0.0'});
      writePackage('gamma', {'alpha': '^1.0.0'});

      expect(findPackageDependencyCycle(packagesDirectory), [
        'alpha',
        'beta',
        'gamma',
        'alpha',
      ]);
    });

    test('finds a multi-package cycle through path declarations', () {
      writePackage('alpha', {'beta': '{path: ../beta}'});
      writePackage('beta', {'gamma': '{path: ../gamma}'});
      writePackage('gamma', {'alpha': '{path: ../alpha}'});

      expect(findPackageDependencyCycle(packagesDirectory), [
        'alpha',
        'beta',
        'gamma',
        'alpha',
      ]);
    });
  });
}
