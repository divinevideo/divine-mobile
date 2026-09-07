// ABOUTME: Test for verifying test infrastructure setup meets quality requirements
// ABOUTME: Ensures coverage, analysis options, and test helpers are properly configured

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  group('Test Infrastructure Setup', () {
    test('test coverage configuration exists', () {
      final coverageConfigFile = File('coverage_config.yaml');
      expect(
        coverageConfigFile.existsSync(),
        isTrue,
        reason: 'coverage_config.yaml should exist',
      );

      final content = coverageConfigFile.readAsStringSync();
      final yaml = loadYaml(content) as Map;

      // Check minimum coverage requirements
      expect(
        yaml['minimum_coverage'],
        equals(80),
        reason: 'Minimum coverage should be 80%',
      );
      expect(
        yaml['fail_on_coverage_drop'],
        isTrue,
        reason: 'Should fail on coverage drop',
      );
    });

    test('hook installer enforces generated files are up to date', () {
      final hookInstallerFile = File('../scripts/install-hooks.sh');
      expect(
        hookInstallerFile.existsSync(),
        isTrue,
        reason: 'scripts/install-hooks.sh should exist',
      );

      final content = hookInstallerFile.readAsStringSync();
      expect(
        content,
        contains('dart run build_runner build --delete-conflicting-outputs'),
        reason:
            'Hook installer should verify generated files with build_runner',
      );
      expect(
        content,
        contains('Generated files changed during verification'),
        reason: 'Pre-commit hook should fail when generated files drift',
      );
      expect(
        content,
        contains('Generated files are out of date.'),
        reason: 'Pre-push hook should mirror the CI generated-files failure',
      );
      expect(
        content,
        contains('git rev-parse --git-common-dir'),
        reason:
            'Hook installer should work from worktrees as well as the main checkout',
      );
      expect(
        content,
        contains('mise exec -- flutter'),
        reason:
            'Hook installer should use mise exec for pinned Flutter version',
      );
      expect(
        content,
        contains('mise exec -- dart'),
        reason: 'Hook installer should use mise exec for pinned Dart version',
      );
    });

    test('test data builders exist', () {
      final testBuildersDir = Directory('test/builders');
      expect(
        testBuildersDir.existsSync(),
        isTrue,
        reason: 'test/builders directory should exist',
      );

      // Check for required builders
      final requiredBuilders = [
        'video_event_builder.dart',
        'user_profile_builder.dart',
        'nostr_event_builder.dart',
        'auth_state_builder.dart',
      ];

      for (final builder in requiredBuilders) {
        final builderFile = File('${testBuildersDir.path}/$builder');
        expect(
          builderFile.existsSync(),
          isTrue,
          reason: '$builder should exist',
        );
      }
    });

    test('test helper utilities are comprehensive', () {
      final testHelpersFile = File('test/helpers/test_helpers.dart');
      expect(
        testHelpersFile.existsSync(),
        isTrue,
        reason: 'test_helpers.dart should exist',
      );

      final content = testHelpersFile.readAsStringSync();

      // Check for required helper functions
      expect(
        content,
        contains('pumpAndSettleWithTimeout'),
        reason: 'Should have timeout helper for widget tests',
      );
      expect(
        content,
        contains('createTestProviderScope'),
        reason: 'Should have provider test helper',
      );
      expect(
        content,
        contains('mockNetworkImages'),
        reason: 'Should have network image mocking helper',
      );
      expect(
        content,
        contains('waitForCondition'),
        reason: 'Should have async condition waiter',
      );
    });

    test('no mock implementations in production code', () {
      final libDir = Directory('lib');
      final mockFiles = <String>[];

      libDir.listSync(recursive: true).forEach((entity) {
        if (entity is File && entity.path.endsWith('.dart')) {
          // Skip scripts and default content directories
          if (entity.path.contains('/scripts/') ||
              entity.path.contains('default_content_service.dart')) {
            return;
          }

          final content = entity.readAsStringSync();
          // Look for mock class definitions or imports
          if (content.contains('class Mock') ||
              content.contains('extends Mock') ||
              content.contains('with Mock') ||
              content.contains("import 'package:mockito/mockito.dart'") ||
              content.contains("import 'package:mocktail/mocktail.dart'")) {
            mockFiles.add(entity.path);
          }
        }
      });

      expect(
        mockFiles,
        isEmpty,
        reason: 'No mock implementations should exist in production lib/ code',
      );
    });
  });
}
