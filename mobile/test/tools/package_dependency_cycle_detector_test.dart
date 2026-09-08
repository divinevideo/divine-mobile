// ABOUTME: Tests the workspace path-dependency cycle detector.
// ABOUTME: Covers acyclic, direct-cycle, and multi-package-cycle graphs.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Scripts live outside lib/ and cannot be imported through package:openvine.
// ignore: avoid_relative_lib_imports
import '../../scripts/lib/package_dependency_cycle_detector.dart';

void main() {
  group('findPackageDependencyCycle', () {
    late Directory temporaryDirectory;
    late Directory packagesDirectory;

    void writePackage(String name, [List<String> dependencies = const []]) {
      final dependencyBlock = dependencies.isEmpty
          ? ''
          : '''
dependencies:
${dependencies.map((dependency) => '  $dependency:\n    path: ../$dependency').join('\n')}
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
      writePackage('models', ['logging_types']);
      writePackage('unified_logger', ['logging_types']);

      expect(findPackageDependencyCycle(packagesDirectory), isNull);
    });

    test('finds a direct cycle', () {
      writePackage('models', ['unified_logger']);
      writePackage('unified_logger', ['models']);

      expect(findPackageDependencyCycle(packagesDirectory), [
        'models',
        'unified_logger',
        'models',
      ]);
    });

    test('finds a multi-package cycle', () {
      writePackage('alpha', ['beta']);
      writePackage('beta', ['gamma']);
      writePackage('gamma', ['alpha']);

      expect(findPackageDependencyCycle(packagesDirectory), [
        'alpha',
        'beta',
        'gamma',
        'alpha',
      ]);
    });
  });
}
