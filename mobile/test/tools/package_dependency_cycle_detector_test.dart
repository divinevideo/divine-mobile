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
      Map<String, String?> devDependencies = const {},
    ]) {
      final dependencyBlock = dependencies.isEmpty
          ? ''
          : '''
dependencies:
${dependencies.entries.map((entry) => entry.value == null ? '  ${entry.key}:' : '  ${entry.key}: ${entry.value}').join('\n')}
''';
      final devDependencyBlock = devDependencies.isEmpty
          ? ''
          : '''
dev_dependencies:
${devDependencies.entries.map((entry) => entry.value == null ? '  ${entry.key}:' : '  ${entry.key}: ${entry.value}').join('\n')}
''';
      File('${packagesDirectory.path}/$name/pubspec.yaml')
        ..createSync(recursive: true)
        ..writeAsStringSync('name: $name\n$dependencyBlock$devDependencyBlock');
    }

    void writeRawPubspec(String name, String contents) {
      File('${packagesDirectory.path}/$name/pubspec.yaml')
        ..createSync(recursive: true)
        ..writeAsStringSync(contents);
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

    test('ignores cycles that exist only through dev dependencies', () {
      writePackage('core', {'fixtures': null});
      writePackage('fixtures', const {}, {'core': null});

      expect(findPackageDependencyCycle(packagesDirectory), isNull);
    });

    group('shell wrapper', () {
      late String scriptPath;

      ProcessResult runGuard() =>
          Process.runSync('bash', [scriptPath, packagesDirectory.path]);

      setUp(() {
        scriptPath =
            '${Directory.current.path}/scripts/check_package_dependency_cycles.sh';
      });

      test('returns zero and an operator-facing success message', () {
        writePackage('logging_types');
        writePackage('models', {'logging_types': null});

        final result = runGuard();

        expect(result.exitCode, 0, reason: result.stderr.toString());
        expect(
          result.stdout,
          contains(
            'OK [package_dependency_cycles]: workspace package graph is acyclic.',
          ),
        );
      });

      test('returns one and the cycle path', () {
        writePackage('models', {'unified_logger': null});
        writePackage('unified_logger', {'models': null});

        final result = runGuard();

        expect(result.exitCode, 1);
        expect(
          result.stderr,
          contains(
            'FAIL [package_dependency_cycles]: models -> unified_logger -> models',
          ),
        );
      });

      test('returns two and the offending pubspec path', () {
        writeRawPubspec('broken', '');

        final result = runGuard();

        expect(result.exitCode, 2);
        expect(result.stderr, contains('FAIL [package_dependency_cycles]'));
        expect(result.stderr, contains('broken/pubspec.yaml'));
      });
    });

    group('unparseable pubspecs', () {
      Matcher throwsFormatExceptionNaming(String path) => throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains(path),
        ),
      );

      test('reports an empty pubspec by path', () {
        writePackage('logging_types');
        writeRawPubspec('broken', '');

        expect(
          () => findPackageDependencyCycle(packagesDirectory),
          throwsFormatExceptionNaming('broken/pubspec.yaml'),
        );
      });

      test('reports a comment-only pubspec by path', () {
        writePackage('logging_types');
        writeRawPubspec('broken', '# nothing declared yet\n');

        expect(
          () => findPackageDependencyCycle(packagesDirectory),
          throwsFormatExceptionNaming('broken/pubspec.yaml'),
        );
      });

      test('reports a pubspec with no name by path', () {
        writePackage('logging_types');
        writeRawPubspec('broken', 'description: no name key\n');

        expect(
          () => findPackageDependencyCycle(packagesDirectory),
          throwsFormatExceptionNaming('broken/pubspec.yaml'),
        );
      });

      test('reports malformed YAML by path', () {
        writePackage('logging_types');
        writeRawPubspec('broken', 'name: [unterminated\n');

        expect(
          () => findPackageDependencyCycle(packagesDirectory),
          throwsFormatExceptionNaming('broken/pubspec.yaml'),
        );
      });
    });
  });
}
