// ABOUTME: Test for verifying test infrastructure setup meets quality requirements
// ABOUTME: Ensures coverage, analysis options, and test helpers are properly configured

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  group('Test Infrastructure Setup', () {
    test('analysis_options.yaml has strict quality rules', () {
      final analysisFile = File('analysis_options.yaml');
      expect(
        analysisFile.existsSync(),
        isTrue,
        reason: 'analysis_options.yaml should exist',
      );

      final content = analysisFile.readAsStringSync();
      final yaml = loadYaml(content) as Map;

      // Check for required analyzer rules
      final analyzerRules = yaml['analyzer'] as Map?;
      expect(analyzerRules, isNotNull, reason: 'analyzer section should exist');

      // Check for strict errors
      final errors = analyzerRules?['errors'] as Map?;
      expect(
        errors?['avoid_future_delayed'],
        equals('error'),
        reason: 'Future.delayed should be configured as error',
      );
      expect(
        errors?['prefer_typing_uninitialized_variables'],
        equals('error'),
        reason: 'Untyped variables should be errors',
      );
      expect(
        errors?['missing_return'],
        equals('error'),
        reason: 'Missing returns should be errors',
      );

      // Check for linter rules
      final linterSection = yaml['linter'] as Map?;
      expect(linterSection, isNotNull, reason: 'Linter section should exist');
      final linterRules = linterSection?['rules'] as Map?;
      expect(linterRules, isNotNull, reason: 'Linter rules should exist');
      expect(
        linterRules?['avoid_future_delayed'],
        isTrue,
        reason: 'Should have avoid_future_delayed rule',
      );
      expect(
        linterRules?['prefer_const_constructors'],
        isTrue,
        reason: 'Should prefer const constructors',
      );
      expect(
        linterRules?['require_trailing_commas'],
        isTrue,
        reason: 'Should require trailing commas for consistency',
      );
    });

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

    test('pre-commit hooks are configured', () {
      final preCommitFile = File('../.pre-commit-config.yaml');
      expect(
        preCommitFile.existsSync(),
        isTrue,
        reason: '.pre-commit-config.yaml should exist',
      );

      final content = preCommitFile.readAsStringSync();
      expect(
        content,
        contains('flutter analyze'),
        reason: 'Pre-commit should run flutter analyze',
      );
      expect(
        content,
        contains('flutter test'),
        reason: 'Pre-commit should run flutter test',
      );
      expect(
        content,
        contains('dart format'),
        reason: 'Pre-commit should run dart format',
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

    test('in-memory service implementations exist', () {
      final inMemoryDir = Directory('test/in_memory');
      expect(
        inMemoryDir.existsSync(),
        isTrue,
        reason: 'test/in_memory directory should exist',
      );

      // Check for required in-memory implementations
      final requiredImplementations = [
        'in_memory_nostr_service.dart',
        'in_memory_video_manager.dart',
        'in_memory_auth_service.dart',
        'in_memory_storage_service.dart',
      ];

      for (final impl in requiredImplementations) {
        final implFile = File('${inMemoryDir.path}/$impl');
        expect(implFile.existsSync(), isTrue, reason: '$impl should exist');
      }
    });

    test('GitHub Actions workflow is configured', () {
      final workflowFile = File('../.github/workflows/flutter_test.yml');
      expect(
        workflowFile.existsSync(),
        isTrue,
        reason: 'Flutter test workflow should exist',
      );

      final content = workflowFile.readAsStringSync();
      expect(
        content,
        contains('flutter test'),
        reason: 'Workflow should run flutter test',
      );
      expect(
        content,
        contains('--coverage'),
        reason: 'Workflow should generate coverage',
      );
      expect(
        content,
        contains('min_coverage: 80'),
        reason: 'Workflow should enforce 80% coverage',
      );
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
              content.contains("import 'package:mockito/mockito.dart'")) {
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

    test('max file length enforcer exists', () {
      final analysisFile = File('analysis_options.yaml');
      final content = analysisFile.readAsStringSync();

      // Check for file length rule
      expect(
        content,
        contains('lines_longer_than_200_chars'),
        reason: 'Should have max line length rule',
      );

      // Additional check for custom plugin if needed
      final customRulesFile = File('tools/max_file_length.dart');
      expect(
        customRulesFile.existsSync(),
        isTrue,
        reason: 'Custom file length checker should exist',
      );
    });
  });
}
